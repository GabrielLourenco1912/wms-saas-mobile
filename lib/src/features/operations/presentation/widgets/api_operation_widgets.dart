import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/application/auth_controller.dart';
import '../../data/warehouse_repository.dart';

class ApiResourceListPage extends ConsumerStatefulWidget {
  const ApiResourceListPage({
    super.key,
    required this.title,
    required this.resource,
    required this.permission,
    this.searchHint = 'Pesquisar',
    this.statuses = const [],
    this.filters = const {},
    this.itemBuilder,
    this.onOpen,
    this.titleBuilder,
    this.subtitleBuilder,
    this.actions = const [],
  });
  final String title, resource, permission, searchHint;
  final List<String> statuses;
  final Map<String, String> filters;
  final Widget Function(BuildContext, WidgetRef, JsonMap)? itemBuilder;
  final FutureOr<void> Function(BuildContext, WidgetRef, JsonMap)? onOpen;
  final String Function(JsonMap)? titleBuilder, subtitleBuilder;
  final List<Widget> actions;

  @override
  ConsumerState<ApiResourceListPage> createState() =>
      _ApiResourceListPageState();
}

class _ApiResourceListPageState extends ConsumerState<ApiResourceListPage> {
  final _search = TextEditingController();
  Timer? _debounce;
  int _page = 0;
  String _q = '', _status = '';
  Future<ApiPage<JsonMap>>? _result;
  Object? _repository;
  String? _identity;
  bool _hadPermission = false;

  Future<void> _reload() async {
    if (!mounted ||
        !(ref.read(authControllerProvider).value?.can(widget.permission) ??
            false)) {
      return;
    }
    final pending = ref
        .read(warehouseRepositoryProvider)
        .list(
          widget.resource,
          page: _page,
          q: _q,
          filters: {
            ...widget.filters,
            if (_status.isNotEmpty) 'status': _status,
          },
        );
    setState(() {
      _result = pending;
    });
    try {
      await pending;
    } catch (_) {
      /* FutureBuilder presents failures. */
    }
  }

  @override
  void didUpdateWidget(covariant ApiResourceListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resource != widget.resource ||
        !mapEquals(oldWidget.filters, widget.filters)) {
      _page = 0;
      _result = null;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allowed =
        ref.watch(authControllerProvider).value?.can(widget.permission) ??
        false;
    final identity = ref.watch(authControllerProvider).value?.user?.id;
    final repository = ref.watch(warehouseRepositoryProvider);
    if (_repository != repository ||
        _identity != identity ||
        allowed != _hadPermission) {
      _debounce?.cancel();
      if (_identity != identity) {
        _search.clear();
        _q = '';
        _status = '';
      }
      _identity = identity;
      _hadPermission = allowed;
      _repository = repository;
      _result = null;
      _page = 0;
    }
    if (allowed) {
      _result ??= repository.list(
        widget.resource,
        page: _page,
        q: _q,
        filters: {...widget.filters, if (_status.isNotEmpty) 'status': _status},
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          ...widget.actions,
          if (allowed)
            IconButton(
              tooltip: 'Atualizar',
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: !allowed
          ? const ApiFeedback(
              message: 'Seu perfil não tem acesso a esta consulta.',
              icon: Icons.lock_outline,
            )
          : SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      children: [
                        TextField(
                          controller: _search,
                          maxLength: 160,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            labelText: widget.searchHint,
                            counterText: '',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: IconButton(
                              tooltip: 'Limpar pesquisa',
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _debounce?.cancel();
                                _search.clear();
                                _q = '';
                                _page = 0;
                                _reload();
                              },
                            ),
                          ),
                          onChanged: (value) {
                            _debounce?.cancel();
                            _debounce = Timer(
                              const Duration(milliseconds: 350),
                              () {
                                _q = value.trim();
                                _page = 0;
                                _reload();
                              },
                            );
                          },
                          onSubmitted: (value) {
                            _debounce?.cancel();
                            _q = value.trim();
                            _page = 0;
                            _reload();
                          },
                        ),
                        if (widget.statuses.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            key: ValueKey(identity),
                            initialValue: _status,
                            decoration: const InputDecoration(
                              labelText: 'Situação',
                            ),
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('Todas as situações'),
                              ),
                              ...widget.statuses.map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(operationStatusLabel(s)),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              _status = value ?? '';
                              _page = 0;
                              _reload();
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder<ApiPage<JsonMap>>(
                      future: _result,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return ApiFeedback(
                            message: '${snapshot.error}',
                            onRetry: _reload,
                          );
                        }
                        final result = snapshot.requireData;
                        return Column(
                          children: [
                            Expanded(
                              child: RefreshIndicator(
                                onRefresh: _reload,
                                child: ListView.separated(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(16),
                                  itemCount: result.content.isEmpty
                                      ? 1
                                      : result.content.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    if (result.content.isEmpty) {
                                      return const Padding(
                                        padding: EdgeInsets.all(24),
                                        child: Text(
                                          'Nenhum registro encontrado. Revise os filtros ou atualize a consulta.',
                                          textAlign: TextAlign.center,
                                        ),
                                      );
                                    }
                                    final item = result.content[index];
                                    final tap = widget.onOpen == null
                                        ? null
                                        : () async {
                                            await widget.onOpen!(
                                              context,
                                              ref,
                                              item,
                                            );
                                            if (mounted) await _reload();
                                          };
                                    if (widget.itemBuilder != null) {
                                      final child = widget.itemBuilder!(
                                        context,
                                        ref,
                                        item,
                                      );
                                      return tap == null
                                          ? child
                                          : InkWell(onTap: tap, child: child);
                                    }
                                    return Card(
                                      child: ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                        title: Text(
                                          widget.titleBuilder?.call(item) ??
                                              '${item['documentNumber'] ?? item['name'] ?? item['id']}',
                                        ),
                                        subtitle: Text(
                                          widget.subtitleBuilder?.call(item) ??
                                              operationStatusLabel(
                                                '${item['status'] ?? ''}',
                                              ),
                                        ),
                                        trailing: tap == null
                                            ? null
                                            : const Icon(Icons.chevron_right),
                                        onTap: tap,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            ApiPageControls(
                              page: result,
                              onPage: (page) {
                                _page = page;
                                _reload();
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class ApiPageControls extends StatelessWidget {
  const ApiPageControls({super.key, required this.page, required this.onPage});
  final ApiPage page;
  final ValueChanged<int> onPage;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Página anterior',
          onPressed: page.first ? null : () => onPage(page.page - 1),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            '${page.totalElements} registros · ${page.totalPages == 0 ? 0 : page.page + 1}/${page.totalPages}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        IconButton(
          tooltip: 'Próxima página',
          onPressed: page.last ? null : () => onPage(page.page + 1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );
}

class ApiFeedback extends StatelessWidget {
  const ApiFeedback({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.cloud_off_outlined,
  });
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(message, textAlign: TextAlign.center),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ],
      ),
    ),
  );
}

class ApiLookupField extends ConsumerWidget {
  const ApiLookupField({
    super.key,
    required this.resource,
    required this.label,
    required this.onChanged,
    this.value,
    this.filters = const {},
    this.enabled = true,
    this.isRequired = false,
    this.helperText,
    this.validator,
  });
  final String resource, label;
  final ValueChanged<LookupOption?> onChanged;
  final LookupOption? value;
  final Map<String, String> filters;
  final bool enabled, isRequired;
  final String? helperText;
  final FormFieldValidator<LookupOption>? validator;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canSelect =
        enabled &&
        (ref
                .watch(authControllerProvider)
                .value
                ?.can(_lookupPermission(resource)) ??
            false);
    return FormField<LookupOption>(
      key: ValueKey('${value?.id}-$resource-${filters.toString()}'),
      initialValue: value,
      enabled: canSelect,
      validator:
          validator ??
          (option) => isRequired && option == null ? 'Selecione $label.' : null,
      builder: (field) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: !canSelect
              ? null
              : () async {
                  final selected = await showDialog<LookupOption>(
                    context: context,
                    builder: (_) => _LookupDialog(
                      resource: resource,
                      label: label,
                      filters: filters,
                    ),
                  );
                  if (selected != null && context.mounted) {
                    field.didChange(selected);
                    onChanged(selected);
                  }
                },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              enabled: canSelect,
              errorText: field.errorText,
              helperText: helperText,
              helperMaxLines: 3,
              suffixIcon: value != null && canSelect
                  ? IconButton(
                      tooltip: 'Limpar $label',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        field.didChange(null);
                        onChanged(null);
                      },
                    )
                  : const Icon(Icons.expand_more),
            ),
            child: Semantics(
              button: true,
              label: label,
              child: Text(
                value?.label ?? 'Selecionar',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LookupDialog extends ConsumerStatefulWidget {
  const _LookupDialog({
    required this.resource,
    required this.label,
    required this.filters,
  });
  final String resource, label;
  final Map<String, String> filters;
  @override
  ConsumerState<_LookupDialog> createState() => _LookupDialogState();
}

class _LookupDialogState extends ConsumerState<_LookupDialog> {
  Timer? _debounce;
  final _search = TextEditingController();
  int _page = 0;
  String _q = '';
  Future<ApiPage<LookupOption>>? _result;
  late final String? _owner;
  bool get _allowed {
    final auth = ref.read(authControllerProvider).value;
    return _owner != null &&
        auth?.user?.id == _owner &&
        (auth?.can(_lookupPermission(widget.resource)) ?? false);
  }

  Future<ApiPage<LookupOption>> _load() => ref
      .read(warehouseRepositoryProvider)
      .lookup(widget.resource, page: _page, q: _q, filters: widget.filters);
  @override
  void initState() {
    super.initState();
    _owner = ref.read(authControllerProvider).value?.user?.id;
    if (_allowed) _result = _load();
  }

  void _reload() {
    if (mounted && _allowed) {
      setState(() {
        _result = _load();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authControllerProvider);
    if (!_allowed) {
      _debounce?.cancel();
      return AlertDialog(
        title: const Text('Seleção indisponível'),
        content: const Text(
          'Sua sessão ou permissão mudou. Feche esta seleção e atualize a operação.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      );
    }
    return Dialog(
      child: SizedBox(
        width: 480,
        height: MediaQuery.sizeOf(context).height * .75,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.label,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar seleção',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _search,
                autofocus: true,
                maxLength: 160,
                decoration: const InputDecoration(
                  labelText: 'Pesquisar opções',
                  prefixIcon: Icon(Icons.search),
                  counterText: '',
                ),
                onChanged: (value) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 350), () {
                    _page = 0;
                    _q = value.trim();
                    _reload();
                  });
                },
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<ApiPage<LookupOption>>(
                  future: _result,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return ApiFeedback(
                        message: '${snapshot.error}',
                        onRetry: _reload,
                      );
                    }
                    final page = snapshot.requireData;
                    return Column(
                      children: [
                        Expanded(
                          child: page.content.isEmpty
                              ? const Center(
                                  child: Text('Nenhuma opção encontrada.'),
                                )
                              : ListView(
                                  children: page.content
                                      .map(
                                        (option) => ListTile(
                                          title: Text(option.label),
                                          onTap: () {
                                            if (_allowed) {
                                              Navigator.pop(context, option);
                                            }
                                          },
                                          trailing: const Icon(
                                            Icons.chevron_right,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                        ),
                        ApiPageControls(
                          page: page,
                          onPage: (value) {
                            _page = value;
                            _reload();
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _lookupPermission(String resource) => switch (resource) {
  'positions' || 'zones' || 'warehouses' => 'WAREHOUSE_VIEW',
  'products' || 'categories' || 'product-packages' => 'PRODUCT_VIEW',
  'lpns' || 'stock' || 'stock-blocks' => 'STOCK_VIEW',
  'users' => 'USER_VIEW',
  'profiles' || 'permissions' => 'PROFILE_VIEW',
  'orders' || 'partners' => 'ORDER_VIEW',
  'waves' => 'WAVE_VIEW',
  'picking-tasks' || 'divergences' => 'PICKING_VIEW',
  'shipments' => 'SHIPMENT_VIEW',
  'transfers' => 'TRANSFER_VIEW',
  'inventories' => 'INVENTORY_VIEW',
  'stock-transactions' => 'AUDIT_VIEW',
  'receipts' => 'RECEIPT_VIEW',
  'pre-receipts' => 'PRE_RECEIPT_VIEW',
  'putaway-tasks' => 'PUTAWAY_VIEW',
  'tasks' => 'TASK_VIEW',
  _ => '',
};

String operationStatusLabel(String status) => switch (status) {
  'PENDENTE' => 'Pendente',
  'EM_RECEBIMENTO' => 'Em recebimento',
  'EM_EXECUCAO' => 'Em execução',
  'CONCLUIDA' || 'CONCLUIDO' => 'Concluído',
  'CANCELADA' || 'CANCELADO' => 'Cancelado',
  'ABERTA' => 'Aberta',
  'CONFERIDA' => 'Conferida',
  'DESPACHADA' => 'Despachada',
  'ATENDIDO' => 'Atendido',
  'EM_CONTAGEM' => 'Em contagem',
  'DIVERGENTE' => 'Divergente',
  _ => status.replaceAll('_', ' '),
};
