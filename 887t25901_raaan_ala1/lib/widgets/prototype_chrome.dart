import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_fonts.dart';

const Color prototypeCyan = Color(0xFF42CEEA);
const Color prototypePanel = Color(0xFF191919);
const Color prototypeTextDim = Color(0x80FFFFFF);

class PrototypePageChrome extends StatelessWidget {
  const PrototypePageChrome({
    Key? key,
    required this.prompt,
    required this.onBack,
    required this.child,
    this.backIconAsset,
    this.backDividerAsset,
    this.backLeft = 112,
    this.backDividerLeft = 108,
    this.backDividerWidth = 184,
  }) : super(key: key);

  final String prompt;
  final VoidCallback onBack;
  final Widget child;
  final String? backIconAsset;
  final String? backDividerAsset;
  final double backLeft;
  final double backDividerLeft;
  final double backDividerWidth;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 465,
            top: 121,
            child: Text(
              prompt,
              style: const TextStyle(
                color: Color(0xCCFFFFFF),
                fontFamily: AppFonts.sourceHanSansSc,
                fontVariations: AppFonts.sourceHanSansScRegularWght400,
                fontSize: 30,
              ),
            ),
          ),
          PrototypeCircularBackControl(
            onTap: onBack,
            iconAsset: backIconAsset,
            dividerAsset: backDividerAsset,
            left: backLeft,
            dividerLeft: backDividerLeft,
            dividerWidth: backDividerWidth,
          ),
          child,
        ],
      ),
    );
  }
}

/// 历史趋势画板的返回控件，作为所有内页统一返回样式。
class PrototypeCircularBackControl extends StatelessWidget {
  const PrototypeCircularBackControl({
    Key? key,
    required this.onTap,
    this.iconAsset,
    this.dividerAsset,
    this.left = 112,
    this.dividerLeft = 108,
    this.dividerWidth = 184,
  }) : super(key: key);

  final VoidCallback onTap;
  final String? iconAsset;
  final String? dividerAsset;
  final double left;
  final double dividerLeft;
  final double dividerWidth;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned(
          left: left,
          top: 112,
          child: GestureDetector(
            key: const ValueKey<String>('inner-page-back'),
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: SizedBox(
              width: 184,
              height: 72,
              child: Stack(
                children: <Widget>[
                  Positioned(
                    left: 0,
                    top: 0,
                    width: 64,
                    height: 64,
                    child: _BackIcon(asset: iconAsset),
                  ),
                  Positioned(
                    left: 84,
                    width: 72,
                    height: 64,
                    child: Center(
                      child: Text(
                        AppLocalizations.of(context).back,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: AppFonts.sourceHanSansSc,
                          fontVariations:
                              AppFonts.sourceHanSansScRegularWght400,
                          fontSize: 36,
                          height: 1.448,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // 默认对应 Figma 1:579；设置页 1:1615 使用 232 px。
        Positioned(
          left: dividerLeft,
          top: 211,
          width: dividerWidth,
          height: 2,
          child: dividerAsset == null
              ? const CustomPaint(painter: _PrototypeBackDividerPainter())
              : Image.asset(
                  dividerAsset!,
                  width: dividerWidth,
                  height: 2,
                  filterQuality: FilterQuality.high,
                ),
        ),
      ],
    );
  }
}

class _BackIcon extends StatelessWidget {
  const _BackIcon({this.asset});

  final String? asset;

  @override
  Widget build(BuildContext context) {
    if (asset != null) {
      return Image.asset(
        asset!,
        width: 64,
        height: 64,
        filterQuality: FilterQuality.high,
      );
    }
    return const CustomPaint(painter: _PrototypeCircularBackPainter());
  }
}

class _PrototypeCircularBackPainter extends CustomPainter {
  const _PrototypeCircularBackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 31, paint);
    canvas.drawLine(const Offset(44, 32), const Offset(20, 32), paint);
    canvas.drawLine(const Offset(20, 32), const Offset(31, 21), paint);
    canvas.drawLine(const Offset(20, 32), const Offset(31, 43), paint);
  }

  @override
  bool shouldRepaint(covariant _PrototypeCircularBackPainter oldDelegate) =>
      false;
}

/// 返回区底线对应 Figma `1:579` 的白色横向透明渐变，非普通分隔线。
class _PrototypeBackDividerPainter extends CustomPainter {
  const _PrototypeBackDividerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[
          Color(0x00FFFFFF),
          Color(0x80FFFFFF),
          Color(0x00FFFFFF),
        ],
        stops: <double>[0, .5, 1],
      ).createShader(Offset.zero & size)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PrototypeBackDividerPainter oldDelegate) =>
      false;
}

enum PrototypeGlyph {
  back,
  standard,
  guest,
  dry,
  warm,
  travel,
  airConditioner,
  floorHeat,
  freshAir,
  humidity,
  clean,
  temperature,
  pm25,
  co2,
  system,
  maintenance,
  engineering,
}

class PrototypeGlyphPainter extends CustomPainter {
  const PrototypeGlyphPainter(
    this.glyph, {
    this.color = Colors.white,
    this.strokeWidth = 2.4,
  });

  final PrototypeGlyph glyph;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width;
    final h = size.height;
    final c = Offset(w / 2, h / 2);

    switch (glyph) {
      case PrototypeGlyph.back:
        canvas.drawLine(
            Offset(w * .72, h * .2), Offset(w * .32, h * .5), paint);
        canvas.drawLine(
            Offset(w * .32, h * .5), Offset(w * .72, h * .8), paint);
        break;
      case PrototypeGlyph.standard:
        canvas.drawCircle(c, w * .27, paint);
        canvas.drawCircle(c, w * .08, paint);
        for (var i = 0; i < 8; i++) {
          final angle = i * 3.1415926 / 4;
          final a = Offset(
            c.dx + w * .34 * _cos(angle),
            c.dy + w * .34 * _sin(angle),
          );
          final b = Offset(
            c.dx + w * .43 * _cos(angle),
            c.dy + w * .43 * _sin(angle),
          );
          canvas.drawLine(a, b, paint);
        }
        break;
      case PrototypeGlyph.guest:
        canvas.drawCircle(Offset(w * .38, h * .35), w * .12, paint);
        canvas.drawCircle(Offset(w * .66, h * .38), w * .1, paint);
        canvas.drawArc(
          Rect.fromLTWH(w * .16, h * .48, w * .46, h * .34),
          3.3,
          2.65,
          false,
          paint,
        );
        canvas.drawArc(
          Rect.fromLTWH(w * .48, h * .51, w * .36, h * .28),
          3.35,
          2.55,
          false,
          paint,
        );
        break;
      case PrototypeGlyph.dry:
      case PrototypeGlyph.humidity:
        final drop = Path()
          ..moveTo(c.dx, h * .12)
          ..cubicTo(w * .75, h * .42, w * .77, h * .72, c.dx, h * .86)
          ..cubicTo(w * .23, h * .72, w * .25, h * .42, c.dx, h * .12)
          ..close();
        canvas.drawPath(drop, paint);
        if (glyph == PrototypeGlyph.dry) {
          canvas.drawLine(
              Offset(w * .24, h * .76), Offset(w * .76, h * .24), paint);
        }
        break;
      case PrototypeGlyph.warm:
      case PrototypeGlyph.temperature:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * .38, h * .12, w * .24, h * .55),
            Radius.circular(w * .12),
          ),
          paint,
        );
        canvas.drawCircle(Offset(c.dx, h * .72), w * .18, paint);
        canvas.drawLine(Offset(c.dx, h * .25), Offset(c.dx, h * .66), paint);
        break;
      case PrototypeGlyph.travel:
        final path = Path()
          ..moveTo(w * .14, h * .54)
          ..lineTo(w * .48, h * .18)
          ..lineTo(w * .86, h * .54)
          ..lineTo(w * .74, h * .54)
          ..lineTo(w * .74, h * .85)
          ..lineTo(w * .28, h * .85)
          ..lineTo(w * .28, h * .54)
          ..close();
        canvas.drawPath(path, paint);
        canvas.drawLine(
            Offset(w * .14, h * .23), Offset(w * .84, h * .82), paint);
        break;
      case PrototypeGlyph.airConditioner:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * .12, h * .22, w * .76, h * .43),
            const Radius.circular(5),
          ),
          paint,
        );
        canvas.drawLine(
            Offset(w * .2, h * .52), Offset(w * .8, h * .52), paint);
        canvas.drawLine(
            Offset(w * .34, h * .72), Offset(w * .34, h * .88), paint);
        canvas.drawLine(
            Offset(w * .66, h * .72), Offset(w * .66, h * .88), paint);
        break;
      case PrototypeGlyph.floorHeat:
        for (var i = 0; i < 3; i++) {
          final x = w * (.28 + i * .22);
          final path = Path()
            ..moveTo(x, h * .86)
            ..cubicTo(x - 10, h * .67, x + 10, h * .52, x, h * .36)
            ..cubicTo(x - 8, h * .23, x + 8, h * .16, x, h * .08);
          canvas.drawPath(path, paint);
        }
        break;
      case PrototypeGlyph.freshAir:
        canvas.drawArc(
          Rect.fromLTWH(w * .1, h * .19, w * .68, h * .38),
          3.5,
          4.2,
          false,
          paint,
        );
        canvas.drawArc(
          Rect.fromLTWH(w * .22, h * .46, w * .68, h * .35),
          .35,
          4.2,
          false,
          paint,
        );
        canvas.drawLine(
            Offset(w * .72, h * .2), Offset(w * .82, h * .3), paint);
        canvas.drawLine(
            Offset(w * .18, h * .7), Offset(w * .28, h * .8), paint);
        break;
      case PrototypeGlyph.clean:
        canvas.drawCircle(c, w * .29, paint);
        canvas.drawLine(Offset(c.dx, h * .1), Offset(c.dx, h * .9), paint);
        canvas.drawLine(Offset(w * .1, c.dy), Offset(w * .9, c.dy), paint);
        canvas.drawLine(
            Offset(w * .22, h * .22), Offset(w * .78, h * .78), paint);
        canvas.drawLine(
            Offset(w * .78, h * .22), Offset(w * .22, h * .78), paint);
        break;
      case PrototypeGlyph.pm25:
        canvas.drawCircle(c, w * .32, paint);
        canvas.drawCircle(Offset(w * .34, h * .42), 3, paint);
        canvas.drawCircle(Offset(w * .57, h * .31), 3, paint);
        canvas.drawCircle(Offset(w * .64, h * .59), 3, paint);
        break;
      case PrototypeGlyph.co2:
        canvas.drawCircle(c, w * .34, paint);
        // 不直接使用 Unicode 下标字符 `₂`。部分嵌入式字体引擎无法
        // 稳定解析该字形，因此与正文 CO2 标注一致，独立绘制普通数字 2。
        final coPainter = TextPainter(
          text: TextSpan(
            text: 'CO',
            style: TextStyle(
              color: color,
              fontFamily: AppFonts.sourceHanSansSc,
              fontVariations: AppFonts.sourceHanSansScRegularWght400,
              fontSize: w * .22,
              height: 1,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final subscriptPainter = TextPainter(
          text: TextSpan(
            text: '2',
            style: TextStyle(
              color: color,
              fontFamily: AppFonts.harmonyRegular,
              fontSize: w * .135,
              height: 1,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final textWidth = coPainter.width + subscriptPainter.width;
        final textLeft = c.dx - textWidth / 2;
        final textTop = c.dy - coPainter.height / 2;
        coPainter.paint(canvas, Offset(textLeft, textTop));
        subscriptPainter.paint(
          canvas,
          Offset(textLeft + coPainter.width, textTop + w * .095),
        );
        break;
      case PrototypeGlyph.system:
        canvas.drawCircle(c, w * .24, paint);
        canvas.drawCircle(c, w * .08, paint);
        for (var i = 0; i < 6; i++) {
          final angle = i * 3.1415926 / 3;
          canvas.drawLine(
            Offset(c.dx + w * .27 * _cos(angle), c.dy + w * .27 * _sin(angle)),
            Offset(c.dx + w * .39 * _cos(angle), c.dy + w * .39 * _sin(angle)),
            paint,
          );
        }
        break;
      case PrototypeGlyph.maintenance:
        canvas.drawLine(
            Offset(w * .2, h * .78), Offset(w * .72, h * .26), paint);
        canvas.drawCircle(Offset(w * .25, h * .73), w * .11, paint);
        canvas.drawArc(
          Rect.fromCircle(center: Offset(w * .7, h * .28), radius: w * .18),
          .5,
          3.8,
          false,
          paint,
        );
        break;
      case PrototypeGlyph.engineering:
        canvas.drawRect(
            Rect.fromLTWH(w * .18, h * .22, w * .64, h * .56), paint);
        canvas.drawLine(
            Offset(w * .32, h * .38), Offset(w * .68, h * .38), paint);
        canvas.drawLine(
            Offset(w * .32, h * .55), Offset(w * .58, h * .55), paint);
        break;
    }
  }

  double _sin(double x) {
    var value = x;
    while (value > 3.1415926) {
      value -= 6.2831852;
    }
    while (value < -3.1415926) {
      value += 6.2831852;
    }
    return value * (1 - value.abs() / 3.1415926) * 1.2732395;
  }

  double _cos(double x) => _sin(x + 1.5707963);

  @override
  bool shouldRepaint(PrototypeGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}

class PrototypeSideMenu extends StatelessWidget {
  const PrototypeSideMenu({
    Key? key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.top = 254,
    this.itemGap = 176,
    this.dividerWidth = 184,
  }) : super(key: key);

  final List<PrototypeMenuItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double top;
  final double itemGap;
  final double dividerWidth;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        for (var index = 0; index < items.length; index++)
          Positioned(
            left: 104,
            top: top + index * itemGap,
            child: GestureDetector(
              key: ValueKey<String>('side-menu-$index'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelected(index),
              child: SizedBox(
                width: 256,
                height: 104,
                child: Row(
                  children: <Widget>[
                    _SideMenuIcon(
                      item: items[index],
                      selected: index == selectedIndex,
                      index: index,
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Text(
                        items[index].label,
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        style: TextStyle(
                          color: index == selectedIndex
                              ? Colors.white
                              : const Color(0x80FFFFFF),
                          fontFamily: AppFonts.sourceHanSansSc,
                          fontVariations: index == selectedIndex
                              ? AppFonts.sourceHanSansScBoldWght700
                              : AppFonts.sourceHanSansScRegularWght400,
                          fontSize: 36,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // Figma sidebar：返回区以外的导航项之间使用 25% 白色细线。
        for (var index = 0; index < items.length - 1; index++)
          Positioned(
            left: 108,
            top: top + 137 + index * itemGap,
            width: dividerWidth,
            height: 1,
            child: const ColoredBox(color: Color(0x40FFFFFF)),
          ),
      ],
    );
  }
}

class _SideMenuIcon extends StatelessWidget {
  const _SideMenuIcon({
    required this.item,
    required this.selected,
    required this.index,
  });

  final PrototypeMenuItem item;
  final bool selected;
  final int index;

  @override
  Widget build(BuildContext context) {
    final asset = selected ? item.activeIconAsset : item.inactiveIconAsset;
    if (asset != null) {
      Widget icon = Image.asset(
        asset,
        key: ValueKey<String>('side-menu-icon-$index-$selected'),
        filterQuality: FilterQuality.high,
      );
      if (item.tintIconAssetWhite) {
        // 部分 Figma 导出 PNG 的笔画为黑色、背景透明；以 alpha 作蒙版
        // 着白色，保留原图中“亮/灭”的不透明度差异。
        icon = ColorFiltered(
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          child: icon,
        );
      }
      if (item.iconAssetOffset != Offset.zero) {
        icon = Transform.translate(
          offset: item.iconAssetOffset,
          child: icon,
        );
      }
      return SizedBox(
        width: 72,
        height: 72,
        child: icon,
      );
    }
    return SizedBox(
      width: 72,
      height: 72,
      child: CustomPaint(
        painter: PrototypeGlyphPainter(
          item.glyph,
          color: selected ? Colors.white : const Color(0x80FFFFFF),
        ),
      ),
    );
  }
}

class PrototypeMenuItem {
  const PrototypeMenuItem(
    this.label,
    this.glyph, {
    this.activeIconAsset,
    this.inactiveIconAsset,
    this.tintIconAssetWhite = false,
    this.iconAssetOffset = Offset.zero,
  });

  final String label;
  final PrototypeGlyph glyph;
  final String? activeIconAsset;
  final String? inactiveIconAsset;
  final bool tintIconAssetWhite;
  final Offset iconAssetOffset;
}
