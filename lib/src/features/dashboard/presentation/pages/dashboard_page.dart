import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/application/auth_controller.dart';
import '../../../operations/data/warehouse_repository.dart';
import '../../../operations/presentation/widgets/operational_modules.dart';

final _dashboardProvider = FutureProvider.autoDispose<List<_ModuleCount>>((
  ref,
) async {
  final auth = ref.watch(authControllerProvider).value;
  final repository = ref.watch(warehouseRepositoryProvider);
  final modules = operationalModules.where(
    (m) => m.pendingStatus != null && m.visible(auth),
  );
  return Future.wait(
    modules.map((module) async {
      try {
        final page = await repository.list(
          module.resource,
          size: 1,
          filters: {'status': module.pendingStatus!},
        );
        return _ModuleCount(module, page.totalElements, null);
      } catch (error) {
        return _ModuleCount(module, null, error);
      }
    }),
  );
});

class _ModuleCount {
  const _ModuleCount(this.module, this.count, this.error);
  final OperationalModule module;
  final int? count;
  final Object? error;
}

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).value;
    final counts = ref.watch(_dashboardProvider);
    final modules = operationalModules.where((module) => module.visible(auth));
    Future<void> refresh() async {
      ref.invalidate(_dashboardProvider);
      await ref.read(_dashboardProvider.future);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel operacional'),
        actions: [
          IconButton(
            tooltip: 'Atualizar painel',
            onPressed: refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF12201E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SEU ARMAZÉM',
                      style: TextStyle(
                        color: Color(0xFF9AE0CF),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Olá, ${auth?.user?.name ?? 'usuário'}',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Acompanhe as pendências e continue a operação.',
                      style: TextStyle(color: Color(0xFFD5DEDB)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Pendências atuais',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              const Text('Totais dos módulos disponíveis para o seu perfil.'),
              const SizedBox(height: 14),
              counts.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Text('$error'),
                data: (items) => items.isEmpty
                    ? const Text('Nenhuma fila disponível para seu perfil.')
                    : LayoutBuilder(
                        builder: (context, constraints) => Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final item in items)
                              SizedBox(
                                width: constraints.maxWidth < 330
                                    ? constraints.maxWidth
                                    : (constraints.maxWidth - 12) / 2,
                                child: _PendingCard(item: item),
                              ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 24),
              Text(
                'Acesso rápido',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final module in modules) ...[
                OperationalModuleTile(
                  module: module,
                  onTap: () => context.go(module.route),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.item});
  final _ModuleCount item;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.go(item.module.route),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              item.module.icon,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              item.count?.toString() ?? 'Indisponível',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              item.module.title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              item.error == null
                  ? (item.module.pendingStatus == 'ABERTA'
                        ? 'Expedições abertas'
                        : 'Pendentes')
                  : 'Atualize para tentar novamente',
            ),
          ],
        ),
      ),
    ),
  );
}
