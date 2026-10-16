import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/branding/brand_tokens.dart';
import '../../../data/warehouse_repository.dart';

typedef OperationDetailBuilder =
    Widget Function(
      BuildContext context,
      WidgetRef ref,
      JsonMap data,
      Future<void> Function() reload,
    );

/// Details always come from the API; successful commands refresh this snapshot.
class OperationDetailPage extends ConsumerStatefulWidget {
  const OperationDetailPage({
    super.key,
    required this.title,
    required this.resource,
    required this.id,
    required this.builder,
  });

  final String title;
  final String resource;
  final String id;
  final OperationDetailBuilder builder;

  @override
  ConsumerState<OperationDetailPage> createState() =>
      _OperationDetailPageState();
}

class _OperationDetailPageState extends ConsumerState<OperationDetailPage> {
  late Future<JsonMap> _detail;

  @override
  void initState() {
    super.initState();
    _detail = _load();
  }

  Future<JsonMap> _load() =>
      ref.read(warehouseRepositoryProvider).detail(widget.resource, widget.id);

  Future<void> _reload() async {
    final pending = _load();
    setState(() {
      _detail = pending;
    });
    try {
      try {
        await pending;
      } catch (_) {
        /* FutureBuilder renders the query failure. */
      }
    } catch (_) {
      /* FutureBuilder renders the failure. */
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: () => setState(() {
            _detail = _load();
          }),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: FutureBuilder<JsonMap>(
        future: _detail,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 36),
                    const SizedBox(height: 12),
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => setState(() {
                        _detail = _load();
                      }),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                widget.builder(context, ref, snapshot.requireData, _reload),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class OperationCommandPage extends StatefulWidget {
  const OperationCommandPage({
    super.key,
    required this.title,
    required this.description,
    required this.submitLabel,
    required this.fields,
    required this.submit,
    this.successMessage,
  });

  final String title;
  final String description;
  final String submitLabel;
  final List<Widget> Function(bool busy) fields;
  final Future<JsonMap> Function() submit;
  final String Function(JsonMap result)? successMessage;

  @override
  State<OperationCommandPage> createState() => _OperationCommandPageState();
}

class _OperationCommandPageState extends State<OperationCommandPage> {
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.submit();
      if (!mounted) return;
      final message =
          widget.successMessage?.call(result) ??
          'Operação confirmada pelo servidor.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(widget.description),
              const SizedBox(height: 20),
              ...widget.fields(_busy),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(_busy ? 'Confirmando…' : widget.submitLabel),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget operationField({
  required String label,
  required TextEditingController controller,
  bool enabled = true,
  bool isRequired = true,
  bool technical = false,
  int maxLength = 100,
  String? helper,
  String? Function(String?)? validator,
  TextInputType? keyboardType,
  ValueChanged<String>? onChanged,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 14),
  child: TextFormField(
    controller: controller,
    enabled: enabled,
    maxLength: maxLength,
    keyboardType: keyboardType,
    style: technical || keyboardType?.index == TextInputType.number.index
        ? const TextStyle(fontFamily: AppBrand.monoFont, fontSize: 16)
        : null,
    autocorrect: false,
    enableSuggestions: false,
    textInputAction: TextInputAction.next,
    decoration: InputDecoration(
      labelText: label,
      helperText: helper,
      helperMaxLines: 3,
      counterText: '',
    ),
    validator:
        validator ??
        (value) => isRequired && (value == null || value.trim().isEmpty)
            ? 'Informe $label.'
            : null,
    onChanged: onChanged,
  ),
);

String? validateOperationQuantity(String? value, {bool allowZero = false}) {
  final normalized = value?.trim().replaceAll(',', '.') ?? '';
  if (!RegExp(r'^\d{1,12}(\.\d{1,6})?$').hasMatch(normalized)) {
    return 'Informe uma quantidade com até 12 inteiros e 6 casas decimais.';
  }
  final quantity = num.tryParse(normalized);
  if (quantity == null || quantity < 0 || (!allowZero && quantity == 0)) {
    return allowZero
        ? 'A quantidade deve ser zero ou positiva.'
        : 'A quantidade deve ser maior que zero.';
  }
  // JSON encodes a num using its shortest round-trip representation. Refuse a
  // value whose representation would change the operator's decimal quantity.
  if (_scaledQuantity(normalized) != _scaledQuantity(quantity.toString())) {
    return 'Esta quantidade excede a precisão do dispositivo. Reduza as casas decimais.';
  }
  return null;
}

BigInt? _scaledQuantity(String value) {
  final scientific = value.toLowerCase().split('e');
  final parts = scientific[0].split('.');
  final fraction = parts.length == 1 ? '' : parts[1];
  final digits = BigInt.parse('${parts[0]}$fraction');
  final scale =
      6 +
      (scientific.length == 1 ? 0 : int.parse(scientific[1])) -
      fraction.length;
  if (scale >= 0) return digits * BigInt.from(10).pow(scale);
  final divisor = BigInt.from(10).pow(-scale);
  return digits.remainder(divisor) == BigInt.zero ? digits ~/ divisor : null;
}

num operationQuantity(String value) =>
    num.parse(value.trim().replaceAll(',', '.'));

String operationValue(JsonMap item, String key) =>
    item[key]?.toString() ?? 'Não informado';

List<JsonMap> operationItems(JsonMap data, [String key = 'items']) =>
    (data[key] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);

Widget operationFacts(Map<String, String> facts) => Card(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final fact in facts.entries) ...[
          Text(fact.key, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 2),
          SelectableText(
            fact.value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
        ],
      ],
    ),
  ),
);

Future<void> openOperationCommand(
  BuildContext context,
  Widget page,
  Future<void> Function() reload,
) async {
  final changed = await Navigator.of(
    context,
  ).push<bool>(MaterialPageRoute(builder: (_) => page));
  if (changed == true && context.mounted) {
    // Loading failures are rendered by the detail/list page, never reported as a
    // failed command after a successful server confirmation.
    try {
      await reload();
    } catch (_) {
      /* The owning page renders the error. */
    }
  }
}
