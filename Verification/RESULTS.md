# WeatherIsland 验证记录

更新：2026-11-02（Asia/Shanghai）。工程位于 `/Users/hekang/Desktop/WeatherIsland`。

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
- 定位接受有效坐标后立即发起天气请求；行政区解析独立进行，上限 5 秒，失败保留坐标天气。坐标获取上限 12 秒，复用 60 秒内有效位置，短暂 locationUnknown 不立即中止。重复定位触发刷新。
- 近似位置不展示区县；权限失败保留原地区并提供搜索或系统设置入口。系统授权弹窗已在 2026-11-02 的首页回测中覆盖允许／拒绝，硬件 GPS 和系统受限分支仍未实机验证。
- 天气剧场可以切换 11 种特效，并打开明确标注的离线详情；真实天气不受演示选择影响。

## 早期验收限制（2026-10-30）

2026-10-30 执行时 CoreSimulator 服务连接失败、无法发现可用运行时，因此当时完成 SDK 编译与离屏静态视觉检查，未完成模拟器或真机交互验收。2026-11-02 已恢复模拟器并完成上述地图交互验收。当时未完成的系统定位弹窗允许／拒绝和模拟海淀坐标、定位 12 秒超时，已在 2026-11-02 的首页回测中补测；真实 GPS 与近似定位、真实全球搜索、导航返回、图表点击、动画流畅度和系统减弱动态效果仍需设备验证。12 秒与 5 秒为代码中的超时界限，不是实测 GPS 获取耗时。

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
