import 'package:flutter/material.dart';

import '../../../../../app/branding/brand_tokens.dart';

import 'inbound_contracts.dart';

class InboundErrorCard extends StatelessWidget {
  const InboundErrorCard({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            error.toString(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ],
      ),
    ),
  );
}

class InboundValue extends StatelessWidget {
  const InboundValue(this.label, this.value, {super.key});

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        SelectableText(
          inboundText(value),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    ),
  );
}

class InboundPanel extends StatelessWidget {
  const InboundPanel({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    ),
  );
}

class InboundScannerField extends StatelessWidget {
  const InboundScannerField({
    super.key,
    required this.controller,
    required this.label,
    this.maxLength = 100,
    this.enabled = true,
    this.validator,
    this.helperText,
  });

  final TextEditingController controller;
  final String label;
  final int maxLength;
  final bool enabled;
  final FormFieldValidator<String>? validator;
  final String? helperText;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      enabled: enabled,
      maxLength: maxLength,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      enableSuggestions: false,
      style: const TextStyle(fontFamily: AppBrand.monoFont, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.barcode_reader),
        helperText:
            helperText ?? 'Digite ou utilize um leitor externo conectado.',
        helperMaxLines: 3,
        counterText: '',
      ),
      validator:
          validator ??
          (value) => (value ?? '').trim().isEmpty ? 'Informe o código.' : null,
    ),
  );
}
