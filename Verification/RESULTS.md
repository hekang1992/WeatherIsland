# WeatherIsland 验证记录

更新：2026-11-02（Asia/Shanghai）。工程位于 `/Users/hekang/Desktop/WeatherIsland`。


## 地图布局、透明面板与图层效果（2026-11-02）

- 右侧竖向排列区域刷新、降水／气温／风速／云量，以及底图切换与回到城市。缩短时间轴，地图延伸到时间轴和 Tab 栏背后；时间轴使用低透明度底色与超薄材质，保留地图可见性。按可用高度收紧工具栏，防止小屏遮挡。
- 气温采用冷暖渐变及 5°C 等温线；风速采用青绿至蓝色渐变及 10 km/h 等值线；云量采用灰蓝色和随覆盖比例变化的透明度。风速数据不包含风向，因此没有绘制方向流线。缩小选点浮标，分离数字和单位，按钮／读数与图层强调色一致。提高图层栅格分辨率，柔化预报范围边缘并拉近默认视野。
- 最终模拟器 Debug 构建通过：`/tmp/WeatherIsland-MapLayers-final-build.log`。离线回归 `bash Verification/run-checks.sh` 全部通过，日志 `/tmp/WeatherIsland-MapLayers-checks.log`。
- iPhone 17 Pro / iOS 27.0 的两项地图 UI 测试通过：`testMapLayerPresentations` 与 `testMapRightRailAndCompactTimeline`。覆盖三种图层选中状态和单位、选点可见、七个右侧按钮对齐及可点击、时间轴高度与 Tab 间距、底图切换／回到城市、66 小时和播放／暂停。结果 `/tmp/WeatherIsland-MapLayers-QA.xcresult`；源码 `Verification/WeatherMapLayoutUITests.swift`。最后的视野和边缘柔化调整在测试后通过最终构建及截图复查。
- 已人工检查最终气温／风速／云量截图和 iPhone SE（第 3 代）小屏云量截图：`Previews/Weather-Map-Temperature.png`、`Weather-Map-Wind.png`、`Weather-Map-Cloud.png`、`Weather-Map-Compact.png`。截图使用明确标注的离线示例天气与 MapKit 底图；小屏本轮为截图检查，未计入自动化通过结果，未进行真机验收。

## 桌面小组件（2026-11-02）

- 新增三个 WidgetKit 功能：山水天气、带伞提醒、日出日落；每个支持 systemSmall、systemMedium、systemLarge，共九个布局。App 内「设置 → 桌面小组件」与系统扩展共享绘制视图；预览无实况时明确标注示例数据。
- 最终模拟器 Debug 构建通过，主 App 正确嵌入 `WeatherWidgets.appex`；日志 `/tmp/weather-widgets-build.log`。最终 iPhone arm64 Release 编译通过（关闭签名），日志 `/tmp/weather-widgets-device.log`。
- 完整数据回归及 `--live` 真实接口检查通过，包含新小组件的 API 解析、夜间图标、Codable 快照、异常数组长度、缺失降水、极地日照缺失、缓存过期、小时滚动和城市时区；扩展独立接口实际取得当前天气、三日预报和六个后续小时。日志 `/tmp/weather-widgets-checks.log`。
- iPhone 17 Pro / iOS 27.0 专用模拟器 `WeatherIsland-Widgets-QA` 上，两项 UI 测试通过：`testAllNineWidgetLayouts` 覆盖九个预览的可见性和屏幕边界并保存截图，`testSettingsGalleryAndWidgetLinks` 覆盖设置入口、三种 URL 跳转、标题和关闭。结果 `/tmp/WeatherIsland-Widgets-QA-Verified.xcresult`，日志 `/tmp/weather-widgets-ui-verified.log`。
- 界面测试发现并修复预览页导航栏被全局样式隐藏，以及装饰圆形视图造成辅助功能边界越界；修复后重跑两项测试全部通过。已人工检查九张最终模拟器截图及导出总览，文字、概率图、日照弧线和底部时间标记均可见。
- 设计总览 `Previews/Widgets-Overview.png`，独立布局 `Previews/Widget-{landscape,rain,daylight}-{small,medium,large}.png`；模拟器截图汇总 `Previews/Widgets-iOS-QA.jpg`。导出图为示例数据。
- 可复现命令：`bash Verification/run-checks.sh --live`；已启动模拟器上的 UI 检查为 `bash Verification/run-widget-ui-checks.sh <UDID>`。本轮 UI 使用等效临时 XCTest 工程执行，仓库脚本已通过 shell 语法检查。
- 验证边界：已完成扩展编译/嵌入与共享 UI 的模拟器验收；未进行系统主屏幕添加、WidgetKit 后台调度或真机运行验收。真机签名需为主 App 和扩展开通同一 App Group `group.com.weather.app.ios`。

## 协议网站与 App 内阅读（2026-11-02）

- 已将协议发布到 GitHub Pages，使用独立 `gh-pages` 分支；线上提交 `a4ec8b4e921008386eb8dce424e82622ee6d66fb`。隐私政策为 `https://hekang1992.github.io/WeatherIsland/privacy.html`，服务协议为 `https://hekang1992.github.io/WeatherIsland/terms.html`，根目录同样提供隐私政策。GitHub Pages 状态 `built`、`https_enforced=true`，两个正文地址实际 GET 均返回 HTTP 200。
- `Scripts/build-legal-site.py` 从 `WeatherSettingsDocument` 生成 `LegalSite/`，校验线上 HTML 与当前生成结果逐字节一致；导航与样式的本地引用均可解析。`Scripts/publish-legal-site.py` 仅发布网站文件；重复运行保留原提交，验证未修改内容不重复提交。协议补充在线托管的 IP 地址处理及 GitHub 隐私声明入口。
- App 保留两份离线协议全文；协议中的第三方条款、隐私说明、在线版本与天气来源入口统一使用内嵌 `WKWebView`。网页新窗口及用户点击的主页面链接由同一 WebView 加载，非 HTTP(S) 跳转被拦截。提供返回、加载提示和失败重试，浏览会话使用非持久化网站存储；系统权限按钮继续进入 iOS 设置。
- `bash Verification/run-checks.sh` 全部通过（连接恢复、定位、偏好、数据解析、缓存与地图），日志 `/tmp/weather-legal-checks-complete.log`。
- 最终 iPhone 17 Pro / iOS 27.0 的 2 项协议专项交互检查全部通过：本地服务协议与隐私政策全文可达，Open-Meteo / Apple / GitHub 隐私说明与数据条款在 App 内打开，在线隐私政策加载完成，网页内跳转服务协议仍保持 App 前台，并可返回本地协议。报告 `/tmp/WeatherIsland-LegalFinalQA.xcresult`，日志 `/tmp/weather-legal-ui-final.log`；已人工查看最终截图 `/tmp/WeatherIsland-Settings-Privacy-Online.png`。
- 最终 Debug iOS Simulator 双架构编译通过，日志 `/tmp/weather-legal-build-final.log`；没有本次 WebKit 导航代理的签名警告。首轮协议网页专项通过；同组既有设置用例在从 iOS 设置重新激活 App 时超时，协议全文与网页入口步骤已通过，详细报告 `/tmp/WeatherIsland-LegalQA.xcresult`。

## 晴、多云、阴的视觉辨识度（2026-11-02）

- 山水画新增完整暖阳、局部遮日浮云、连续灰青层云三种独立天空。晴天增加柔和暖光与水面金色反射，阴天降低环境亮度；小岛插画同步调整太阳大小、遮挡关系、云量及饱和度。
- 最终 Debug iOS Simulator 双架构构建通过（关闭代码签名），日志 `/tmp/WeatherIsland-WeatherClarity-build.log`。`bash Verification/run-checks.sh` 全部通过，日志 `/tmp/WeatherIsland-WeatherClarity-checks.log`；采用固定样本与离线检查，未请求真实天气服务。
- `bash Branding/export-global-previews.sh --weather-only` 通过。已人工查看 `Previews/Weather-Clear-Cloudy-Overcast.png` 与 `Previews/Weather-Island-Clarity.png`：覆盖江渚、山水、花鸟三种画境和 85 点宽城市卡片，确认静止画面的太阳、云量和冷暖差异。日晕透明端保持相同色相，消除灰色光圈与渐变边界。
- 对照图由实际 SwiftUI / Canvas 组件通过 macOS ImageRenderer 离屏绘制；本轮未运行模拟器交互测试。

## 设置功能与配图比例（2026-11-02）

- 补齐界面主题、关于我们、服务协议与隐私政策四个入口。主题支持跟随系统／浅色／深色，立即应用并本机持久化；版本和构建号读取 Bundle。协议与隐私说明可离线阅读，包含实际的数据来源、定位、地图网格与缓存行为，隐私页可打开 App 系统权限设置。
- 早期画面检查发现“已选择深色但实际仍为浅色”：启动根容器与 Tab 容器同时设置外观，根容器又读取不同的默认存储。已统一为 Tab 容器按应用模型设置外观，移除生产页面的强制浅色与 Info.plist 的 Light 限制；测试新增对实际环境深浅色的断言，避免只检查选中状态。
- 配图原先分别按容器宽、高缩放，在设置三连缩略图和窄城市卡片中发生拉伸。宋韵画境现按 360 × 248 等比居中；首页、缩略图和城市卡片采用原始横幅比例，天气详情同样保留比例。早期小岛组件按 360 × 230 等比绘制，天气粒子也保持形状。
- 最终 Debug 模拟器双架构构建通过，日志 `/tmp/weather-settings-build.log`；最终 Release iPhone 架构构建通过（关闭代码签名），日志 `/tmp/weather-settings-device-build.log`。两者均包含辅助字号布局优化。
- `bash Verification/run-checks.sh` 通过，日志 `/tmp/weather-settings-final-checks.log`：新增主题损坏值回退、持久化、预览隔离、城市／画境／天气对象保留检查；已有首次联网、定位名称恢复、手动选城保护、天气和地图回归通过。本轮数据回归采用保存的接口样本与可控异步响应，没有据此声称重新验证真实服务可用性。
- iPhone 17 Pro / iOS 27.0 最终交互组 `/tmp/WeatherIsland-SettingsFinalQA.xcresult`：3 项通过、0 失败。覆盖深浅色实际显示、重启保留、画廊返回、版本与来源入口、协议全文滚动、隐私全文、系统设置跳转与返回；另覆盖首页 → 城市卡片 → 设置画廊 → 画境详情的配图截图与导航。早期 About 点击用例因未等待目标可点击而失败，补充可点击检查后同一流程通过。
- 系统外观专项 `/tmp/WeatherIsland-SettingsSystemQA.xcresult`：1 项通过、0 失败。用 simctl 将测试设备设为系统深色，验证默认跟随系统、手动浅色、再回到跟随系统时实际页面恢复深色；测试后已恢复该模拟器为浅色。该项测试有系统深色前置条件，不能直接计入默认浅色环境的整套运行。
- 初轮 iPhone SE（第 3 代）最大辅助字号专项 `/tmp/WeatherIsland-SettingsSmallQA.xcresult` 通过主题选择与隐私全文可达检查；画面复查仍发现主题说明被左右图标挤窄，随后改为辅助字号时图标与选择标记一行、说明文字独占整行。最终补测 `/tmp/WeatherIsland-SettingsSmallFinalQA.xcresult` 1 项通过、0 失败，确认深色实际显示和隐私全文末尾可达；截图 `Previews/Weather-Settings-Large-Type.png` 为优化后最大字号的实际页面。
- 已保存并人工查看 `Previews/Weather-Artwork-Home.png`、`Weather-Artwork-Cities.png`、`Weather-Artwork-Gallery.png`、`Weather-Artwork-Detail.png` 及 `Weather-Settings-Light.png`、`Weather-Settings-Dark.png`、`Weather-Settings-About.png`、`Weather-Settings-Privacy.png`。首页配图截图来自离线设计检查入口，使用示例天气；设置交互入口使用隔离的测试偏好，未改写正常用户收藏和主题。
- 自动化源码为 `Verification/WeatherSettingsUITests.swift`；临时 UI 测试工程 `/tmp/WeatherIslandMapQA` 的 MapQA 目标运行这些测试。设备架构构建关闭代码签名；未进行真机安装与运行，外部第三方页面内容及真实系统网络授权弹窗不属于本轮验收。

## Xcode 编译与启动修复（2026-11-02）

- 读取用户 Xcode 最新构建记录：14:10–14:11 的三次失败均为 `cannot find 'WeatherLocationNaming' in scope`，编译日志不包含 `WeatherLocationNaming.swift`。磁盘工程已有该文件的 Sources 条目，新的命令行真机架构构建可通过；失败记录反映 Xcode 当时使用的编译列表未纳入新增文件。
- 将 `WeatherLocationNaming` 原样合并到已有的 `WeatherPlace.swift`，移除独立文件及工程引用，并同步回归脚本。城市名称恢复、重试及取消逻辑不变，既有编译列表也能解析该类型。
- 修复后 Debug 模拟器编译通过（常规签名，arm64 / x86_64）：`/tmp/weather-buildfix-simulator-final.log`；Debug iPhone 真机架构编译通过（关闭代码签名）：`/tmp/weather-buildfix-device-final.log`。未进行真机安装验收。
- `bash Verification/run-checks.sh` 全部通过：首次联网、定位引导、名称恢复、迟到响应与手动选城保护、天气数据、地图和地区缓存，日志 `/tmp/weather-buildfix-checks.log`。
- 已在 iPhone 17 Pro / iOS 27.0 测试模拟器安装并正常启动常规 App（无测试启动参数），人工检查首页已显示地区名称、天气和四个 Tab；启动进程 PID 18335，截图 `/tmp/weather-buildfix-running.png`。模拟器沿用之前测试保存的位置与缓存，此次不作为首次安装或真实 GPS 验收。

## 首次授权后的地区名称恢复（2026-11-02）

- 问题：坐标天气请求可在联网放行后恢复，但此前行政区反向解析只尝试一次，5 秒超时、断网或无名称结果后不再恢复，导致天气已更新而标题长期停留在「当前位置／地区名称暂缺」。
- 修复：使用独立的 `WeatherLocationNaming` 前台任务恢复行政区名称。单次解析 15 秒超时，失败或空城市每 60 秒重试；天气更新和返回前台会重新尝试。用户选城、重新定位、打开选城页或离开前台时取消旧任务，每次查询独立管理 `CLGeocoder`，旧任务不能取消新查询。名称更新沿用坐标缓存，保留已有天气和获取时间。
- 只有国家名、空白城市、无效坐标、不同坐标或非当前位置结果均不算有效解析。选择版本号与坐标身份拦截迟到结果，避免覆盖手动选城。未获取真实名称前显示解析／自动重试状态，不编造城市。
- 确定性回归通过：`bash Verification/run-checks.sh`，日志 `/tmp/weather-naming-checks-final.log`。新增 8 次查询链（断网、nil、空白、国家名、无效坐标、手动城市、不同坐标、有效城市），验证 60 秒重试间隔、请求和等待取消、新旧任务交错隔离、重启解析、持久化与手动城市保护；既有天气／地图／首次联网检查通过。
- Debug 模拟器双架构编译通过：`/tmp/weather-naming-build-final.log`。早期编译发现取消回调的 Swift 6 非 Sendable 捕获错误，已用 MainActor 隔离的查询对象修复。源码编辑期间的早期命令行回归因输入文件变化中止，最终固定源码后完整运行通过。
- 第一轮模拟器回测 `/tmp/WeatherIsland-NamingQA.xcresult`：真实系统定位允许、拒绝后手动选择及重启、模拟名称自动恢复、前后台名称恢复与既有 3 项首次联网检查通过。手动选城专项因脚本使用了只在首次引导页提供的 Tokyo 按钮而失败，已改为选择页面实际收藏的上海。该轮名称截图时已经恢复，随后为 Debug 成功名称增加 8 秒延迟，并增加标题由「当前位置」变成具体城市的明确断言。
- 手动选城首次补测 `/tmp/WeatherIsland-NamingManualQA.xcresult` 未启动用例：QA 模拟器关闭导致 Runner 初始化时被终止；此记录不计为功能通过。

- 最终专项：`/tmp/WeatherIsland-NamingFinalQA.xcresult` 中手动选择上海后旧地名不覆盖、返回前台后自动补齐地区两项通过；同组严格过渡用例因期望的无障碍标签少了「当前」二字而失败。修正测试文字后，`/tmp/WeatherIsland-NamingTransitionQA.xcresult` 单项补测通过（1 项、0 失败），明确断言已加载天气时标题先为「当前位置」，随后无需点击定位自动变为「北京市 · 海淀区」，未来预报仍存在且无弹窗。日志分别为 `/tmp/weather-naming-final-ui.log`、`/tmp/weather-naming-transition-ui.log`。该轮只修改测试夹具的返回延迟和断言，没有修改生产恢复逻辑。
- 已导出最终截图：`Previews/Weather-Home-Name-Pending.png`、`Weather-Home-Name-Recovered.png`、`Weather-Home-Name-Foreground.png`、`Weather-Home-Name-Manual.png`。系统定位授权由模拟器实际操作，坐标由 XCTest 提供，天气使用真实接口；恢复用例的断网、空名称、北京行政区名称由 Debug 夹具模拟，重试等待缩短为 3 秒、成功名称额外延迟 8 秒。未使用国行真机，不将模拟恢复等同于真实系统联网弹窗或真实 GPS 验收。

## 首页气温与启动定位验收（2026-11-02）

- 修复首页气温数字、度数与天气说明的对齐；度数独立置顶，数字与说明按末行基线排列，宽度不足时改为上下排列。辅助功能大字号固定使用上下布局。取消首次从 0 起跳，直接显示天气读数；实际数值变化时保留动画并遵循减弱动态效果。
- 新安装在品牌入场结束后自动请求使用期间定位，取得坐标或用户明确选择城市前不请求默认上海天气、不进入空首页。已有手动城市选择会持久化，后续启动直接使用；旧版有效手动城市可迁移，损坏收藏恢复为首次选择流程。
- 拒绝／受限／超时提供手动选城；拒绝时还提供系统设置入口。首次城市选择不能直接滑掉，已收藏和常用城市可离线选择；已有可用城市时，后续定位失败可保留当前城市。进入后台取消未完成的定位，返回前台按状态恢复；手动选城取消定位、反向解析和超时，选择版本号同时拦截迟到回调。
- `bash Verification/run-checks.sh` 全部通过，包含 CONNECTION PASS、LOCATION ENTRY PASS、LOCATION PASS、GLOBAL PASS、MAP PASS、Weather service PASS。新增用例覆盖首次选择、手动偏好保存／迁移、重复选择同城、非法坐标、取消与后台恢复、失败不破坏既有城市、迟到名称不覆盖手动城市、Preview 隔离。日志：`/tmp/weather-location-checks-final.log`。
- 最终生产源码 iOS Simulator Debug 构建通过（arm64 / x86_64，关闭签名）：`/tmp/weather-location-build-final.log`。
- iPhone 17 Pro / iOS 27.0：真实系统定位授权允许、拒绝后选 Tokyo 与重启／前后台保持选择、城市搜索弹层内重新定位失败后正确展示提示、定位等待期间手动选城取消后续超时、12 秒无坐标超时后选城均通过。无坐标用例通过 Debug 开关抑制位置更新，授权弹窗仍由系统实际显示。原有首次联网 3 项回归通过；气温 0、9、23、-28、-100、100 的边界与不重叠检查通过。合并报告：`/tmp/WeatherIsland-HomeQA-Final.xcresult`，日志：`/tmp/weather-home-ui-final.log`。该合并报告中的系统设置用例因自动化未匹配到 Settings 入口而失败，其补测单独记录。
- 系统设置授权最终补测通过：真实拒绝 → 系统设置「使用 App 期间」→ 回到 App 自动恢复定位、取得真实天气并进入首页；同时重新验证首次直接允许定位，共 2 项、0 失败。报告 `/tmp/WeatherIsland-LocationAuthorizationQA.xcresult`，日志 `/tmp/weather-location-authorization-ui.log`。先前补测曾遇到 Settings 中文入口／记忆页面定位失败，以及模拟器未继续提供有效坐标而触发真实 12 秒超时；最终用例使用系统 Settings 权限项标识，并通过 `XCUIDevice.shared.location` 提供带当前时间的模拟坐标，测试后清理。补测未修改生产源码，没有放宽进入首页或当前坐标天气断言。
- iPhone SE（第 3 代）/ iOS 27.0：同六种气温的边界与不重叠检查通过，报告 `/tmp/WeatherIsland-HomeSmallQA.xcresult`、日志 `/tmp/weather-home-small-ui.log`。最大辅助字号（accessibility-extra-extra-extra-large）下 -100° 和说明上下分开、均在屏幕内，检查通过，报告 `/tmp/WeatherIsland-HomeAccessibilityQA.xcresult`、日志 `/tmp/weather-home-accessibility-ui.log`。测试后已恢复模拟器标准字号。
- 已人工检查并保存模拟器截图：`Previews/Weather-Home-Current-Location.png`（模拟海淀坐标，真实天气接口）、`Weather-Location-Denied.png`、`Weather-Home-Manual-City.png`、`Weather-Home-Settings-Granted.png`、`Weather-Home-Small.png` 和 `Weather-Home-Large-Type.png`。气温边界截图来自 Debug 离线数据，不能作为真实温度记录。
- 未使用真机；模拟位置不验证硬件 GPS、国行系统首次联网弹窗、实际受限设备或近似定位的系统表现。既有联网恢复以 Debug 模拟阻断进行回归，未声称模拟器复现国行联网权限弹窗。

## 首次联网与自动恢复验收（2026-11-02）

- 修复首次无缓存、系统联网权限尚未放行时提前进入空首页的问题。品牌入场结束后显示独立连接等待页；获取当前地区天气后自动创建首页与四个 Tab。有缓存时立即进入首页，空气质量请求独立进行。
- 天气与空气质量使用 `waitsForConnectivity` 会话，资源等待上限 30 秒。网络连接类错误在前台按 1 / 2 / 4 / 8 / 15 秒间隔重试，之后保持 15 秒；离开前台或切换城市会取消原恢复任务，回到前台重新检查。HTTP / 数据错误不作为联网权限错误持续重试。
- 12 秒后或首次错误时保留「重新连接」「检查网络设置」「稍后进入」操作，自动重试期间按钮不会反复消失。首次连接等待期间不创建首页或系统 Tab 栏。「稍后进入」允许继续使用其他页面，同时保留前台恢复任务。
- `bash Verification/run-checks.sh` 最终通过：新增 CONNECTION PASS，原有 LOCATION / GLOBAL / MAP / 天气服务回归通过。确定性测试覆盖连续 7 次模拟权限未放行后自动恢复、退避上限、非联网错误停止重试、取消退避、天气与空气独立恢复、请求中取消后恢复同城市、缓存启动及离线 Preview 不请求网络。日志：`/tmp/weather-network-checks-final.log`。
- 最终 iOS Simulator Debug 构建通过（arm64 / x86_64，关闭签名），日志：`/tmp/weather-network-build-final.log`。只有既有 AppIntents 元数据跳过警告。
- iPhone 17 Pro / iOS 27.0 模拟器的 3 项 XCUITest 全部通过：联网前无首页及 Tab 栏、模拟两次 `dataNotAllowed` 后自动加载真实天气并进入首页、稍后进入和设置访问、自动恢复期间点击手动重试、进入首页后往返地图。最终报告：`/tmp/WeatherIsland-StartupQA-Verified.xcresult`，日志：`/tmp/weather-startup-ui-verified.log`。UI 用例源码保存在 `Verification/WeatherStartupUITests.swift`，本次由 `/tmp/WeatherIslandMapQA` 的独立 UI 测试目标执行。
- 已查看最终模拟器截图：`Previews/Weather-Startup-Connecting.png`、`Previews/Weather-Startup-Waiting.png`、`Previews/Weather-Startup-Recovered.png`，包括重试按钮文字对比度。前两张的权限延迟来自 Debug 模拟，恢复后的天气来自真实接口。
- 本次未使用国行真机，也没有复现系统自身的联网权限弹窗；模拟器使用 `--startup-connection-check` 复现请求被阻止和稍后恢复。仍需国行设备实际确认「首次弹窗稍后允许」「拒绝后进入设置放行」「已有缓存且离线启动」的系统行为。不将蜂窝网络状态或本地网络权限当作该联网授权的准确状态。

## 晴雨地图验收（2026-11-02）

- 底部新增「地图」Tab；实装 Apple 地图、降水 / 气温 / 风速 / 云量热力层、选点读数、城市选择、标准 / 卫星切换、回到所选城市，以及 12 / 24 / 66 小时时间轴与播放。
- 最终 iOS Simulator Debug 构建通过，包含 arm64 与 x86_64；关闭代码签名。工程、scheme 均为 WeatherIsland。构建日志：`/tmp/WeatherIsland-MapBuild.log`。
- `bash Verification/run-checks.sh` 通过；`bash Verification/run-checks.sh --map-live` 也通过。本次实际联网验证 49 个坐标返回 67 个对齐的小时点，经过生产服务解码后生成区域预报；原有 LOCATION / GLOBAL / 天气服务回归全部通过。地图回归覆盖 Mercator 网格、日期变更线、双线性插值、缺测、错误网格 / 时刻、66 小时范围、无雨透明与区域缓存。
- 在 iPhone 17 Pro / iOS 27.0 模拟器运行两组临时 XCUITest，最终 2 项通过、0 失败。验证首次地图取景、四种图层切换、滑至第 66 小时、播放与切换 Tab 自动暂停、底图切换、数据说明与城市选择；真实接口模式下验证加载完成、地图选点、拖动后加载新区域与回到城市。测试工程在 `/tmp/WeatherIslandMapQA`；最终报告为 `/tmp/WeatherIsland-MapQA-Verified.xcresult`。
- 已修正验收中发现的首次取景偏远、右侧控件遮挡地图署名和重试后一直强制刷新问题；生成新区域图层前核对预报区域，避免使用旧区域图像。地图边缘插值加入浮点容差。
- 已人工查看以下最终模拟器截图，确认图层、选点标记、浮层控件、图例、时间轴与四个 Tab 的布局：`Previews/Weather-Map-Precipitation.png`、`Previews/Weather-Map-Temperature.png`、`Previews/Weather-Map-Live.png`。前两张明确标注演示数据；最后一张为本次真实接口返回的气温预报。
- 天气颜色来自 7 × 7 个采样点的模型小时预报插值；降水不是雷达实测。移动 / 选点沿用搜索城市的时区。真机、小屏 / 大字号排版、VoiceOver、定位权限及真实搜索输入流程尚未在此次地图验收中验证；自动化只验证了城市列表的选择流程。后台与减弱动态效果的处理已实现，未自动化触发系统环境进行验证。

## 既有页面执行结果（2026-10-30）

- iOS Simulator SDK Debug 构建通过：`WeatherIsland.xcodeproj` / `WeatherIsland`，generic iOS Simulator，关闭代码签名，包含 arm64、x86_64 编译。
- `bash Verification/run-checks.sh` 通过。本轮采用固定接口样本和可控异步响应，未再次请求真实天气或空气质量服务。输出中的「live response decoding」指保存的真实响应样本解码，不代表本轮联网。
- `bash Branding/export-global-previews.sh` 通过：直接使用工程的 SwiftUI / Canvas 组件生成六种宋韵意境放大图、50 张总览、长首页、首页上部、六种天气特效对照及十张独立场景图。
- 已人工查看总览、放大图、首页和天气特效静态预览，检查山水与花鸟构图、字体与数据区块。图片由 macOS ImageRenderer 离屏渲染，不是 iOS 模拟器截图。

## 回归覆盖

- 全部 WMO 天气代码、可选字段、缺失紫外线、不完整响应、正确降水单位、跨午夜高低温归属。
- 24 个预报时点，北京、东京、伦敦、纽约四个时区的日期与日出日落样本。
- 按地区构造天气与空气质量坐标请求、地区缓存隔离、并发请求、取消和迟到响应隔离；旧上海缓存只迁移到上海。
- 缓存保存、离线保留天气、首次失败、Preview 不读取真实缓存、不联网。
- 定位坐标缓存身份不随行政区名称变化；请求过程中与完成后补齐名称，保留天气和获取时间；其他坐标名称不覆盖已有数据；手动切换城市后忽略迟到的定位名称。
- 收藏重复添加、最少保留一城、默认与选中城市删除后的修复、持久化恢复。
- 50 个唯一插画标识、10 卷宋韵意境；法国巴黎与美国同名城市不混用地标，地区自动选画的标识兼容性。
- 空气质量部分字段缺失与日照进度边界。

## 本轮界面与交互实现

- 50 张插画采用 10 卷宋韵意境，每系列 5 种构图；原有已保存的场景 ID 保留。无真实照片、远程图片检索或图片下载请求。
- 设置 → 宋韵画境 → 画境小赏明确显示系统导航栏和返回入口；实际点击返回尚待设备验收。
- 首页按当前天气、未来趋势、当前环境、日照和生活建议组织。温度与降水概率使用明确单位，缺失降水概率显示暂无预报。
- 定位接受有效坐标后立即发起天气请求；行政区解析独立进行，每次上限 15 秒；失败／空名称保留坐标天气，在前台每 60 秒重试，天气更新或返回前台时重新尝试。坐标获取上限 12 秒，复用 60 秒内有效位置，短暂 locationUnknown 不立即中止。重复定位触发刷新。
- 近似位置不展示区县；权限失败保留原地区并提供搜索或系统设置入口。系统授权弹窗已在 2026-11-02 的首页回测中覆盖允许／拒绝，硬件 GPS 和系统受限分支仍未实机验证。
- 天气剧场可以切换 11 种特效，并打开明确标注的离线详情；真实天气不受演示选择影响。

## 早期验收限制（2026-10-30）

2026-10-30 执行时 CoreSimulator 服务连接失败、无法发现可用运行时，因此当时完成 SDK 编译与离屏静态视觉检查，未完成模拟器或真机交互验收。2026-11-02 已恢复模拟器并完成上述地图交互验收。当时未完成的系统定位弹窗允许／拒绝和模拟海淀坐标、定位 12 秒超时，已在 2026-11-02 的首页回测中补测；真实 GPS 与近似定位、真实全球搜索、导航返回、图表点击、动画流畅度和系统减弱动态效果仍需设备验证。12 秒（坐标获取）与 15 秒（单次地名解析）为当前代码中的超时界限，不是实测 GPS 获取耗时；早期地名解析上限为 5 秒。

此前轮次已记录真实天气及空气质量接口返回成功；不据此声称本轮或所有地区当前都可访问。可使用 `bash Verification/run-checks.sh --live` 额外检查真实天气请求。

## 品牌资源

保留 WeatherIsland 名称、Logo、AppIcon 和 LaunchScreen，版本 1.0.0。品牌启动页只由应用根容器控制，不绑定 Tab 切换。全局主题、关于、服务协议和隐私政策仍标记「即将开放」。


## 宋韵视觉更新（2026-10-30）

- 50 幅 Canvas 画境改为绢色、淡墨与青绿的原创意境，分烟岚江渚、庭院清供、水墨行舟、青绿山水、荷风莲影、墨竹松风、远山秋霁、寒江晴雪、花鸟小景、田园清和十卷。保留原场景 ID，使已保存的选择继续生效。
- 首页、设置、画廊、天气详情、天气剧场和启动页统一配色；中文展示标题采用宋体，温度和正文保持可读的数据排版。
- Logo 改为圆形山水纹样，配朱砂小日；图标与启动页资源由同一 SwiftUI 品牌组件导出。
- 修正山水渐隐和岸线边缘；雨雪、雾与雷光在画境上减弱，保留天气演示与减弱动态效果支持。
- 无真实照片，无新增图片搜索或图片下载请求。画境不是历史古画复制，也不代表城市实景。

- 本轮 `export-global-previews.sh` 与 `export-assets.sh` 均成功；已人工检查六幅放大图、50 幅总览、首页上部、长首页及品牌启动页。预览使用离线数据。
- 完整数据回归通过，包含 LOCATION PASS、GLOBAL PASS、MAP PASS 和天气服务 PASS。验证用稳定源码副本，包含地图边缘浮点容差修正；没有再次发起真实天气或图片请求。

- 桌面原工程的最终 iOS Simulator SDK Debug 构建通过（arm64 / x86_64，关闭签名），包含新 AppIcon、BrandMark 和宋体 LaunchScreen。日志：`/tmp/weather-song-build-final.log`。当时未进行 CoreSimulator 交互验收；2026-11-02 的地图验收结果见上。
