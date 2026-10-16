import 'package:flutter/material.dart';
import '../../../auth/application/auth_controller.dart';

class OperationalModule {
  const OperationalModule(
    this.title,
    this.description,
    this.route,
    this.resource,
    this.permissions,
    this.icon, {
    this.pendingStatus,
  });
  final String title, description, route, resource;
  final List<String> permissions;
  final IconData icon;
  final String? pendingStatus;
  bool visible(AuthState? state) =>
      permissions.any((p) => state?.can(p) ?? false);
}

const operationalModules = [
  OperationalModule(
    'Recebimento',
    'Confira produtos, embalagens, lotes e LPNs.',
    '/operations/receiving',
    'receipts',
    ['RECEIPT_VIEW'],
    Icons.move_to_inbox_outlined,
    pendingStatus: 'PENDENTE',
  ),
  OperationalModule(
    'Armazenagem',
    'Execute o putaway integral no endereço planejado.',
    '/operations/putaway',
    'putaway-tasks',
    ['PUTAWAY_VIEW'],
    Icons.shelves,
    pendingStatus: 'PENDENTE',
  ),
  OperationalModule(
    'Separação',
    'Execute tarefas de picking e registre faltas.',
    '/operations/picking',
    'picking-tasks',
    ['PICKING_VIEW'],
    Icons.shopping_cart_checkout_outlined,
    pendingStatus: 'PENDENTE',
  ),
  OperationalModule(
    'Expedição',
    'Confira os volumes e confirme a saída pela doca.',
    '/operations/dispatch',
    'shipments',
    ['SHIPMENT_VIEW'],
    Icons.local_shipping_outlined,
    pendingStatus: 'ABERTA',
  ),
  OperationalModule(
    'Inventário',
    'Conte o estoque físico e acompanhe os ajustes.',
    '/operations/inventory',
    'inventories',
    ['INVENTORY_VIEW'],
    Icons.fact_check_outlined,
    pendingStatus: 'PENDENTE',
  ),
  OperationalModule(
    'Transferências',
    'Movimente um LPN integral ou uma camada de estoque.',
    '/operations/transfers',
    'transfers',
    ['TRANSFER_VIEW'],
    Icons.compare_arrows,
    pendingStatus: 'PENDENTE',
  ),
  OperationalModule(
    'Estoque e auditoria',
    'Consulte saldos, bloqueios e movimentações.',
    '/operations/stock-audit',
    'stock',
    ['STOCK_VIEW', 'AUDIT_VIEW'],
    Icons.manage_search_outlined,
  ),
];

class OperationalModuleTile extends StatelessWidget {
  const OperationalModuleTile({
    super.key,
    required this.module,
    required this.onTap,
    this.caption,
  });
  final OperationalModule module;
  final VoidCallback onTap;
  final String? caption;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          module.icon,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        module.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(caption ?? module.description),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}
