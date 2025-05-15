import 'package:flutter/material.dart';

class LogoWithText extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/logo.png',
          width: logoSize,
          height: logoSize,
          fit: BoxFit.contain,
        ),
        if (includeText) ...[
          const SizedBox(height: 10),
          Text(
            'Magic Home',
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }
} 