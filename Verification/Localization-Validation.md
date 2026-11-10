# 气象岛多语言与发版素材交付验证

验证日期：2026-11-10。范围为简体中文、英文、越南文；品牌分别为气象岛、Weather Island、Đảo Thời Tiết。

按用户补充要求，主 App 与扩展的 `TARGETED_DEVICE_FAMILY = 1`，仅提供 iPhone；App 保持竖屏，不增加 iPad 模式。也检查了已构建 App 与扩展的 `UIDeviceFamily = [1]`，主 App 仅包含 `UIInterfaceOrientationPortrait`（`Artifacts/Localization/iphone-only.json`）。发版素材中的 2556 × 1179 横图是品牌宣传总览，不代表 App 支持横屏。

## 实现内容

- 共享 `AppLanguage` 区分用户偏好和实际语言。按系统首选语言列表顺序匹配 zh/en/vi，中文变体统一简体中文，无匹配使用英文。
- 设置 → 语言可选择跟随系统、简体中文、English、Tiếng Việt；立即生效并持久化，跟随系统在返回前台时重新解析。
- App、模型字符串、Canvas 功能文字、无障碍文案和 Widget 共用 `Shared/Localizable.xcstrings`；932 个条目，其中 914 个为可翻译条目，其余为装饰内容。
- 三类小组件各三种尺寸完成三语适配；通过 App Group 共享语言，切换重新发布显示信息并请求三个类型更新时间线。缓存包含稳定天气类型标识，兼容旧中文缓存。
- 城市显示名与稳定城市 ID、天气缓存键分离。搜索和逆地理编码传入当前语言，国家按代码本地化；独立缓存各语言地名，离线缺失译名时保留原地名。
- 切换语言保留城市、收藏、默认城市、主题、画境和已加载天气。取消旧语言搜索/地名请求，防止旧回调覆盖。
- 中文标题保留宋体；英文、越南文使用系统无衬线字体；处理换行、字距与重音空间。温度保持现有视觉层级；画内题款与印章保持原作。
- 日期、星期按界面语言；显示小时按手机 12/24 小时偏好，天气时间保持所选城市时区。摄氏度和公制不变。
- 主 App、扩展系统名称、定位权限说明、启动屏增加本地化。系统名称和权限框服从 iOS 的应用语言，App 内手动切换控制应用内容。
- 协议、隐私政策入口及中文正文提示翻译，正文和画内中文题款保留中文。没有可用译名的地名、系统地图地名可能保留原写法。官网未改动。

## 环境与结果

Xcode 27.1（27A9275）；iOS 27.0 模拟器：

| 设备 | 范围 | 结果 |
| --- | --- | --- |
| iPhone 18 Pro | 三语首页、画廊、作品详情、地图、城市、手动城市首页 | 通过，截图检查完成 |
| iPhone 13 mini | 同上六类主要页面，三语 | 通过，截图检查完成 |
| iPhone 18 Pro / iPhone 13 mini | 三语最大辅助字号、竖屏和深色首页 | 最终修正后再次运行均为 0 失败；见 `ui-adaptive-standard-final.txt`、`ui-adaptive-compact-final.txt` |
| iPhone 18 Pro | EN→VI 即时切换、重启保留 VI、ZH、恢复系统、不支持语言回退、系统列表 FR/VI/EN 顺序匹配 | 单独复测通过 |
| 三语原生 Widget 视图 | 山水天气、带伞、日照 × 小中大，共 27 种渲染 | 导出并检查预览，扩展构建通过 |

首次标准屏 UI 全套运行的语言切换步骤存在页面就绪等待不足（5 秒）的测试超时；已改为先等待语言入口，再等待语言列表。该场景随后单独运行通过（0 失败）。首次整套日志保留，不将其表述为整套无失败。最终标签栏修正后，两种设备的三语大字号/竖屏/深色场景再次单独运行，均通过。

大字号截图允许正文自然换行、内容纵向滚动；画作构图和题款保持原尺寸。底部浮动栏使用与浅色画作匹配的外观，避免深色模式文字被画作背景冲淡。最终测试只检查竖屏；早期名为 `QA-Landscape` 的截图实际仍为竖屏，不能作为横屏验收证据。

| 工程检查 | 结果 | 记录 |
| --- | --- | --- |
| 主 App + Widget simulator Debug build | 通过 | `Artifacts/Localization/ios-build.txt` |
| `Verification/run-checks.sh` | 通过 | `Artifacts/Localization/service-checks.txt` |
| 编译后 `.strings/.stringsdict` 实际资源加载 | 通过 | `Artifacts/Localization/compiled-localizations.txt` |
| Catalog 完整性、占位符、译文中文残留检查 | 通过：914 条可翻译资源均有三语 | `Artifacts/Localization/resource-validation.json` |
| 三套图尺寸、RGB、无透明、源文件哈希、ZIP 字节完整性、文案长度 | 通过 | 各语言 `validation.json` |
| `git diff --check` | 通过 | 最终工作区检查 |

独立检查涵盖语言匹配顺序/回退、手动覆盖、复数与安全插值、旧 Widget 缓存、城市标识稳定、请求语言、切换后城市/画境/主题/天气缓存保留、离线地名缓存，以及原有服务、地图、收藏、定位、设置、启动和小组件检查。

## 发版素材

原设计的绢纸底色、黛绿山水、手机框和七张内容顺序均保留。图内 App 与小组件采用对应语言的生产视图，使用固定天气示例数据；这些截图不代表捕获当天的实时天气。宣传标题按各语言重排。画内题款保留原作，画外标题、说明和宣传文字翻译。

每套包含：7 张原图、`preview.jpg`、7 图 ZIP、`manifest.json`、`validation.json`、`metadata.json`、`metadata.txt`。

| 语言 | 目录 | 原图 | 关键词 UTF-8 | 推广文本字符 | 介绍字符 |
| --- | --- | --- | --- | --- | --- |
| 简体中文 | `Branding/AppStore/zh-Hans/` | 6×1179×2556 + 1×2556×1179 | 85 / 100 | 79 / 170 | 688 / 4000 |
| English | `Branding/AppStore/en-US/` | 6×1179×2556 + 1×2556×1179 | 97 / 100 | 151 / 170 | 2220 / 4000 |
| Tiếng Việt | `Branding/AppStore/vi/` | 6×1179×2556 + 1×2556×1179 | 96 / 100 | 151 / 170 | 2281 / 4000 |

中文补充套图沿用原中文宋体排版，换入本次中文 App 与小组件截图；三幅山水原作和天气效果示例复用原素材。已检查七图预览及小组件、晴雨画境大图，未发现文字重叠或裁切。

PNG 均为 8-bit RGB、无透明通道，嵌入 sRGB；ZIP 的 7 个成员逐一与交付 PNG 比较一致。App 名称、副标题、推广文本、关键词、完整介绍均已提供纯文本和 JSON；地图按模型预报能力描述，不宣传实时雷达。

## 复现

```sh
bash Verification/run-checks.sh
bash Verification/check-compiled-localizations.sh
python3 Verification/check-localization-resources.py --assets

xcodebuild -project WeatherIsland.xcodeproj -scheme WeatherIsland \
  -configuration Debug -sdk iphonesimulator \
  -derivedDataPath work/LocalizationBuild CODE_SIGNING_ALLOWED=NO build

WEATHER_QA_APP_BUILD="$PWD/work/LocalizationBuild" \
  bash Verification/run-home-ui-checks.sh SIMULATOR_UDID WeatherLocalizationUITests.swift

WEATHER_ISLAND_LANGUAGE=en bash Branding/export-widget-previews.sh "$PWD/Previews/en-US"
WEATHER_ISLAND_LANGUAGE=vi bash Branding/export-widget-previews.sh "$PWD/Previews/vi"
python3 Branding/render-app-store.py --language zh-Hans
python3 Branding/render-app-store.py --language en-US
python3 Branding/render-app-store.py --language vi
```

出图 Python 需要 Pillow。本次使用已安装 Pillow 的工作区依赖 Python。UI runner 为每次运行创建独立的临时项目、截图目录和 `.xcresult`，日志中保留具体路径；交付目录保存相关测试日志和预览拼图。

## 验证范围的边界

完成的是模拟器构建、独立逻辑检查、主要页面截图检查及原生 Widget 视图渲染。尚未在真实 iPhone 上验证 WidgetKit 调度、主屏幕实际刷新时机、系统添加列表及定位权限弹窗；未穷举每个次级页面与所有字号、外观组合。未进行签名 Archive、TestFlight 或 App Store Connect 上传/审核提交。
