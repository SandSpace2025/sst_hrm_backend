import 'package:flutter/material.dart';

class OfflineIndicatorWidget extends StatelessWidget {
  final String message;
  final double? iconSize;
  final double? fontSize;

  const OfflineIndicatorWidget({
    super.key,
    this.message = 'No internet connection',
    this.iconSize,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final size = iconSize ?? 80.0;
    final textSize = fontSize ?? 18.0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [

            Stack(
              alignment: Alignment.center,
              children: [

                Icon(
                  Icons.cloud,
                  size: size,
                  color: Colors.grey[400],
                ),

                CustomPaint(
                  size: Size(size, size),
                  painter: StrikeThroughPainter(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Text(
              message,
              style: TextStyle(
                fontSize: textSize,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class StrikeThroughPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;


    final padding = size.width * 0.1;
    canvas.drawLine(
      Offset(padding, padding),
      Offset(size.width - padding, size.height - padding),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

