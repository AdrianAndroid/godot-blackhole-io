#!/usr/bin/env python3
"""Run the complete local Mac prototype acceptance suite and summarize evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
GODOT = Path(os.environ.get("GODOT", "/usr/local/bin/godot"))
ARTIFACTS = ROOT / "artifacts"
ACCEPTANCE = ARTIFACTS / "acceptance"

EXPECTED_HASHES = {
    "assets/game/fonts/NotoSansSC-Variable.ttf": "a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da",
    "assets/game/fonts/OFL.txt": "1c05c68c34f9708415aada51f17e1b0092d2cea709bf4a94cd38114f9e73d7d9",
    "assets/game/audio/devour.ogg": "f74c1334c0c1ab9ec69f3dd723611a8eb89a2630df6c3760dee3b09413370c83",
    "assets/game/audio/level_up.ogg": "1a4c90fed704b4f4b36d58f481117cfac5cdc25279a9af97d4765b71ff21ed48",
    "assets/game/audio/knockdown.ogg": "154991a6d9ac80ae193ebad3de7eacb642821e9e48d801d054aa9d2b1004e8c6",
    "assets/game/audio/tower_spawn.ogg": "f2ed0b3b5ad7662f0900d3ca5db81f314af6bf4583802874d308656ba31de1ad",
    "assets/game/audio/victory.ogg": "c5faa31bbf4a921332cdc9e7d7f7d930ca73fc8cc96e35ccc70ed2de975b26e5",
    "assets/game/audio/defeat.ogg": "736c70844cc7cfe87fc95d5e9711c186a593bbe8ccca04e3f4c9cfa7d4e42f3a",
    "assets/candidates/city-kit-commercial/source.zip": "f8b09b081c2bb88bcc126e2dec1cb40fd0dad7e7e591b6c26aaefe96fb35276b",
    "assets/candidates/city-kit-roads/source.zip": "374a4552115cbd11b4ec5c930ee31a533562dc78a09af249a655d03f7ea3b959",
    "assets/candidates/city-kit-suburban/source.zip": "5869c35cf30b1c87bdb2d197b6d325eebadd2ef08ea27f04797e8e08d77a9a39",
    "assets/candidates/city-kit-industrial/source.zip": "5b381164e5760f3830a2dbee43b972deee38b2a695d091b56e238ab2910c96d2",
    "assets/candidates/tiny-town/source.zip": "9768692dccff1d706408a5aedd6ca4f6cd1409506cbc84cb2f862919764be977",
    "assets/candidates/ui-pack/source.zip": "a8a14a234911eb648c062622915c93e79e94e97cb7f9f375a70f6617f1174318",
}

CHECKPOINTS = [
    "home", "initial", "growing", "sinking", "max_level", "multi_knockdown",
    "tower", "victory", "defeat", "input_edge", "occlusion", "water_hole",
]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def load_json(relative: str) -> dict:
    path = ROOT / relative
    if not path.is_file():
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return value if isinstance(value, dict) else {}


def command_for(group: str) -> tuple[list[str], int]:
    godot = str(GODOT)
    base = [godot, "--path", str(ROOT)]
    commands = {
        "editor": ([godot, "--headless", "--path", str(ROOT), "--editor", "--quit"], 0),
        "logic": (base + ["--headless", "--script", "res://tests/test_runner.gd", "--", "--group=all", "--skip=soak", "--report=logic.json"], 0),
        "self_test_failure": (base + ["--headless", "--script", "res://tests/test_runner.gd", "--", "--group=unit", "--filter=input_controller", "--self-test-fail", "--report=self_test_failure.json"], 1),
        "soak": (base + ["--headless", "--script", "res://tests/test_runner.gd", "--", "--group=integration", "--filter=soak", "--report=soak.json"], 0),
        "visual_regression": (base + ["--script", "res://tests/visual/visual_regression.gd"], 0),
        "city_projection": (base + ["--script", "res://tests/visual/projection_baseline_test.gd"], 0),
        "city_sample": (base + ["--script", "res://tests/visual/city_sample_test.gd"], 0),
        "fault_visual": (base + ["--script", "res://tests/test_runner.gd", "--", "--group=integration", "--filter=fault_replay", "--report=fault_visual.json"], 0),
        "replay_cli": (base + ["--headless", "--script", "res://tests/gameplay/replay_failure.gd", "--", "--report=artifacts/failures/self_test_tick_limit.json"], 0),
        "performance": (base + ["--script", "res://tests/performance/performance_sample.gd"], 0),
        "forced_failure": (base + ["--headless", "--script", "res://tests/test_runner.gd", "--", "--group=invalid", "--report=acceptance_expected_failure.json"], 0),
    }
    return commands[group]


def run_group(group: str) -> dict:
    command, expected_exit = command_for(group)
    started = time.monotonic()
    try:
        process = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=600)
        output = process.stdout
        exit_code = process.returncode
    except subprocess.TimeoutExpired as error:
        output = (error.stdout or "") + "\n验收组执行超时（600 秒）"
        exit_code = 124
    ACCEPTANCE.mkdir(parents=True, exist_ok=True)
    log_path = ACCEPTANCE / f"{group}.log"
    log_path.write_text(output, encoding="utf-8")
    passed = exit_code == expected_exit
    if group in {"editor", "logic", "soak"} and ("SCRIPT ERROR:" in output or "ERROR:" in output):
        passed = False
    if group == "self_test_failure":
        report = load_json("artifacts/self_test_failure.json")
        passed = passed and report.get("passed") is False and any(r.get("name") == "intentional_failure" for r in report.get("results", []))
    return {
        "name": group,
        "passed": passed,
        "exit_code": exit_code,
        "expected_exit": expected_exit,
        "duration_seconds": round(time.monotonic() - started, 3),
        "log": str(log_path.relative_to(ROOT)),
        "command": command,
    }


def audit() -> dict:
    failures: list[str] = []
    checked_hashes = 0
    for relative, expected in EXPECTED_HASHES.items():
        path = ROOT / relative
        if not path.is_file() or sha256(path) != expected:
            failures.append(f"资源缺失或 SHA-256 改变: {relative}")
        else:
            checked_hashes += 1
    licenses = [
        "assets/game/models/commercial/License.txt",
        "assets/game/models/suburban/License.txt",
        "assets/game/models/industrial/License.txt",
        "assets/game/models/roads/License.txt",
        "assets/game/audio/LICENSE-Kenney-CC0.txt",
        "assets/game/fonts/OFL.txt",
    ]
    for relative in licenses:
        path = ROOT / relative
        if not path.is_file() or path.stat().st_size < 100:
            failures.append(f"授权正文缺失: {relative}")
    catalog = load_json("config/model_catalog.json")
    models = catalog.get("models", [])
    if len(models) != 29:
        failures.append(f"模型注册数量不是 29: {len(models)}")
    for model in models:
        resource = str(model.get("path", "")).removeprefix("res://")
        if not resource or not (ROOT / resource).is_file():
            failures.append(f"注册模型资源缺失: {resource}")
    for checkpoint in CHECKPOINTS:
        for projection in ("perspective", "orthographic"):
            label = f"{checkpoint}_{projection}"
            for relative in (
                f"tests/baselines/{label}.png",
                f"artifacts/visual/regression/{label}.png",
                f"artifacts/visual/regression/{label}_diff.png",
            ):
                if not (ROOT / relative).is_file() or (ROOT / relative).stat().st_size == 0:
                    failures.append(f"视觉证据缺失: {relative}")
    required_reports = {
        "artifacts/logic.json": True,
        "artifacts/soak.json": True,
        "artifacts/soak_matches.json": True,
        "artifacts/visual/regression/report.json": True,
        "artifacts/visual/projection/report.json": True,
        "artifacts/visual/city_sample.json": True,
        "artifacts/fault_visual.json": True,
        "artifacts/failures/self_test_tick_limit_replay.json": True,
        "artifacts/performance/report.json": True,
    }
    for relative, expected in required_reports.items():
        report = load_json(relative)
        if report.get("passed") is not expected:
            failures.append(f"报告不存在或未通过: {relative}")
    fault = load_json("artifacts/failures/self_test_tick_limit.json")
    if fault.get("screenshot_status") != "captured" or not (ROOT / str(fault.get("screenshot", ""))).is_file():
        failures.append("真实图形故障截图缺失")
    soak = load_json("artifacts/soak_matches.json")
    if len(soak.get("matches", [])) != 20:
        failures.append("soak 详细报告不足 20 局")
    report = {"passed": not failures, "failures": failures, "checked_hashes": checked_hashes, "licenses": licenses, "registered_models": len(models), "visual_images": len(CHECKPOINTS) * 6, "soak_matches": len(soak.get("matches", []))}
    path = ARTIFACTS / "asset_audit.json"
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    return report


def write_summary(groups: list[dict], audit_report: dict, require_clean: bool) -> bool:
    git_head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True, capture_output=True).stdout.strip()
    git_status = subprocess.run(["git", "status", "--porcelain"], cwd=ROOT, text=True, capture_output=True).stdout.strip()
    clean = not git_status
    passed = all(group["passed"] for group in groups) and audit_report.get("passed") is True and (clean or not require_clean)
    summary = {
        "passed": passed,
        "created_unix": time.time(),
        "project": str(ROOT),
        "git_head": git_head,
        "git_clean": clean,
        "clean_required": require_clean,
        "godot": str(GODOT),
        "groups": groups,
        "asset_audit": audit_report,
        "limitations": [
            "Mac 原型验收不证明未来抖音小游戏兼容性。",
            "像素回归验证预设视觉不变量，不证明主观美术与视频完全一致。",
            "音效测试验证资源与事件，不替代主观听感评审。",
            "Intel UHD 630 / MoltenVK 仍输出 compute pipeline 驱动日志；真实图像已成功生成并比较。",
        ],
    }
    (ACCEPTANCE / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    lines = [
        "# 完整自动验收汇总", "",
        f"- 结果：**{'通过' if passed else '失败'}**",
        f"- Git：`{git_head}`",
        f"- 工作区干净：{clean}（本次要求：{require_clean}）",
        f"- Godot：`{GODOT}`", "",
        "| 验收组 | 结果 | 退出码 | 秒 | 日志 |", "| --- | --- | ---: | ---: | --- |",
    ]
    for group in groups:
        lines.append(f"| {group['name']} | {'通过' if group['passed'] else '失败'} | {group['exit_code']} | {group['duration_seconds']} | `{group['log']}` |")
    lines += ["", f"素材审计：{'通过' if audit_report.get('passed') else '失败'}；校验 {audit_report.get('checked_hashes', 0)} 个 SHA-256、{audit_report.get('registered_models', 0)} 个注册模型。", ""]
    performance = load_json("artifacts/performance/report.json")
    if performance:
        lines += ["## 性能采样（仅报告，不设 FPS 门槛）", "", "| 场景 | 样本 | p50 ms | p95 ms | p99 ms | 最大绘制调用 | 峰值静态内存 MiB |", "| --- | ---: | ---: | ---: | ---: | ---: | ---: |"]
        for phase in performance.get("phases", []):
            timing = phase["frame_time_ms"]
            lines.append(f"| {phase['name']} | {phase['samples']} | {timing['p50']} | {timing['p95']} | {timing['p99']} | {phase['rendering']['peak_draw_calls']} | {phase['memory']['peak_static_mb']} |")
        lines.append("")
    lines += ["## 边界", ""] + [f"- {item}" for item in summary["limitations"]]
    (ACCEPTANCE / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return passed


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--require-clean", action="store_true")
    parser.add_argument("--verify-failure-exit", action="store_true", help="Deliberately run one invalid required group; acceptance must exit 1")
    parser.add_argument("--groups", help="Comma-separated development subset; full suite is the default")
    args = parser.parse_args()
    if not GODOT.is_file():
        print(f"Godot not found: {GODOT}", file=sys.stderr)
        return 2
    ACCEPTANCE.mkdir(parents=True, exist_ok=True)
    names = ["editor", "logic", "self_test_failure", "soak", "visual_regression", "city_projection", "city_sample", "fault_visual", "replay_cli", "performance"]
    if args.verify_failure_exit:
        names = ["forced_failure"]
    elif args.groups:
        names = args.groups.split(",")
    groups = []
    for name in names:
        print(f"[acceptance] {name}", flush=True)
        result = run_group(name)
        groups.append(result)
        print(f"[acceptance] {name}: {'PASS' if result['passed'] else 'FAIL'} ({result['exit_code']})", flush=True)
    audit_report = audit() if not args.verify_failure_exit and not args.groups else {"passed": False, "failures": ["开发子组或故意失败运行不执行完整素材审计"]}
    passed = write_summary(groups, audit_report, args.require_clean)
    print(json.dumps({"passed": passed, "summary": "artifacts/acceptance/summary.json", "markdown": "artifacts/acceptance/summary.md"}, ensure_ascii=False))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
