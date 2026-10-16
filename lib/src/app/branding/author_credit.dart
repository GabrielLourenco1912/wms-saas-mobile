import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'brand_tokens.dart';

class AuthorCredit extends StatelessWidget {
  const AuthorCredit({super.key, this.showPortfolioAction = false});

  final bool showPortfolioAction;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Semantics(
        label: '${AppBrand.authorLabel} ${AppBrand.authorName}',
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(AppBrand.authorLight, width: 32, height: 32),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppBrand.authorLabel,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    AppBrand.authorName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (showPortfolioAction) ...[
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(
              const ClipboardData(text: AppBrand.portfolio),
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link do portfólio copiado.')),
              );
            }
          },
          icon: const Icon(Icons.copy_outlined, size: 20),
          label: const Text('Copiar link do portfólio'),
        ),
      ],
    ],
  );
}
