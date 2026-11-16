# 开发与自动验收

## 阶段提交

本项目只使用本地 Git，不配置远程仓库。每个实现阶段在自动检查通过后提交；提交只包含该阶段已验证的源码、正式资源、测试和文档。

原始候选 ZIP、预览和授权清单入库；`assets/candidates/*/extracted/`、参考视频、`.godot/` 与 `artifacts/` 保持本地，不提交。不得通过覆盖原始素材修复正式资源。

## 工程基线

- Godot：4.7.2，路径 `/usr/local/bin/godot`。
- 渲染：OpenGL Compatibility，实时 3D；432×960，固定 9:20 竖屏比例。
- 逻辑：GDScript，XZ 地面平面；不采用刚体驱动物体吞噬。
- 操作：鼠标左键或单指拖动浮动摇杆；Esc 暂停/继续，C 切换投影，M 静音。
- 测试：项目内 GDScript 固定步进入口，不要求用户手工参与。
- 画质优先；性能组只报告采样，不设 30/60 FPS 通过门槛。

## 一键完整验收

```bash
python3 tools/acceptance.py
```

入口依次运行编辑器导入、全部逻辑（含 100 个固定种子）、预期失败自检、20 局混合结局 soak、12 检查点双投影真实截图、城市投影/分区、真实故障截图及独立重放、性能采样和素材审计。任一必需组失败均返回非零。

汇总：

- `artifacts/acceptance/summary.json`
- `artifacts/acceptance/summary.md`
- `artifacts/acceptance/<组名>.log`

干净提交验收使用：

```bash
python3 tools/acceptance.py --require-clean
```

验证汇总器自身能把必需组失败转换为退出码 1：

```bash
python3 tools/acceptance.py --verify-failure-exit
# 预期命令退出码为 1，并生成 passed=false 的汇总。
```

## 分组检查

```bash
/usr/local/bin/godot --headless --path . --editor --quit
/usr/local/bin/godot --headless --path . --script res://tests/smoke_test.gd
/usr/local/bin/godot --headless --path . --script res://tests/test_runner.gd -- --group=all --report=logic.json
/usr/local/bin/godot --headless --path . --script res://tests/test_runner.gd -- --group=unit --filter=swallowing_growth --report=swallowing_growth.json
/usr/local/bin/godot --headless --path . --script res://tests/test_runner.gd -- --group=integration --filter=soak --report=soak.json
/usr/local/bin/godot --headless --path . --script res://tests/test_runner.gd -- --group=unit --filter=input_controller --self-test-fail --report=self_test_failure.json
```

最后一条是故意失败自检，预期退出码 1；报告必须包含 `intentional_failure`。测试发现按文件名排序，编译失败、实例创建失败、零断言和空测试集都不能视为通过。`--skip=soak` 可在开发时拆分长 soak 组；正式完整验收不会跳过。

自动整局只通过 `AutoDriver` 选择输入并调用真实 `GameSession.step`。覆盖终点塔胜利、追逐大型对手被吞、自然 600 秒超时，以及暂停、鼠标/触摸、双投影和多重击倒组合。详细 20 局结果见 `artifacts/soak_matches.json`。

## 输入与镜头调试

- `InputController.handle_event()` 可直接注入鼠标、触摸、拖动和取消事件；`input_vector`、活动触摸 ID 和摇杆状态可断言。
- 第二指不夺取活动触摸 ID；取消、暂停和结算必须清输入。
- `FollowCamera.snapshot()` 提供投影、位置和观察范围。成长仅改变观察范围，不直接改变移动速度、资格或奖励。
- `tests/integration/match_controls_test.gd` 用同一完整输入轨迹分别运行透视和正交，并比较最终逻辑快照。
- `input_edge` 截图把玩家和摇杆放在地图角落；`occlusion` 检查大型不可吞建筑遮挡，`water_hole` 检查水面黑洞。HUD 的 `safe_rects` 不得超出 432×960。

## 真实视觉回归

普通比较（不得改写基线）：

```bash
/usr/local/bin/godot --path . --script res://tests/visual/visual_regression.gd
/usr/local/bin/godot --path . --script res://tests/visual/projection_baseline_test.gd
/usr/local/bin/godot --path . --script res://tests/visual/city_sample_test.gd
```

12 个检查点为首页、初始、成长、下沉中、满级、二重击倒、终点塔、胜利、失败、地图边缘输入、不可吞建筑遮挡和水面黑洞。每个检查点分别保存透视和正交，共 24 张基线。固定种子为 `20261115`，黑洞与终点塔固定动画时刻为 `2.0`；不得用 headless 截图替代。

每通道容差为 `0.04`，允许变化像素比例为 `1%`。截图前最多读取 16 个真实渲染帧，必须出现两张完整像素数据一致的连续帧，避免把消失物体的瞬时旧阴影录成基线；无法在上限内稳定也判失败。报告中的 `rendered_frames` 记录实际等待帧数。普通模式缺基线、缺检查点、超容差、投影前后逻辑快照变化、基线 SHA-256 被改写或 HUD 越界均失败。

- 基线：`tests/baselines/`
- 实际图和差异图：`artifacts/visual/regression/`
- 报告：`artifacts/visual/regression/report.json`

只有审查实际图后才显式更新：

```bash
/usr/local/bin/godot --path . --script res://tests/visual/visual_regression.gd -- --update-baselines
/usr/local/bin/godot --path . --script res://tests/visual/projection_baseline_test.gd -- --update-baselines
```

完整回归更新会保留每个标签的 `_before.png`、`_after.png` 和 `artifacts/visual/baseline_updates/report.json`。更新后必须再运行不带参数的普通比较。

当前 Mac 使用 OpenGL Compatibility，避开 Intel UHD 630 / MoltenVK 的 compute pipeline 初始化错误。真实渲染日志仍完整保留；资源加载提示等警告不会被描述为不存在。

## 故障保存与重放

驱动达到 tick 上限会自动保存：种子、生成版本、布局签名、驱动模式、固定 delta、逐 tick 输入、最近 30 个事件、逻辑快照、观察结果和失败退出码。真实图形测试还会保存截图。

```bash
/usr/local/bin/godot --headless --path . --script res://tests/test_runner.gd -- --group=integration --filter=fault_replay --report=fault_replay.json
/usr/local/bin/godot --path . --script res://tests/test_runner.gd -- --group=integration --filter=fault_replay --report=fault_visual.json
/usr/local/bin/godot --headless --path . --script res://tests/gameplay/replay_failure.gd -- --report=artifacts/failures/self_test_tick_limit.json
```

重放器从种子重建城市，仅回放输入轨迹，比较布局签名、最终快照和故障类别，结果写入 `artifacts/failures/*_replay.json`。自检使用有界驱动故障夹具，不直接写完成度或结局。

## 性能采样

```bash
/usr/local/bin/godot --path . --script res://tests/performance/performance_sample.gd
```

普通城市 120 帧、连续吞噬 240 帧、额外 144 栋建筑的高密度场景 120 帧；四个对手保持活动。报告实际帧时间 min/p50/p95/p99/max/mean、绘制调用、图元、节点、资源、静态内存和系统可用内存：

- `artifacts/performance/report.json`
- `artifacts/performance/high_density.png`

样本数和报告完整性是通过条件，帧率数值不是通过门槛。

## 验证边界

- Mac 原型不证明未来抖音小游戏兼容性。
- 像素回归验证预设视觉不变量，不证明主观美术与参考视频完全一致。
- 音效测试验证资源、事件次数、静音和玩法继续，不替代主观听感评审。
