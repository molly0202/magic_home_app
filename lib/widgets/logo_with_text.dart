import 'package:flutter/material.dart';

class LogoWithText extends StatefulWidget {
  final double logoSize;
  final double fontSize;
  final bool includeText;

  const LogoWithText({
    super.key,
    this.logoSize = 80.0,
    this.fontSize = 32.0,
    this.includeText = true,
  });

  @override
  State<LogoWithText> createState() => _LogoWithTextState();
}

class _LogoWithTextState extends State<LogoWithText> {
  bool _isImageLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheImage();
  }

  Future<void> _precacheImage() async {
    await precacheImage(
      const AssetImage('assets/images/logo.png'),
      context,
    );
    if (mounted) {
      setState(() {
        _isImageLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isImageLoaded
              ? Image.asset(
                  'assets/images/logo.png',
                  width: widget.logoSize,
                  height: widget.logoSize,
                  fit: BoxFit.contain,
                )
              : Container(
                  width: widget.logoSize,
                  height: widget.logoSize,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
        ),
        if (widget.includeText) ...[
          const SizedBox(height: 10),
          Text(
            'Magic Home',
            style: TextStyle(
              color: Colors.white,
              fontSize: widget.fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }
} 