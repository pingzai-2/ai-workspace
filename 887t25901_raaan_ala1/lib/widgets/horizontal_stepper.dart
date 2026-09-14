import 'dart:async';

import 'package:flutter/material.dart';

enum _PressedSide { none, minus, plus }

/// 设计稿横向加减按钮：默认、左按下、右按下、禁用四种完整切图状态。
class HorizontalStepper extends StatefulWidget {
  const HorizontalStepper({
    Key? key,
    required this.keyPrefix,
    required this.enabled,
    required this.interactionEnabled,
    required this.onMinus,
    required this.onPlus,
  }) : super(key: key);

  final String keyPrefix;

  /// 决定使用正常或禁用切图，只表达设备本身是否可用。
  final bool enabled;

  /// 临时锁定点击但保持当前视觉，例如设置正在写盘时。
  final bool interactionEnabled;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  State<HorizontalStepper> createState() => _HorizontalStepperState();
}

class _HorizontalStepperState extends State<HorizontalStepper> {
  static const Duration _minimumPressedDuration = Duration(milliseconds: 90);
  static const Duration _repeatDelay = Duration(milliseconds: 450);
  static const Duration _repeatInterval = Duration(milliseconds: 120);
  static const List<String> _assets = <String>[
    'assets/smart/standard_stepper_on.png',
    'assets/smart/standard_stepper_off.png',
    'assets/smart/standard_stepper_press_left.png',
    'assets/smart/standard_stepper_press_right.png',
  ];

  _PressedSide _pressedSide = _PressedSide.none;
  Timer? _releaseTimer;
  Timer? _repeatDelayTimer;
  Timer? _repeatTimer;
  bool _repeatStarted = false;
  bool _assetsPrecached = false;

  bool get _canInteract => widget.enabled && widget.interactionEnabled;

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
  void didUpdateWidget(covariant HorizontalStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_canInteract && _pressedSide != _PressedSide.none) {
      _cancelTimers();
      _pressedSide = _PressedSide.none;
    }
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }

  void _cancelTimers() {
    _releaseTimer?.cancel();
    _repeatDelayTimer?.cancel();
    _repeatTimer?.cancel();
  }

  void _startPress(_PressedSide side, VoidCallback action) {
    _cancelTimers();
    _repeatStarted = false;
    setState(() => _pressedSide = side);
    _repeatDelayTimer = Timer(_repeatDelay, () {
      if (!mounted || !_canInteract || _pressedSide != side) return;
      _repeatStarted = true;
      action();
      _repeatTimer = Timer.periodic(_repeatInterval, (_) {
        if (mounted && _canInteract && _pressedSide == side) action();
      });
    });
  }

  void _release(VoidCallback action) {
    _repeatDelayTimer?.cancel();
    _repeatTimer?.cancel();
    if (!_repeatStarted) action();
    _repeatStarted = false;
    _releaseTimer = Timer(_minimumPressedDuration, () {
      if (mounted) {
        setState(() => _pressedSide = _PressedSide.none);
      }
    });
  }

  void _cancelPress() {
    _cancelTimers();
    _repeatStarted = false;
    if (_pressedSide != _PressedSide.none) {
      setState(() => _pressedSide = _PressedSide.none);
    }
  }

  String get _assetPath {
    if (!widget.enabled) {
      return 'assets/smart/standard_stepper_off.png';
    }
    switch (_pressedSide) {
      case _PressedSide.minus:
        return 'assets/smart/standard_stepper_press_left.png';
      case _PressedSide.plus:
        return 'assets/smart/standard_stepper_press_right.png';
      case _PressedSide.none:
        return 'assets/smart/standard_stepper_on.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 262,
      height: 90,
      child: Stack(
        children: <Widget>[
          Image.asset(
            _assetPath,
            key: ValueKey<String>('${widget.keyPrefix}-image'),
            width: 262,
            height: 90,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: GestureDetector(
                  key: ValueKey<String>('${widget.keyPrefix}-minus'),
                  behavior: HitTestBehavior.opaque,
                  onTapDown: _canInteract
                      ? (_) => _startPress(_PressedSide.minus, widget.onMinus)
                      : null,
                  onTapUp:
                      _canInteract ? (_) => _release(widget.onMinus) : null,
                  onTapCancel: _canInteract ? _cancelPress : null,
                ),
              ),
              Expanded(
                child: GestureDetector(
                  key: ValueKey<String>('${widget.keyPrefix}-plus'),
                  behavior: HitTestBehavior.opaque,
                  onTapDown: _canInteract
                      ? (_) => _startPress(_PressedSide.plus, widget.onPlus)
                      : null,
                  onTapUp: _canInteract ? (_) => _release(widget.onPlus) : null,
                  onTapCancel: _canInteract ? _cancelPress : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
