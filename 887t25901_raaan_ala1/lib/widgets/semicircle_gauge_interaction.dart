import 'dart:math' as math;

import 'package:flutter/material.dart';

typedef SemicircleGaugeRectResolver = Rect Function(Size size);

/// 8 寸可调半圆弧的统一视觉和触摸几何。
const Size semicircleGaugeVisualSize = Size(462, 231);
const double semicircleGaugeArcInset = 6;
const double semicircleGaugeDotRadius = 20;
const double semicircleGaugeHitPadding = 24;

/// 智能和手动页面共用的唯一半圆弧 Painter。
class SemicircleGaugePainter extends CustomPainter {
  const SemicircleGaugePainter({
    required this.progress,
    required this.trackColor,
    required this.activeColor,
    required this.dotColor,
  });

  final double progress;
  final Color trackColor;
  final Color activeColor;
  final Color dotColor;

  static Rect gaugeRect(Size size) => Rect.fromLTWH(
        semicircleGaugeArcInset,
        semicircleGaugeArcInset,
        size.width - semicircleGaugeArcInset * 2,
        size.height * 1.88,
      );

  @override
  void paint(Canvas canvas, Size size) {
    final rect = gaugeRect(size);
    final resolvedProgress = progress.clamp(0.0, 1.0);
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.butt;
    final active = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, math.pi, math.pi, false, track);
    canvas.drawArc(
      rect,
      math.pi,
      math.pi * resolvedProgress,
      false,
      active,
    );

    final angle = math.pi + math.pi * resolvedProgress;
    final center = rect.center;
    canvas.drawCircle(
      Offset(
        center.dx + rect.width / 2 * math.cos(angle),
        center.dy + rect.height / 2 * math.sin(angle),
      ),
      semicircleGaugeDotRadius,
      Paint()..color = dotColor,
    );
  }

  @override
  bool shouldRepaint(covariant SemicircleGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.dotColor != dotColor;
  }
}

/// 462×231 半圆在 8 寸设计稿中的端点文字纵坐标。
const double semicircleGaugeEndpointLabelTop = 403;

/// 让不同长度的端点文字以自身中心对准半圆端点。
class SemicircleGaugeEndpointLabel extends StatelessWidget {
  const SemicircleGaugeEndpointLabel({
    Key? key,
    required this.text,
    required this.style,
    required this.isRightEndpoint,
  }) : super(key: key);

  final String text;
  final TextStyle style;
  final bool isRightEndpoint;

  @override
  Widget build(BuildContext context) {
    return FractionalTranslation(
      translation: Offset(isRightEndpoint ? .5 : -.5, 0),
      child: Text(text, style: style),
    );
  }
}

/// 主数值独立居中，单位只作为右侧后缀显示。
class SemicircleGaugeValue extends StatelessWidget {
  const SemicircleGaugeValue({
    Key? key,
    required this.value,
    required this.valueStyle,
    this.valueKey,
    this.unit,
    this.unitStyle,
    this.unitGap = 12,
  }) : super(key: key);

  final String value;
  final TextStyle valueStyle;
  final Key? valueKey;
  final String? unit;
  final TextStyle? unitStyle;
  final double unitGap;

  @override
  Widget build(BuildContext context) {
    final suffix = unit;
    final suffixStyle = unitStyle;
    assert(suffix == null || suffixStyle != null);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        if (suffix != null)
          ExcludeSemantics(
            child: Opacity(
              opacity: 0,
              child: Padding(
                padding: EdgeInsets.only(right: unitGap),
                child: Text(suffix, style: suffixStyle),
              ),
            ),
          ),
        Text(value, key: valueKey, style: valueStyle),
        if (suffix != null)
          Padding(
            padding: EdgeInsets.only(left: unitGap),
            child: Text(suffix, style: suffixStyle),
          ),
      ],
    );
  }
}

/// 8 寸智能、手动设备页共用的完整半圆仪表。
///
/// 页面只提供数据、颜色和文字样式；圆弧尺寸、圆点、数值居中、端点坐标
/// 以及交互层均由这里统一。固定模式传入 [interactionEnabled] 为 false，
/// 保留相同视觉但不响应拖动。
class SemicircleGauge extends StatelessWidget {
  const SemicircleGauge({
    Key? key,
    required this.gaugeKey,
    required this.title,
    required this.titleStyle,
    required this.value,
    required this.valueStyle,
    required this.valueTop,
    required this.currentValue,
    required this.minValue,
    required this.maxValue,
    required this.minLabel,
    required this.maxLabel,
    required this.endpointStyle,
    required this.trackColor,
    required this.activeColor,
    required this.dotColor,
    required this.interactionEnabled,
    this.valueKey,
    this.unit,
    this.unitStyle,
    this.onPreviewChanged,
    this.onInteractionEnd,
  })  : assert(minValue <= maxValue),
        super(key: key);

  final Key gaugeKey;
  final String title;
  final TextStyle titleStyle;
  final String value;
  final TextStyle valueStyle;
  final double valueTop;
  final int currentValue;
  final int minValue;
  final int maxValue;
  final String minLabel;
  final String maxLabel;
  final TextStyle endpointStyle;
  final Color trackColor;
  final Color activeColor;
  final Color dotColor;
  final bool interactionEnabled;
  final Key? valueKey;
  final String? unit;
  final TextStyle? unitStyle;
  final ValueChanged<int>? onPreviewChanged;
  final VoidCallback? onInteractionEnd;

  @override
  Widget build(BuildContext context) {
    final progress = maxValue == minValue
        ? 0.0
        : (currentValue - minValue) / (maxValue - minValue);
    return SizedBox(
      width: semicircleGaugeVisualSize.width + semicircleGaugeHitPadding * 2,
      height: 600,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: <Widget>[
          IgnorePointer(child: Text(title, style: titleStyle)),
          Positioned(
            left: 0,
            top: 150 - semicircleGaugeHitPadding,
            child: SemicircleGaugeInteraction(
              key: gaugeKey,
              size: semicircleGaugeVisualSize,
              interactionEnabled: interactionEnabled,
              minValue: minValue,
              maxValue: maxValue,
              gaugeRect: SemicircleGaugePainter.gaugeRect,
              onPreviewChanged: onPreviewChanged,
              onInteractionEnd: onInteractionEnd,
              child: CustomPaint(
                size: semicircleGaugeVisualSize,
                painter: SemicircleGaugePainter(
                  progress: progress,
                  trackColor: trackColor,
                  activeColor: activeColor,
                  dotColor: dotColor,
                ),
              ),
            ),
          ),
          Positioned(
            top: valueTop,
            child: IgnorePointer(
              child: SemicircleGaugeValue(
                value: value,
                valueKey: valueKey,
                valueStyle: valueStyle,
                unit: unit,
                unitStyle: unitStyle,
              ),
            ),
          ),
          Positioned(
            left: semicircleGaugeHitPadding + semicircleGaugeArcInset,
            top: semicircleGaugeEndpointLabelTop,
            child: IgnorePointer(
              child: SemicircleGaugeEndpointLabel(
                text: minLabel,
                style: endpointStyle,
                isRightEndpoint: false,
              ),
            ),
          ),
          Positioned(
            right: semicircleGaugeHitPadding + semicircleGaugeArcInset,
            top: semicircleGaugeEndpointLabelTop,
            child: IgnorePointer(
              child: SemicircleGaugeEndpointLabel(
                text: maxLabel,
                style: endpointStyle,
                isRightEndpoint: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 8 寸可调半圆弧的统一手势层。
///
/// 这里统一触点换算、拖动预览以及松手/手势取消后的单次提交边界。
/// 交互锁不会改变圆弧视觉。
class SemicircleGaugeInteraction extends StatelessWidget {
  const SemicircleGaugeInteraction({
    Key? key,
    required this.size,
    required this.interactionEnabled,
    required this.minValue,
    required this.maxValue,
    required this.gaugeRect,
    required this.onPreviewChanged,
    required this.onInteractionEnd,
    required this.child,
  })  : assert(minValue <= maxValue),
        super(key: key);

  final Size size;
  final bool interactionEnabled;
  final int minValue;
  final int maxValue;
  final SemicircleGaugeRectResolver gaugeRect;
  final ValueChanged<int>? onPreviewChanged;
  final VoidCallback? onInteractionEnd;
  final Widget child;

  bool get _acceptsInput =>
      interactionEnabled &&
      onPreviewChanged != null &&
      onInteractionEnd != null;

  int _valueForPosition(Offset position) {
    final rect = gaugeRect(size);
    final center = rect.center;
    final visualPosition = position -
        const Offset(
          semicircleGaugeHitPadding,
          semicircleGaugeHitPadding,
        );
    final normalizedX = (visualPosition.dx - center.dx) / (rect.width / 2);
    final normalizedY = (visualPosition.dy - center.dy) / (rect.height / 2);
    var angle = math.atan2(normalizedY, normalizedX);
    if (angle > 0) {
      angle = normalizedX < 0 ? -math.pi : 0;
    }
    final progress = ((angle + math.pi) / math.pi).clamp(0.0, 1.0);
    return (minValue + (maxValue - minValue) * progress)
        .round()
        .clamp(minValue, maxValue);
  }

  void _preview(Offset position) {
    onPreviewChanged?.call(_valueForPosition(position));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.width + semicircleGaugeHitPadding * 2,
      height: size.height + semicircleGaugeHitPadding * 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown:
            _acceptsInput ? (details) => _preview(details.localPosition) : null,
        onPanUpdate:
            _acceptsInput ? (details) => _preview(details.localPosition) : null,
        onPanEnd: _acceptsInput ? (_) => onInteractionEnd?.call() : null,
        onPanCancel: _acceptsInput ? () => onInteractionEnd?.call() : null,
        child: Padding(
          padding: const EdgeInsets.all(semicircleGaugeHitPadding),
          child: SizedBox.fromSize(size: size, child: child),
        ),
      ),
    );
  }
}
