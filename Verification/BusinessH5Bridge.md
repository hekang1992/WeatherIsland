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

用户点击登录、新建验码命令前，H5 并行采集原生设备信息和同盾 blackBox，再 POST `/api/h5/v1/risk/device-collections`。原有 KYC 设备采集继续使用相同桥。原生同步读取当前快照，不等待网络；H5 本地已修复为等待原生回包或本次 500ms 超时；修复尚未部署的测试站仍可能在同盾先完成时漏传 nativeDeviceInfo。

字段按新的 Markdown 规范逐项核对，并应用用户后续两批删减：70 项中明确排除 34 项，最终代码支持 31 项，另 5 项因没有适合当前上报的可靠值而省略。保留屏幕、电量、电源的首选/兼容字段、内存、设备与 App 版本/语言、设备型号、网络类型/IP、条件 Wi-Fi 信息、模拟器和代理状态。实际返回数量随设备与权限变化。

完整的每项数据来源、采集条件和省略原因见 [V6.1 原生设备字段逐项对照](BusinessDeviceFields.md)。未获取到的字段不填 null、空串或猜测值，真实 0 和 false 保留。新增字段仍由同一个 getDeviceInfo 回调整体 Base64 返回。

## 回调和生命周期

只接受入口同源（协议/主机/端口一致）的顶层 frame、所属 WKWebView 消息。支持 `onNativeAdjustId_<数字>` / `onNativeDeviceInfo_<数字>`，兼容旧固定回调。通过 callAsyncJavaScript 参数字典传 callbackName 和 payload，不拼接脚本。单请求只回复一次，导航后丢弃旧回包，销毁时移除两个 handler。普通浏览器保持原有 H5 流程。

## 本地验证

`Verification/BusinessBridgeChecks.swift` 可与 `BusinessBridgePayload.swift` 一起用 swiftc 编译运行，覆盖动态回调拒绝非法名称、ADID格式、完整Base64对象解码、0/false原类型与大小限制。业务入口原有检查 `BusinessEntryChecks.swift` 保留。完整模拟器构建与实际真机 Adjust 安装归因/后端接口联调是不同验证层级，不能互相替代。
