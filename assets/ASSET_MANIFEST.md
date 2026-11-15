# 素材清单与授权记录

记录日期：2026-11-15

## 当前状态

- 以下 6 套素材均为 **CANDIDATE / 候选，待用户审核**，不代表已经批准用于游戏。
- 素材来自 Kenney 官方网站，原始压缩包、解压文件和预览图均保留在项目中。
- 6 个 ZIP 均已通过完整性检查，并检查了解压路径穿越和符号链接；所有素材均已成功解压。
- 各包内的 `License.txt` 均明确标注 **Creative Commons Zero（CC0）**，允许个人、教育和商业使用，署名不是强制要求。
- `candidates/` 与 `previews/` 下已放置 `.gdignore`，Godot 不会自动导入这些候选文件。
- 目前尚未进行模型渲染、图片切分、修改或游戏导入。

## 目录约定

```text
assets/
  ASSET_MANIFEST.md          本清单
  candidates/<素材名>/
    source.zip               官方原始压缩包
    extracted/               完整解压内容，含原始 License.txt
    preview.png              官方封面预览
    sample.png               官方示例图（部分素材提供）
  previews/                  集中放置便于查看的预览副本与索引
```

## 候选素材

### 1. City Kit Commercial — 推荐作为主要建筑来源

- **审核状态**：CANDIDATE / 待用户审核
- **官方来源**：https://kenney.nl/assets/city-kit-commercial
- **作者/发布方**：Kenney
- **包内版本**：2.1
- **授权**：CC0，原文见 `candidates/city-kit-commercial/extracted/License.txt`
- **内容**：商业建筑、低细节建筑和摩天楼；含 FBX、GLB、OBJ/MTL、纹理和单体预览。
- **项目用途**：城市中心、高楼和最终高塔的候选来源。
- **视觉判断**：斜俯视构图与参考视频方向接近；默认灰白配色之外还提供橙色、红色变体。
- **建议优先查看**：
  - `previews/city-kit-commercial-sample.png`
  - `previews/city-kit-commercial-variation-a.png`
  - `previews/city-kit-commercial-variation-b.png`
- **ZIP SHA-256**：`f8b09b081c2bb88bcc126e2dec1cb40fd0dad7e7e591b6c26aaefe96fb35276b`

### 2. City Kit Roads — 推荐作为道路来源

- **审核状态**：CANDIDATE / 待用户审核
- **官方来源**：https://kenney.nl/assets/city-kit-roads
- **作者/发布方**：Kenney
- **包内版本**：2.2
- **授权**：CC0，原文见 `candidates/city-kit-roads/extracted/License.txt`
- **内容**：道路、交叉口、高架、路牌、交通灯和路灯等街道设施。
- **项目用途**：城市地面、道路网格与街道装饰。
- **范围建议**：MVP 优先选择普通道路和少量街道设施，不默认采用复杂高架。
- **建议优先查看**：`previews/city-kit-roads-sample.png`
- **ZIP SHA-256**：`374a4552115cbd11b4ec5c930ee31a533562dc78a09af249a655d03f7ea3b959`

### 3. City Kit Suburban — 可选的低层住宅区

- **审核状态**：CANDIDATE / 待用户审核
- **官方来源**：https://kenney.nl/assets/city-kit-suburban
- **作者/发布方**：Kenney
- **包内版本**：2.0
- **授权**：CC0，原文见 `candidates/city-kit-suburban/extracted/License.txt`
- **内容**：低层住宅、屋顶和住宅区配套模型。
- **项目用途**：地图边缘或前期低等级可吞噬建筑。
- **视觉判断**：绿色屋顶低层住宅适合作为辅助城区，不建议替代主要高楼素材。
- **预览**：`previews/city-kit-suburban-sample.png`
- **ZIP SHA-256**：`5869c35cf30b1c87bdb2d197b6d325eebadd2ef08ea27f04797e8e08d77a9a39`

### 4. City Kit Industrial — 可选的工业区域

- **审核状态**：CANDIDATE / 待用户审核
- **官方来源**：https://kenney.nl/assets/city-kit-industrial
- **作者/发布方**：Kenney
- **包内版本**：2.0
- **授权**：CC0，原文见 `candidates/city-kit-industrial/extracted/License.txt`
- **内容**：工厂、烟囱、仓库、储罐等工业模型。
- **项目用途**：可选工业城区，用于增加建筑体型和轮廓变化。
- **预览**：`previews/city-kit-industrial-sample.png`
- **ZIP SHA-256**：`5b381164e5760f3830a2dbee43b972deee38b2a695d091b56e238ab2910c96d2`

### 5. Tiny Town — 仅作对比，不推荐用于主视觉

- **审核状态**：CANDIDATE / 待用户审核
- **官方来源**：https://kenney.nl/assets/tiny-town
- **作者/发布方**：Kenney
- **包内版本**：1.1
- **授权**：CC0，原文见 `candidates/tiny-town/extracted/License.txt`
- **内容**：16×16 像素风 2D tiles 和 PNG。
- **项目用途**：布局参考或风格对比。
- **视觉判断**：纯俯视像素风不符合已经确认的斜俯视／三分之四俯视 2.5D 方向，不作为主视觉候选。
- **预览**：`previews/tiny-town-sample.png`
- **ZIP SHA-256**：`9768692dccff1d706408a5aedd6ca4f6cd1409506cbc84cb2f862919764be977`

### 6. UI Pack — HUD 基础组件候选

- **审核状态**：CANDIDATE / 待用户审核
- **官方来源**：https://kenney.nl/assets/ui-pack
- **作者/发布方**：Kenney
- **包内版本**：2.0
- **授权**：CC0，原文见 `candidates/ui-pack/extracted/License.txt`
- **内容**：按钮、面板、勾选框、箭头等 PNG/SVG，以及少量字体和音效。
- **项目用途**：摇杆、按钮、面板和 HUD 的基础参考或组件来源。
- **范围建议**：需要重新统一颜色、形状和尺寸，不能默认认为与参考视频 UI 风格一致。
- **预览**：`previews/ui-pack-sample.png`
- **ZIP SHA-256**：`a8a14a234911eb648c062622915c93e79e94e97cb7f9f375a70f6617f1174318`

## 审核与后续使用边界

1. 先由用户根据 `previews/README.md` 审核整体风格、建筑类型和配色。
2. 只有明确选中的素材才进入后续制作；未选中的包继续保留为候选，不导入游戏。
3. 若采用 3D 模型制作 2.5D 精灵，需要另行统一相机、光照、透明背景、锚点、地面占地和缩放规范。
4. 后续生成或修改过的素材应记录来源模型、处理方式和输出路径，不能覆盖这里的原始文件。
5. 第三方字体的使用还需单独核对其随包授权信息，不能仅凭整个 UI 包的 CC0 说明推定所有字体授权细节。
