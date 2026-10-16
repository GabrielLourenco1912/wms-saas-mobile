import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/application/auth_controller.dart';
import '../widgets/api_operation_widgets.dart';
import 'inventory/inventory_detail_page.dart';
import 'inventory/inventory_forms.dart';

class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  int _revision = 0;

  Future<void> _create() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateInventoryPage()),
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
    return ApiResourceListPage(
      key: ValueKey(_revision),
      title: 'Inventário',
      resource: 'inventories',
      permission: 'INVENTORY_VIEW',
      searchHint: 'Pesquisar inventário ou responsável',
      statuses: const ['PENDENTE', 'EM_CONTAGEM', 'CONCLUIDO', 'CANCELADO'],
      actions: [
        if ((auth?.can('INVENTORY_EXECUTE') ?? false) &&
            (auth?.can('WAREHOUSE_VIEW') ?? false))
          IconButton(
            tooltip: 'Abrir inventário',
            onPressed: _create,
            icon: const Icon(Icons.add),
          ),
      ],
      titleBuilder: (item) => 'Inventário ${item['id']}',
      subtitleBuilder: (item) =>
          'Posição: ${item['positionId']}\n${operationStatusLabel('${item['status']}')}',
      onOpen: (context, ref, item) async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => InventoryDetailPage(id: item['id'] as String),
          ),
        );
      },
    );
  }
}
