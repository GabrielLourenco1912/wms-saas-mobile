import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/application/auth_controller.dart';
import '../widgets/api_operation_widgets.dart';
import 'outbound/shipment_detail_page.dart';

class DispatchPage extends ConsumerStatefulWidget {
  const DispatchPage({super.key});

  @override
  ConsumerState<DispatchPage> createState() => _DispatchPageState();
}

class _DispatchPageState extends ConsumerState<DispatchPage> {
  int _revision = 0;

  Future<void> _prepare() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PrepareShipmentPage()),
    );
    if (changed == true && mounted) {
      setState(() {
        _revision++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider).value;
    final canPrepare = [
      'SHIPMENT_EXECUTE',
      'ORDER_VIEW',
      'STOCK_VIEW',
      'WAREHOUSE_VIEW',
    ].every((permission) => auth?.can(permission) ?? false);
    return ApiResourceListPage(
      key: ValueKey(_revision),
      title: 'Expedição',
      resource: 'shipments',
      permission: 'SHIPMENT_VIEW',
      searchHint: 'Pesquisar carga, estado ou pedido',
      statuses: const ['ABERTA', 'CONFERIDA', 'DESPACHADA', 'CANCELADA'],
      actions: [
        if (canPrepare)
          IconButton(
            tooltip: 'Preparar carga',
            onPressed: _prepare,
            icon: const Icon(Icons.add),
          ),
      ],
      titleBuilder: (item) => 'Carga ${item['id']}',
      subtitleBuilder: (item) =>
          'Pedido: ${item['orderId']}\n${operationStatusLabel('${item['status']}')} · ${(item['items'] as List? ?? const []).length} linhas',
      onOpen: (context, ref, item) async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => ShipmentDetailPage(id: item['id'] as String),
          ),
        );
      },
    );
  }
}
