import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/api_operation_widgets.dart';
import 'outbound/picking_detail_page.dart';

class PickingPage extends ConsumerWidget {
  const PickingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ApiResourceListPage(
    title: 'Picking',
    resource: 'picking-tasks',
    permission: 'PICKING_VIEW',
    searchHint: 'Pesquisar tarefa, pedido ou LPN',
    statuses: const [
      'PENDENTE',
      'EM_EXECUCAO',
      'CONCLUIDA',
      'DIVERGENTE',
      'CANCELADA',
    ],
    titleBuilder: (item) =>
        '${item['productSku'] ?? 'Produto'} · ${item['targetQuantity']} na unidade base',
    subtitleBuilder: (item) =>
        '${item['productName'] ?? ''}\nOrigem: ${item['originPositionCode'] ?? '—'} · ${item['sourceLpnCode'] ?? '—'}\n${operationStatusLabel('${item['status']}')}',
    onOpen: (context, ref, item) async {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => PickingDetailPage(id: item['id'] as String),
        ),
      );
    },
  );
}
