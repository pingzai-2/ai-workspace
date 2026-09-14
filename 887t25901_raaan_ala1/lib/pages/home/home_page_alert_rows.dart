part of 'home_page.dart';

class _AlertListRow extends StatelessWidget {
  const _AlertListRow({
    Key? key,
    required this.item,
    required this.isFault,
    required this.onConfirm,
  }) : super(key: key);

  final DashboardAlertItem item;
  final bool isFault;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 900,
      height: 146,
      child: ColoredBox(
        color: const Color(0xFF282828),
        child: Stack(
          children: <Widget>[
            if (isFault)
              const Positioned(
                left: 72,
                top: 33,
                width: 80,
                height: 80,
                child: Image(
                  image: AssetImage('assets/home/alerts/error.png'),
                  fit: BoxFit.contain,
                ),
              ),
            Positioned(
              left: isFault ? 184 : 34,
              top: 17,
              right: isFault ? 180 : 330,
              height: 52,
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xE6FFFFFF),
                  fontFamily: AppFonts.sourceHanSansSc,
                  fontVariations: AppFonts.sourceHanSansScRegularWght400,
                  fontSize: 36,
                  height: 1.448,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            Positioned(
              left: isFault ? 184 : 34,
              top: 76,
              right: isFault ? 180 : 330,
              height: 41,
              child: Text(
                item.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0x99FFFFFF),
                  fontFamily: AppFonts.sourceHanSansSc,
                  fontVariations: AppFonts.sourceHanSansScRegularWght400,
                  fontSize: 28,
                  height: 1.448,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            Positioned(
              left: isFault ? 738 : 585,
              top: 56,
              width: 126,
              height: 35,
              child: Text(
                item.date,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0x80FFFFFF),
                  fontFamily: AppFonts.sourceHanSansSc,
                  fontVariations: AppFonts.sourceHanSansScRegularWght400,
                  fontSize: 24,
                  height: 1.448,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            if (!isFault)
              Positioned(
                left: 768,
                top: 49,
                width: 96,
                height: 48,
                child: _NotificationConfirmButton(
                  key: ValueKey<String>('notification-confirm-${item.id}'),
                  onPressed: onConfirm!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationConfirmButton extends StatefulWidget {
  const _NotificationConfirmButton({
    Key? key,
    required this.onPressed,
  }) : super(key: key);

  final VoidCallback onPressed;

  @override
  State<_NotificationConfirmButton> createState() =>
      _NotificationConfirmButtonState();
}

class _NotificationConfirmButtonState
    extends State<_NotificationConfirmButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) {
        _setPressed(false);
        widget.onPressed();
      },
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image(
            image: AssetImage(
              _pressed
                  ? 'assets/home/alerts/confirm-press.png'
                  : 'assets/home/alerts/confirm.png',
            ),
            fit: BoxFit.fill,
          ),
          Center(
            child: Transform.translate(
              key: const ValueKey<String>('notification-confirm-label-offset'),
              offset: const Offset(0, -3),
              child: Text(
                AppLocalizations.of(context).confirm,
                key: const ValueKey<String>('notification-confirm-label'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: AppFonts.sourceHanSansSc,
                  fontVariations: AppFonts.sourceHanSansScRegularWght400,
                  fontSize: 20,
                  height: 1.3,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaultServiceRow extends StatelessWidget {
  const _FaultServiceRow({required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey<String>('fault-service-row'),
      width: 900,
      height: 146,
      child: ColoredBox(
        color: const Color(0xFF282828),
        child: Stack(
          children: <Widget>[
            const Positioned(
              left: 72,
              top: 33,
              width: 80,
              height: 80,
              child: Image(
                image: AssetImage('assets/home/alerts/service-tel.png'),
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              left: 184,
              top: 47,
              width: 144,
              height: 52,
              child: Text(
                AppLocalizations.of(context).contactSupport,
                style: const TextStyle(
                  color: Color(0xE6FFFFFF),
                  fontFamily: AppFonts.sourceHanSansSc,
                  fontVariations: AppFonts.sourceHanSansScRegularWght400,
                  fontSize: 36,
                  height: 1.448,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            Positioned(
              left: 564,
              top: 38,
              width: 300,
              height: 70,
              child: Text(
                phone,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xE6FFFFFF),
                  fontFamily: AppFonts.sourceHanSansSc,
                  fontVariations: AppFonts.sourceHanSansScRegularWght400,
                  fontSize: 48,
                  height: 1.448,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
