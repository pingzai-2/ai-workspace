import 'dart:async';

import 'package:flutter/material.dart';

enum _PressedSide { none, plus, minus }

/// 设计稿纵向加减按钮：默认、上按下、下按下、禁用四种完整切图状态。
class VerticalStepper extends StatefulWidget {
  const VerticalStepper({
    Key? key,
    required this.keyPrefix,
    required this.enabled,
    required this.interactionEnabled,
    required this.onPlus,
    required this.onMinus,
  }) : super(key: key);

  final String keyPrefix;

  /// 控制正常/禁用切图；只反映设备自身是否允许调节。
  final bool enabled;

  /// 临时禁止输入但不改变切图，例如同组数据正在保存时。
  final bool interactionEnabled;
  final VoidCallback onPlus;
  final VoidCallback onMinus;

  @override
  State<VerticalStepper> createState() => _VerticalStepperState();
}

class _VerticalStepperState extends State<VerticalStepper> {
  static const Duration _minimumPressedDuration = Duration(milliseconds: 90);
  static const List<String> _assets = <String>[
    'assets/manual/vertical_stepper_on.png',
    'assets/manual/vertical_stepper_off.png',
    'assets/manual/vertical_stepper_press_up.png',
    'assets/manual/vertical_stepper_press_down.png',
  ];

  _PressedSide _pressedSide = _PressedSide.none;
  Timer? _releaseTimer;
  bool _assetsPrecached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_assetsPrecached) {
      return;
    }
    _assetsPrecached = true;
    for (final path in _assets) {
      precacheImage(AssetImage(path), context);
    }
  }

  @override
  void didUpdateWidget(covariant VerticalStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_acceptsInput && _pressedSide != _PressedSide.none) {
      _releaseTimer?.cancel();
      _pressedSide = _PressedSide.none;
    }
  }

  bool get _acceptsInput => widget.enabled && widget.interactionEnabled;

  @override
  void dispose() {
    _releaseTimer?.cancel();
    super.dispose();
  }

  void _showPressed(_PressedSide side) {
    _releaseTimer?.cancel();
    setState(() => _pressedSide = side);
  }

  void _release(VoidCallback action) {
    action();
    _releaseTimer?.cancel();
    _releaseTimer = Timer(_minimumPressedDuration, () {
      if (mounted) {
        setState(() => _pressedSide = _PressedSide.none);
      }
    });
  }

  void _cancelPress() {
    _releaseTimer?.cancel();
    if (_pressedSide != _PressedSide.none) {
      setState(() => _pressedSide = _PressedSide.none);
    }
  }

  String get _assetPath {
    if (!widget.enabled) {
      return 'assets/manual/vertical_stepper_off.png';
    }
    switch (_pressedSide) {
      case _PressedSide.plus:
        return 'assets/manual/vertical_stepper_press_up.png';
      case _PressedSide.minus:
        return 'assets/manual/vertical_stepper_press_down.png';
      case _PressedSide.none:
        return 'assets/manual/vertical_stepper_on.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      height: 198,
      child: Stack(
        children: <Widget>[
          Image.asset(
            _assetPath,
            key: ValueKey<String>('${widget.keyPrefix}-image'),
            width: 68,
            height: 198,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          ),
          Column(
            children: <Widget>[
              Expanded(
                child: GestureDetector(
                  key: ValueKey<String>('${widget.keyPrefix}-plus'),
                  behavior: HitTestBehavior.opaque,
                  onTapDown: _acceptsInput
                      ? (_) => _showPressed(_PressedSide.plus)
                      : null,
                  onTapUp:
                      _acceptsInput ? (_) => _release(widget.onPlus) : null,
                  onTapCancel: _acceptsInput ? _cancelPress : null,
                ),
              ),
              Expanded(
                child: GestureDetector(
                  key: ValueKey<String>('${widget.keyPrefix}-minus'),
                  behavior: HitTestBehavior.opaque,
                  onTapDown: _acceptsInput
                      ? (_) => _showPressed(_PressedSide.minus)
                      : null,
                  onTapUp:
                      _acceptsInput ? (_) => _release(widget.onMinus) : null,
                  onTapCancel: _acceptsInput ? _cancelPress : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
