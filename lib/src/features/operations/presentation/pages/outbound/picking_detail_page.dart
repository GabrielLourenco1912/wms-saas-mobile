import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/application/auth_controller.dart';
import '../../../application/operation_command.dart';
import '../../../data/warehouse_repository.dart';
import '../../widgets/api_operation_widgets.dart';
import 'operation_flow_widgets.dart';

class PickingDetailPage extends ConsumerWidget {
  const PickingDetailPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OperationDetailPage(
    title: 'Tarefa de picking',
    resource: 'picking-tasks',
    id: id,
    builder: (context, ref, task, reload) {
      final auth = ref.watch(authControllerProvider).value;
      final status = task['status'];
      final owner = task['assignedUserId'];
      final mine = owner == null || owner == auth?.user?.id;
      final running = status == 'EM_EXECUCAO';
      final editable = status == 'PENDENTE' || running;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          operationFacts({
            'Produto': '${task['productSku']} · ${task['productName']}',
            'Estado': operationStatusLabel(operationValue(task, 'status')),
            'Quantidade alvo (unidade base)': operationValue(
              task,
              'targetQuantity',
            ),
            'Origem / LPN esperado':
                '${task['originPositionCode']} / ${task['sourceLpnCode']}',
            'Pedido': operationValue(task, 'orderId'),
            'Tarefa': id,
            if (owner != null) 'Operador responsável': owner.toString(),
            if (task['actualQuantity'] != null)
              'Quantidade coletada': operationValue(task, 'actualQuantity'),
            if (task['destinationLpnId'] != null)
              'LPN de destino (ID)': operationValue(task, 'destinationLpnId'),
          }),
          const SizedBox(height: 12),
          const Text(
            'Confira os códigos no local. Concluir a coleta prepara a mercadoria para a doca; o despacho é realizado na expedição.',
          ),
          if (!mine && editable) ...[
            const SizedBox(height: 12),
            const Text(
              'Esta tarefa está atribuída a outro operador. A execução deve ser feita pelo responsável.',
            ),
          ],
          if (status == 'PENDENTE' &&
              mine &&
              (auth?.can('PICKING_EXECUTE') ?? false)) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => openOperationCommand(
                context,
                _PickingStartPage(id: id),
                reload,
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Iniciar e assumir tarefa'),
            ),
          ],
          if (running && mine && (auth?.can('PICKING_EXECUTE') ?? false)) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => openOperationCommand(
                context,
                PickingCollectionPage(task: task),
                reload,
              ),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Conferir e concluir coleta'),
            ),
          ],
          if (running &&
              mine &&
              (auth?.can('PICKING_REPORT_DIVERGENCE') ?? false)) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => openOperationCommand(
                context,
                PickingCollectionPage(task: task, shortage: true),
                reload,
              ),
              icon: const Icon(Icons.report_problem_outlined),
              label: const Text('Registrar falta física'),
            ),
          ],
          if (editable && (auth?.can('TASK_QUANTITY_OVERRIDE') ?? false)) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => openOperationCommand(
                context,
                _PickingExcessPage(task: task),
                reload,
              ),
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('Autorizar novo alvo'),
            ),
          ],
        ],
      );
    },
  );
}

class _PickingStartPage extends ConsumerWidget {
  const _PickingStartPage({required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OperationCommandPage(
    title: 'Iniciar picking',
    description:
        'A tarefa será atribuída ao seu usuário e passará para EM_EXECUCAO. Confirme somente quando estiver pronto para executar a coleta.',
    submitLabel: 'Confirmar início',
    fields: (_) => const [],
    submit: () => ref
        .read(operationCommandProvider)
        .run('/api/picking-tasks/$id/start', keyInBody: true),
  );
}

class PickingCollectionPage extends ConsumerStatefulWidget {
  const PickingCollectionPage({
    super.key,
    required this.task,
    this.shortage = false,
  });
  final JsonMap task;
  final bool shortage;

  @override
  ConsumerState<PickingCollectionPage> createState() =>
      _PickingCollectionPageState();
}

class _PickingCollectionPageState extends ConsumerState<PickingCollectionPage> {
  final _quantity = TextEditingController();
  final _sourcePosition = TextEditingController();
  final _sourceLpn = TextEditingController();
  final _product = TextEditingController();
  final _destinationLpn = TextEditingController();
  final _destinationPosition = TextEditingController();
  final _reason = TextEditingController();
  LookupOption? _dock;

  bool get _hasCollection =>
      !widget.shortage ||
      (num.tryParse(_quantity.text.trim().replaceAll(',', '.')) ?? 0) > 0;

  @override
  void dispose() {
    for (final controller in [
      _quantity,
      _sourcePosition,
      _sourceLpn,
      _product,
      _destinationLpn,
      _destinationPosition,
      _reason,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OperationCommandPage(
    title: widget.shortage ? 'Registrar falta física' : 'Concluir coleta',
    description:
        'Alvo atual: ${widget.task['targetQuantity']} na unidade base. Leia ou digite os códigos reais. ${widget.shortage ? 'Informe o que foi localizado, inclusive zero; o servidor registra a divergência e tenta realocar o restante.' : 'A quantidade coletada deve corresponder ao alvo vigente.'}',
    submitLabel: widget.shortage
        ? 'Registrar falta e realocar'
        : 'Confirmar coleta',
    fields: (busy) => [
      operationField(
        label: 'Posição de origem lida',
        scan: true,
        technical: true,
        controller: _sourcePosition,
        enabled: !busy,
        maxLength: 50,
      ),
      operationField(
        label: 'LPN de origem lido',
        scan: true,
        technical: true,
        controller: _sourceLpn,
        enabled: !busy,
      ),
      operationField(
        label: 'SKU ou barcode do produto lido',
        scan: true,
        technical: true,
        controller: _product,
        enabled: !busy,
      ),
      operationField(
        label: 'Quantidade física em unidade base',
        controller: _quantity,
        enabled: !busy,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        validator: (value) {
          final error = validateOperationQuantity(
            value,
            allowZero: widget.shortage,
          );
          if (error != null) return error;
          final quantity = operationQuantity(value!);
          final target = num.parse(widget.task['targetQuantity'].toString());
          if (widget.shortage && quantity >= target) {
            return 'A falta exige uma quantidade menor que o alvo.';
          }
          if (!widget.shortage && quantity != target) {
            return 'Informe o alvo vigente; use falta ou autorização de excesso para divergências.';
          }
          return null;
        },
      ),
      if (_hasCollection) ...[
        ApiLookupField(
          resource: 'positions',
          label: 'Doca de expedição de destino',
          value: _dock,
          enabled: !busy,
          isRequired: true,
          filters: const {'purpose': 'EXPEDICAO', 'active': 'true'},
          helperText: 'Escolha uma doca do mesmo armazém do pedido.',
          onChanged: (value) => setState(() {
            _dock = value;
          }),
        ),
        const SizedBox(height: 14),
        operationField(
          label: 'Código da doca lido',
          scan: true,
          technical: true,
          controller: _destinationPosition,
          enabled: !busy,
          maxLength: 50,
        ),
        operationField(
          label: 'LPN de destino lido',
          scan: true,
          technical: true,
          controller: _destinationLpn,
          enabled: !busy,
        ),
      ],
      if (widget.shortage)
        operationField(
          label: 'Motivo da falta',
          controller: _reason,
          enabled: !busy,
          maxLength: 255,
        ),
    ],
    submit: () => ref
        .read(operationCommandProvider)
        .run(
          '/api/picking-tasks/${widget.task['id']}/${widget.shortage ? 'divergences' : 'complete'}',
          keyInBody: true,
          body: {
            'actualQuantity': operationQuantity(_quantity.text),
            'sourceLpnCode': _sourceLpn.text.trim(),
            'sourcePositionCode': _sourcePosition.text.trim(),
            'productCode': _product.text.trim(),
            if (_hasCollection) ...{
              'destinationLpnCode': _destinationLpn.text.trim(),
              'destinationPositionId': _dock!.id,
              'destinationPositionCode': _destinationPosition.text.trim(),
            },
            if (widget.shortage) 'reason': _reason.text.trim(),
          },
        ),
    successMessage: widget.shortage
        ? (result) =>
              'Falta registrada. Demanda não realocada: ${result['unallocatedQuantity'] ?? 'consulte o detalhe'} na unidade base.'
        : null,
  );
}

class _PickingExcessPage extends ConsumerStatefulWidget {
  const _PickingExcessPage({required this.task});
  final JsonMap task;
  @override
  ConsumerState<_PickingExcessPage> createState() => _PickingExcessPageState();
}

class _PickingExcessPageState extends ConsumerState<_PickingExcessPage> {
  final _quantity = TextEditingController();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _quantity.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OperationCommandPage(
    title: 'Autorizar excesso',
    description:
        'Alvo atual: ${widget.task['targetQuantity']} na unidade base. A autorização aumenta o alvo e a reserva, respeitando o saldo e a demanda. A coleta continua sendo confirmada separadamente pelo operador.',
    submitLabel: 'Autorizar novo alvo',
    fields: (busy) => [
      operationField(
        label: 'Novo alvo em unidade base',
        controller: _quantity,
        enabled: !busy,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (value) {
          final error = validateOperationQuantity(value);
          if (error != null) return error;
          return operationQuantity(value!) <=
                  num.parse(widget.task['targetQuantity'].toString())
              ? 'O novo alvo deve ser maior que o atual.'
              : null;
        },
      ),
      operationField(
        label: 'Justificativa da autorização',
        controller: _reason,
        enabled: !busy,
        maxLength: 255,
      ),
    ],
    submit: () => ref
        .read(operationCommandProvider)
        .run(
          '/api/tasks/${widget.task['id']}/authorize-excess',
          keyInBody: true,
          body: {
            'newTargetQuantity': operationQuantity(_quantity.text),
            'reason': _reason.text.trim(),
          },
        ),
  );
}
