import 'package:flutter/material.dart';
import 'logo_with_text.dart';

class AuthLogoHeader extends StatelessWidget {
  const AuthLogoHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Orange wave background
        SizedBox(
          width: double.infinity,
          height: 300,
          child: CustomPaint(
            painter: WavePainter(),
          ),
        ),
        
        // Logo centered with text
        Positioned(
          top: 100,
          child: const LogoWithText(
            logoSize: 120,
            fontSize: 32,
          ),
        ),
      ],
    );
  }
}

class WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    final path = Path();
    
    // Starting point (top-left)
    path.moveTo(0, 0);
    
    // Draw line to bottom-left with some padding
    path.lineTo(0, size.height * 0.8);
    
    // Draw curve
    path.quadraticBezierTo(
      size.width * 0.5, // Control point x
      size.height * 1.2, // Control point y
      size.width,      // End point x
      size.height * 0.8, // End point y
    );
    
    // Draw line to top-right
    path.lineTo(size.width, 0);
    
    // Close the path
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
} 