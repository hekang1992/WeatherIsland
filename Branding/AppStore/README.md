# 气象岛 · App 发版图片

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
