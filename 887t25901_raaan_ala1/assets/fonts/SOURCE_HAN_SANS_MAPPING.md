# Source Han Sans 设计字重与可变字体对应表

当前工程使用 Adobe Source Han Sans 2.005 可变 TTF：

- 简体中文：`Source_Han_Sans_SC/SourceHanSansSC-VF.ttf`

客户确认：中文、日文、英文翻译文字统一使用 `Source Han Sans SC`。日文字体
`Source_Han_Sans_JP/SourceHanSans-VF.ttf` 暂时保留在工程中作为备份，但不在
`pubspec.yaml` 中注册，不编译进 App。HarmonyOS Sans 仅用于数字、符号和大号读数。

设计稿字重与 VF `wght` 对应如下：

| 设计字重 | Flutter 逻辑字重 | VF 实际字重 |
|---|---:|---:|
| ExtraLight | `FontWeight.w200` | `wght=250` |
| Light | `FontWeight.w300` | `wght=300` |
| Normal | `FontWeight.w400` | `wght=350` |
| Regular | `FontWeight.w400` | `wght=400` |
| Medium | `FontWeight.w500` | `wght=500` |
| Bold | `FontWeight.w700` | `wght=700` |
| Heavy | `FontWeight.w900` | `wght=900` |

`Normal` 是特殊情况：Flutter 没有 `FontWeight.w350`，因此使用
`FontWeight.w400 + FontVariation('wght', 350)`。

所有使用 Source Han Sans 的 `TextStyle` 都必须同时写出逻辑字重和
`fontVariations`，不能只依赖 Flutter 的 `fontWeight` 自动匹配。
