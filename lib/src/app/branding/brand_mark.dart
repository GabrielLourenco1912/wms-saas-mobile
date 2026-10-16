import 'package:flutter/material.dart';

import 'brand_tokens.dart';

/// A mesma silhueta vetorial do web, sem fonte ou dependência de SVG.
class WmsBrandMark extends StatelessWidget {
  const WmsBrandMark({
    super.key,
    this.size = 40,
    this.color = BrandColors.primary,
    this.semanticLabel,
  });

  final double size;
  final Color color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    image: semanticLabel != null,
    excludeSemantics: true,
    child: CustomPaint(
      size: Size.square(size),
      painter: _BrandMarkPainter(color),
    ),
  );
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 128, size.height / 128);
    canvas.drawPath(createBrandSymbolPath(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BrandMarkPainter oldDelegate) =>
      color != oldDelegate.color;
}
