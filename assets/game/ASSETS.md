# 游戏字体与基础音效资源

收录日期：2026-11-15。本文件记录本次加入 `assets/game/` 的字体和音频；授权正文以各资源目录内随附的 License 文件为准。

## 中文字体

### `fonts/NotoSansSC-Variable.ttf`

- **名称**：Noto Sans SC（简体中文），可变字重 `wght`，包含 Thin 至 Black 字重实例。
- **用途**：游戏内中文 UI、标题、提示与结算文字。
- **官方来源**：Google Fonts 官方 GitHub 仓库 [`google/fonts`](https://github.com/google/fonts) 的 `ofl/notosanssc/`。
- **固定版本**：提交 `cc39c4c2c304bc368c9b7c311ea2bcc6013299fe`。
- **原始文件名**：`NotoSansSC[wght].ttf`；本地仅重命名文件，字体二进制内容未修改。
- **官方文件页**：<https://github.com/google/fonts/blob/cc39c4c2c304bc368c9b7c311ea2bcc6013299fe/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf>
- **下载地址**：<https://raw.githubusercontent.com/google/fonts/cc39c4c2c304bc368c9b7c311ea2bcc6013299fe/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf>
- **授权**：SIL Open Font License 1.1；版权行和保留字体名见随附的 `fonts/OFL.txt`。允许随软件再分发，但不得单独销售字体，且再分发时必须保留版权与授权文本。
- **完整性**：17,772,300 字节，与上述固定提交的 GitHub API 元数据一致；SHA-256：`a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da`。

### `fonts/OFL.txt`

- **来源**：同一官方仓库、同一固定提交的 [`ofl/notosanssc/OFL.txt`](https://github.com/google/fonts/blob/cc39c4c2c304bc368c9b7c311ea2bcc6013299fe/ofl/notosanssc/OFL.txt)。
- **用途**：完整保留 Noto Sans SC 的版权声明及 SIL OFL 1.1 授权正文，未作修改。
- **SHA-256**：`1c05c68c34f9708415aada51f17e1b0092d2cea709bf4a94cd38114f9e73d7d9`。

## 基础音效

以下 6 个文件均直接复制自项目已有候选包 `assets/candidates/ui-pack/extracted/Sounds/`，没有重新编码或修改音频内容。候选包为 **Kenney UI Pack (2.0)**，包内标注创建者为 [Kenney](https://www.kenney.nl/)，官方资源页为 <https://kenney.nl/assets/ui-pack>。

所有文件均为 Ogg Vorbis、44,100 Hz、双声道。时长为本机 `afinfo` 报告的约值。

| 本地文件 | 候选包原文件 | 时长 | 游戏用途 | 授权 |
| --- | --- | ---: | --- | --- |
| `audio/devour.ogg` | `tap-a.ogg` | 0.094 秒 | 吞噬目标 | CC0 1.0 |
| `audio/level_up.ogg` | `switch-a.ogg` | 0.227 秒 | 升级、成长阶段提升 | CC0 1.0 |
| `audio/knockdown.ogg` | `click-b.ogg` | 0.057 秒 | 击倒目标 | CC0 1.0 |
| `audio/tower_spawn.ogg` | `switch-b.ogg` | 0.297 秒 | 高塔出现 | CC0 1.0 |
| `audio/victory.ogg` | `click-a.ogg` | 0.367 秒 | 胜利提示 | CC0 1.0 |
| `audio/defeat.ogg` | `tap-b.ogg` | 0.056 秒 | 失败提示 | CC0 1.0 |

这些是同一 UI Pack 提供的基础短提示音，优先保证六类事件均有可再分发资源；后续若需要更强的胜利/失败旋律或事件辨识度，可在保持授权记录的前提下替换。

### `audio/LICENSE-Kenney-CC0.txt`

- **来源**：逐字复制自 `assets/candidates/ui-pack/extracted/License.txt`。
- **授权**：Creative Commons Zero（CC0）；原包明确允许用于个人、教育和商业项目，署名不是强制要求。授权说明及链接见该文件，CC0 页面为 <https://creativecommons.org/publicdomain/zero/1.0/>。
- **用途**：保留 UI Pack 原始授权说明，覆盖上表来自该包的 6 个音效。
- **SHA-256**：`69f7eaa5e05913b4d09cf5848f75390b5c3c9a409ef8555777803d9ca0c171fb`。

## 音频文件 SHA-256

| 文件 | SHA-256 |
| --- | --- |
| `audio/devour.ogg` | `f74c1334c0c1ab9ec69f3dd723611a8eb89a2630df6c3760dee3b09413370c83` |
| `audio/level_up.ogg` | `1a4c90fed704b4f4b36d58f481117cfac5cdc25279a9af97d4765b71ff21ed48` |
| `audio/knockdown.ogg` | `154991a6d9ac80ae193ebad3de7eacb642821e9e48d801d054aa9d2b1004e8c6` |
| `audio/tower_spawn.ogg` | `f2ed0b3b5ad7662f0900d3ca5db81f314af6bf4583802874d308656ba31de1ad` |
| `audio/victory.ogg` | `c5faa31bbf4a921332cdc9e7d7f7d930ca73fc8cc96e35ccc70ed2de975b26e5` |
| `audio/defeat.ogg` | `736c70844cc7cfe87fc95d5e9711c186a593bbe8ccca04e3f4c9cfa7d4e42f3a` |
