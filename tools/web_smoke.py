#!/usr/bin/env python3
"""Exercise a served Godot Web export in a real Chrome browser."""

import argparse
import json
import sys
import time
from pathlib import Path
from urllib.parse import urlparse

from PIL import Image, ImageChops, ImageStat
from playwright.sync_api import sync_playwright


def image_metrics(path):
    image = Image.open(path).convert("RGB")
    sample = image.resize((108, 240))
    stat = ImageStat.Stat(sample)
    return {
        "size": list(image.size),
        "sampled_colors": len(sample.getcolors(sample.width * sample.height) or []),
        "stddev": [round(value, 3) for value in stat.stddev],
    }


def changed_fraction(before_path, after_path):
    before = Image.open(before_path).convert("RGB")
    after = Image.open(after_path).convert("RGB")
    if before.size != after.size:
        return 1.0
    difference = ImageChops.difference(before, after)
    pixels = difference.tobytes()
    changed = sum(1 for index in range(0, len(pixels), 3) if max(pixels[index:index + 3]) > 12)
    return changed / (before.width * before.height)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default="http://127.0.0.1:8765/")
    parser.add_argument("--output", default="artifacts/web/local")
    parser.add_argument("--headless", action="store_true")
    parser.add_argument("--timeout-ms", type=int, default=120_000)
    args = parser.parse_args()

    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    direct = urlparse(args.url).path.endswith("play.html")
    report = {
        "url": args.url,
        "mode": "direct" if direct else "iframe",
        "passed": False,
        "console": [],
        "page_errors": [],
        "failed_requests": [],
        "responses": [],
        "checks": {},
    }
    started = time.monotonic()

    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(channel="chrome", headless=args.headless)
        page = browser.new_page(viewport={"width": 1280, "height": 1080}, device_scale_factor=1)
        page.on("console", lambda message: report["console"].append({"type": message.type, "text": message.text}))
        page.on("pageerror", lambda error: report["page_errors"].append(str(error)))
        page.on("requestfailed", lambda request: report["failed_requests"].append({"url": request.url, "failure": request.failure}))
        page.on("response", lambda response: report["responses"].append({"url": response.url, "status": response.status}))

        try:
            navigation_started = time.monotonic()
            response = page.goto(args.url, wait_until="domcontentloaded", timeout=args.timeout_ms)
            report["checks"]["document_http_200"] = response is not None and response.status == 200
            frame = page.main_frame if direct else page.locator("iframe").element_handle().content_frame()
            canvas = frame.locator("#canvas")
            canvas.wait_for(state="visible", timeout=args.timeout_ms)
            frame.locator("#status").wait_for(state="detached", timeout=args.timeout_ms)
            report["startup_seconds"] = round(time.monotonic() - navigation_started, 3)
            report["engine_ready_ms"] = round(frame.evaluate("performance.now()"), 3)
            report["resources"] = frame.evaluate("""
                performance.getEntriesByType('resource').map(entry => ({
                    name: entry.name,
                    duration_ms: Math.round(entry.duration),
                    transfer_bytes: entry.transferSize,
                    encoded_bytes: entry.encodedBodySize,
                    decoded_bytes: entry.decodedBodySize,
                    initiator: entry.initiatorType,
                }))
            """)
            page.wait_for_timeout(3000)

            report["checks"]["non_threaded_export"] = frame.evaluate("GODOT_THREADS_ENABLED") is False
            dimensions = canvas.evaluate("element => ({width: element.width, height: element.height})")
            report["checks"]["canvas_dimensions"] = dimensions
            report["checks"]["canvas_has_area"] = dimensions["width"] >= 200 and dimensions["height"] >= 400

            page.screenshot(path=output / "page.png", full_page=True)
            canvas.screenshot(path=output / "home.png")
            home_metrics = image_metrics(output / "home.png")
            report["checks"]["home_image"] = home_metrics
            report["checks"]["home_is_rendered"] = home_metrics["sampled_colors"] > 100 and max(home_metrics["stddev"]) > 10

            box = canvas.bounding_box()
            page.mouse.click(box["x"] + box["width"] * 0.5, box["y"] + box["height"] * 0.54)
            page.wait_for_timeout(6000)
            canvas.screenshot(path=output / "gameplay.png")
            game_metrics = image_metrics(output / "gameplay.png")
            report["checks"]["gameplay_image"] = game_metrics
            report["checks"]["gameplay_is_rendered"] = game_metrics["sampled_colors"] > 500 and max(game_metrics["stddev"]) > 20
            report["checks"]["start_changed_fraction"] = changed_fraction(output / "home.png", output / "gameplay.png")
            report["checks"]["start_entered_gameplay"] = report["checks"]["start_changed_fraction"] > 0.25

            page.mouse.move(box["x"] + box["width"] * 0.5, box["y"] + box["height"] * 0.65)
            page.mouse.down()
            page.mouse.move(box["x"] + box["width"] * 0.64, box["y"] + box["height"] * 0.50, steps=20)
            page.wait_for_timeout(2000)
            page.mouse.up()
            page.keyboard.press("c")
            page.wait_for_timeout(1500)
            canvas.screenshot(path=output / "moved_orthographic.png")
            page.keyboard.press("Escape")
            page.wait_for_timeout(750)
            canvas.screenshot(path=output / "paused.png")
            page.keyboard.press("m")
            page.keyboard.press("Escape")
            page.wait_for_timeout(500)

            essential_suffixes = (".wasm", ".pck", ".js", ".png", ".html", "/")
            bad_responses = [item for item in report["responses"] if item["status"] >= 400 and urlparse(item["url"]).path.endswith(essential_suffixes)]
            loaded = {suffix: any(item["status"] == 200 and urlparse(item["url"]).path.endswith(suffix) for item in report["responses"]) for suffix in (".wasm", ".pck", ".js")}
            report["checks"]["essential_resources_loaded"] = loaded
            report["checks"]["http_errors"] = bad_responses
            report["checks"]["no_page_errors"] = not report["page_errors"]
            report["checks"]["no_failed_requests"] = not report["failed_requests"]
            report["checks"]["no_console_errors"] = not any(item["type"] == "error" for item in report["console"])
            boolean_checks = [value for value in report["checks"].values() if isinstance(value, bool)]
            report["passed"] = all(boolean_checks) and all(loaded.values()) and not bad_responses
        except Exception as error:
            report["exception"] = f"{type(error).__name__}: {error}"
            try:
                page.screenshot(path=output / "failure.png", full_page=True)
            except Exception:
                pass
        finally:
            report["elapsed_seconds"] = round(time.monotonic() - started, 3)
            browser.close()

    (output / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"passed": report["passed"], "report": str(output / "report.json"), "exception": report.get("exception")}, ensure_ascii=False))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
