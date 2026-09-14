# 页面目录与生命周期边界

## 入口目录

页面现在提供按功能命名的入口目录，便于新代码和后续接手者按功能查找：

```text
lib/pages/
├── home/home_page.dart                 # 主页入口与主页实现
├── history/history_page.dart            # 历史趋势
├── manual/manual_page.dart              # 手动模式
├── smart/smart_page.dart                # 智能模式
├── settings/system_settings_page.dart  # 系统设置
├── idle/idle_page.dart                  # 息屏时钟
└── engineering/engineering_mode_page.dart # 工程模式
```

这些目录是页面源码的实际归属，`lib/pages/` 根目录不放 Dart 文件。各页面入口与实现
都在对应功能目录内；主页入口直接使用 `home/home_page.dart`，其他入口
文件直接承载对应页面源码。旧的 `lib/pages/*_page.dart` 扁平路径已不再保留，新增代码
请使用上述目录路径。

主页的 `home/home_page_*.dart` 是同一个 Dart library 的 `part` 文件，必须与
`home/home_page.dart` 保持同级。它们按责任拆分为数据、导航、息屏、告警、主页卡片
和天气，不应当被当成可以独立导入的页面。

## 当前生命周期实现

本工程采用“软生命周期”约定，通过现有 Flutter 生命周期表达页面职责，不额外引入统一的
`PageLifecycle` 基类：

- `HomePage` 负责统一的两秒运行快照轮询、页面进入令牌、页面级 `ValueNotifier` 更新和
  页面切换前后的保护。
- 各页面/子面板使用 Flutter 原生 `initState()`、`didUpdateWidget()`（需要时）和
  `dispose()` 管理自己的 Timer、AnimationController、FocusNode、Overlay 和异步回调。
- 页面进入/离开通过挂载、入口令牌和 `dispose()` 体现；周期更新由主页把属于该页的快照
  推送给对应 notifier，页面没有直接调用 `build()`。
- `页面生命周期与按需刷新机制说明.md` 中的 `onEnter/onTick/onLeave` 是职责名称和设计语义，
  用来帮助新增页面保持边界；当前页面不需要为了对齐文档而声明同名方法。

新增页面时，先明确它是否需要自己的计时器或异步资源；需要就按 Flutter 原生生命周期
创建和释放，不需要就只消费传入快照。
