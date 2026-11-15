# 开发约定

## 阶段提交

本项目只使用本地 Git，不配置远程仓库。每个实现阶段在自动检查通过后提交；提交只包含该阶段已验证的源码、正式资源、测试和文档。

原始候选 ZIP、预览和授权清单入库；`assets/candidates/*/extracted/`、参考视频、`.godot/` 与 `artifacts/` 保持本地，不提交。不得通过覆盖原始素材修复正式资源。

## 当前工程基线

- Godot：4.7.2，路径 `/usr/local/bin/godot`。
- 渲染：Mobile，实时 3D。
- 视口：432×960，固定 9:20 竖屏比例。
- 逻辑：GDScript，XZ 地面平面；不采用刚体驱动物体吞噬。
- 测试：项目内 GDScript 测试入口，不要求用户手工参与。

## 当前检查命令

```bash
/usr/local/bin/godot --headless --path . --editor --quit
/usr/local/bin/godot --headless --path . --script res://tests/smoke_test.gd
/usr/local/bin/godot --headless --path . --script res://tests/smoke_test.gd -- --self-test-fail
```

最后一条用于验证故意失败必须返回非零，因此其退出码 1 是预期结果。
