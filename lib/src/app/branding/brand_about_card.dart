import 'package:flutter/material.dart';

import 'author_credit.dart';
import 'brand_mark.dart';
import 'brand_tokens.dart';

/// Crédito do projeto separado dos dados da pessoa conectada.
class BrandAboutCard extends StatelessWidget {
  const BrandAboutCard({super.key});

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      leading: const WmsBrandMark(size: 32),
      title: const Text('Sobre o WMS'),
      childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppBrand.name, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text('${AppBrand.descriptor}. ${AppBrand.tagline}'),
        const SizedBox(height: 24),
        const AuthorCredit(showPortfolioAction: true),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: AppBrand.name,
            applicationIcon: const WmsBrandMark(size: 48),
          ),
          icon: const Icon(Icons.description_outlined, size: 20),
          label: const Text('Licenças do aplicativo'),
        ),
      ],
    ),
  );
}
