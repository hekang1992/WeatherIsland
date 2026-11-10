# 气象岛 · App 发版图片

## 最新中文交付（2026-11-10）

新版中文整套位于 `zh-Hans/`，使用本次多语言适配后的中文 App 与小组件截图，保留原有宋体、绢纸底色、山水、印章和七张内容顺序。根目录原有中文素材保留。

- 7 张原图：6 张 1179 × 2556 竖图、1 张 2556 × 1179 横版品牌总览。App 仍为 iPhone 竖屏，不增加 iPad 模式。
- 原图压缩包：`zh-Hans/WeatherIsland-AppStore-zh-Hans-7-Images.zip`。
- 统一七图预览：`zh-Hans/preview.jpg`。
- 素材清单及校验：`zh-Hans/manifest.json`、`zh-Hans/validation.json`。
- 中文名称、副标题、推广文本、关键词和介绍：`zh-Hans/metadata.txt`、`zh-Hans/metadata.json`，源文件为 `Branding/AppStoreCopy/zh-Hans.json`。

重新生成：`python3 Branding/render-app-store.py --language zh-Hans`（需要 Pillow）。实际界面、小组件从 `Previews/zh-Hans/` 读取；三幅原作和天气效果示例复用 `Previews/` 原素材，清单记录实际来源和哈希。

以下为根目录历史中文素材说明。

本套共 7 张原尺寸 PNG：6 张 1179 × 2556 px 竖版，以及 1 张 2556 × 1179 px 横版。

| 文件 | 内容 | 尺寸 |
| --- | --- | --- |
| 01-weather-1179x2556.png | 天气首页：把天气，读成一卷山水。 | 1179 × 2556 |
| 02-scenes-1179x2556.png | 原创画境：五十幅画境，每天都有新风景。 | 1179 × 2556 |
| 03-maps-1179x2556.png | 晴雨地图：放眼晴雨，看见天气的走向。 | 1179 × 2556 |
| 04-widgets-1179x2556.png | 桌面小组件：抬眼之间，天气就在桌面。 | 1179 × 2556 |
| 05-overview-2556x1179.png | 横版品牌与功能总览 | 2556 × 1179 |
| 06-cities-1179x2556.png | 城市天气：关心的城市，都有一方晴空。 | 1179 × 2556 |
| 07-weather-scenes-1179x2556.png | 晴雨画境：晴雨更迭，山水各有意境。 | 1179 × 2556 |

- `WeatherIsland-AppStore-Additional-2-Images.zip` 包含新增的第 06、07 张 PNG 原图。
- `WeatherIsland-AppStore-7-Images.zip` 包含全部 7 张 PNG 原图。
- `WeatherIsland-AppStore-5-Images.zip` 保留原先的前 5 张 PNG 原图。
- `preview.jpg` 为原先 5 张缩略预览；`preview-additional.jpg` 为新增 2 张缩略预览，不作为原尺寸图片使用。
- 原图为 RGB PNG、不含透明通道，嵌入 sRGB 色彩配置。采用两倍尺寸绘制后缩小，保留清晰文字、圆角和阴影。
- 画面复用 `Previews/` 中的实际 App 界面、组件导出图与原创山水画，素材对应关系记录于 `manifest.json`。
- 地图按预报功能表述，不宣传实时雷达；小组件保留原界面中的示例数据说明。

重新生成：在 macOS 且 Python 已安装 Pillow 的环境中，运行 `python3 Branding/render-app-store.py`。字体使用系统宋体、黑体和 Arial。

仅生成新增两张并打包合集（保留前五张原图）：`python3 Branding/render-app-store.py --additional-only`。


## 英文与越南文交付（2026-11-10）

沿用原图的底色、山水、手机框、内容顺序和尺寸，每种语言各 7 张原图。横版为品牌总览宣传图；App 本身仅支持 iPhone 竖屏，不提供 iPad 模式。

| 语言 | 原图及预览 | ZIP | 可复制文案 |
| --- | --- | --- | --- |
| English | `en-US/` | `en-US/WeatherIsland-AppStore-en-US-7-Images.zip` | `en-US/metadata.txt`、`metadata.json` |
| Tiếng Việt | `vi/` | `vi/WeatherIsland-AppStore-vi-7-Images.zip` | `vi/metadata.txt`、`metadata.json` |

每套包含 `preview.jpg`、`manifest.json`、`validation.json`。清单记录源截图与哈希，校验记录包含 RGB、透明通道、尺寸、ZIP 完整性及文案长度。App 与小组件截图使用对应语言的生产视图和固定示例数据。

在安装 Pillow 的 Python 环境重新生成：

```sh
python3 Branding/render-app-store.py --language en-US
python3 Branding/render-app-store.py --language vi
python3 Verification/check-localization-resources.py --assets
```

先使用 `Verification/WeatherLocalizationUITests.swift` 捕获对应语言的 App 界面到 `Previews/<locale>/`；小组件通过 `Branding/export-widget-previews.sh` 导出，画境通过 `Branding/export-assets.sh` 与 `Branding/export-global-previews.sh` 导出。这些脚本共享 String Catalog，语言参数与具体运行方法见各脚本。

商店文案源文件为 `Branding/AppStoreCopy/en-US.json` 与 `Branding/AppStoreCopy/vi.json`。修改后重新出图将同步生成纯文本与结构化文案。关键词按 UTF-8 字节数 ≤100、推广文本 ≤170 字符、介绍 ≤4,000 字符校验。

验证结果与已知验证范围见 `Verification/Localization-Validation.md`。本次未上传 App Store Connect。
