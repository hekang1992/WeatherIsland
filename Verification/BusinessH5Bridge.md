# WeatherIsland H5 原生接入

`WeatherIslandApp.init()` 调用 `BusinessAdjust.start()`，通过 CocoaPods `pod 'Adjust', '~> 5.8.2'` 接入，仅 App target 链接 `AdjustSdk`；使用 `WeatherIsland.xcworkspace` 打开工程。App Token 为 `4g040hdbpx4w`。Debug 用 sandbox，Release 用 production；联调安装回执应匹配同一 App 和环境。SDK 日志关闭，不记录 ADID 或设备数据。

## Adjust ID

`BusinessTabsView` 在 WKWebView.load 前注册 `getAdjustId` 和 `getDeviceInfo`。

```javascript
window.webkit.messageHandlers.getAdjustId.postMessage({
  callback: 'onNativeAdjustId_1'
})
// 原生安全调用本次动态回调：
window.onNativeAdjustId_1({adjustid: '<32位十六进制ADID>'})
```

SDK ADID 等待上限 4500ms，H5 桥上限 5s。H5 启动和点击发送验证码时异步请求；提交验证码时，将已获得的值作为可选 `adjustDeviceId` 放入 `/api/h5/v1/auth/otp/verifications`。同一次命令重试沿用首次快照；未就绪省略，不阻塞发码或登录。不把 ADID 当成 App Token，也不使用 IDFA/IDFV 代替。

## 设备信息 Base64

```javascript
window.webkit.messageHandlers.getDeviceInfo.postMessage({
  callback: 'onNativeDeviceInfo_2'
})
// 回调参数是 Base64 字符串本身：
window.onNativeDeviceInfo_2('<标准Base64字符串>')
```

按用户提供的 V6.1 字段映射及其 Base64 补充要求，原生把完整 `{"version":1,"fields":{...}}` 序列化为紧凑 UTF-8 JSON，再用 `Data.base64EncodedString()` 编码一次。只编码此对象；不编码外层 HTTP 请求，也不额外包一层 `nativeDeviceInfo`。H5 原样透传，提交格式为：

```json
{"scene":"LOGIN","blackBox":"<同盾返回值>","nativeDeviceInfo":"<上述Base64字符串>"}
```

用户点击登录、新建验码命令前，H5 并行采集原生设备信息和同盾 blackBox，再 POST `/api/h5/v1/risk/device-collections`。原有 KYC 设备采集继续使用相同桥。原生同步读取当前快照，不等待网络；H5 仅使用 500ms 内、同盾返回前收到的值。

当前采集字段（仅在读取成功且值有效时提供）：

| 字段 | 数据来源 |
| --- | --- |
| a9a83d27d82d / db364a8eea95 | 当前窗口宽高 × 屏幕 nativeScale，成对提供物理像素 |
| ef02cd5586bc | UIDevice 电量整数百分比 |
| fe5bfc5ccba1 | UIDevice 电源状态；未知时省略 |
| 35dac7a89792 / 6b2ed867abe2 | 总物理内存 / 当前 free pages 字节数 |
| ef84ad290e77 / 56e967761ee7 | Apple / phone 或 tablet |
| e6b6e67871d1 / 336a72a9ba4a | 系统版本 / 系统地区语言标识 |
| b14e873df31b / bd8d64b3b73d | sysctl hw.machine / hw.model |
| 61b21bc4282f / 29752e1f59f9 | 当前运行架构 ABI |
| 9f9bdf2e1456 | CPU 核数 |
| f2fd42e9bc36 / 1bb9f2f4b87a | nativeScale / 包含系统字体缩放的密度 |
| a4a366f265b8 / 84b4bbeda526 | CFBundleShortVersionString |
| 3f3bf72d1ebc / 3cd527c516c2 | CFBundleVersion 字符串 / 仅纯整数字符串提供的 Int32 |
| 8a537473299e / 541354e5225c | NWPathMonitor 缓存网络类型 / 活跃接口 IP 字面量 |

未采集磁盘容量、Wi-Fi 名称/BSSID、运营商、物理 DPI、电池温度或无法确认映射的原生标识；不新增权限弹窗或使用私有 API。模拟器保持实际架构标识，不伪装真机型号。未知字段省略，真实 0 和 false 保留。JSON 上限8192字节、96项字段，字符串上限128个 Unicode 码点且无控制字符。

## 回调和生命周期

只接受入口同源（协议/主机/端口一致）的顶层 frame、所属 WKWebView 消息。支持 `onNativeAdjustId_<数字>` / `onNativeDeviceInfo_<数字>`，兼容旧固定回调。通过 callAsyncJavaScript 参数字典传 callbackName 和 payload，不拼接脚本。单请求只回复一次，导航后丢弃旧回包，销毁时移除两个 handler。普通浏览器保持原有 H5 流程。

## 本地验证

`Verification/BusinessBridgeChecks.swift` 可与 `BusinessBridgePayload.swift` 一起用 swiftc 编译运行，覆盖动态回调拒绝非法名称、ADID格式、完整Base64对象解码、0/false原类型与大小限制。业务入口原有检查 `BusinessEntryChecks.swift` 保留。完整模拟器构建与实际真机 Adjust 安装归因/后端接口联调是不同验证层级，不能互相替代。
