import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/application/auth_controller.dart';
import '../../application/operation_command.dart';
import '../../data/warehouse_repository.dart';
import '../widgets/api_operation_widgets.dart';
import 'inbound/inbound_contracts.dart';
import 'inbound/inbound_view_helpers.dart';
import 'outbound/operation_flow_widgets.dart';
import 'stock/transfer_contracts.dart';

class TransfersPage extends ConsumerStatefulWidget {
  const TransfersPage({super.key});

  @override
  ConsumerState<TransfersPage> createState() => _TransfersPageState();
}

class _TransfersPageState extends ConsumerState<TransfersPage> {
  int _revision = 0;

  Future<void> _create() async {
    final task = await Navigator.of(context).push<JsonMap>(
      MaterialPageRoute(builder: (_) => const _CreateTransferPage()),
    );
    if (!mounted || task == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _TransferDetailPage(id: task['id'].toString()),
      ),
    );
    if (mounted) {
      setState(() {
        _revision++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canExecute =
        ref.watch(authControllerProvider).value?.can('TRANSFER_EXECUTE') ??
        false;
    return ApiResourceListPage(
      key: ValueKey(_revision),
      title: 'Transferências',
      resource: 'transfers',
      permission: 'TRANSFER_VIEW',
      searchHint: 'Pesquisar tarefa, tipo, situação ou motivo',
      statuses: const ['PENDENTE', 'CONCLUIDA', 'CANCELADA'],
      titleBuilder: (task) => 'Transferência ${inboundText(task['id'])}',
      subtitleBuilder: (task) =>
          '${inboundStatus(task['status'])} · Quantidade ${inboundText(task['targetQuantity'])}\n${task['sourceStockId'] == null ? 'LPN integral' : 'Saldo de um produto'}',
      actions: [
        if (canExecute)
          IconButton(
            tooltip: 'Planejar transferência',
            icon: const Icon(Icons.add),
            onPressed: _create,
          ),
      ],
      onOpen: (context, ref, task) async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => _TransferDetailPage(id: task['id'].toString()),
          ),
        );
      },
    );
  }
}

class _TransferDetailPage extends ConsumerWidget {
  const _TransferDetailPage({required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OperationDetailPage(
    title: 'Detalhe da transferência',
    resource: 'transfers',
    id: id,
    builder: (context, ref, task, reload) =>
        _TransferSummary(task: task, reload: reload),
  );
}

class _TransferSummary extends ConsumerStatefulWidget {
  const _TransferSummary({required this.task, required this.reload});
  final JsonMap task;
  final Future<void> Function() reload;

  @override
  ConsumerState<_TransferSummary> createState() => _TransferSummaryState();
}

class _TransferSummaryState extends ConsumerState<_TransferSummary> {
  late Future<JsonMap> _references;

  @override
  void initState() {
    super.initState();
    _references = _loadReferences();
  }

  Future<JsonMap> _loadReferences() async {
    final repository = ref.read(warehouseRepositoryProvider);
    final auth = ref.read(authControllerProvider).value;
    final result = <String, dynamic>{};
    final requests = <Future<void>>[];
    if (auth?.can('STOCK_VIEW') ?? false) {
      requests.add(
        repository.detail('lpns', widget.task['lpnId'].toString()).then<void>((
          value,
        ) {
          result['lpn'] = value;
        }),
      );
    }
    if (auth?.can('WAREHOUSE_VIEW') ?? false) {
      requests.add(
        repository
            .detail('positions', widget.task['originPositionId'].toString())
            .then<void>((value) {
              result['origin'] = value;
            }),
      );
      requests.add(
        repository
            .detail(
              'positions',
              widget.task['destinationPositionId'].toString(),
            )
            .then<void>((value) {
              result['destination'] = value;
            }),
      );
    }
    if (widget.task['productId'] != null &&
        (auth?.can('PRODUCT_VIEW') ?? false)) {
      requests.add(
        repository
            .detail('products', widget.task['productId'].toString())
            .then<void>((value) {
              result['product'] = value;
            }),
      );
    }
    await Future.wait(requests);
    return result;
  }

  Future<void> _confirm(JsonMap references) async {
    final quantity = TextEditingController();
    final lpn = TextEditingController();
    final origin = TextEditingController();
    final destination = TextEditingController();
    final product = TextEditingController();
    final wholeLpn = widget.task['sourceStockId'] == null;
    try {
      await openOperationCommand(
        context,
        OperationCommandPage(
          title: 'Confirmar transferência',
          description:
              'Confira fisicamente o LPN, a origem e o destino. ${wholeLpn ? 'Esta operação move o LPN inteiro.' : 'Informe o SKU do produto e a quantidade efetivamente movida.'} A API rejeita uma origem alterada desde o planejamento.',
          submitLabel: 'Executar transferência',
          fields: (busy) => [
            InboundPanel(
              title: 'Planejamento',
              children: [
                InboundValue(
                  'LPN esperado',
                  (references['lpn'] as Map?)?['trackingCode'] ??
                      widget.task['lpnId'],
                ),
                InboundValue(
                  'Origem',
                  (references['origin'] as Map?)?['code'] ??
                      widget.task['originPositionId'],
                ),
                InboundValue(
                  'Destino',
                  (references['destination'] as Map?)?['code'] ??
                      widget.task['destinationPositionId'],
                ),
                InboundValue(
                  wholeLpn
                      ? 'Quantidade integral'
                      : 'Quantidade máxima planejada',
                  widget.task['targetQuantity'],
                ),
              ],
            ),
            const SizedBox(height: 12),
            operationField(
              label: 'Quantidade efetivamente movida',
              controller: quantity,
              enabled: !busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) => transferQuantityError(
                value,
                widget.task['targetQuantity'],
                wholeLpn: wholeLpn,
              ),
            ),
            InboundScannerField(
              controller: lpn,
              label: 'Leitura do LPN de origem',
              enabled: !busy,
            ),
            InboundScannerField(
              controller: origin,
              label: 'Leitura da posição de origem',
              maxLength: 50,
              enabled: !busy,
            ),
            InboundScannerField(
              controller: destination,
              label: 'Leitura da posição de destino',
              maxLength: 50,
              enabled: !busy,
            ),
            if (!wholeLpn)
              InboundScannerField(
                controller: product,
                label: 'Leitura do SKU do produto',
                maxLength: 50,
                enabled: !busy,
                helperText:
                    'Na transferência por saldo, a API exige o SKU, não o barcode da embalagem.',
              ),
          ],
          submit: () => ref
              .read(operationCommandProvider)
              .run(
                '/api/transfers/${widget.task['id']}/confirm',
                body: {
                  'actualQuantity': wholeLpn
                      ? widget.task['targetQuantity']
                      : operationQuantity(quantity.text),
                  'scannedLpnCode': lpn.text.trim(),
                  'scannedOriginCode': origin.text.trim(),
                  'scannedDestinationCode': destination.text.trim(),
                  if (!wholeLpn) 'scannedProductCode': product.text.trim(),
                },
              ),
        ),
        widget.reload,
      );
    } finally {
      for (final controller in [quantity, lpn, origin, destination, product]) {
        controller.dispose();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canExecute =
        ref.watch(authControllerProvider).value?.can('TRANSFER_EXECUTE') ??
        false;
    return FutureBuilder<JsonMap>(
      future: _references,
      builder: (context, snapshot) {
        final refs = snapshot.data ?? const <String, dynamic>{};
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InboundPanel(
              title: widget.task['sourceStockId'] == null
                  ? 'LPN integral'
                  : 'Transferência por saldo',
              children: [
                InboundValue('Situação', inboundStatus(widget.task['status'])),
                InboundValue(
                  'LPN',
                  (refs['lpn'] as Map?)?['trackingCode'] ??
                      widget.task['lpnId'],
                ),
                InboundValue(
                  'Origem',
                  (refs['origin'] as Map?)?['code'] ??
                      widget.task['originPositionId'],
                ),
                InboundValue(
                  'Destino',
                  (refs['destination'] as Map?)?['code'] ??
                      widget.task['destinationPositionId'],
                ),
                if (widget.task['productId'] != null)
                  InboundValue(
                    'Produto',
                    (refs['product'] as Map?)?['sku'] ??
                        widget.task['productId'],
                  ),
                if (widget.task['destinationLpnId'] != null)
                  InboundValue(
                    'LPN de destino',
                    widget.task['destinationLpnId'],
                  ),
                InboundValue(
                  'Quantidade planejada',
                  widget.task['targetQuantity'],
                ),
                InboundValue(
                  'Quantidade executada',
                  widget.task['actualQuantity'],
                ),
                InboundValue('Criada em', widget.task['createdAt']),
                InboundValue('Concluída em', widget.task['completedAt']),
                if (widget.task['cancellationReason'] != null)
                  InboundValue(
                    'Motivo do cancelamento',
                    widget.task['cancellationReason'],
                  ),
              ],
            ),
            if (snapshot.connectionState == ConnectionState.waiting)
              const LinearProgressIndicator(),
            if (snapshot.hasError)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Não foi possível carregar todos os códigos de referência. Os identificadores do planejamento estão disponíveis acima.',
                ),
              ),
            if (canExecute && widget.task['status'] == 'PENDENTE')
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: FilledButton.icon(
                  onPressed: () => _confirm(refs),
                  icon: const Icon(Icons.barcode_reader),
                  label: const Text('Conferir e executar'),
                ),
              ),
          ],
        );
      },
    );
  }
}

enum _TransferMode { wholeLpn, stock }

class _CreateTransferPage extends ConsumerStatefulWidget {
  const _CreateTransferPage();

  @override
  ConsumerState<_CreateTransferPage> createState() =>
      _CreateTransferPageState();
}

class _CreateTransferPageState extends ConsumerState<_CreateTransferPage> {
  final _form = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _destinationLpn = TextEditingController();
  _TransferMode _mode = _TransferMode.wholeLpn;
  LookupOption? _source;
  LookupOption? _destination;
  JsonMap? _sourceInfo;
  JsonMap? _origin;
  String? _warehouseId;
  String? _wholeQuantity;
  int _layers = 0;
  bool _loadingSource = false;
  bool _submitting = false;
  Object? _error;
  int _selectionVersion = 0;

  @override
  void dispose() {
    _quantity.dispose();
    _destinationLpn.dispose();
    super.dispose();
  }

  void _changeMode(_TransferMode mode) {
    setState(() {
      _mode = mode;
      _source = null;
      _destination = null;
      _sourceInfo = null;
      _origin = null;
      _warehouseId = null;
      _wholeQuantity = null;
      _layers = 0;
      _quantity.clear();
      _destinationLpn.clear();
      _error = null;
      _selectionVersion++;
    });
  }

  Future<void> _selectSource(LookupOption? source) async {
    final version = ++_selectionVersion;
    setState(() {
      _source = source;
      _sourceInfo = null;
      _origin = null;
      _warehouseId = null;
      _destination = null;
      _wholeQuantity = null;
      _layers = 0;
      _error = null;
      _loadingSource = source != null;
      _quantity.clear();
    });
    if (source == null) return;
    try {
      final repository = ref.read(warehouseRepositoryProvider);
      final info = await repository.detail(
        _mode == _TransferMode.wholeLpn ? 'lpns' : 'stock',
        source.id,
      );
      if (info['positionId'] == null) {
        throw StateError(
          'O LPN selecionado não está em uma posição disponível.',
        );
      }
      final origin = await repository.detail(
        'positions',
        info['positionId'].toString(),
      );
      final zone = await repository.detail(
        'zones',
        origin['zoneId'].toString(),
      );
      String? total;
      var layers = 0;
      if (_mode == _TransferMode.wholeLpn) {
        var sum = BigInt.zero;
        var page = 0;
        while (true) {
          final balances = await repository.list(
            'stock',
            page: page,
            size: 100,
            filters: {'lpnId': source.id},
          );
          for (final balance in balances.content) {
            final amount = scaledInboundQuantity('${balance['quantity']}');
            if (amount == null) {
              throw StateError(
                'Uma quantidade do LPN está em formato inválido. Atualize a consulta.',
              );
            }
            sum += amount;
            layers++;
          }
          if (balances.last) break;
          page++;
        }
        total = inboundDecimalFromScaled(sum);
      }
      if (!mounted || version != _selectionVersion) return;
      setState(() {
        _sourceInfo = info;
        _origin = origin;
        _warehouseId = zone['warehouseId'].toString();
        _wholeQuantity = total;
        _layers = layers;
        _loadingSource = false;
      });
    } catch (error) {
      if (mounted && version == _selectionVersion) {
        setState(() {
          _error = error;
          _loadingSource = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_submitting ||
        _loadingSource ||
        _sourceInfo == null ||
        !(_form.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final task = await ref
          .read(operationCommandProvider)
          .run(
            '/api/transfers',
            body: {
              if (_mode == _TransferMode.wholeLpn)
                'lpnId': _source!.id
              else
                'stockId': _source!.id,
              'destinationPositionId': _destination!.id,
              if (_mode == _TransferMode.stock)
                'destinationLpnCode': _destinationLpn.text.trim(),
              'quantity': operationQuantity(_quantity.text),
            },
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Transferência ${task['id']} planejada. A movimentação exige conferência e execução.',
          ),
        ),
      );
      Navigator.of(context).pop(task);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
        });
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
    final auth = ref.watch(authControllerProvider).value;
    final canExecute = auth?.can('TRANSFER_EXECUTE') ?? false;
    final canSelect =
        canExecute &&
        (auth?.can('STOCK_VIEW') ?? false) &&
        (auth?.can('WAREHOUSE_VIEW') ?? false);
    final busy = _submitting || _loadingSource;
    return PopScope(
      canPop: !_submitting,
      child: Scaffold(
        appBar: AppBar(title: const Text('Planejar transferência')),
        body: SafeArea(
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Planeje a movimentação dentro do mesmo armazém. O estoque só muda após a execução com conferência dos códigos.',
                ),
                const SizedBox(height: 16),
                if (!canSelect)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'O planejamento nesta tela exige execução de transferências e consulta de estoque e posições. Solicite as permissões ao gestor.',
                    ),
                  ),
                SegmentedButton<_TransferMode>(
                  segments: const [
                    ButtonSegment(
                      value: _TransferMode.wholeLpn,
                      icon: Icon(Icons.pallet),
                      label: Text('LPN inteiro'),
                    ),
                    ButtonSegment(
                      value: _TransferMode.stock,
                      icon: Icon(Icons.inventory_2_outlined),
                      label: Text('Por saldo'),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: busy || !canSelect
                      ? null
                      : (values) => _changeMode(values.single),
                ),
                const SizedBox(height: 20),
                ApiLookupField(
                  key: ValueKey(_mode),
                  resource: _mode == _TransferMode.wholeLpn ? 'lpns' : 'stock',
                  label: _mode == _TransferMode.wholeLpn
                      ? 'LPN de origem'
                      : 'Saldo de origem',
                  value: _source,
                  enabled: !busy && canSelect,
                  isRequired: true,
                  onChanged: _selectSource,
                  helperText:
                      'Pesquise o código do LPN ou o produto. A API verifica reservas e bloqueios.',
                ),
                if (_loadingSource)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: LinearProgressIndicator(),
                  ),
                if (_sourceInfo != null) ...[
                  const SizedBox(height: 12),
                  InboundPanel(
                    title: 'Origem selecionada',
                    children: [
                      InboundValue('Posição', _origin?['code']),
                      if (_mode == _TransferMode.wholeLpn) ...[
                        InboundValue('Camadas de saldo', _layers),
                        InboundValue('Quantidade integral', _wholeQuantity),
                      ],
                      if (_mode == _TransferMode.stock) ...[
                        InboundValue('Produto', _sourceInfo?['sku']),
                        InboundValue('LPN', _sourceInfo?['lpnCode']),
                        InboundValue(
                          'Quantidade disponível',
                          _sourceInfo?['availableQuantity'],
                        ),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                ApiLookupField(
                  key: ValueKey('destination-$_warehouseId'),
                  resource: 'positions',
                  label: 'Posição de destino',
                  value: _destination,
                  filters: {
                    'warehouseId': _warehouseId ?? '',
                    'active': 'true',
                  },
                  enabled: !busy && canSelect && _warehouseId != null,
                  isRequired: true,
                  validator: (value) => value == null
                      ? 'Selecione o destino.'
                      : value.id == _sourceInfo?['positionId']
                      ? 'Selecione uma posição diferente da origem.'
                      : null,
                  onChanged: (value) => setState(() {
                    _destination = value;
                  }),
                  helperText:
                      'São exibidas posições ativas no mesmo armazém da origem.',
                ),
                const SizedBox(height: 20),
                if (_mode == _TransferMode.stock)
                  operationField(
                    label: 'Código do LPN de destino',
                    technical: true,
                    controller: _destinationLpn,
                    enabled: !busy && canSelect,
                    helper:
                        'Use um LPN diferente do LPN de origem. A API cria ou valida o LPN nesta posição.',
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Informe o LPN de destino.';
                      }
                      if (value!.trim() == _sourceInfo?['lpnCode']) {
                        return 'O LPN de destino precisa ser diferente do de origem.';
                      }
                      return null;
                    },
                  ),
                operationField(
                  label: _mode == _TransferMode.wholeLpn
                      ? 'Confirme a quantidade integral'
                      : 'Quantidade a transferir',
                  controller: _quantity,
                  enabled: !busy && canSelect && _sourceInfo != null,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) => transferQuantityError(
                    value,
                    _mode == _TransferMode.wholeLpn
                        ? _wholeQuantity
                        : _sourceInfo?['availableQuantity'],
                    wholeLpn: _mode == _TransferMode.wholeLpn,
                  ),
                ),
                if (_error != null)
                  InboundErrorCard(
                    error: _error!,
                    onRetry: _source != null && !busy
                        ? () => _selectSource(_source)
                        : null,
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: !busy && canSelect && _sourceInfo != null
                      ? _submit
                      : null,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.swap_horiz),
                  label: Text(
                    _submitting ? 'Planejando…' : 'Criar planejamento',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
