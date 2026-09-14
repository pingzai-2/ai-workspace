import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_fonts.dart';

/// 主页左侧导航栏，对应 Figma function bar（1:2484 / 1:2694）。
class LeftNavBar extends StatelessWidget {
  const LeftNavBar({
    Key? key,
    this.currentIndex = 0,
    this.areaName = '',
    this.onItemSelected,
    this.smartModeActive = false,
    this.manualModeActive = false,
  }) : super(key: key);

  final int currentIndex;
  final String areaName;
  final ValueChanged<int>? onItemSelected;
  final bool smartModeActive;
  final bool manualModeActive;

  static const Color _activeColor = Color(0xFF42CEEA);
  static const Color _inactiveColor = Color(0xFFFFFFFF);

  // Home uses the directly exported latest Figma icons. The cyan press exports
  // are used for the selected item; the white exports are used when inactive.
  static final List<_NavData> _homeItems = <_NavData>[
    _NavData(
      inactiveAsset: 'assets/home/figma_home/home_inactive.png',
      activeAsset: 'assets/home/figma_home/home_active.png',
      useSourceColors: true,
      label: (l10n) => l10n.navHome,
    ),
    _NavData(
      inactiveAsset: 'assets/home/figma_home/smart_inactive.png',
      activeAsset: 'assets/home/figma_home/smart_active.png',
      useSourceColors: true,
      label: (l10n) => l10n.navSmart,
    ),
    _NavData(
      inactiveAsset: 'assets/home/figma_home/manual_inactive.png',
      activeAsset: 'assets/home/figma_home/manual_active.png',
      useSourceColors: true,
      label: (l10n) => l10n.navManual,
    ),
    _NavData(
      inactiveAsset: 'assets/home/figma_home/history_inactive.png',
      activeAsset: 'assets/home/figma_home/history_active.png',
      useSourceColors: true,
      label: (l10n) => l10n.navTrends,
    ),
    _NavData(
      inactiveAsset: 'assets/home/figma_home/settings_inactive.png',
      activeAsset: 'assets/home/figma_home/settings_active.png',
      useSourceColors: true,
      label: (l10n) => l10n.navSettings,
    ),
  ];

  static final List<_NavData> _items = <_NavData>[
    _NavData(
      inactiveAsset: 'assets/home/figma_home/home_inactive.png',
      activeAsset: 'assets/home/figma_home/home_active.png',
      useSourceColors: true,
      label: (l10n) => l10n.navMain,
    ),
    _NavData(
      inactiveAsset: 'assets/home/figma_home/smart_inactive.png',
      activeAsset: 'assets/home/figma_home/smart_active.png',
      useSourceColors: true,
      label: (l10n) => l10n.navSmart,
    ),
    _NavData(
      inactiveAsset: 'assets/home/figma_home/manual_inactive.png',
      activeAsset: 'assets/home/figma_home/manual_active.png',
      useSourceColors: true,
      label: (l10n) => l10n.navManual,
    ),
    _NavData(
      inactiveAsset: 'assets/home/figma_home/history_inactive.png',
      activeAsset: 'assets/home/figma_home/history_active.png',
      useSourceColors: true,
      label: (l10n) => l10n.navHistory,
    ),
    _NavData(
      inactiveAsset: 'assets/home/figma_home/settings_inactive.png',
      activeAsset: 'assets/home/figma_home/settings_active.png',
      useSourceColors: true,
      label: (l10n) => l10n.navSettingsAlt,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final items = currentIndex == 0 ? _homeItems : _items;
    return SizedBox(
      width: 182,
      height: 960,
      child: Stack(
        children: <Widget>[
          for (int i = 0; i < items.length; i++)
            Positioned(
              top: i * 208,
              child: _NavItem(
                index: i,
                data: items[i],
                active: i == currentIndex ||
                    (i == 1 && smartModeActive) ||
                    (i == 2 && manualModeActive),
                activeColor: _activeColor,
                inactiveColor: _inactiveColor,
                onTap: onItemSelected == null ? null : () => onItemSelected!(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavData {
  const _NavData({
    required this.inactiveAsset,
    required this.activeAsset,
    this.useSourceColors = false,
    required this.label,
  });
  final String inactiveAsset;
  final String activeAsset;
  final bool useSourceColors;
  final String Function(AppLocalizations) label;
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.index,
    required this.data,
    required this.active,
    required this.activeColor,
    required this.inactiveColor,
    this.onTap,
  });

  final int index;
  final _NavData data;
  final bool active;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback? onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(AssetImage(widget.data.inactiveAsset), context);
    precacheImage(AssetImage(widget.data.activeAsset), context);
  }

  void _setPressed(bool value) {
    if (_pressed == value) {
      return;
    }
    setState(() => _pressed = value);
  }

  TextStyle _labelStyle(BuildContext context, bool highlighted) {
    final color = highlighted
        ? widget.activeColor
        : widget.inactiveColor.withOpacity(.5);
    return TextStyle(
      color: color,
      fontFamily: AppFonts.sourceHanSansSc,
      fontVariations: highlighted
          ? AppFonts.sourceHanSansScBoldWght700
          : AppFonts.sourceHanSansScRegularWght400,
      fontSize: 32,
      height: 30 / 32,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 设计稿的彩色态同时承担两个含义：当前页面已选中，或手指正在按下。
    final highlighted = widget.active || _pressed;
    return GestureDetector(
      key: ValueKey<String>('left-nav-item-${widget.index}'),
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
      onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
      child: SizedBox(
        width: 182,
        height: 128,
        child: Stack(children: <Widget>[
          Positioned(
            left: widget.data.useSourceColors ? 46 : 59,
            top: widget.data.useSourceColors ? 0 : 13,
            child: Image.asset(
              highlighted ? widget.data.activeAsset : widget.data.inactiveAsset,
              key: ValueKey<String>(
                'left-nav-icon-${widget.index}-$highlighted',
              ),
              width: widget.data.useSourceColors ? 90 : 64,
              height: widget.data.useSourceColors ? 90 : 64,
              color: widget.data.useSourceColors
                  ? null
                  : (highlighted
                      ? widget.activeColor
                      : widget.inactiveColor.withOpacity(.5)),
            ),
          ),
          Positioned(
            left: 0,
            top: 98,
            child: SizedBox(
              width: 182,
              child: Text(
                widget.data.label(AppLocalizations.of(context)),
                textAlign: TextAlign.center,
                maxLines: 1,
                softWrap: false,
                style: _labelStyle(context, highlighted),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
