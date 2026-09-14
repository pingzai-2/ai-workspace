# 字体审计

## 当前白名单

工程字体目录严格与工程外的 `贝昂字体/` 保持一致，只保留以下实际字体文件：

| 系列 | 文件 | 当前用途 |
|---|---|---|
| HarmonyOS Sans | Thin、Light、Regular、Medium、Bold、Black（6 个 TTF） | 数字、符号和大号读数 |
| Source Han Sans SC | `SourceHanSansSC-VF.ttf`（1 个 VF） | 中文标题、导航、状态和单位 |
| Source Han Sans JP | `SourceHanSans-VF.ttf`（工程备份，不注册） | 暂不编译进 App |

`pubspec.yaml` 只注册 HarmonyOS Sans 和 Source Han Sans SC；中文、日文、英文翻译文字统一落到
SC VF，不依赖桌面系统字体回退。JP 文件保留在工程中，但不进入 App 资源清单。

## 明确不随工程保留

- Gilroy（OTF/TTF）；
- GSYH00B-CN；
- 旧的 Source Han Sans SC 静态 OTF；
- 与静态字体映射相关的旧说明文件。

这些文件不再位于工程 `assets/fonts/`，因此不会被 Flutter 打包。

## 设计稿与实现的关系

部分早期 Figma 节点标记过 Gilroy。当前交付工程遵从贝昂字体白名单，翻译文字（中文、日文、英文）
使用 Source Han Sans SC VF，数字、符号和大号读数使用 HarmonyOS Sans；不使用系统字体回退，VF 实际
字重通过 `fontVariations` 显式指定。

## 主页字体校对（Figma `1:2482`）

本轮逐项核对冻结设计资料中的所有主页文字信息，并在 1920×1200 Golden 中复核。代码按文字类别使用
下列字体：

| 区域 | 设计字体与参数 | 实现规则 |
|---|---|---|
| 顶部时间 | HarmonyOS Sans Regular 24，整体 70% 透明度 | 状态栏时间 |
| 左侧导航 | 当前项 Source Han Sans SC Bold 32；其余 Regular 32、50% 透明度 | 图标保持直接 Figma PNG，所有语言文字统一使用 SC，按状态切换字重 |
| “室内” | Source Han Sans SC Regular 48、80% 透明度 | 显式使用 SC VF `wght=400`，不用中文系统回退 |
| PM2.5 圆球 | 标题 Source Han Regular 26；数值 Harmony Light 100；单位 Harmony Regular 24、70% 透明度 | 数值保留 Harmony 原生行高，避免与 PM2.5 挤在一起 |
| 室内 2×2 数据 | 中文标签 Source Han Regular 26、70%；数值 Harmony Light 56；单位 Harmony Regular 24、70% | 坐标来自 `1:2557` 的十六个直接文字节点 |
| CO₂ 标签 | Source Han Regular 26，末位 `2` 是 60% 的原生下标，基线下移 5.2 px | 不使用 Unicode `₂` 或系统字体代替，保持设计稿字形和宽度 |
| 天气卡 | 地点/日期 Source Han Regular 24、85%；天气 Source Han Regular 32；温度范围 Harmony Regular 32；三行数据依次为 Source Han 26 / Harmony 36 / Harmony 24 | 日期保留设计稿中日期与星期之间的三空格 |
| 设备与快捷卡 | 设备名 Source Han Bold 36；状态 Source Han Regular 24（“50%”为 Harmony Regular 24）；快捷文字 Source Han Bold 36、48 行高 | 快捷卡背景不含文字，仍可后续翻译 |

上述映射只使用当前白名单内的静态字体文件；字体、字重、字号、透明度和关键文字坐标都可以
从冻结设计资料回查。

## 验证

- `flutter analyze --no-pub`；
- `flutter test --no-pub`；
- `./build_macos.sh debug`。

均应在 Flutter 3.3.7 的离线缓存条件下通过。
