# AGENTS.md

## 工程定位

这是贝昂 8 寸空管器 Flutter UI 原型工程，应用包名为
`home_dashboard_practice_app`，设计基准为 1920×1200；本工程目录名为 `flutter_home_dashboard_8cun`。

本轮核心页面和对应 Figma 节点：

- 主页：`1:2482`
- 智能：`1:169`
- 手动：`1:3847`
- 历史：`1:514`
- 设定：`1:1567`
- 主页左侧导航：`1:2694`

设计任务先读当前 8 寸交付材料，再读取登记的本地冻结缓存，不得只凭缩略图猜页面。

## 当前结构

```text
lib/
├── main.dart
├── models/dashboard_data.dart
├── services/
│   ├── beiang8panel_api.dart
│   ├── dashboard_runtime_sync_service.dart
│   ├── dashboard_storage.dart
│   └── time_source.dart
├── pages/
│   ├── home/home_page.dart
│   ├── smart/smart_page.dart
│   ├── manual/manual_page.dart
│   ├── history/history_page.dart
│   ├── settings/system_settings_page.dart
│   ├── idle/idle_page.dart
│   └── engineering/engineering_mode_page.dart
└── widgets/
    ├── design_resolution_scaler.dart
    ├── left_navigation_bar.dart
    ├── prototype_chrome.dart
    ├── live_clock.dart
    └── status_bar.dart
```

页面源码按功能实际归入 `lib/pages/<功能>/`，`lib/pages/` 根目录不放 Dart 文件。
主页入口和实现统一位于 `home/home_page.dart`；主页的 `home/home_page_*.dart`
是同一个 Dart library 的 `part` 文件，继续与 `home/home_page.dart` 同级维护。
旧的 `lib/pages/*_page.dart` 扁平路径不再保留；详细边界见 `lib/pages/docs/README.md`。

当前生命周期采用软实现：主页统一轮询并按页面分发快照，各页面使用 Flutter 原生的
`initState/dispose` 管理局部资源，入口令牌和销毁保护承担进入/离开语义。文档中的
`PageLifecycle/onEnter/onTick/onLeave` 是职责命名约定，用于指导边界，不要求页面现在
额外声明同名接口；后续如需统一抽象，应在现有实现基础上提炼。

- 五页均为完整 1920×1200 页面，不把内页挤进主页内容框。
- 主页导航负责进入四个内页，内页统一用“返回”回主页。
- `PrototypePageChrome` 统一顶部状态、返回区和内页公共坐标。
- 智能模式、手动房间开关、历史周期、设置选项均有基础交互。
- `DashboardStorage` 使用 `dashboard_settings.json`（设置目标）与
  `dashboard_runtime.json`（实际运行快照）；runtime 只由非重入两秒刷新任务写入。
- `DashboardRuntimeSyncService` 的任务 A 列表顺序读取 BeiAng8Panel；任务 B 统一合并、原子写入、
  读回并校验。新增设备函数不得把 HTTP 或总线细节散落到页面。
- 时间来自 `TimeSource`，不写入 JSON。
- `设置状态直接驱动开关显示方案.md`、`运行状态驱动开关显示方案.md` 与
  `设置与运行状态融合驱动方案_当前实现.md` 是三套互不依赖、可独立实施的平行方案；每份文档都必须
  自成完整契约，不得要求先阅读另外两份。当前代码只以融合方案为实现契约，不得把另外两套方案的
  状态所有权规则混入当前实现。
- 当前融合实现的所有权固定为“settings 负责写入设置目标，runtime 负责设备读取和 UI 显示”：
  设置提交函数不得直接写 `xxxRunning`；2 秒刷新任务不得覆盖 settings。后端不可达时只记录一次性
  内存待同步值并交给下一次 runtime 轮询消费；一旦读取到设备实际值，实际值始终优先。
- 当前主页 30 秒无操作会进入时钟休眠页，首次触摸或按键唤醒并回到休眠前页面；休眠页仍使用
  设备本地时间，不读取或写入 JSON。

## 字体与素材

- 中文、日文、英文翻译文字：统一使用 Source Han Sans SC VF；Source Han Sans JP VF
  仅保留在工程中备用，不编译进 App。
- 数字、符号和大号数字：HarmonyOS Sans Thin/Light/Bold 静态 TTF。
- Source Han Sans 的字重必须通过 `fontVariations` 显式指定，不能只依赖 `fontWeight`。
- HarmonyOS Sans 当前文件不包含中文字形；不得把中文交给系统字体回退。
- 天气资源使用同名的高分辨率 PNG 静态兜底和 GIF 动态层。
- 图片优先复用 Figma/工程真实素材；没有可靠资源时才允许用简单几何绘制，并在视觉检查中记录偏差。

## 修改边界

1. 只修改本工程，不修改正式参考工程、冻结 `.fig`、本地冻结缓存或归档 ZIP。
2. 页面坐标、尺寸和文案优先来自登记的设计资料；关键坐标在代码注释中保留设计来源。
3. 不回退为 Material 默认图标、Emoji 或统一占位页。
4. JSON 语法错误、根节点不是对象、必需字段缺失或必需字段类型/值不合法时，整份对应文件按当前
   默认内容重建；合法 JSON 中的多余字段一律忽略，不触发重建。
5. 主题、全应用多语言和完整设备通信尚未实现，不得写成现有能力；系统设置只有“语言选择”自身的
   中/日/英切换证明。室内 PM2.5 和超净 BeiAng8Panel HTTP 只是一条样板，不代表 R818 真机验收完成。
6. macOS 只代表桌面联调通过；Windows、Linux PC、R818 必须在对应环境验收。

## 验证命令

```bash
flutter analyze --no-pub
flutter test --no-pub

./build_macos.sh debug
./run_macos.sh debug

# 以下必须在对应主机或板端执行
./build_linux.sh release
./run_linux.sh release
build_windows.bat release
powershell -ExecutionPolicy Bypass -File .\run_windows.ps1 release
./build_embedded_r528.sh
./build_embedded_r818.sh
```

修改页面后必须同时检查：

- 1920×1200 Golden；
- 800×500、800×600、1280×720 等比例缩放；
- 五页导航和返回；
- 智能模式、手动开关、历史周期、设置选项；
- 真实 macOS 窗口截图；
- `Golden 测试判定规范.md` 中约定的基准和实现快照边界。
