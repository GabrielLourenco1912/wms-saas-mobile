import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../branding/brand_mark.dart';
import '../branding/brand_tokens.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: BrandColors.ink,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const WmsBrandMark(size: 96, color: BrandColors.accent),
                const SizedBox(height: 18),
                Text(
                  AppBrand.name,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: BrandColors.inverseText,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  AppBrand.tagline,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: BrandColors.inverseMuted),
                ),
                const SizedBox(height: 24),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: BrandColors.accent,
                    strokeWidth: 2.6,
                    semanticsLabel: 'Carregando o WMS',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
