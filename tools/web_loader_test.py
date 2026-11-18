#!/usr/bin/env python3
"""Exercise the patched Web loader with a real interrupted download and cache reuse."""

from __future__ import annotations

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import re
import socket
import threading
import time
from urllib.parse import urlparse

from playwright.sync_api import sync_playwright


class InterruptingHandler(SimpleHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    wasm_attempts: list[dict] = []
    interrupt_next = True
    lock = threading.Lock()

    def log_message(self, format, *args):
        pass

    def do_GET(self):
        request_path = urlparse(self.path).path
        requested_name = Path(request_path).name
        if requested_name == "play.wasm" or not (
            requested_name.startswith("play.") and requested_name.endswith(".wasm")
        ):
            return super().do_GET()
        path = Path(self.directory) / requested_name
        size = path.stat().st_size
        range_header = self.headers.get("Range")
        start = 0
        if range_header:
            start = int(range_header.removeprefix("bytes=").split("-", 1)[0])
        with self.lock:
            type(self).wasm_attempts.append({"path": request_path, "range": range_header, "start": start})
            should_interrupt = type(self).interrupt_next and not range_header
            if should_interrupt:
                type(self).interrupt_next = False
        self.send_response(206 if range_header else 200)
        self.send_header("Content-Type", "application/wasm")
        self.send_header("Accept-Ranges", "bytes")
        if range_header:
            self.send_header("Content-Range", f"bytes {start}-{size - 1}/{size}")
        self.send_header("Content-Length", str(size - start))
        self.end_headers()
        with path.open("rb") as source:
            source.seek(start)
            remaining = size - start
            if should_interrupt:
                remaining = min(2 * 1024 * 1024, remaining)
            try:
                while remaining > 0:
                    chunk = source.read(min(65536, remaining))
                    if not chunk:
                        break
                    self.wfile.write(chunk)
                    remaining -= len(chunk)
                self.wfile.flush()
                if should_interrupt:
                    self.connection.shutdown(socket.SHUT_RDWR)
                    self.connection.close()
            except (BrokenPipeError, ConnectionResetError, OSError):
                pass
        return None


def wait_for_engine(page, progress_values: list[float], retry_messages: set[str], timeout: float = 90) -> float:
    started = time.monotonic()
    while time.monotonic() - started < timeout:
        state = page.evaluate("""
            () => ({
                status: Boolean(document.getElementById('status')),
                progress: document.getElementById('status-progress')?.value || 0,
                detail: document.getElementById('status-detail')?.textContent || '',
                retry: document.getElementById('status-retry')?.hidden === false,
                notice: document.getElementById('status-notice')?.textContent || '',
            })
        """)
        if not state["status"]:
            return time.monotonic() - started
        progress_values.append(float(state["progress"]))
        if "继续" in state["detail"] or "中断" in state["detail"]:
            retry_messages.add(state["detail"])
        if state["retry"]:
            raise RuntimeError(state["notice"])
        time.sleep(0.05)
    raise TimeoutError("Engine did not start")


def exercise_engine_retry(context, url: str, export_dir: Path, output: Path, result: dict) -> None:
    html = (export_dir / "play.html").read_text(encoding="utf-8")
    version_match = re.search(r'const GAME_VERSION = "([A-Za-z0-9._-]+)"', html)
    if not version_match:
        raise RuntimeError("Patched game version was not found")
    script_path = export_dir / f"play.{version_match.group(1)}.js"
    if not script_path.is_file():
        raise RuntimeError(f"Versioned engine script is missing: {script_path}")
    source = script_path.read_text(encoding="utf-8")
    factory_return = "\t\treturn new Engine(initConfig);"
    injected_return = r"""		const instance = new Engine(initConfig);
		const originalStartGame = instance.startGame;
		instance.startGame = function () {
			const args = arguments;
			return originalStartGame.apply(this, args).then(function (result) {
				if (!window.sessionStorage.getItem('blackhole-injected-start-failure')) {
					window.sessionStorage.setItem('blackhole-injected-start-failure', '1');
					throw new Error('Injected post-initialization failure');
				}
				return result;
			});
		};
		return instance;"""
    injected = source.replace(factory_return, injected_return, 1)
    if injected == source:
        raise RuntimeError("Godot engine factory injection point was not found")
    page = context.new_page()
    console: list[dict] = []
    page_errors: list[str] = []
    resource_requests: list[str] = []
    route_urls: list[str] = []
    result.update({"console": console, "page_errors": page_errors, "resource_requests": resource_requests, "route_urls": route_urls, "checks": {}})
    page.on("console", lambda message: console.append({"type": message.type, "text": message.text}))
    page.on("pageerror", lambda error: page_errors.append(str(error)))
    page.on("request", lambda request: resource_requests.append(request.url) if urlparse(request.url).path.endswith((".wasm", ".pck")) else None)

    def route_engine(route):
        route_urls.append(route.request.url)
        if Path(urlparse(route.request.url).path).name == script_path.name:
            route.fulfill(status=200, content_type="application/javascript", body=injected)
        else:
            route.continue_()

    try:
        page.route("**/*.js", route_engine)
        page.goto(url, wait_until="domcontentloaded")
        retry = page.locator("#status-retry")
        retry.wait_for(state="visible", timeout=15000)
        notice = page.locator("#status-notice").text_content() or ""
        retry_label = retry.text_content() or ""
        result["checks"]["engine_failure_was_visible"] = "Injected post-initialization failure" in notice and retry_label == "重新初始化"
        with page.expect_navigation(wait_until="domcontentloaded", timeout=90000) as navigation_info:
            retry.click()
        navigation = navigation_info.value
        result["checks"]["retry_requested_reload"] = navigation is not None and navigation.url == url
        progress: list[float] = []
        wait_for_engine(page, progress, set())
        page.screenshot(path=output / "retry-recovered-home.png")
        unexpected = [
            item for item in console
            if item["type"] == "error" and "Injected post-initialization failure" not in item["text"]
        ]
        result["unexpected_console_errors"] = unexpected
        result["checks"].update({
            "retry_recovered_engine_started": page.locator("#status").count() == 0,
            "retry_used_cached_resources": not resource_requests,
            "retry_progress_monotonic": all(later >= earlier for earlier, later in zip(progress, progress[1:])),
            "retry_no_page_errors": not page_errors,
            "retry_no_unexpected_console_errors": not unexpected,
        })
    except Exception as error:
        result["exception"] = f"{type(error).__name__}: {error}"
        try:
            result["failure_state"] = page.evaluate("""
                () => ({
                    status: Boolean(document.getElementById('status')),
                    notice: document.getElementById('status-notice')?.textContent || '',
                    detail: document.getElementById('status-detail')?.textContent || '',
                    retry: document.getElementById('status-retry')?.hidden === false,
                    injected: window.sessionStorage.getItem('blackhole-injected-start-failure'),
                    startGame: typeof engine === 'undefined' || !engine ? 'missing' : engine.startGame.toString().slice(0, 300),
                })
            """)
            page.screenshot(path=output / "retry-failure.png")
        except Exception as debug_error:
            result["debug_exception"] = str(debug_error)
        raise
    finally:
        page.close()


def read_diagnostics(page) -> dict:
    return page.evaluate("""
        () => {
            const snapshot = JSON.parse(window.BlackholeDiagnostics.snapshot());
            return {
                current: snapshot.current,
                previous: snapshot.previous,
                stored: JSON.parse(window.sessionStorage.getItem('blackhole-city-runtime-v1')),
            };
        }
    """)


def wait_for_gameplay(page, timeout: float = 20) -> dict:
    started = time.monotonic()
    latest: dict = {}
    while time.monotonic() - started < timeout:
        latest = read_diagnostics(page)
        if latest["current"].get("gameplay"):
            return latest
        time.sleep(0.1)
    return latest


def exercise_swallow_interruption(context, url: str, result: dict) -> None:
    page = context.new_page()
    checks: dict[str, bool] = {}
    page_errors: list[str] = []
    result.update({"checks": checks, "page_errors": page_errors})
    page.on("pageerror", lambda error: page_errors.append(str(error)))
    page.add_init_script("""
        window.addEventListener('pagehide', function (event) {
            event.stopImmediatePropagation();
        }, true);
    """)
    try:
        page.goto(url, wait_until="domcontentloaded")
        wait_for_engine(page, [], set())
        canvas_box = page.locator("#canvas").bounding_box()
        page.mouse.click(canvas_box["x"] + canvas_box["width"] * 0.5, canvas_box["y"] + canvas_box["height"] * 0.54)
        origin_x = canvas_box["x"] + canvas_box["width"] * 0.5
        origin_y = canvas_box["y"] + canvas_box["height"] * 0.70
        page.mouse.move(origin_x, origin_y)
        page.mouse.down()
        directions = [(1, -1), (1, 0), (0, -1), (-1, 0), (0, 1), (-1, -1), (1, 1), (-1, 1)]
        latest: dict = {}
        started = time.monotonic()
        while time.monotonic() - started < 20:
            elapsed = time.monotonic() - started
            dx, dy = directions[int(elapsed) % len(directions)]
            page.mouse.move(origin_x + dx * 72, origin_y + dy * 72)
            latest = read_diagnostics(page)
            if (latest["stored"].get("lastEvent") or {}).get("type") == "swallow":
                break
            page.wait_for_timeout(50)
        page.mouse.up()
        result["at_swallow"] = latest
        swallow = latest["stored"].get("lastSwallow") or {}
        checks["real_swallow_persisted_before_next_heartbeat"] = (
            isinstance(swallow.get("object_id"), int)
            and bool(swallow.get("model_id"))
            and latest["stored"]["lastEvent"]["type"] == "swallow"
        )
        page.reload(wait_until="domcontentloaded")
        wait_for_engine(page, [], set())
        recovered = read_diagnostics(page)
        result["recovered"] = recovered
        previous_gameplay = (recovered.get("previous") or {}).get("gameplay")
        checks["swallow_survives_abrupt_reload"] = (
            recovered["current"]["interruptionCount"] == 1
            and recovered["current"]["safeMode"] is True
            and (recovered.get("previous") or {}).get("lastSwallow") == swallow
        )
        checks["swallow_updates_latest_progress_snapshot"] = (
            previous_gameplay is None or previous_gameplay.get("last_swallow") == swallow
        )
        checks["swallow_recovery_has_no_page_errors"] = not page_errors
    except Exception as error:
        result["exception"] = f"{type(error).__name__}: {error}"
        raise
    finally:
        page.close()


def exercise_startup_interruption(context, url: str, export_dir: Path, output: Path, result: dict) -> None:
    html = (export_dir / "play.html").read_text(encoding="utf-8")
    version_match = re.search(r'const GAME_VERSION = "([A-Za-z0-9._-]+)"', html)
    if not version_match:
        raise RuntimeError("Patched game version was not found")
    script_path = export_dir / f"play.{version_match.group(1)}.js"
    source = script_path.read_text(encoding="utf-8")
    factory_return = "\t\treturn new Engine(initConfig);"
    injected_return = r"""		const instance = new Engine(initConfig);
			const originalStartGame = instance.startGame;
			instance.startGame = function () {
				if (!window.sessionStorage.getItem('blackhole-allow-engine-start')) {
					return new Promise(function () {});
				}
				return originalStartGame.apply(this, arguments);
			};
			return instance;"""
    injected = source.replace(factory_return, injected_return, 1)
    if injected == source:
        raise RuntimeError("Godot engine factory injection point was not found")
    page = context.new_page()
    checks: dict[str, bool] = {}
    page_errors: list[str] = []
    result.update({"checks": checks, "page_errors": page_errors})
    page.on("pageerror", lambda error: page_errors.append(str(error)))
    page.add_init_script("""
        window.addEventListener('pagehide', function (event) {
            event.stopImmediatePropagation();
        }, true);
    """)

    def route_engine(route):
        if Path(urlparse(route.request.url).path).name == script_path.name:
            route.fulfill(status=200, content_type="application/javascript", body=injected)
        else:
            route.continue_()

    def wait_for_pending_start():
        page.wait_for_function("""
            () => document.getElementById('status-detail')?.textContent.includes('正在初始化 WebGL')
        """, timeout=15000)

    try:
        page.route("**/*.js", route_engine)
        page.goto(url, wait_until="domcontentloaded")
        wait_for_pending_start()
        initial = read_diagnostics(page)
        result["initial"] = initial
        checks["pending_engine_start_is_loading"] = initial["stored"]["phase"] == "loading"

        page.reload(wait_until="domcontentloaded")
        wait_for_pending_start()
        first = read_diagnostics(page)
        result["first_recovery"] = first
        checks["startup_interruption_uses_safe_mode"] = (
            first["current"]["interruptionCount"] == 1
            and first["current"]["safeMode"] is True
            and first["previous"]["phase"] == "loading"
        )

        page.reload(wait_until="domcontentloaded")
        retry = page.locator("#status-retry")
        retry.wait_for(state="visible", timeout=15000)
        blocked = read_diagnostics(page)
        result["blocked"] = blocked
        checks["repeated_startup_interruption_blocks_autostart"] = (
            blocked["current"]["phase"] == "recovery-blocked"
            and blocked["current"]["interruptionCount"] == 2
        )
        page.screenshot(path=output / "startup-interruption-blocked.png")

        page.evaluate("window.sessionStorage.setItem('blackhole-allow-engine-start', '1')")
        retry.click()
        wait_for_engine(page, [], set())
        recovered = read_diagnostics(page)
        checks["startup_manual_retry_recovers_in_safe_mode"] = (
            recovered["current"]["phase"] == "running"
            and recovered["current"]["safeMode"] is True
        )
        checks["startup_recovery_has_no_page_errors"] = not page_errors
    except Exception as error:
        result["exception"] = f"{type(error).__name__}: {error}"
        raise
    finally:
        page.close()


def exercise_context_loss_reload(context, url: str, result: dict) -> None:
    page = context.new_page()
    checks: dict[str, bool] = {}
    page_errors: list[str] = []
    result.update({"checks": checks, "page_errors": page_errors})
    page.on("pageerror", lambda error: page_errors.append(str(error)))
    page.on("dialog", lambda dialog: dialog.dismiss())
    try:
        page.goto(url, wait_until="domcontentloaded")
        wait_for_engine(page, [], set())
        page.locator("#canvas").dispatch_event("webglcontextlost", {"cancelable": True})
        fault = read_diagnostics(page)
        result["fault"] = fault
        checks["context_loss_is_recorded_as_abnormal"] = (
            fault["stored"]["phase"] == "context-lost"
            and fault["stored"]["abnormal"] is True
        )

        page.reload(wait_until="domcontentloaded")
        wait_for_engine(page, [], set())
        recovered = read_diagnostics(page)
        result["recovered"] = recovered
        checks["context_loss_survives_normal_recovery_reload"] = (
            recovered["current"]["interruptionCount"] == 1
            and recovered["current"]["safeMode"] is True
            and recovered["previous"]["phase"] == "context-lost"
            and recovered["previous"]["lastEvent"]["type"] == "pagehide"
            and recovered["previous"]["lastEvent"]["payload"]["faultPreserved"] is True
        )
        checks["context_loss_recovery_has_no_page_errors"] = not page_errors
    except Exception as error:
        result["exception"] = f"{type(error).__name__}: {error}"
        raise
    finally:
        page.close()


def exercise_duplicate_tab(context, url: str, result: dict) -> None:
    original = context.new_page()
    duplicate = None
    checks: dict[str, bool] = {}
    page_errors: list[str] = []
    console: list[dict] = []
    result.update({"checks": checks, "page_errors": page_errors, "console": console})
    original.on("pageerror", lambda error: page_errors.append(str(error)))
    try:
        original.goto(url, wait_until="domcontentloaded")
        wait_for_engine(original, [], set())
        original_state = read_diagnostics(original)
        result["original"] = original_state
        with context.expect_page() as page_info:
            original.evaluate("() => { window.open(window.location.href, '_blank'); }")
        duplicate = page_info.value
        duplicate.on("pageerror", lambda error: page_errors.append(str(error)))
        duplicate.on("console", lambda message: console.append({"type": message.type, "text": message.text}))
        duplicate.wait_for_load_state("domcontentloaded")
        wait_for_engine(duplicate, [], set())
        duplicated_state = read_diagnostics(duplicate)
        result["duplicate"] = duplicated_state
        checks["duplicated_running_tab_is_not_interruption"] = (
            duplicated_state["previous"] is not None
            and duplicated_state["current"]["interruptionCount"] == 0
            and duplicated_state["current"]["safeMode"] is False
            and duplicated_state["current"]["duplicateTab"] is True
            and duplicated_state["current"]["tabId"] != original_state["current"]["tabId"]
        )
        checks["duplicate_tab_has_no_page_errors"] = not page_errors
        checks["duplicate_tab_has_no_console_errors"] = not any(item["type"] == "error" for item in console)
    except Exception as error:
        result["exception"] = f"{type(error).__name__}: {error}"
        raise
    finally:
        if duplicate is not None and not duplicate.is_closed():
            duplicate.close()
        original.close()


def exercise_interruption_recovery(context, url: str, output: Path, result: dict) -> None:
    page = context.new_page()
    checks: dict[str, bool] = {}
    console: list[dict] = []
    page_errors: list[str] = []
    navigations: list[str] = []
    result.update({"checks": checks, "console": console, "page_errors": page_errors, "navigations": navigations})
    page.on("console", lambda message: console.append({"type": message.type, "text": message.text}))
    page.on("pageerror", lambda error: page_errors.append(str(error)))
    page.on("framenavigated", lambda frame: navigations.append(frame.url) if frame == page.main_frame else None)
    # A real WebContent crash cannot run pagehide. Suppress only that clean-exit
    # marker to emulate the persistent state left by two abrupt interruptions.
    page.add_init_script("""
        window.addEventListener('pagehide', function (event) {
            event.stopImmediatePropagation();
        }, true);
        window.__webglContextAttributes = [];
        const originalGetContext = HTMLCanvasElement.prototype.getContext;
        HTMLCanvasElement.prototype.getContext = function (type, attributes) {
            window.__webglContextAttributes.push({type: type, attributes: attributes || {}});
            return originalGetContext.call(this, type, attributes);
        };
    """)
    try:
        page.goto(url, wait_until="domcontentloaded")
        wait_for_engine(page, [], set())
        page.wait_for_timeout(500)
        canvas_box = page.locator("#canvas").bounding_box()
        page.mouse.click(canvas_box["x"] + canvas_box["width"] * 0.5, canvas_box["y"] + canvas_box["height"] * 0.54)
        page.wait_for_timeout(4000)
        initial = wait_for_gameplay(page)
        result["initial"] = initial
        initial_gameplay = initial["current"].get("gameplay") or {}
        checks["gameplay_heartbeat_recorded"] = (
            initial["current"]["phase"] == "running"
            and isinstance(initial_gameplay.get("objects_remaining"), int)
            and initial_gameplay.get("shadows_enabled") is True
            and initial["stored"]["gameplay"] == initial_gameplay
        )
        page.evaluate("""
            () => window.dispatchEvent(new ErrorEvent('error', {
                message: 'Injected runtime diagnostic marker',
                filename: 'runtime-diagnostic-test',
                lineno: 17,
            }))
        """)
        fault = read_diagnostics(page)
        checks["runtime_fault_persisted"] = (
            fault["stored"]["phase"] == "runtime-error"
            and fault["stored"]["abnormal"] is True
            and fault["stored"]["lastError"]["message"] == "Injected runtime diagnostic marker"
            and fault["stored"]["lastError"]["line"] == 17
        )

        page.reload(wait_until="domcontentloaded")
        wait_for_engine(page, [], set())
        page.wait_for_timeout(500)
        canvas_box = page.locator("#canvas").bounding_box()
        page.mouse.click(canvas_box["x"] + canvas_box["width"] * 0.5, canvas_box["y"] + canvas_box["height"] * 0.54)
        page.wait_for_timeout(4000)
        first_recovery = wait_for_gameplay(page)
        result["first_recovery"] = first_recovery
        context_requests = page.evaluate("window.__webglContextAttributes")
        result["first_recovery_contexts"] = context_requests
        previous_gameplay = (first_recovery.get("previous") or {}).get("gameplay") or {}
        recovery_gameplay = first_recovery["current"].get("gameplay") or {}
        checks["first_interruption_uses_safe_mode"] = (
            first_recovery["current"]["interruptionCount"] == 1
            and first_recovery["current"]["safeMode"] is True
            and first_recovery["current"]["phase"] == "running"
            and recovery_gameplay.get("safe_mode") is True
            and recovery_gameplay.get("render_scale") == 0.75
            and recovery_gameplay.get("msaa") == 0
            and recovery_gameplay.get("audio_muted") is True
            and recovery_gameplay.get("shadows_enabled") is False
        )
        checks["safe_mode_disables_context_antialias_before_engine"] = any(
            request.get("type") == "webgl2" and (request.get("attributes") or {}).get("antialias") is False
            for request in context_requests
        )
        checks["previous_progress_and_fault_preserved"] = (
            previous_gameplay.get("objects_remaining") == initial_gameplay.get("objects_remaining")
            and first_recovery["previous"]["lastError"]["message"] == "Injected runtime diagnostic marker"
        )
        page.screenshot(path=output / "interruption-safe-mode.png")
        page.evaluate("""
            () => window.dispatchEvent(new PromiseRejectionEvent('unhandledrejection', {
                promise: Promise.resolve(),
                reason: new Error('Injected rejection diagnostic marker'),
            }))
        """)
        rejection = read_diagnostics(page)
        checks["unhandled_rejection_persisted"] = (
            rejection["stored"]["phase"] == "unhandled-rejection"
            and rejection["stored"]["abnormal"] is True
            and rejection["stored"]["lastError"]["message"] == "Injected rejection diagnostic marker"
        )

        page.reload(wait_until="domcontentloaded")
        retry = page.locator("#status-retry")
        retry.wait_for(state="visible", timeout=15000)
        page.wait_for_timeout(500)
        blocked = read_diagnostics(page)
        checks["repeated_interruption_blocks_autostart"] = (
            blocked["current"]["phase"] == "recovery-blocked"
            and blocked["current"]["interruptionCount"] == 2
            and page.locator("#status-notice").text_content() == "浏览器连续中断，已暂停自动启动"
            and "上次进度 Lv." in (page.locator("#status-detail").text_content() or "")
            and retry.text_content() == "重试稳定模式"
        )
        checks["blocked_page_does_not_auto_reload"] = len(navigations) == 3
        page.screenshot(path=output / "interruption-blocked.png")

        retry.click()
        wait_for_engine(page, [], set())
        recovered = read_diagnostics(page)
        checks["manual_safe_retry_starts_engine"] = (
            page.locator("#status").count() == 0
            and recovered["current"]["phase"] == "running"
            and recovered["current"]["safeMode"] is True
        )
        checks["manual_safe_retry_does_not_navigate"] = len(navigations) == 3
        page.screenshot(path=output / "interruption-manual-recovery.png")
        page.close()

        normal = context.new_page()
        normal_errors: list[str] = []
        normal_console: list[dict] = []
        normal.on("pageerror", lambda error: normal_errors.append(str(error)))
        normal.on("console", lambda message: normal_console.append({"type": message.type, "text": message.text}))
        normal.goto(url, wait_until="domcontentloaded")
        wait_for_engine(normal, [], set())
        normal.reload(wait_until="domcontentloaded")
        wait_for_engine(normal, [], set())
        normal_state = read_diagnostics(normal)
        checks["normal_manual_reload_is_not_interruption"] = (
            normal_state["current"]["interruptionCount"] == 0
            and normal_state["current"]["safeMode"] is False
            and normal_state["previous"]["phase"] == "pagehide"
        )
        checks["normal_reload_has_no_page_errors"] = not normal_errors
        normal.close()
        unexpected = [item for item in console + normal_console if item["type"] == "error"]
        result["unexpected_console_errors"] = unexpected
        checks["recovery_has_no_page_errors"] = not page_errors
        checks["recovery_has_no_console_errors"] = not unexpected
    except Exception as error:
        result["exception"] = f"{type(error).__name__}: {error}"
        try:
            result["failure_state"] = {
                "notice": page.locator("#status-notice").text_content(),
                "detail": page.locator("#status-detail").text_content(),
                "diagnostics": read_diagnostics(page),
            }
            page.screenshot(path=output / "interruption-failure.png")
        except Exception as debug_error:
            result["debug_exception"] = str(debug_error)
        raise
    finally:
        if not page.is_closed():
            page.close()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--export-dir", type=Path, default=Path("build/web"))
    parser.add_argument("--output", type=Path, default=Path("artifacts/web/loader-resilience"))
    parser.add_argument("--headless", action="store_true")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    InterruptingHandler.wasm_attempts = []
    InterruptingHandler.interrupt_next = True
    handler = partial(InterruptingHandler, directory=str(args.export_dir.resolve()))
    server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    url = f"http://127.0.0.1:{server.server_port}/play.html"
    report = {
        "passed": False,
        "url": url,
        "wasm_attempts": [],
        "second_load_requests": [],
        "retry_messages": [],
        "console": [],
        "page_errors": [],
        "checks": {},
    }
    progress_batches: list[list[float]] = [[], []]
    retry_messages: set[str] = set()
    second_load = {"active": False}
    second_requests: list[str] = []

    try:
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(channel="chrome", headless=args.headless)
            context = browser.new_context(viewport={"width": 1280, "height": 1080})
            page = context.new_page()
            page.on("console", lambda message: report["console"].append({"type": message.type, "text": message.text}))
            page.on("pageerror", lambda error: report["page_errors"].append(str(error)))

            def on_request(request):
                if second_load["active"] and urlparse(request.url).path.endswith((".wasm", ".pck")):
                    second_requests.append(request.url)

            page.on("request", on_request)
            page.goto(url, wait_until="domcontentloaded")
            report["first_startup_seconds"] = wait_for_engine(page, progress_batches[0], retry_messages)
            report["checks"]["first_engine_started"] = page.locator("#status").count() == 0
            page.screenshot(path=args.output / "first-home.png")
            second_load["active"] = True
            page.reload(wait_until="domcontentloaded")
            report["second_startup_seconds"] = wait_for_engine(page, progress_batches[1], retry_messages)
            report["checks"]["second_engine_started"] = page.locator("#status").count() == 0
            page.screenshot(path=args.output / "cached-home.png")
            canvas = page.locator("#canvas")
            box = canvas.bounding_box()
            page.mouse.click(box["x"] + box["width"] * 0.5, box["y"] + box["height"] * 0.54)
            page.wait_for_timeout(4000)
            canvas.screenshot(path=args.output / "cached-gameplay.png")
            report["checks"]["no_new_resource_download"] = not second_requests
            report["engine_retry"] = {}
            exercise_engine_retry(context, url, args.export_dir.resolve(), args.output, report["engine_retry"])
            report["checks"].update(report["engine_retry"]["checks"])
            report["interruption_recovery"] = {}
            exercise_interruption_recovery(context, url, args.output, report["interruption_recovery"])
            report["checks"].update(report["interruption_recovery"]["checks"])
            report["swallow_interruption"] = {}
            exercise_swallow_interruption(context, url, report["swallow_interruption"])
            report["checks"].update(report["swallow_interruption"]["checks"])
            report["startup_interruption"] = {}
            exercise_startup_interruption(context, url, args.export_dir.resolve(), args.output, report["startup_interruption"])
            report["checks"].update(report["startup_interruption"]["checks"])
            report["context_loss_recovery"] = {}
            exercise_context_loss_reload(context, url, report["context_loss_recovery"])
            report["checks"].update(report["context_loss_recovery"]["checks"])
            report["duplicate_tab"] = {}
            exercise_duplicate_tab(context, url, report["duplicate_tab"])
            report["checks"].update(report["duplicate_tab"]["checks"])
            browser.close()

        attempts = list(InterruptingHandler.wasm_attempts)
        report["wasm_attempts"] = attempts
        report["second_load_requests"] = second_requests
        report["retry_messages"] = sorted(retry_messages)
        report["checks"]["interrupted_once"] = len(attempts) == 2 and attempts[0]["range"] is None
        report["checks"]["versioned_resource_used"] = (
            len(attempts) == 2
            and attempts[0]["path"].startswith("/play.")
            and attempts[0]["path"] != "/play.wasm"
            and attempts[0]["path"].endswith(".wasm")
        )
        report["checks"]["resumed_from_byte"] = (
            len(attempts) == 2
            and attempts[1]["start"] == 2 * 1024 * 1024
            and attempts[1]["range"] == "bytes=2097152-"
        )
        report["checks"]["retry_was_visible"] = bool(retry_messages)
        report["checks"]["progress_monotonic"] = all(
            later >= earlier
            for batch in progress_batches
            for earlier, later in zip(batch, batch[1:])
        )
        report["checks"]["no_page_errors"] = not report["page_errors"]
        unexpected_console_errors = [
            item for item in report["console"]
            if item["type"] == "error" and "net::ERR_CONTENT_LENGTH_MISMATCH" not in item["text"]
        ]
        report["unexpected_console_errors"] = unexpected_console_errors
        report["checks"]["no_unexpected_console_errors"] = not unexpected_console_errors
        report["passed"] = all(report["checks"].values())
    except Exception as error:
        report["exception"] = f"{type(error).__name__}: {error}"
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)
        report["wasm_attempts"] = list(InterruptingHandler.wasm_attempts)
        report["second_load_requests"] = second_requests
        report["retry_messages"] = sorted(retry_messages)
        report["progress_samples"] = sum(len(batch) for batch in progress_batches)
        report["progress_batches"] = progress_batches
        (args.output / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(json.dumps({"passed": report["passed"], "report": str(args.output / "report.json"), "checks": report["checks"], "exception": report.get("exception")}, ensure_ascii=False))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
