import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../app/branding/brand_tokens.dart';

typedef CodeScanLauncher = Future<String?> Function(BuildContext context);

/// Camera and HID input share the same string contract; leading zeros survive.
class CodeScanField extends StatefulWidget {
  const CodeScanField({
    super.key,
    required this.controller,
    required this.label,
    this.enabled = true,
    this.maxLength = 100,
    this.helperText,
    this.validator,
    this.onChanged,
    this.scanLauncher,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final int maxLength;
  final String? helperText;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final CodeScanLauncher? scanLauncher;

  @override
  State<CodeScanField> createState() => _CodeScanFieldState();
}

class _CodeScanFieldState extends State<CodeScanField> {
  bool _opening = false;

  Future<void> _scan() async {
    if (_opening || !widget.enabled) return;
    setState(() => _opening = true);
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      final launcher = widget.scanLauncher;
      final pending = launcher != null
          ? launcher(context)
          : Navigator.of(context).push<String>(
              MaterialPageRoute(
                builder: (_) => CodeScannerPage(
                  label: widget.label,
                  maxLength: widget.maxLength,
                ),
              ),
            );
      final result = await pending;
      if (!mounted || !widget.enabled || result == null) return;
      final code = result.trim();
      if (code.isEmpty || code.length > widget.maxLength) {
        throw const FormatException(
          'O código lido está vazio ou é muito longo.',
        );
      }
      widget.controller.value = TextEditingValue(
        text: code,
        selection: TextSelection.collapsed(offset: code.length),
      );
      widget.onChanged?.call(code);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível ler o código. Tente novamente ou digite.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    enabled: widget.enabled,
    maxLength: widget.maxLength,
    textInputAction: TextInputAction.next,
    autocorrect: false,
    enableSuggestions: false,
    style: const TextStyle(fontFamily: AppBrand.monoFont, fontSize: 16),
    decoration: InputDecoration(
      labelText: widget.label,
      prefixIcon: const Icon(Icons.barcode_reader),
      suffixIcon: IconButton(
        tooltip: 'Ler ${widget.label} com câmera',
        onPressed: widget.enabled && !_opening ? _scan : null,
        icon: const Icon(Icons.camera_alt_outlined),
      ),
      helperText:
          widget.helperText ??
          'Digite, utilize um leitor conectado ou abra a câmera.',
      helperMaxLines: 3,
      counterText: '',
    ),
    validator:
        widget.validator ??
        (value) => (value ?? '').trim().isEmpty ? 'Informe o código.' : null,
    onChanged: widget.onChanged,
  );
}

class CodeScannerPage extends StatefulWidget {
  const CodeScannerPage({
    super.key,
    required this.label,
    required this.maxLength,
  });
  final String label;
  final int maxLength;

  @override
  State<CodeScannerPage> createState() => _CodeScannerPageState();
}

class _CodeScannerPageState extends State<CodeScannerPage> {
  bool _accepted = false;
  String? _error;

  void _detect(BarcodeCapture capture) {
    if (_accepted || !mounted) return;
    final codes = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim())
        .whereType<String>()
        .where((code) => code.isNotEmpty)
        .toSet();
    if (codes.length != 1) {
      if (codes.length > 1) {
        setState(() => _error = 'Aponte para apenas uma etiqueta.');
      }
      return;
    }
    final code = codes.single;
    if (code.length > widget.maxLength) {
      setState(
        () => _error = 'Código maior que ${widget.maxLength} caracteres.',
      );
      return;
    }
    _accepted = true;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Ler ${widget.label}')),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            // The widget owns its controller and manages camera lifecycle/disposal.
            child: MobileScanner(
              onDetect: _detect,
              onDetectError: (error, stackTrace) {
                if (mounted && !_accepted) {
                  setState(
                    () => _error =
                        'Não foi possível reconhecer a etiqueta. Tente novamente ou volte para digitar.',
                  );
                }
              },
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.no_photography_outlined, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Câmera indisponível ou sem permissão. Autorize nas configurações do Android ou volte para digitar o código.',
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Voltar para digitar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _error ??
                  'Aponte para uma etiqueta de produto, LPN ou posição. A leitura preenche o campo; confirme os demais dados da operação.',
            ),
          ),
        ],
      ),
    ),
  );
}
