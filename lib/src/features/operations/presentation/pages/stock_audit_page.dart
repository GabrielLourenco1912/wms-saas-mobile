import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/application/auth_controller.dart';
import '../../application/operation_command.dart';
import '../widgets/api_operation_widgets.dart';
import 'inbound/inbound_contracts.dart';
import 'inbound/inbound_view_helpers.dart';
import 'outbound/operation_flow_widgets.dart';

class StockAuditPage extends ConsumerWidget {
  const StockAuditPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).value;
    final canViewStock = auth?.can('STOCK_VIEW') ?? false;
    final canViewAudit = auth?.can('AUDIT_VIEW') ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Estoque e auditoria')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (canViewStock) ...[
              _NavigationCard(
                title: 'Saldos de estoque',
                description:
                    'Consulte o saldo físico, reservado e disponível por produto, lote, LPN e posição.',
                icon: Icons.inventory_2_outlined,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => const _StockListPage()),
                ),
              ),
              _NavigationCard(
                title: 'Bloqueios ativos',
                description:
                    'Veja os motivos e o alcance dos bloqueios. A liberação depende da permissão do seu perfil.',
                icon: Icons.lock_outline,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => const _BlockListPage()),
                ),
              ),
            ],
            if (canViewAudit)
              _NavigationCard(
                title: 'Livro razão',
                description:
                    'Consulte lançamentos imutáveis, movimentações e vínculos de rastreabilidade.',
                icon: Icons.receipt_long_outlined,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => const _LedgerListPage()),
                ),
              ),
            if (!canViewStock && !canViewAudit)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Seu perfil não permite consultar estoque ou auditoria.',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavigationCard extends StatelessWidget {
  const _NavigationCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(description),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class _StockListPage extends ConsumerWidget {
  const _StockListPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) => ApiResourceListPage(
    title: 'Saldos de estoque',
    resource: 'stock',
    permission: 'STOCK_VIEW',
    searchHint: 'Pesquisar SKU, produto, lote, LPN ou posição',
    titleBuilder: (stock) =>
        '${inboundText(stock['sku'])} · ${inboundText(stock['productName'])}',
    subtitleBuilder: (stock) =>
        '${inboundText(stock['lpnCode'])} · ${inboundText(stock['positionCode'])}\nDisponível ${inboundText(stock['availableQuantity'])} · Físico ${inboundText(stock['quantity'])} · ${inboundText(stock['blockStatus'])}',
    onOpen: (context, ref, stock) async {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => StockBalanceDetailPage(id: stock['id'].toString()),
        ),
      );
    },
  );
}

class StockBalanceDetailPage extends ConsumerWidget {
  const StockBalanceDetailPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OperationDetailPage(
    title: 'Saldo de estoque',
    resource: 'stock',
    id: id,
    builder: (context, ref, stock, reload) {
      final auth = ref.watch(authControllerProvider).value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InboundPanel(
            title:
                '${inboundText(stock['sku'])} · ${inboundText(stock['productName'])}',
            children: [
              InboundValue('Saldo físico', stock['quantity']),
              InboundValue('Reservado', stock['reservedQuantity']),
              InboundValue('Disponível', stock['availableQuantity']),
              InboundValue('Bloqueio', stock['blockStatus']),
              InboundValue('LPN', stock['lpnCode']),
              InboundValue('Posição', stock['positionCode']),
              InboundValue('Lote', stock['lot']),
              InboundValue('Validade', stock['expiryDate']),
              InboundValue('Entrada original', stock['entryAt']),
            ],
          ),
          if (auth?.can('STOCK_BLOCK') ?? false)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                onPressed: () => _openReasonCommand(
                  context,
                  ref,
                  '/api/stock/$id/block',
                  'Bloquear saldo',
                  'O bloqueio restringe a movimentação desta camada de saldo. Informe o motivo.',
                  reload,
                ),
                icon: const Icon(Icons.lock_outline),
                label: const Text('Bloquear saldo'),
              ),
            ),
          if (auth?.can('STOCK_UNBLOCK') ?? false)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                onPressed: () => _openReasonCommand(
                  context,
                  ref,
                  '/api/stock/$id/unblock',
                  'Liberar bloqueio do saldo',
                  'Este comando libera bloqueios diretos deste saldo. Bloqueios de lote ou posição e reservas podem continuar impedindo a movimentação.',
                  reload,
                ),
                icon: const Icon(Icons.lock_open_outlined),
                label: const Text('Liberar bloqueio direto'),
              ),
            ),
          if (auth?.can('AUDIT_VIEW') ?? false)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => _LedgerListPage(stockId: id),
                  ),
                ),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Ver lançamentos deste saldo'),
              ),
            ),
        ],
      );
    },
  );
}

Future<void> _openReasonCommand(
  BuildContext context,
  WidgetRef ref,
  String path,
  String title,
  String description,
  Future<void> Function() reload,
) async {
  final reason = TextEditingController();
  try {
    await openOperationCommand(
      context,
      OperationCommandPage(
        title: title,
        description: description,
        submitLabel: title,
        fields: (busy) => [
          operationField(
            label: 'Motivo',
            controller: reason,
            maxLength: 255,
            enabled: !busy,
          ),
        ],
        submit: () => ref
            .read(operationCommandProvider)
            .run(path, body: {'reason': reason.text.trim()}),
      ),
      reload,
    );
  } finally {
    reason.dispose();
  }
}

class _BlockListPage extends ConsumerWidget {
  const _BlockListPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) => ApiResourceListPage(
    title: 'Bloqueios ativos',
    resource: 'stock-blocks',
    permission: 'STOCK_VIEW',
    filters: const {'active': 'true'},
    searchHint: 'Pesquisar motivo, tipo, lote ou ID',
    titleBuilder: (block) =>
        '${inboundText(block['type'])} · ${inboundText(block['reason'])}',
    subtitleBuilder: (block) =>
        'Lote ${inboundText(block['lot'])}\nCriado em ${inboundText(block['createdAt'])}',
    onOpen: (context, ref, block) async {
      final reason = TextEditingController();
      try {
        final canRelease =
            ref.read(authControllerProvider).value?.can('STOCK_UNBLOCK') ??
            false;
        final facts = InboundPanel(
          title: 'Bloqueio ${inboundText(block['type'])}',
          children: [
            InboundValue('Motivo original', block['reason']),
            InboundValue('Armazém', block['warehouseId']),
            InboundValue('Saldo', block['stockId']),
            InboundValue('Produto', block['productId']),
            InboundValue('Lote', block['lot']),
            InboundValue('Posição', block['positionId']),
          ],
        );
        if (!canRelease) {
          await Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Detalhe do bloqueio')),
                body: SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [facts],
                  ),
                ),
              ),
            ),
          );
          return;
        }
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => OperationCommandPage(
              title: 'Liberar bloqueio',
              description:
                  'Confira o alcance do bloqueio antes de liberar. O saldo pode continuar restrito por outros bloqueios ou reservas.',
              submitLabel: 'Liberar este bloqueio',
              fields: (busy) => [
                facts,
                const SizedBox(height: 16),
                operationField(
                  label: 'Motivo da liberação',
                  controller: reason,
                  maxLength: 255,
                  enabled: !busy,
                ),
              ],
              submit: () => ref
                  .read(operationCommandProvider)
                  .run(
                    '/api/stock-blocks/${block['id']}/release',
                    body: {'reason': reason.text.trim()},
                  ),
            ),
          ),
        );
      } finally {
        reason.dispose();
      }
    },
  );
}

class _LedgerListPage extends ConsumerWidget {
  const _LedgerListPage({this.stockId});
  final String? stockId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ApiResourceListPage(
    title: 'Livro razão',
    resource: 'stock-transactions',
    permission: 'AUDIT_VIEW',
    filters: stockId == null ? const {} : {'stockId': stockId!},
    searchHint: 'Pesquisar ID, lote ou motivo',
    titleBuilder: (entry) =>
        '${inboundText(entry['movementType'])} · ${inboundText(entry['quantity'])}',
    subtitleBuilder: (entry) =>
        '${inboundText(entry['occurredAt'])}\nLote ${inboundText(entry['recordedLot'])} · Saldo ${inboundText(entry['resultingBalance'])}',
    onOpen: (context, ref, entry) async {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => OperationDetailPage(
            title: 'Lançamento do livro razão',
            resource: 'stock-transactions',
            id: entry['id'].toString(),
            builder: (context, ref, row, reload) => InboundPanel(
              title: inboundText(row['movementType']),
              children: [
                const Text('Registro imutável da movimentação de estoque.'),
                InboundValue('Quantidade', row['quantity']),
                InboundValue('Saldo anterior', row['previousBalance']),
                InboundValue('Saldo resultante', row['resultingBalance']),
                InboundValue('Lote registrado', row['recordedLot']),
                InboundValue('Validade registrada', row['recordedExpiryDate']),
                InboundValue('Entrada original', row['recordedEntryAt']),
                InboundValue('Data da movimentação', row['occurredAt']),
                InboundValue('Motivo', row['reason']),
                InboundValue('Produto', row['productId']),
                InboundValue('LPN', row['lpnId']),
                InboundValue('Posição anterior', row['previousPositionId']),
                InboundValue('Nova posição', row['newPositionId']),
                InboundValue('Saldo de origem', row['stockId']),
                InboundValue('Saldo de destino', row['destinationStockId']),
                InboundValue('LPN de destino', row['destinationLpnId']),
                InboundValue(
                  'Saldo anterior no destino',
                  row['destinationPreviousBalance'],
                ),
                InboundValue(
                  'Saldo resultante no destino',
                  row['destinationResultingBalance'],
                ),
                InboundValue('Operador', row['userId']),
                InboundValue('Operação', row['operationId']),
                InboundValue('Sequência da operação', row['sequence']),
                InboundValue('Tarefa', row['taskId']),
                InboundValue(
                  'Compensa lançamento',
                  row['compensatedTransactionId'],
                ),
                InboundValue('Item de inventário', row['inventoryItemId']),
                InboundValue('Item de expedição', row['shipmentItemId']),
                InboundValue('ID do lançamento', row['id']),
              ],
            ),
          ),
        ),
      );
    },
  );
}
