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
