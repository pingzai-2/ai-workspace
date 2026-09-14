part of 'home_page.dart';

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.cardKey,
    required this.width,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.artwork,
    required this.artworkOffset,
    this.artworkOpacity = 1,
    this.artworkKey,
    this.onCardTap,
    this.onPowerTap,
    this.powerKey,
    this.busy = false,
  });

  final Key cardKey;
  final double width;
  final String title;
  final String subtitle;
  final bool enabled;
  final String artwork;
  final Offset artworkOffset;
  final double artworkOpacity;
  final Key? artworkKey;
  final VoidCallback? onCardTap;
  final VoidCallback? onPowerTap;
  final Key? powerKey;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final textLeft = width >= 400 ? 48.0 : 24.0;
    return GestureDetector(
      key: cardKey,
      behavior: HitTestBehavior.opaque,
      onTap: onCardTap,
      child: SizedBox(
        width: width,
        height: 386,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: <Widget>[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF25292E),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Positioned(
              left: textLeft,
              top: 24,
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: AppFonts.sourceHanSansSc,
                  fontVariations: AppFonts.sourceHanSansScBoldWght700,
                  fontSize: 36,
                ),
              ),
            ),
            Positioned(
              left: textLeft,
              top: 72,
              child: Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xB3FFFFFF),
                  fontFamily: AppFonts.sourceHanSansSc,
                  fontVariations: AppFonts.sourceHanSansScRegularWght400,
                  fontSize: 24,
                  height: 33 / 24,
                ),
              ),
            ),
            Positioned(
              // main-icons 是 288×288 完整母图。5/4/3 台布局分别使用
              // Figma 锚点，卡片自身裁掉超出部分，母图尺寸不变。
              left: artworkOffset.dx,
              top: artworkOffset.dy,
              width: 288,
              height: 288,
              child: Opacity(
                opacity: artworkOpacity,
                child: Image.asset(
                  artwork,
                  key: artworkKey,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              left: width - 104,
              top: 32,
              width: 80,
              height: 80,
              child: GestureDetector(
                key: powerKey,
                behavior: HitTestBehavior.opaque,
                onTap: onPowerTap,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Image.asset(
                      enabled
                          ? 'assets/home/figma_home/power_on.png'
                          : 'assets/home/figma_home/power_off.png',
                      fit: BoxFit.contain,
                    ),
                    if (busy)
                      const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatefulWidget {
  const _QuickAction({
    Key? key,
    required this.label,
    required this.width,
    required this.backgroundAsset,
    this.foregroundAsset,
    this.onTap,
  }) : super(key: key);

  final String label;
  final double width;
  final String backgroundAsset;
  final String? foregroundAsset;
  final VoidCallback? onTap;

  @override
  State<_QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<_QuickAction> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(AssetImage(widget.backgroundAsset), context);
    if (widget.foregroundAsset != null) {
      precacheImage(AssetImage(widget.foregroundAsset!), context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: SizedBox(
        width: widget.width,
        height: 188,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Image.asset(
                widget.backgroundAsset,
                key: ValueKey<String>(widget.backgroundAsset),
                fit: BoxFit.fill,
                gaplessPlayback: true,
              ),
            ),
            if (widget.foregroundAsset != null)
              Positioned(
                left: widget.width >= 413
                    ? 215
                    : widget.width >= 328
                        ? 164
                        : 129,
                top: 34,
                width: 120,
                height: 120,
                child: Image.asset(
                  widget.foregroundAsset!,
                  key: ValueKey<String>(widget.foregroundAsset!),
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                ),
              ),
            Positioned(
              left: 27,
              top: 46,
              child: Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: AppFonts.sourceHanSansSc,
                  fontVariations: AppFonts.sourceHanSansScBoldWght700,
                  fontSize: 36,
                  height: 48 / 36,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
