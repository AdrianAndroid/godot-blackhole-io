# 首关正式模型

本目录仅包含从候选包复制的原始 GLB 和纹理，没有覆盖候选文件。每个子目录保留对应 Kenney CC0 `License.txt`。

| 分区 | 来源 | 选用模型 |
|---|---|---|
| `commercial/` | https://kenney.nl/assets/city-kit-commercial | low-detail-building-a/b/c、building-a/c、building-skyscraper-a/b/c、detail-parasol-a |
| `suburban/` | https://kenney.nl/assets/city-kit-suburban | building-type-a/b/c/d、tree-small、planter |
| `industrial/` | https://kenney.nl/assets/city-kit-industrial | building-a/b/c、detail-tank、shipping-container-a |
| `roads/` | https://kenney.nl/assets/city-kit-roads | road-straight、road-crossroad、road-intersection、road-square、tile-low、construction-cone、dumpster、traffic-light、light-square |

Commercial 的 `Textures/variation-a.png` 和 `variation-b.png` 来自素材包 `Models/Textures/`，用于运行时材质变体。GLB 的相对纹理引用保持为 `Textures/colormap.png`。

模型在首关中按需使用，不表示候选包中的全部模型都会采用。各模型的统一尺度、地面原点、半径和玩分数值由 `config/model_catalog.json` 与模型注册表管理。
