import 'dart:ui' show FontVariation, FontWeight, Color;
import 'package:flutter/painting.dart' show TextStyle;

/// 自定义字重，存 VF wght 值，不依赖系统 FontWeight。
///
/// 设计意图：Flutter 的 FontWeight 只有 9 档（w100-w900），
/// 无法表达可变字体的精细 wght 值（如 550）。
/// AppFontWeight 存原始 wght 数值，通过 [fontWeight] 和 [fontVariations]
/// 输出到 TextStyle，用哪个字体由 [_FontFamily] 决定。
///
/// 遗留说明：项目中已有大量 FontWeight.w700 等系统用法，属于技术债，
/// 保留不动。新加代码请用 AppFontWeight（如 AppFonts.w550），
/// 配合 AppFonts.sc 字体上下文调用，
/// 不要再新增 FontWeight 直接用法。
/// 两套共存，逐步迁移。
class AppFontWeight {
  final int wght;
  const AppFontWeight(this.wght);

  /// 最近的系统 FontWeight 档位（给不支持 VF 的回退用）。
  FontWeight get fontWeight =>
      FontWeight.values[((wght / 100).round() - 1).clamp(0, 8)];

  /// VF wght 轴声明。
  List<FontVariation> get fontVariations =>
      <FontVariation>[FontVariation('wght', wght.toDouble())];
}

/// 绑定一个可变字体名，通过 [call] 接收字重和样式属性生成 TextStyle。
///
/// 调用方先拿字体上下文，后面改字重、字号、颜色无需重复传 fontFamily：
/// ```dart
/// AppFonts.sc(AppFonts.w550, fontSize: 42);
/// ```
///
/// 非可变字体不走这里，直接 [TextStyle] 构造。
class _FontFamily {
  final String fontFamily;
  const _FontFamily(this.fontFamily);

  TextStyle call(AppFontWeight weight, {double? fontSize, Color? color}) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        fontWeight: weight.fontWeight,
        fontVariations: weight.fontVariations,
        color: color,
      );
}

/// 贝昂工程字体定义。
///
/// Source Han Sans SC 负责所有翻译文字（中文、日文、英文）；HarmonyOS Sans
/// 负责数字、符号和大号读数。Source Han Sans SC 只保留一个 VF 文件，实际
/// 字重必须通过 [FontVariation] 显式指定。
abstract class AppFonts {
  // HarmonyOS Sans 系列（数字、符号和大号读数）
  static const String harmonyThin = 'HarmonyOS Sans Thin';
  static const String harmonyLight = 'HarmonyOS Sans Light';
  static const String harmonyRegular = 'HarmonyOS Sans';
  static const String harmonyMedium = 'HarmonyOS Sans Medium';
  static const String harmonyBold = 'HarmonyOS Sans Bold';
  static const String harmonyBlack = 'HarmonyOS Sans Black';

  static const String sourceHanSansSc = 'Source Han Sans SC';

  /// 字体上下文 —— 先选字体，再传字重和样式。
  static const _FontFamily sc = _FontFamily(sourceHanSansSc);

  /// HarmonyOS Sans 多文件字重映射。
  /// 接口与 [sc] 并列，内部根据 wght 选对应 fontFamily。
  static TextStyle harmony(AppFontWeight weight,
          {double? fontSize, Color? color}) =>
      TextStyle(
        fontFamily: _harmonyFontFamily(weight.wght),
        fontSize: fontSize,
        fontWeight: weight.fontWeight,
        color: color,
      );

  static String _harmonyFontFamily(int wght) {
    if (wght >= 700) return harmonyBold;
    if (wght >= 500) return harmonyMedium;
    if (wght >= 400) return harmonyRegular;
    if (wght >= 300) return harmonyLight;
    return harmonyThin;
  }

  // 设计稿字重 -> VF wght 轴：ExtraLight 250、Light 300、
  // Normal 350、Regular 400、Medium 500、Bold 700、Heavy 900。
  static const List<FontVariation> sourceHanSansScExtraLightWght250 =
      <FontVariation>[FontVariation('wght', 250)];
  static const List<FontVariation> sourceHanSansScLightWght300 =
      <FontVariation>[FontVariation('wght', 300)];
  static const List<FontVariation> sourceHanSansScNormalWght350 =
      <FontVariation>[FontVariation('wght', 350)];
  static const List<FontVariation> sourceHanSansScRegularWght400 =
      <FontVariation>[FontVariation('wght', 400)];
  static const List<FontVariation> sourceHanSansScMediumWght500 =
      <FontVariation>[FontVariation('wght', 500)];
  // ── 中间档位，用于精细调节字重 ──
  static const List<FontVariation> sourceHanSansScSemiMediumWght450 =
      <FontVariation>[FontVariation('wght', 450)];
  static const List<FontVariation> sourceHanSansScMediumSemiBoldWght550 =
      <FontVariation>[FontVariation('wght', 550)];
  static const List<FontVariation> sourceHanSansScSemiBoldWght600 =
      <FontVariation>[FontVariation('wght', 600)];
  // ───────────────────────────────
  static const List<FontVariation> sourceHanSansScBoldWght700 =
      <FontVariation>[FontVariation('wght', 700)];
  static const List<FontVariation> sourceHanSansScHeavyWght900 =
      <FontVariation>[FontVariation('wght', 900)];

  /// 字重映射表，50 一个档位，直接用 AppFontWeight。
  /// 配合 [sc] / [jp] 使用：
  /// ```dart
  /// AppFonts.sc(AppFonts.w550, fontSize: 42);
  /// ```
  static const AppFontWeight w50 = AppFontWeight(50);
  static const AppFontWeight w100 = AppFontWeight(100);
  static const AppFontWeight w150 = AppFontWeight(150);
  static const AppFontWeight w200 = AppFontWeight(200);
  static const AppFontWeight w250 = AppFontWeight(250);
  static const AppFontWeight w300 = AppFontWeight(300);
  static const AppFontWeight w350 = AppFontWeight(350);
  static const AppFontWeight w400 = AppFontWeight(400);
  static const AppFontWeight w450 = AppFontWeight(450);
  static const AppFontWeight w500 = AppFontWeight(500);
  static const AppFontWeight w550 = AppFontWeight(550);
  static const AppFontWeight w600 = AppFontWeight(600);
  static const AppFontWeight w650 = AppFontWeight(650);
  static const AppFontWeight w700 = AppFontWeight(700);
  static const AppFontWeight w750 = AppFontWeight(750);
  static const AppFontWeight w800 = AppFontWeight(800);
  static const AppFontWeight w850 = AppFontWeight(850);
  static const AppFontWeight w900 = AppFontWeight(900);
  static const AppFontWeight w950 = AppFontWeight(950);
  static const AppFontWeight w1000 = AppFontWeight(1000);
  static const AppFontWeight w1050 = AppFontWeight(1050);
  static const AppFontWeight w1100 = AppFontWeight(1100);
  static const AppFontWeight w1150 = AppFontWeight(1150);
  static const AppFontWeight w1200 = AppFontWeight(1200);

  /// 翻译文字统一使用 SC；保留列表接口，便于需要字体回退的控件复用。
  static const List<String> cjkFallback = <String>[
    sourceHanSansSc,
  ];
}
