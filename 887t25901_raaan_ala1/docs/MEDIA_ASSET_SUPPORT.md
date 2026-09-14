# 媒体素材能力与离线构建说明

## 当前支持范围

| 格式 | 当前方式 | 嵌入式建议 |
| --- | --- | --- |
| PNG/JPG | Flutter `Image.asset` | 推荐，最稳妥 |
| GIF | Flutter `Image.asset` | 推荐用于简单循环动效，注意帧数和尺寸 |
| SVG | `flutter_svg 1.1.6` | 适合简单静态图层；复杂或高频动画优先转 PNG/GIF |
| Lottie JSON | `lottie 1.4.3` | 作为主要动画能力之一；有适配好的专用 Lottie 素材时优先接入，上板前需评估 CPU、内存和动画复杂度 |
| MP4/MKV | 当前不接入 | 需要原生/第三方解码库，暂不纳入嵌入式闭环 |

## 使用边界

当前工程没有保留未被页面调用的通用媒体组件。现有页面直接使用 `Image.asset` 加载已经验证的
PNG/GIF；未来确实接入 SVG 或 Lottie 时，再在使用页面附近增加范围明确的适配器，不预先维护
无人调用的万能组件。

## 资源目录

```text
assets/media/svg/       公共 SVG
assets/media/lottie/    公共 Lottie JSON/.lottie
assets/four_inch/...    4 寸正式页面素材（存在时）
assets/home/...         8 寸主页天气、PM2.5 等既有素材（存在时）
```

## 离线依赖

`pubspec.yaml` 固定 `lottie: 1.4.3`，避免 Flutter 3.3.7 被新版 Lottie 的 Dart/Flutter 下限阻断。首次联网准备依赖后，必须把包保留在：

```text
third_party/pub-cache/hosted/pub.dartlang.org/
```

离线验证：

```bash
cd /Users/as/Desktop/docu/workspace/flutter_3.3.7
. ./use_jdk11_flutter337.sh
cd /绝对路径/当前工程根目录
PUB_CACHE="$PWD/third_party/pub-cache" PUB_HOSTED_URL=https://pub.dartlang.org flutter337 pub get --offline
flutter337 analyze --no-pub
flutter337 test --no-pub
```

如果以后需要接入 MP4/MKV，应另立平台解码评估，不要把视频库混入当前嵌入式资源链路。
