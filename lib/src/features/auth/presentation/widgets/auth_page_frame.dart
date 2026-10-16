import 'package:flutter/material.dart';

import '../../../../app/branding/author_credit.dart';
import '../../../../app/branding/brand_mark.dart';
import '../../../../app/branding/brand_tokens.dart';

class AuthPageFrame extends StatelessWidget {
  const AuthPageFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(color: BrandColors.background),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth > 620
                  ? 460.0
                  : constraints.maxWidth - 32;

              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: BrandColors.ink,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: WmsBrandMark(
                                  size: 44,
                                  color: BrandColors.accent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppBrand.name,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: BrandColors.text,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Operação mobile de armazém',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: BrandColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  title,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: BrandColors.text,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  subtitle,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: BrandColors.muted,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                child,
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        footer,
                        const SizedBox(height: 24),
                        const Center(child: AuthorCredit()),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
