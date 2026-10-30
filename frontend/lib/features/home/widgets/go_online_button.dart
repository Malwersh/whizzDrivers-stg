import 'package:flutter/material.dart';

/// A map action that follows the draggable home panel.
class GoOnlineButton extends StatefulWidget {
  const GoOnlineButton(
      {super.key, required this.busy, required this.onPressed});
  final bool busy;
  final VoidCallback onPressed;

  @override
  State<GoOnlineButton> createState() => _GoOnlineButtonState();
}

class _GoOnlineButtonState extends State<GoOnlineButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathing = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAnimation();
  }

  @override
  void didUpdateWidget(covariant GoOnlineButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateAnimation();
  }

  void _updateAnimation() {
    if (widget.busy || MediaQuery.disableAnimationsOf(context)) {
      _breathing.stop();
      _breathing.value = 0.5;
    } else if (!_breathing.isAnimating) {
      _breathing.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breathing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const ink = Colors.white;
    return SizedBox.square(
      dimension: 80,
      child: Material(
        color: const Color(0xFF00296B),
        shape: const CircleBorder(),
        elevation: 5,
        shadowColor: Colors.black26,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: widget.busy ? null : widget.onPressed,
          child: Semantics(
            button: true,
            enabled: !widget.busy,
            label: widget.busy ? 'جارٍ بدء استقبال الطلبات' : 'انطلق',
            excludeSemantics: true,
            child: Stack(alignment: Alignment.center, children: [
              AnimatedBuilder(
                animation: _breathing,
                builder: (context, _) => Transform.scale(
                  scale:
                      0.88 + Curves.easeInOut.transform(_breathing.value) * 0.1,
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: ink, width: 1.6),
                    ),
                  ),
                ),
              ),
              if (widget.busy)
                const SizedBox.square(
                  dimension: 24,
                  child:
                      CircularProgressIndicator(strokeWidth: 2.5, color: ink),
                )
              else
                const Text('انطلق',
                    style: TextStyle(
                      color: ink,
                      fontSize: 18,
                      fontWeight: FontWeight.normal,
                    )),
            ]),
          ),
        ),
      ),
    );
  }
}
