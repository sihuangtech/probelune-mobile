import 'package:flutter/material.dart';

class BrandIcon extends StatelessWidget {
  const BrandIcon({super.key, this.size = 54});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .22),
    child: Image.asset(
      'assets/branding/app-icon.png',
      width: size,
      height: size,
      semanticLabel: 'Probelune',
    ),
  );
}
