# Captally

截图一下，账就记好了。

**Capture it. Tally it.**

Captally 是一款自动记账工具。它会从你的支付截图中发现消费，在设备上识别金额、商户和交易信息，排除重复，并自动整理到你的账本。

```text
Capture      发现新的支付截图
Understand   在设备本地识别金额、商户、订单信息
Tally        排除重复、分类、记入账本
```

## 产品原则

- **Capture First** — 用户只需要养成「支付后截图」这一个习惯。
- **Local First** — 截图、OCR、AI 分析默认全部在设备本地完成，不上传第三方服务器；账本通过 iCloud 同步。
- **Deterministic First** — 金额、订单号、交易号、时间、支付平台由确定性解析器得出，不交给模型猜测。
- **Safe Automation** — 宁可少记一笔，也不错记一笔；置信度不足进入待确认。
- **Safe Dedup** — 宁可提示疑似重复，也绝不删除真实消费。

## 模块

```text
Captally/
├── App/            入口、依赖注入容器
├── Core/           持久化、配置、日志、工具
├── Ledger/         账本、账单、分类、预算
├── Capture/        截图发现与扫描流水线
├── Understand/     OCR、平台识别、解析、分类
├── Tally/          排重、置信度、学习
├── Inbox/          待处理
├── Statistics/     统计与图表
└── Settings/       设置
```

## 开发

要求 Xcode 27+，最低支持 iOS 17。零第三方依赖。

```bash
brew install xcodegen
xcodegen generate
open Captally.xcodeproj
```

命令行构建与测试：

```bash
xcodebuild -scheme Captally -destination 'generic/platform=iOS Simulator' build
xcodebuild -scheme Captally -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

工程文件由 `project.yml` 生成，不要手工编辑 `Captally.xcodeproj`。

### 真机运行

`./run_device.sh --device` 负责构建、安装、拉起。前提是 Xcode → Settings → Accounts 里已登录
拥有该 Team 的 Apple 账户：CloudKit entitlements 不能由通配 profile 签名，首次构建必须由 Xcode
向开发者门户注册 App ID `com.misswell.Captally` 与容器 `iCloud.com.misswell.Captally`（容器 ID
一经注册即永久占用）。Team 只配置在 `project.yml` 的 `DEVELOPMENT_TEAM` 一处。

两条真机上才会暴露的约束：

- entitlements 不写 `com.apple.developer.icloud-container-environment`。省略时 CloudKit 按签名类型
  选环境（开发包 Development、分发包 Production）；写死 Production 会让开发包在新容器上打不开 store。
- CloudKit 要求**所有 relationship 都是 optional**，否则真机报 `NSCocoaErrorDomain 134060`，一个 store
  都加载不出来，随后第一次 save 直接崩溃。Simulator 走 local-only（`cloudKitContainerOptions = nil`），
  这条约束在模拟器上完全看不出来，因此由 `CoreDataSchemaTests` 把守。

首次启动会把相册里既有截图全部登记为已处理（一台真实设备的量级是数千张），此后只处理新增。

### 演示数据

正式运行不会写入任何演示数据。仅 Debug 构建、且显式设置环境变量时才允许：

```bash
# Xcode scheme 的 Arguments → Environment Variables
CAPTALLY_SEED_DEMO_DATA=1
```

### 数据模型

`Captally.xcdatamodeld` 维护真实版本链：`CaptallyV1`（上游基线）→ `CaptallyV2`（移除
`Member` / `SplitRecord`，新增截图溯源与置信度字段）→ `CaptallyV3`（新增截图扫描状态表）。
新增字段一律 Optional 或带默认值，这是 CloudKit 的硬性要求，由 `CoreDataSchemaTests` 把关；
版本升级必须保持轻量迁移可通过（`testV1StoreUpgradesToV2AndKeepsItsRows`、
`testV2StoreUpgradesToV3AndKeepsItsRows`）。

进程内只允许存在一个 `NSPersistentCloudKitContainer`。多容器会让 `+entity` 无法判定实体归属，
账本也会被劈成两半，因此 `AppEnvironment` 默认复用 `PersistenceController.shared`，
仅预览与测试使用 `AppEnvironment.ephemeral()`；测试另用
`PersistenceController(storeURL:)` 打开临时文件库来验证重启后的状态。

### 截图扫描

V3 的两张表记录扫描进度，且 `syncable="NO"`：另一台设备有自己的照片库，同步「已读过」会让这台
设备跳过自己从未见过的截图。

- `ProcessedAsset`：`assetIdentifier`（只存 `PHAsset.localIdentifier`，不复制图片）+ 结论 `outcome` + `retryCount`。
- `ScanBatch`：一次扫描的时间与张数。

扫描算法是一次集合差：照片库 − 已有终态结论的截图。因此「增量」不依赖游标：日期游标既省不下
枚举开销，又可能永久漏掉后来才出现的旧截图（iCloud 合并、恢复备份），所以 Captally 不保存第二份
「扫描到哪里了」的事实。`pending`（写到一半被杀）与预算未用完的 `failed` 会重新参与扫描，
终态结论永不重读。

模拟器验证：授权后启动日志出现
`[com.misswell.Captally:capture] scan saw 0 screenshots, 0 settled, 0 to read`，
第二次启动同样为 0 to read。`addmedia` 导入的图片不带截图子类型，因此「发现新截图 → 只读一次」
这一条由 `CaptureScanCoordinatorTests` 用假照片库覆盖，真机截图需再验一次。

### 文字识别

`Understand/` 只负责「图上写了什么」，不负责「这是不是一笔消费」。

- `ScreenshotOCR`：按 `PHAsset.localIdentifier` 取图（长边 ≤ 2048、不走 iCloud 网络），
  交给 `VisionTextRecognizer`，返回 `OCRDocument`。截图本身不落盘，也不留副本。
- `OCRLine`：文本 + 归一化 `boundingBox`（**左上原点**，y 向下）+ 单行 confidence。
  Vision 用的是左下原点，翻转只发生在识别器一处。
- 识别全程在设备本地完成（`VNRecognizeTextRequest`），语言为 `zh-Hans` + `en-US`。
- 日志只写行数、尺寸、置信度；识别文本属于用户财务数据，永不进日志。

解析器（下一层）是它的消费者；`OCRTests` 用真实 Vision 跑合成截图，验证中文商户名、金额、
阅读顺序与坐标约定。

### CloudKit

容器 ID 只有一个来源：Info.plist 的 `CaptallyCloudKitContainerIdentifier`
（由 `iCloud.$(PRODUCT_BUNDLE_IDENTIFIER)` 展开），Swift 侧通过
`CaptallyConfiguration.cloudKitContainerIdentifier` 读取。业务代码不得出现容器 ID 字面量。

模拟器上 CloudKit 被关闭（无模拟器 iCloud 账户），账本以本地模式运行。

## 许可

MIT。本项目部分代码由 [Ledgerly](https://github.com/DMLayMan/Ledgerly) 演进而来，
上游版权声明保留于 `LICENSE` 与 `NOTICE`。
