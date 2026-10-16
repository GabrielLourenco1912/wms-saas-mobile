import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/application/auth_controller.dart';
import '../../../application/operation_command.dart';
import '../../../data/warehouse_repository.dart';
import '../../widgets/api_operation_widgets.dart';
import 'operation_flow_widgets.dart';

class ShipmentDetailPage extends ConsumerWidget {
  const ShipmentDetailPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OperationDetailPage(
    title: 'Carga de expedição',
    resource: 'shipments',
    id: id,
    builder: (context, ref, shipment, reload) {
      final auth = ref.watch(authControllerProvider).value;
      final items = operationItems(shipment);
      final confirmed = items
          .where(
            (item) =>
                item['status'] == 'CONFERIDO' || item['confirmedAt'] != null,
          )
          .length;
      final status = shipment['status'];
      final executable = auth?.can('SHIPMENT_EXECUTE') ?? false;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          operationFacts({
            'Estado': operationStatusLabel(operationValue(shipment, 'status')),
            'Pedido': operationValue(shipment, 'orderId'),
            'Doca (ID)': operationValue(shipment, 'dockPositionId'),
            'Linhas conferidas': '$confirmed de ${items.length}',
            'Carga': id,
            if (shipment['dispatchedAt'] != null)
              'Despachada em': operationValue(shipment, 'dispatchedAt'),
          }),
          const SizedBox(height: 12),
          Text(
            'Volumes da carga',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final item in items)
            Card(
              child: ListTile(
                leading: Icon(
                  item['confirmedAt'] != null
                      ? Icons.check_circle_outline
                      : Icons.qr_code_scanner,
                ),
                title: Text('${item['lpnCode']} · ${item['sku']}'),
                subtitle: Text(
                  '${item['quantity']} na unidade base · ${operationStatusLabel('${item['status']}')}',
                ),
              ),
            ),
          if (executable && status == 'ABERTA') ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => openOperationCommand(
                context,
                ShipmentScanPage(shipment: shipment),
                reload,
              ),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Conferir um LPN'),
            ),
          ],
          if (executable && (status == 'ABERTA' || status == 'CONFERIDA')) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: status == 'CONFERIDA'
                  ? () => openOperationCommand(
                      context,
                      ShipmentScanPage(shipment: shipment, dispatch: true),
                      reload,
                    )
                  : null,
              icon: const Icon(Icons.local_shipping_outlined),
              label: const Text('Despachar carga'),
            ),
            if (status != 'CONFERIDA')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'O despacho será liberado após a conferência de todos os LPNs.',
                ),
              ),
          ],
          if ((auth?.can('ORDER_CANCEL') ?? false) &&
              (status == 'ABERTA' || status == 'CONFERIDA')) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => openOperationCommand(
                context,
                _CancelShipmentPage(id: id),
                reload,
              ),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancelar carga'),
            ),
          ],
        ],
      );
    },
  );
}

class ShipmentScanPage extends ConsumerStatefulWidget {
  const ShipmentScanPage({
    super.key,
    required this.shipment,
    this.dispatch = false,
  });
  final JsonMap shipment;
  final bool dispatch;

  @override
  ConsumerState<ShipmentScanPage> createState() => _ShipmentScanPageState();
}

class _ShipmentScanPageState extends ConsumerState<ShipmentScanPage> {
  final _lpn = TextEditingController();
  final _dock = TextEditingController();

  @override
  void dispose() {
    _lpn.dispose();
    _dock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OperationCommandPage(
    title: widget.dispatch ? 'Despachar carga' : 'Conferir LPN',
    description: widget.dispatch
        ? 'Confirme a saída física da carga ${widget.shipment['id']}. O despacho baixa o estoque e atende as quantidades do pedido. Leia o código da doca e confirme somente após a conferência física.'
        : 'Leia o LPN real da carga ${widget.shipment['id']} e o código da doca. Cada volume deve ser conferido fisicamente; a confirmação não despacha a carga.',
    submitLabel: widget.dispatch
        ? 'Confirmar despacho físico'
        : 'Confirmar LPN lido',
    fields: (busy) => [
      if (!widget.dispatch)
        operationField(label: 'LPN lido', controller: _lpn, enabled: !busy),
      operationField(
        label: 'Código da doca lido',
        controller: _dock,
        enabled: !busy,
        maxLength: 50,
      ),
    ],
    submit: () => ref
        .read(operationCommandProvider)
        .run(
          '/api/shipments/${widget.shipment['id']}/${widget.dispatch ? 'dispatch' : 'confirm'}',
          keyInBody: true,
          body: {
            'dockPositionCode': _dock.text.trim(),
            if (!widget.dispatch) 'lpnCode': _lpn.text.trim(),
          },
        ),
  );
}

class PrepareShipmentPage extends ConsumerStatefulWidget {
  const PrepareShipmentPage({super.key});
  @override
  ConsumerState<PrepareShipmentPage> createState() =>
      _PrepareShipmentPageState();
}

class _PrepareShipmentPageState extends ConsumerState<PrepareShipmentPage> {
  LookupOption? _order;
  LookupOption? _dock;
  String? _warehouseId;
  String? _orderError;
  bool _loadingOrder = false;
  int _orderGeneration = 0;
  final List<LookupOption> _lpns = [];

  Future<void> _selectOrder(LookupOption? value) async {
    final generation = ++_orderGeneration;
    setState(() {
      _order = value;
      _dock = null;
      _warehouseId = null;
      _lpns.clear();
      _orderError = null;
      _loadingOrder = value != null;
    });
    if (value == null) return;
    try {
      final order = await ref
          .read(warehouseRepositoryProvider)
          .detail('orders', value.id);
      if (mounted && generation == _orderGeneration) {
        setState(() {
          _warehouseId = order['warehouseId'] as String?;
          _loadingOrder = false;
        });
      }
    } catch (error) {
      if (mounted && generation == _orderGeneration) {
        setState(() {
          _orderError = '$error';
          _loadingOrder = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => OperationCommandPage(
    title: 'Preparar carga',
    description:
        'Selecione um pedido e os LPNs já separados na doca. A preparação cria a carga; cada LPN ainda precisará ser lido antes do despacho.',
    submitLabel: 'Criar carga para conferência',
    fields: (busy) => [
      ApiLookupField(
        resource: 'orders',
        label: 'Pedido de saída',
        value: _order,
        enabled: !busy,
        isRequired: true,
        onChanged: _selectOrder,
      ),
      const SizedBox(height: 14),
      if (_loadingOrder) const LinearProgressIndicator(),
      if (_orderError != null) ...[
        Text(
          _orderError!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        TextButton(
          onPressed: busy ? null : () => _selectOrder(_order),
          child: const Text('Recarregar pedido'),
        ),
      ],
      ApiLookupField(
        resource: 'positions',
        label: 'Doca de expedição',
        value: _dock,
        enabled: !busy && _warehouseId != null && !_loadingOrder,
        isRequired: true,
        filters: {
          'purpose': 'EXPEDICAO',
          'active': 'true',
          'warehouseId': ?_warehouseId,
        },
        onChanged: (value) => setState(() {
          _dock = value;
          _lpns.clear();
        }),
      ),
      const SizedBox(height: 14),
      ApiLookupField(
        key: ValueKey('${_order?.id}-${_dock?.id}-${_lpns.length}'),
        resource: 'lpns',
        label: 'Adicionar LPN à carga',
        enabled: !busy && _order != null && _dock != null && !_loadingOrder,
        filters: {
          'status': 'SEPARADO',
          if (_order != null) 'outboundOrderId': _order!.id,
          if (_dock != null) 'positionId': _dock!.id,
        },
        onChanged: (value) {
          if (value != null && !_lpns.any((lpn) => lpn.id == value.id)) {
            setState(() {
              _lpns.add(value);
            });
          }
        },
      ),
      const SizedBox(height: 12),
      FormField<bool>(
        validator: (_) => _lpns.isEmpty
            ? 'Adicione ao menos um LPN separado na doca selecionada.'
            : _lpns.length > 500
            ? 'Uma carga aceita no máximo 500 LPNs.'
            : null,
        builder: (field) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final lpn in _lpns)
                  InputChip(
                    label: Text(lpn.label),
                    onDeleted: busy
                        ? null
                        : () => setState(() {
                            _lpns.remove(lpn);
                          }),
                  ),
              ],
            ),
            if (field.hasError)
              Text(
                field.errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ],
    submit: () async {
      if (_loadingOrder || _orderError != null || _warehouseId == null) {
        throw StateError('Carregue o pedido antes de preparar a carga.');
      }
      return ref
          .read(operationCommandProvider)
          .run(
            '/api/shipments',
            keyInBody: true,
            body: {
              'orderId': _order!.id,
              'dockPositionId': _dock!.id,
              'lpnIds': _lpns.map((lpn) => lpn.id).toList(),
            },
          );
    },
  );
}

class _CancelShipmentPage extends ConsumerStatefulWidget {
  const _CancelShipmentPage({required this.id});
  final String id;
  @override
  ConsumerState<_CancelShipmentPage> createState() =>
      _CancelShipmentPageState();
}

class _CancelShipmentPageState extends ConsumerState<_CancelShipmentPage> {
  final _reason = TextEditingController();
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OperationCommandPage(
    title: 'Cancelar carga',
    description:
        'A carga será cancelada e não poderá ser despachada. Informe o motivo; os vínculos e o histórico permanecem disponíveis.',
    submitLabel: 'Confirmar cancelamento',
    fields: (busy) => [
      operationField(
        label: 'Motivo do cancelamento',
        controller: _reason,
        enabled: !busy,
        maxLength: 255,
      ),
    ],
    submit: () => ref
        .read(operationCommandProvider)
        .run(
          '/api/shipments/${widget.id}/cancel',
          keyInBody: true,
          body: {'reason': _reason.text.trim()},
        ),
  );
}
