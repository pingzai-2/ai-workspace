# flutter_home_dashboard_8cun

贝昂 8 寸空管器 Flutter UI 原型工程，固定使用 Flutter 3.3.7，设计分辨率为
1920×1200。

## 代码仓库

```text
https://jhd-rd.com:4433/contract/887t25901_raaan_ala1.git
```

## Figma 设计稿

```text
https://www.figma.com/design/a1XOqZn42Goii9hZ8jsyRs/贝昂-8-寸开发交付?node-id=69-5469&t=UDLooi9eKKu0Ohjq-0
```

本机 Figma 缓存根目录：

```text
/Users/as/Desktop/docu/figma-cache
```

阅读缓存根目录中的说明类文档。

当前客户重新提供版的本地 Figma 冻结缓存：

```text
/Users/as/Desktop/docu/figma-cache/贝昂 8 寸开发交付-20260810-20260810-162837/source/贝昂 8 寸开发交付-20260810.fig
```

正式 Figma 逐画板参考图单独保存在：

```text
test/goldens/
```

该目录只保存客户提供的规范参考基准，用于像素级对照，不写入测试生成图。

PNG、GIF、图标等客户交付的视觉素材通常优先在以下切图目录查找：

```text
/Users/as/Desktop/docu/workspace/beiang/8寸UI资源/贝昂8寸切图-20260810
```

## 文档入口

- 各平台的 `build_*` 与 `run_*` 脚本：既是可执行入口，也是对应平台的配置、依赖、构建、运行和验证说明。
- `页面生命周期与按需刷新机制说明.md`：页面生命周期、统一周期、加载策略和按需刷新通用方案。
- `AGENTS.md`：工程修改约束。
- `Golden 测试判定规范.md`：8 寸规范基准、实现快照和差异判定边界。

### 三套数据方案

以下三份是互不依赖、可分别交付和独立实施的平行方案，没有前后阅读顺序：

- `设置状态直接驱动开关显示方案.md`：点击立即可见，但设备中途异常不能及时反馈。
- `运行状态驱动开关显示方案.md`：设备实际状态准确，但无后端时点击可能看起来失效。
- `设置与运行状态融合驱动方案_当前实现.md`：当前工程采用的独立方案；包含双 JSON 契约、
  2 秒聚合读取、350ms 写后补读、全局后端状态、失败降级和后续扩展规则。

当前代码所说的“融合”不是两个 JSON 同时驱动界面，而是明确分工：

```text
UI 控制写入 -> BeiAng8Panel set -> 保存并读回 settings 设置目标
后端接受写入 -> 设备写成功 -> 精确确认读 -> 后端发布实际状态
前端接受写入 -> 末次写入 350ms 后补读一次统一运行快照
2 秒刷新读取 -> BeiAng8Panel 实际数据 -> 原子更新并读回 runtime
UI 开关显示 -> 只读取 runtime.xxxRunning
后端不可达 -> settings 仍保存；一次性待同步值由下一次 runtime 轮询消费
后端可达但 485 超过 30 秒无成功读写 -> 保留最后有效值并提示“设备数据陈旧”
后端恢复   -> 设备实际 runtime 重新取得最高优先级
```

设置处理函数不直接写 runtime；runtime 刷新也不覆盖 settings。详细所有权和失败分支见
`设置与运行状态融合驱动方案_当前实现.md`。

## 当前已实现

- 主页：室内 PM2.5、温度、湿度、CO₂、甲醛，室外天气和五类设备状态。
- 智能：标准、会客、干爽、温润、旅行五种模式；温湿度弧形调节、加减按钮和启停开关。
- 手动：空调、地暖、新风、调湿、超净五类设备入口；四房间卡片和独立开关。
- 历史：温度、湿度、PM2.5、CO₂ 入口；通过统一脉搏接入 `/api/history/trend`，按时间戳局部更新室内/室外双曲线、平均值和日/周/月切换。
- 设定：系统设置、维护保养、工程模式；系统设置已接入时间格式、语言证明、亮度、AQI 指示灯、网络、定时和系统信息交互。
- 主页五项导航均可点击；内页“返回”回到主页。
- 整个 UI 按 1920×1200 排版，通过 `FittedBox(BoxFit.contain)` 在不同窗口保持
  16:10 比例，不拉伸变形。
- 顶部时间读取设备本地时间；日期由可注入的 `TimeSource` 生成，便于跨平台测试。
- 右下“一键开关”和五类设备独立开关会写入并读回 settings；同一按钮处理期间会暂时防连按。
- 室内 PM2.5 与超净已提供 BeiAng8Panel 读写样板；实际设备样式由 runtime 驱动。
- 屏幕亮度按后端返回的原生量程与界面百分比双向换算；后端在线时以实际回读值为准，后端不可达时保留本地样板调节。
- AQI 指示灯开关和 Wi-Fi 管理已接入同一份后端聚合快照。Wi-Fi 扫描、连接和断开由页面无关管理器处理；进入网络详情页立即扫描、停留时每 10 秒扫描，离开页面不会取消已提交操作。
- 首次运行无 JSON 时，所有设备默认关闭，运行设备数为 0；避免未接入真实设备时误显示运行中。
- 连续无操作达到设置时间后进入时钟 Idle 页；Idle 页再连续 30 秒无触摸，先显示纯黑帧，
  再请求后端息屏。硬件息屏后的首次触摸先唤醒，清黑帧后仍回到 Idle；息屏前触摸才返回此前页面。

## 字体与素材

- 中文、日文、英文翻译文字统一使用随工程打包的 Source Han Sans SC VF；
  Source Han Sans JP VF 仅保留在工程中备用，不编译进 App。
- 数字、符号和大号读数使用 HarmonyOS Sans Thin/Light/Bold 静态 TTF。
- Source Han Sans VF 的实际字重统一通过 `fontVariations` 显式指定，并保留 Figma 字重到 `wght` 轴的映射注释。
- 当前天气界面使用高分辨率 GIF；同状态的 1024×1024 透明 PNG、动态 SVG 和静态 SVG
  一并随工程保留，便于后续平台适配、静态降级和素材复核，当前不切换 SVG 显示。
- 31 组天气素材分别位于 `assets/home/weather/dynamic_gif/`、
  `assets/home/weather/static_png/`、`assets/home/weather/dynamic_svg/` 和
  `assets/home/weather/static_svg/`；四套素材严格使用相同的数字下划线名称。
- 主页中心 PM2.5 圆盘的 GIF、PNG、动态 SVG 和静态 SVG 分别保存在
  `assets/home/pm25_orb/dynamic_gif/`、`assets/home/pm25_orb/static_png/`、
  `assets/home/pm25_orb/dynamic_svg/` 和 `assets/home/pm25_orb/static_svg/`，文件名统一为
  `pm25_orb`。
  当前正常运行使用 GIF，
  PM2.5 标题、数值和单位仍由 Flutter 实时叠加。禁用动效的 Golden/测试场景继续使用原有
  确定性圆环画法，不因多种素材并存而改写既有基准图。

## 数据文件

主页与系统设置使用同一组数据文件；设置数据与运行数据分别保存、互不混写。两份 JSON 均保存到
构建时确定的运行时配置目录；工程不再创建或读取第三份设置 JSON：

- `dashboard_settings.json`：总开关、兼容设备设置、`pureSettings`、时间格式、语言、亮度、AQI 指示灯、网络选择、已确认 Wi-Fi 凭据和定时；
- `dashboard_runtime.json`：室内外环境、天气、网络过程、通知/告警与设备实际状态；超净样板字段为 `pureRunning`。

新文件不存在或内容损坏时会按当前完整字段契约重建。
主要字段包括：

- 室内外温湿度、PM2.5、CO₂、甲醛；
- 温度、湿度、PM2.5 日/周/月趋势采样：三类指标均有室内、室外两组；按日各 12 点，按周各
  7 点，按月默认 30 点，实际可为 29、30、31 点中的一种。字段分别以 `Temperature...`、
  `Humidity...Percent`、`Pm25...` 命名；
  平均值由 UI 根据当前周期采样计算并四舍五入为整数，不单独保存；
- CO₂ 历史页默认只显示室内数据；`dailyCo2Ppm`、`weeklyCo2Ppm`、`monthlyCo2Ppm` 分别提供
  日（12 点）、周（7 点）、月（29/30/31 点）曲线。所有趋势页的室内/室外系列均由页面代码传入
  `showIndoor`、`showOutdoor` 组装系列列表决定；为 `false` 的系列不会进入列表，因此不会创建图例、
  平均值或曲线路径，也不写入 JSON；
- 月视图日期使用 `monthlyTrendYear`、`monthlyTrendMonth`；二月无论底层数组有 29 或 30 项，
  均只读取前 `25` 项并让图表收口；其他月份使用同一套完整宽度，最后横轴标签按实际数组长度标为
  `29`、`30` 或 `31`。月平均值除数与实际读取数量一致；
- 天气代码和位置；`weatherCode` 直接对应 `assets/home/weather/` 四个分类目录中的素材名，统一使用
  小写下划线，例如 `09_extreme_rain`；
- 总开关与五个设备开关；
- 通知、Wi-Fi、告警；其中 Wi-Fi 运行分区包含后端能力、实际开关、连接状态、SSID、IP、扫描结果、过程状态和错误；铃铛、红点/数字、告警三角独立控制，不互相推导。

Wi-Fi 凭据按 SSID 只保存最近一次确认连接成功的值，最多 10 个并按 LRU 排序；扫描列表独立去重、按信号排序并最多显示 20 个。输入框不预填密码；连接失败不覆盖旧值，普通断开不删除凭据。后端不可达时，已保存 SSID 可直接进行离线联调，首次出现的 SSID 只接受工程内统一测试密码 `666666`；后端可达后完全服从真实扫描与连接结果，开放网络使用空密码。已保存的 Wi-Fi 开关是连接策略：App 启动、后端恢复和开关重新开启各触发一轮 LRU 自动连接；关闭会禁用 Wi-Fi，普通断开则只断当前连接并在本次后端在线期间抑制自动重连。网络详情页进入即扫描，停留期间每 10 秒扫描，后端不可达时冻结最后一次有效列表。

主页启动时读取两份 JSON；之后每两秒先顺序请求 BeiAng8Panel，再由单一任务合并、原子更新、
完整读回和校验 runtime。上一次刷新未结束会跳过下一周期。控制动作只提交 settings；超净实际样式
读取 `pureRunning`。后端不可达时可通过一次内存待同步值完成纯 UI 打样，后端恢复后实际状态优先。
运行中手工修改 settings 不会自动刷新页面。手工联调 runtime 时应完整原子替换，不要直接截断文件。
整份文件必须是合法 JSON 对象；必需字段缺失或类型/值异常时，
整份对应 JSON 重建为默认值。合法 JSON 中的多余字段会被忽略，不触发重建。
当前 macOS、Linux PC 和 Windows 构建脚本默认使用工程内 `config/`；当前 R528/R818
嵌入式构建默认使用 `${FLUTTER_BOARD_CONFIG_ROOT}` 外置可写目录。该路径在构建时通过
`DASHBOARD_CONFIG_ROOT` 写入 App；运行脚本只准备同一目录和权限，不能临时改变已编译 App
的配置路径。
各平台实际路径和可覆盖参数见对应的 `build_*`、`run_*` 脚本。

## 构建与验证

```bash
./build_macos.sh debug
./run_macos.sh debug

flutter analyze --no-pub
flutter test --no-pub
```

正式验证证据：

- 8 寸标准 Figma 素材：`test/goldens/`，只读，不写入测试生成物
- 8 寸实现 Golden 快照：`test/generated/8cun/$name.png`，尺寸固定为 1920×1200
- 全部关键页面 Golden：
  `flutter test --no-pub --dart-define=RUN_IMPLEMENTATION_GOLDENS=true test/visual_goldens.dart`
- 重新生成候选实现 Golden：
  `flutter test --no-pub --update-goldens test/visual_goldens.dart`
- 只验证动态主页结构：
  `flutter test --no-pub test/visual_goldens.dart --name 'checks the 8-inch dynamic home structure only'`
- 只验证手动-调湿 Golden：
  `flutter test --no-pub --dart-define=RUN_IMPLEMENTATION_GOLDENS=true test/visual_goldens.dart --name 'captures the 8-inch manual humidifier golden only'`
- 真实 macOS 运行截图：`design_reference/implementation_*_001.png`
- 主页并排对照：`design_reference/compare_home_full_001.png`
- 视觉检查以真实运行截图和 `Golden 测试判定规范.md` 的边界为准

`test/goldens/` 只保留标准 Figma 素材，保持只读。Golden 测试先固定字体、DPR
和设计分辨率，再等待页面首屏资源，最后写入 `test/generated/8cun/`；不得写入标准素材目录。
视觉脚本使用非 `_test.dart` 文件名，普通 `flutter test --no-pub` 不会自动执行这份脚本，
也不会因为它额外启动首页或读取 PNG。
只有明确执行 `test/visual_goldens.dart` 时才运行视觉页面；不加 Golden 开关时照常检查页面和按钮，
但不读取 PNG。首页自身或整机流程测试确实需要首页时，仍可启动首页。
测试必须从首页进入时，首页只作为导航入口，不检查首页截图，也不添加与目标页面无关的首页断言；
只有首页测试才检查首页。

Linux、Windows 和 R818 的脚本入口已经保留，但必须在对应主机或板端完成真实验收。

## 后续边界

当前只有一套深色主题；语言选择已实现中/日/英三种持久化，并让“语言选择”这一项自身随选择翻译，
用于证明字体与数据链路。全应用多语言、主题切换、完整设备映射和板端实测仍属于后续任务；
室内 PM2.5 与超净的 BeiAng8Panel 样板及两秒任务框架已经实现。详见
`设置与运行状态融合驱动方案_当前实现.md`。
