import '../../../../core/diagnostics/feedback_probe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/application/auth_controller.dart';
import '../../application/operation_command.dart';
import '../../data/warehouse_repository.dart';
import '../widgets/api_operation_widgets.dart';
import 'inbound/inbound_contracts.dart';
import 'inbound/inbound_view_helpers.dart';

class PutawayPage extends ConsumerWidget {
  const PutawayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ApiResourceListPage(
    title: 'Armazenagem · Putaway',
    resource: 'putaway-tasks',
    permission: 'PUTAWAY_VIEW',
    searchHint: 'Pesquisar tarefa, pedido ou ID do LPN',
    statuses: const ['PENDENTE', 'EM_EXECUCAO', 'CONCLUIDA', 'CANCELADA'],
    titleBuilder: (row) => inboundText(
      row['lpnCode'],
      fallback: 'Tarefa ${inboundText(row['id'])}',
    ),
    subtitleBuilder: (row) =>
        '${inboundStatus(row['status'])} · Quantidade ${inboundText(row['targetQuantity'])}\n${inboundText(row['originPositionCode'])} → ${inboundText(row['destinationPositionCode'])}',
    onOpen: (context, ref, row) async {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => _PutawayDetailPage(id: row['id'].toString()),
        ),
      );
    },
  );
}

class _PutawayDetailPage extends ConsumerStatefulWidget {
  const _PutawayDetailPage({required this.id});

  final String id;

  @override
  ConsumerState<_PutawayDetailPage> createState() => _PutawayDetailPageState();
}

class _PutawayDetailPageState extends ConsumerState<_PutawayDetailPage> {
  late Future<JsonMap> _detail;
  bool _starting = false;
  Object? _actionError;

  @override
  void initState() {
    super.initState();
    _detail = ref
        .read(warehouseRepositoryProvider)
        .detail('putaway-tasks', widget.id);
  }

  Future<void> _reload() async {
    final next = ref
        .read(warehouseRepositoryProvider)
        .detail('putaway-tasks', widget.id);
    setState(() {
      _detail = next;
      _actionError = null;
    });
    try {
      await next;
    } catch (_) {
      /* FutureBuilder renders the query failure. */
    }
  }

  Future<void> _start() async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _actionError = null;
    });
    try {
      final task = await ref
          .read(operationCommandProvider)
          .run('/api/putaway-tasks/${widget.id}/start');
      if (!mounted) return;
      setState(() {
        _detail = Future.value(task);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Armazenagem iniciada. Confira o LPN e o endereço de destino.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _actionError = error;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _starting = false;
        });
      }
    }
  }

  Future<void> _complete(JsonMap task) async {
    final result = await Navigator.of(context).push<JsonMap>(
      MaterialPageRoute(builder: (_) => _PutawayCompletePage(task: task)),
    );
    if (!mounted || result == null) return;
    setState(() {
      _detail = Future.value(result);
      _actionError = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'LPN armazenado em ${inboundText(result['destinationPositionCode'])}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider).value;
    final canExecute = auth?.can('PUTAWAY_EXECUTE') ?? false;
    return PopScope(
      canPop: !_starting,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tarefa de armazenagem'),
          actions: [
            IconButton(
              onPressed: _starting
                  ? null
                  : () => setState(() {
                      _detail = ref
                          .read(warehouseRepositoryProvider)
                          .detail('putaway-tasks', widget.id);
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
                            .detail('putaway-tasks', widget.id);
                      }),
                    ),
                  ],
                );
              }
              final task = snapshot.data ?? const <String, dynamic>{};
              final contents = inboundMaps(task['contents']);
              final ownTask = task['assignedUserId'] == auth?.user?.id;
              return RefreshIndicator(
                onRefresh: _starting ? () async {} : _reload,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    InboundPanel(
                      title: 'LPN ${inboundText(task['lpnCode'])}',
                      children: [
                        InboundValue('Situação', inboundStatus(task['status'])),
                        InboundValue('Origem', task['originPositionCode']),
                        InboundValue(
                          'Destino indicado',
                          task['destinationPositionCode'],
                        ),
                        InboundValue(
                          'Quantidade integral do LPN',
                          task['targetQuantity'],
                        ),
                        InboundValue(
                          'Operador responsável',
                          task['assignedUserId'],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Mova o LPN inteiro ao endereço indicado. A conclusão confere os códigos do LPN e da posição e preserva os lotes e validades.',
                        ),
                      ],
                    ),
                    InboundPanel(
                      title: 'Conteúdo do LPN (${contents.length})',
                      children: [
                        if (contents.isEmpty)
                          const Text(
                            'O backend não informou conteúdo para este LPN.',
                          ),
                        for (final content in contents) ...[
                          Text(
                            '${inboundText(content['sku'])} · ${inboundText(content['productName'])}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          InboundValue('Quantidade', content['quantity']),
                          if (content['lot'] != null)
                            InboundValue('Lote', content['lot']),
                          if (content['expiryDate'] != null)
                            InboundValue('Validade', content['expiryDate']),
                          const Divider(),
                        ],
                      ],
                    ),
                    if (!canExecute)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'Seu perfil permite consultar a tarefa. A execução exige permissão de armazenagem.',
                        ),
                      ),
                    if (canExecute && task['status'] == 'PENDENTE') ...[
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _starting ? null : _start,
                        icon: _starting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.play_arrow),
                        label: Text(
                          _starting ? 'Iniciando…' : 'Iniciar e assumir tarefa',
                        ),
                      ),
                    ],
                    if (canExecute &&
                        task['status'] == 'EM_EXECUCAO' &&
                        ownTask) ...[
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _starting ? null : () => _complete(task),
                        icon: const Icon(Icons.barcode_reader),
                        label: const Text('Conferir destino e concluir'),
                      ),
                    ],
                    if (task['status'] == 'EM_EXECUCAO' && !ownTask)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'Esta tarefa está em execução por outro operador. Somente o responsável pode concluí-la.',
                        ),
                      ),
                    if (task['status'] == 'CONCLUIDA')
                      InboundPanel(
                        title: 'Armazenagem concluída',
                        children: [
                          InboundValue(
                            'Quantidade armazenada',
                            task['actualQuantity'],
                          ),
                          InboundValue('Concluída em', task['completedAt']),
                        ],
                      ),
                    if (_actionError != null)
                      InboundErrorCard(error: _actionError!),
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

class _PutawayCompletePage extends ConsumerStatefulWidget {
  const _PutawayCompletePage({required this.task});

  final JsonMap task;

  @override
  ConsumerState<_PutawayCompletePage> createState() =>
      _PutawayCompletePageState();
}

class _PutawayCompletePageState extends ConsumerState<_PutawayCompletePage> {
  final _form = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _scannedLpn = TextEditingController();
  final _scannedDestination = TextEditingController();
  Object? _error;
  bool _submitting = false;

  @override
  void dispose() {
    for (final controller in [_quantity, _scannedLpn, _scannedDestination]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(operationCommandProvider)
          .run(
            '/api/putaway-tasks/${widget.task['id']}/complete',
            body: {
              // The operator confirms the full amount; preserve the server's value.
              'actualQuantity': widget.task['targetQuantity'],
              'scannedLpnCode': _scannedLpn.text.trim(),
              'scannedDestinationCode': _scannedDestination.text.trim(),
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
    final auth = ref.watch(authControllerProvider).value;
    final enabled =
        !_submitting &&
        (auth?.can('PUTAWAY_EXECUTE') ?? false) &&
        widget.task['assignedUserId'] == auth?.user?.id;
    return PopScope(
      canPop: !_submitting,
      child: Scaffold(
        appBar: AppBar(title: const Text('Concluir armazenagem')),
        body: SafeArea(
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                InboundPanel(
                  title: 'Confira o destino físico',
                  children: [
                    InboundValue('LPN esperado', widget.task['lpnCode']),
                    InboundValue(
                      'Posição de destino',
                      widget.task['destinationPositionCode'],
                    ),
                    InboundValue(
                      'Quantidade integral esperada',
                      widget.task['targetQuantity'],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Confira o conteúdo e registre os códigos presentes nas etiquetas. Leituras não são preenchidas automaticamente.',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                InboundScannerField(
                  controller: _scannedLpn,
                  label: 'Leitura da etiqueta do LPN',
                  enabled: enabled,
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Leia ou digite o código do LPN.';
                    }
                    return value!.trim() == widget.task['lpnCode']
                        ? null
                        : 'A etiqueta precisa corresponder ao LPN da tarefa.';
                  },
                ),
                InboundScannerField(
                  controller: _scannedDestination,
                  label: 'Leitura da posição de destino',
                  maxLength: 50,
                  enabled: enabled,
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Leia ou digite o código da posição.';
                    }
                    return value!.trim() ==
                            widget.task['destinationPositionCode']
                        ? null
                        : 'O código precisa corresponder ao destino indicado.';
                  },
                ),
                TextFormField(
                  controller: _quantity,
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Confirme a quantidade integral',
                    helperText:
                        'A armazenagem movimenta todo o conteúdo do LPN.',
                  ),
                  validator: (value) => integralPutawayQuantityError(
                    value,
                    widget.task['targetQuantity'],
                  ),
                ),
                const SizedBox(height: 20),
                if (_error != null) InboundErrorCard(error: _error!),
                FilledButton.icon(
                  onPressed: enabled ? _submit : null,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    _submitting
                        ? 'Concluindo armazenagem…'
                        : 'Concluir armazenagem',
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
