import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_fonts.dart';

enum TouchKeyboardLayout { letters, symbols, symbolsExtended }

/// 1920×1200 中控屏共用触控键盘。
///
/// 组件只负责字符输入、退格、键盘切换和确认，不读取系统输入法，
/// 也不包含 Wi-Fi、工程模式等业务判断。
class TouchPasswordKeyboard extends StatefulWidget {
  const TouchPasswordKeyboard({
    Key? key,
    required this.initialValue,
    required this.onChanged,
    required this.onConfirm,
    this.maxLength = 64,
    this.enabled = true,
    this.initialLayout = TouchKeyboardLayout.letters,
  }) : super(key: key);

  final String initialValue;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onConfirm;
  final int maxLength;
  final bool enabled;
  final TouchKeyboardLayout initialLayout;

  @override
  State<TouchPasswordKeyboard> createState() => _TouchPasswordKeyboardState();
}

class _TouchPasswordKeyboardState extends State<TouchPasswordKeyboard> {
  late String _value;
  late TouchKeyboardLayout _layout;
  bool _uppercase = true;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
    _layout = widget.initialLayout;
  }

  @override
  void didUpdateWidget(covariant TouchPasswordKeyboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _value) {
      _value = widget.initialValue;
    }
  }

  void _append(String value) {
    if (!widget.enabled || _value.length >= widget.maxLength) {
      return;
    }
    final next = '$_value$value';
    setState(() => _value = next);
    widget.onChanged(next);
  }

  void _backspace() {
    if (!widget.enabled || _value.isEmpty) {
      return;
    }
    final next = _value.substring(0, _value.length - 1);
    setState(() => _value = next);
    widget.onChanged(next);
  }

  void _switchLayout(TouchKeyboardLayout layout) {
    if (!widget.enabled) {
      return;
    }
    setState(() => _layout = layout);
  }

  @override
  Widget build(BuildContext context) {
    final body = _layout == TouchKeyboardLayout.letters
        ? _buildLetters()
        : _buildSymbols(
            extended: _layout == TouchKeyboardLayout.symbolsExtended,
          );
    return Container(
      key: const ValueKey<String>('touch-password-keyboard'),
      width: 1085,
      height: 501,
      padding: const EdgeInsets.fromLTRB(24, 41, 24, 24),
      color: const Color(0xFF18191B),
      child: Column(
        children: <Widget>[
          ...body,
          const SizedBox(height: 12),
          _buildBottomRow(),
        ],
      ),
    );
  }

  List<Widget> _buildLetters() {
    final first = _uppercase ? 'QWERTYUIOP' : 'qwertyuiop';
    final second = _uppercase ? 'ASDFGHJKL' : 'asdfghjkl';
    final third = _uppercase ? 'ZXCVBNM' : 'zxcvbnm';
    return <Widget>[
      _characterRow(first.split('')),
      const SizedBox(height: 12),
      _characterRow(second.split(''), horizontalPadding: 52),
      const SizedBox(height: 12),
      SizedBox(
        height: 100,
        child: Row(
          children: <Widget>[
            _KeyboardKey(
              keyName: 'shift',
              width: 120,
              onTap: widget.enabled
                  ? () => setState(() => _uppercase = !_uppercase)
                  : null,
              child: CustomPaint(
                size: const Size(36, 36),
                painter: _ShiftGlyphPainter(),
              ),
            ),
            const SizedBox(width: 12),
            for (var index = 0; index < third.length; index++) ...<Widget>[
              Expanded(child: _characterKey(third[index])),
              if (index != third.length - 1) const SizedBox(width: 12),
            ],
            const SizedBox(width: 12),
            _backspaceKey(),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildSymbols({required bool extended}) {
    if (extended) {
      return <Widget>[
        _characterRow(
          const <String>['#', '%', '*', '+', '<', '=', '>', '[', ']', '^'],
        ),
        const SizedBox(height: 12),
        _characterRow(
          const <String>['\\', '`', '{', '|', '}', '~', '-', '/', ':', ';'],
        ),
        const SizedBox(height: 12),
        _characterRowWithBackspace(
          const <String>['(', ')', '&', '@', '"', "'", '.'],
        ),
      ];
    }
    return <Widget>[
      _characterRow('1234567890'.split('')),
      const SizedBox(height: 12),
      _characterRow(
        const <String>['-', '/', ':', ';', '(', ')', r'$', '&', '@', '"'],
      ),
      const SizedBox(height: 12),
      _characterRowWithBackspace(
        const <String>['.', ',', '?', '!', "'", '_'],
      ),
    ];
  }

  Widget _characterRowWithBackspace(List<String> characters) {
    return SizedBox(
      height: 100,
      child: Row(
        children: <Widget>[
          for (final character in characters) ...<Widget>[
            Expanded(child: _characterKey(character)),
            const SizedBox(width: 12),
          ],
          _backspaceKey(width: 144),
        ],
      ),
    );
  }

  Widget _characterRow(
    List<String> characters, {
    double horizontalPadding = 0,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: SizedBox(
        height: 100,
        child: Row(
          children: <Widget>[
            for (var index = 0; index < characters.length; index++) ...<Widget>[
              Expanded(child: _characterKey(characters[index])),
              if (index != characters.length - 1) const SizedBox(width: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _characterKey(String character) {
    return _KeyboardKey(
      keyName: character,
      onTap: widget.enabled ? () => _append(character) : null,
      child: Text(character, style: _keyTextStyle),
    );
  }

  Widget _backspaceKey({double width = 120}) {
    return _KeyboardKey(
      keyName: 'backspace',
      width: width,
      onTap: widget.enabled ? _backspace : null,
      child: CustomPaint(
        size: const Size(42, 32),
        painter: _BackspaceGlyphPainter(),
      ),
    );
  }

  Widget _buildBottomRow() {
    final symbolMode = _layout != TouchKeyboardLayout.letters;
    final extendedSymbols = _layout == TouchKeyboardLayout.symbolsExtended;
    return SizedBox(
      height: 100,
      child: Row(
        children: <Widget>[
          _KeyboardKey(
            keyName: symbolMode ? 'ABC' : '123',
            width: symbolMode ? 140 : 180,
            onTap: widget.enabled
                ? () => _switchLayout(
                      symbolMode
                          ? TouchKeyboardLayout.letters
                          : TouchKeyboardLayout.symbols,
                    )
                : null,
            child: Text(symbolMode ? 'ABC' : '123', style: _keyTextStyle),
          ),
          if (symbolMode) ...<Widget>[
            const SizedBox(width: 12),
            _KeyboardKey(
              keyName: extendedSymbols ? '123' : '#+=',
              width: 140,
              onTap: widget.enabled
                  ? () => _switchLayout(
                        extendedSymbols
                            ? TouchKeyboardLayout.symbols
                            : TouchKeyboardLayout.symbolsExtended,
                      )
                  : null,
              child: Text(
                extendedSymbols ? '123' : '#+=',
                style: _keyTextStyle,
              ),
            ),
          ],
          const SizedBox(width: 12),
          Expanded(
            child: _KeyboardKey(
              keyName: 'space',
              onTap: widget.enabled ? () => _append(' ') : null,
              child: Text(
                AppLocalizations.of(context).space,
                style: _functionTextStyle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _KeyboardKey(
            keyName: 'confirm',
            width: 220,
            color: const Color(0xFF3474CB),
            onTap: widget.enabled ? () => widget.onConfirm(_value) : null,
            child: Text(
              AppLocalizations.of(context).confirm,
              style: _confirmTextStyle,
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyboardKey extends StatelessWidget {
  const _KeyboardKey({
    required this.keyName,
    required this.child,
    required this.onTap,
    this.width,
    this.color = const Color(0xFF303033),
  });

  final String keyName;
  final Widget child;
  final VoidCallback? onTap;
  final double? width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey<String>('touch-key-$keyName'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: width,
        height: 100,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: onTap == null ? const Color(0xFF242426) : color,
          border: Border.all(color: const Color(0xFF4B4B4E)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      ),
    );
  }
}

class _ShiftGlyphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * .18, size.height * .48)
      ..lineTo(size.width * .5, size.height * .16)
      ..lineTo(size.width * .82, size.height * .48)
      ..lineTo(size.width * .64, size.height * .48)
      ..lineTo(size.width * .64, size.height * .82)
      ..lineTo(size.width * .36, size.height * .82)
      ..lineTo(size.width * .36, size.height * .48)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BackspaceGlyphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(0, size.height / 2)
      ..lineTo(size.width * .28, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * .28, size.height)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawLine(
      Offset(size.width * .48, size.height * .3),
      Offset(size.width * .76, size.height * .7),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * .76, size.height * .3),
      Offset(size.width * .48, size.height * .7),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

const TextStyle _keyTextStyle = TextStyle(
  color: Colors.white,
  fontFamily: AppFonts.harmonyRegular,
  fontSize: 36,
);

const TextStyle _functionTextStyle = TextStyle(
  color: Colors.white,
  fontFamily: AppFonts.sourceHanSansSc,
  fontVariations: AppFonts.sourceHanSansScMediumWght500,
  fontSize: 30,
);

const TextStyle _confirmTextStyle = TextStyle(
  color: Colors.white,
  fontFamily: AppFonts.sourceHanSansSc,
  fontVariations: AppFonts.sourceHanSansScBoldWght700,
  fontSize: 36,
);
