# Blackhole City

Godot 4.7.2 + GDScript 的实时 3D 黑洞吞噬原型。当前目标是在 Mac 上完成参考视频风格的竖屏单局闭环；抖音适配后置。

## 运行

```bash
/usr/local/bin/godot --path .
```

## 启动检查

```bash
/usr/local/bin/godot --headless --path . --editor --quit
/usr/local/bin/godot --headless --path . --script res://tests/smoke_test.gd
```

Smoke test 将结果写入 `artifacts/smoke.json`，失败返回退出码 1。可通过附加 `-- --self-test-fail` 验证故意失败路径。

## 目录

- `scenes/`：应用与对局场景。
- `scripts/`：核心状态、玩法、渲染与界面。
- `config/`：成长和模型等数据配置。
- `assets/game/`：正式使用且授权可追溯的资源。
- `assets/candidates/`：原始候选包；解压目录不进入 Git，也不由 Godot 导入。
- `tests/`：逻辑、整局与图形自动测试。
- `artifacts/`：本地自动验收输出，不进入 Git。
- `openspec/changes/add-video-referenced-mvp/`：本轮需求、设计和任务。

所有验收由自动测试执行，不需要用户手工试玩。
