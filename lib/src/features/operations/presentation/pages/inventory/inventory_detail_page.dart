import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/application/auth_controller.dart';
import '../../widgets/api_operation_widgets.dart';
import '../outbound/operation_flow_widgets.dart';
import 'inventory_forms.dart';

class InventoryDetailPage extends ConsumerWidget {
  const InventoryDetailPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OperationDetailPage(
    title: 'Contagem de inventário',
    resource: 'inventories',
    id: id,
    builder: (context, ref, data, reload) {
      final inventory = Map<String, dynamic>.from(data['inventory'] as Map);
      final items = operationItems(data);
      final auth = ref.watch(authControllerProvider).value;
      final open = ['PENDENTE', 'EM_CONTAGEM'].contains(inventory['status']);
      final mine = inventory['responsibleUserId'] == auth?.user?.id;
      final canCount =
          open && mine && (auth?.can('INVENTORY_EXECUTE') ?? false);
      final canAdjust = open && (auth?.can('INVENTORY_ADJUST') ?? false);
      final allCounted = items.every((item) => item['countedQuantity'] != null);
      final counted = items
          .where((item) => item['countedQuantity'] != null)
          .length;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          operationFacts({
            'Estado': operationStatusLabel(operationValue(inventory, 'status')),
            'Posição (ID)': operationValue(inventory, 'positionId'),
            'Responsável (ID)': operationValue(inventory, 'responsibleUserId'),
            'Linhas contadas': '$counted de ${items.length}',
            'Inventário': id,
          }),
          if (open) ...[
            const SizedBox(height: 12),
            const Text(
              'A posição permanece congelada. Registrar a contagem preserva o saldo até a reconciliação por um usuário autorizado.',
            ),
            if (!mine)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'A contagem deve ser registrada pelo responsável deste inventário.',
                ),
              ),
          ],
          const SizedBox(height: 16),
          Text(
            'Snapshot e contagens',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'O snapshot não contém itens. Registre mercadorias encontradas antes de reconciliar, se houver.',
              ),
            ),
          for (final item in items)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${item['sku']} · ${item['lpnCode']}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Saldo no snapshot: ${item['theoreticalQuantity']} na unidade base\nContado: ${item['countedQuantity'] ?? 'Não contado'}',
                    ),
                    if (item['lot'] != null) Text('Lote: ${item['lot']}'),
                    if (item['expiryDate'] != null)
                      Text('Validade: ${item['expiryDate']}'),
                    if (canCount) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => openOperationCommand(
                          context,
                          InventoryCountPage(inventory: inventory, item: item),
                          reload,
                        ),
                        icon: const Icon(Icons.edit_note_outlined),
                        label: Text(
                          item['countedQuantity'] == null
                              ? 'Registrar contagem física'
                              : 'Recontar item',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (canCount && (auth?.can('PRODUCT_VIEW') ?? false)) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => openOperationCommand(
                context,
                InventoryCountPage(inventory: inventory),
                reload,
              ),
              icon: const Icon(Icons.add_box_outlined),
              label: const Text('Registrar mercadoria encontrada'),
            ),
          ],
          if (canAdjust) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: allCounted
                  ? () => openOperationCommand(
                      context,
                      InventoryClosePage(inventory: inventory),
                      reload,
                    )
                  : null,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Reconciliar e encerrar'),
            ),
            if (!allCounted)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Registre todas as contagens antes da reconciliação. Zero é uma contagem válida.',
                ),
              ),
          ],
          if (canCount || canAdjust) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => openOperationCommand(
                context,
                InventoryClosePage(inventory: inventory, cancel: true),
                reload,
              ),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancelar inventário'),
            ),
          ],
        ],
      );
    },
  );
}
