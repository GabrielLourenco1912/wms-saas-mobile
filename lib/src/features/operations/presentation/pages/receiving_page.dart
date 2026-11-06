import '../../../../core/diagnostics/feedback_probe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/application/auth_controller.dart';
import '../../application/operation_command.dart';
import '../../data/warehouse_repository.dart';
import '../widgets/api_operation_widgets.dart';
import 'inbound/inbound_contracts.dart';
import 'inbound/inbound_view_helpers.dart';

class ReceivingPage extends ConsumerWidget {
  const ReceivingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ApiResourceListPage(
    title: 'Recebimento',
    resource: 'receipts',
    permission: 'RECEIPT_VIEW',
    searchHint: 'Pesquisar documento ou ID',
    statuses: const ['PENDENTE', 'EM_RECEBIMENTO', 'ATENDIDO', 'CANCELADO'],
    titleBuilder: (row) => 'Documento ${inboundText(row['documentNumber'])}',
    subtitleBuilder: (row) =>
        '${inboundStatus(row['status'])}\nPrevisão: ${inboundText(row['expectedAt'])}',
    onOpen: (context, ref, row) async {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => _ReceiptDetailPage(id: row['id'].toString()),
        ),
      );
    },
  );
}

class _ReceiptDetailPage extends ConsumerStatefulWidget {
  const _ReceiptDetailPage({required this.id});

  final String id;

  @override
  ConsumerState<_ReceiptDetailPage> createState() => _ReceiptDetailPageState();
}

class _ReceiptDetailPageState extends ConsumerState<_ReceiptDetailPage> {
  late Future<JsonMap> _detail;

  @override
  void initState() {
    super.initState();
    _detail = ref
        .read(warehouseRepositoryProvider)
        .detail('receipts', widget.id);
  }

  Future<void> _reload() async {
    final next = ref
        .read(warehouseRepositoryProvider)
        .detail('receipts', widget.id);
    setState(() {
      _detail = next;
    });
    try {
      await next;
    } catch (_) {
      /* FutureBuilder renders the query failure. */
    }
  }

  Future<void> _confirm(JsonMap receipt, JsonMap item) async {
    final result = await Navigator.of(context).push<JsonMap>(
      MaterialPageRoute(
        builder: (_) => _ReceiptConfirmationPage(receipt: receipt, item: item),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _detail = ref
          .read(warehouseRepositoryProvider)
          .detail('receipts', widget.id);
    });
    final confirmation = result['confirmation'] is Map
        ? result['confirmation'] as Map
        : const {};
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Conferência registrada. LPN ${inboundText(confirmation['lpnCode'])} disponível para putaway.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canExecute =
        ref.watch(authControllerProvider).value?.can('RECEIPT_EXECUTE') ??
        false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conferir recebimento'),
        actions: [
          IconButton(
            onPressed: () => setState(() {
              _detail = ref
                  .read(warehouseRepositoryProvider)
                  .detail('receipts', widget.id);
            }),
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<JsonMap>(
          future: _detail,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  InboundErrorCard(
                    error: snapshot.error!,
                    onRetry: () => setState(() {
                      _detail = ref
                          .read(warehouseRepositoryProvider)
                          .detail('receipts', widget.id);
                    }),
                  ),
                ],
              );
            }
            final data = snapshot.data ?? const <String, dynamic>{};
            final receipt = data['receipt'] is Map
                ? JsonMap.from(data['receipt'] as Map)
                : <String, dynamic>{};
            final items = inboundMaps(data['items']);
            final confirmations = inboundMaps(data['confirmations']);
            final pending = [
              'PENDENTE',
              'EM_RECEBIMENTO',
            ].contains(receipt['status']);
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  InboundPanel(
                    title:
                        'Documento ${inboundText(receipt['documentNumber'])}',
                    children: [
                      InboundValue(
                        'Situação',
                        inboundStatus(receipt['status']),
                      ),
                      InboundValue('Armazém', receipt['warehouseId']),
                      InboundValue('Fornecedor', receipt['partnerId']),
                      const SizedBox(height: 8),
                      const Text(
                        'Confira cada item na doca de recebimento. A embalagem converte a quantidade informada para a unidade base do produto.',
                      ),
                    ],
                  ),
                  if (!canExecute)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Seu perfil permite consultar este recebimento. A conferência exige permissão de execução.',
                      ),
                    ),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Este documento não possui itens.'),
                    ),
                  for (final item in items)
                    InboundPanel(
                      title:
                          '${inboundText(item['sku'])} · ${inboundText(item['productName'])}',
                      children: [
                        InboundValue(
                          'Esperado em unidade base',
                          item['requestedQuantity'],
                        ),
                        InboundValue('Conferido', item['fulfilledQuantity']),
                        InboundValue('Restante', item['remainingQuantity']),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed:
                              canExecute &&
                                  pending &&
                                  (num.tryParse(
                                            '${item['remainingQuantity']}',
                                          ) ??
                                          0) >
                                      0
                              ? () => _confirm(receipt, item)
                              : null,
                          icon: const Icon(Icons.barcode_reader),
                          label: const Text('Conferir item'),
                        ),
                      ],
                    ),
                  InboundPanel(
                    title: 'Conferências registradas (${confirmations.length})',
                    children: [
                      if (confirmations.isEmpty)
                        const Text('Nenhuma conferência registrada.'),
                      for (final confirmation in confirmations) ...[
                        InboundValue('LPN', confirmation['lpnCode']),
                        InboundValue(
                          'Quantidade base / doca',
                          '${inboundText(confirmation['baseQuantity'])} · ${inboundText(confirmation['positionCode'])}',
                        ),
                        if (confirmation['lot'] != null)
                          InboundValue('Lote', confirmation['lot']),
                        if (confirmation['expiryDate'] != null)
                          InboundValue('Validade', confirmation['expiryDate']),
                        const Divider(),
                      ],
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ReceiptConfirmationPage extends ConsumerStatefulWidget {
  const _ReceiptConfirmationPage({required this.receipt, required this.item});

  final JsonMap receipt;
  final JsonMap item;

  @override
  ConsumerState<_ReceiptConfirmationPage> createState() =>
      _ReceiptConfirmationPageState();
}

class _ReceiptConfirmationPageState
    extends ConsumerState<_ReceiptConfirmationPage> {
  final _form = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _lot = TextEditingController();
  final _lpn = TextEditingController();
  final _scannedProduct = TextEditingController();
  final _scannedLpn = TextEditingController();
  final _scannedPosition = TextEditingController();
  late Future<JsonMap> _product;
  LookupOption? _packaging;
  LookupOption? _dock;
  DateTime? _expiry;
  Object? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _product = ref
        .read(warehouseRepositoryProvider)
        .detail('products', widget.item['productId'].toString());
  }

  @override
  void dispose() {
    for (final controller in [
      _quantity,
      _lot,
      _lpn,
      _scannedProduct,
      _scannedLpn,
      _scannedPosition,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? get _expiryDate => _expiry == null
      ? null
      : '${_expiry!.year.toString().padLeft(4, '0')}-${_expiry!.month.toString().padLeft(2, '0')}-${_expiry!.day.toString().padLeft(2, '0')}';

  Future<void> _chooseExpiry() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = await showDatePicker(
      context: context,
      initialDate: _expiry ?? today.add(const Duration(days: 1)),
      firstDate: DateTime(1900),
      lastDate: DateTime(today.year + 50),
    );
    if (mounted && selected != null) {
      setState(() {
        _expiry = selected;
      });
    }
  }

  Future<void> _submit(JsonMap product) async {
    if (_submitting || !(_form.currentState?.validate() ?? false)) return;
    if (product['expiryControlled'] == true && _expiry == null) {
      setState(() {
        _error = 'Informe a data de validade do produto.';
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(operationCommandProvider)
          .run(
            '/api/receipts/${widget.receipt['id']}/confirm',
            body: {
              'orderItemId': widget.item['id'],
              'packagingId': _packaging!.id,
              'quantity': num.parse(_quantity.text.trim().replaceAll(',', '.')),
              'lot': _lot.text.trim().isEmpty ? null : _lot.text.trim(),
              'expiryDate': _expiryDate,
              'lpnCode': _lpn.text.trim(),
              'positionId': _dock!.id,
              'scannedProductCode': _scannedProduct.text.trim(),
              'scannedLpnCode': _scannedLpn.text.trim(),
              'scannedPositionCode': _scannedPosition.text.trim(),
            },
          );
      if (mounted) {
        Navigator.of(context).pop(result);
        FeedbackProbe.rendered('confirmed');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
        });
        FeedbackProbe.rendered('rejected');
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canExecute =
        ref.watch(authControllerProvider).value?.can('RECEIPT_EXECUTE') ??
        false;
    return PopScope(
      canPop: !_submitting,
      child: Scaffold(
        appBar: AppBar(title: const Text('Registrar conferência')),
        body: SafeArea(
          child: FutureBuilder<JsonMap>(
            future: _product,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    InboundErrorCard(
                      error: snapshot.error!,
                      onRetry: () => setState(() {
                        _product = ref
                            .read(warehouseRepositoryProvider)
                            .detail(
                              'products',
                              widget.item['productId'].toString(),
                            );
                      }),
                    ),
                  ],
                );
              }
              final product = snapshot.data ?? const <String, dynamic>{};
              return Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    InboundPanel(
                      title:
                          '${inboundText(widget.item['sku'])} · ${inboundText(widget.item['productName'])}',
                      children: [
                        InboundValue(
                          'Quantidade restante na unidade base',
                          '${inboundText(widget.item['remainingQuantity'])} ${inboundText(product['baseUnit'], fallback: '')}',
                        ),
                        const Text(
                          'Informe quantas embalagens foram recebidas. O saldo é atualizado somente após a confirmação da API.',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ApiLookupField(
                      resource: 'product-packages',
                      label: 'Embalagem do produto',
                      value: _packaging,
                      filters: {
                        'productId': widget.item['productId'].toString(),
                        'active': 'true',
                      },
                      enabled: !_submitting && canExecute,
                      isRequired: true,
                      helperText:
                          'O fator de conversão aparece ao lado do tipo da embalagem.',
                      onChanged: (value) => setState(() {
                        _packaging = value;
                      }),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _quantity,
                      enabled: !_submitting && canExecute,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Quantidade de embalagens',
                        helperText:
                            'Aceita até 6 casas decimais. Não informe a quantidade convertida.',
                      ),
                      validator: inboundQuantityError,
                    ),
                    const SizedBox(height: 20),
                    ApiLookupField(
                      resource: 'positions',
                      label: 'Doca de recebimento',
                      value: _dock,
                      filters: {
                        'warehouseId': widget.receipt['warehouseId'].toString(),
                        'purpose': 'RECEBIMENTO',
                        'active': 'true',
                      },
                      enabled: !_submitting && canExecute,
                      isRequired: true,
                      onChanged: (value) => setState(() {
                        _dock = value;
                      }),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _lot,
                      enabled: !_submitting && canExecute,
                      maxLength: 100,
                      decoration: InputDecoration(
                        labelText: product['lotControlled'] == true
                            ? 'Lote obrigatório'
                            : 'Lote (opcional)',
                        counterText: '',
                      ),
                      validator: (value) =>
                          product['lotControlled'] == true &&
                              (value ?? '').trim().isEmpty
                          ? 'Informe o lote.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: !_submitting && canExecute
                          ? _chooseExpiry
                          : null,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        _expiryDate ??
                            (product['expiryControlled'] == true
                                ? 'Informar validade obrigatória'
                                : 'Informar validade (opcional)'),
                      ),
                    ),
                    if (_expiry != null)
                      TextButton(
                        onPressed: _submitting
                            ? null
                            : () => setState(() {
                                _expiry = null;
                              }),
                        child: const Text('Limpar validade'),
                      ),
                    const SizedBox(height: 20),
                    InboundScannerField(
                      controller: _lpn,
                      label: 'Código do LPN a receber',
                      enabled: !_submitting && canExecute,
                      helperText:
                          'Identifique o LPN. Use o mesmo código para adicionar conteúdo enquanto o putaway estiver pendente.',
                    ),
                    const Text(
                      'Conferência dos códigos',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    InboundScannerField(
                      controller: _scannedProduct,
                      label: 'Leitura do SKU ou barcode',
                      enabled: !_submitting && canExecute,
                    ),
                    InboundScannerField(
                      controller: _scannedLpn,
                      label: 'Leitura da etiqueta do LPN',
                      enabled: !_submitting && canExecute,
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Leia ou digite o código da etiqueta.';
                        }
                        if (value!.trim() != _lpn.text.trim()) {
                          return 'O código lido precisa corresponder ao LPN informado.';
                        }
                        return null;
                      },
                    ),
                    InboundScannerField(
                      controller: _scannedPosition,
                      label: 'Leitura do código da doca',
                      maxLength: 50,
                      enabled: !_submitting && canExecute,
                    ),
                    if (_error != null) InboundErrorCard(error: _error!),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: !_submitting && canExecute
                          ? () => _submit(product)
                          : null,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(
                        _submitting
                            ? 'Registrando conferência…'
                            : 'Confirmar recebimento',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Digite, utilize um leitor externo (HID) ou toque na câmera ao lado do campo.',
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
