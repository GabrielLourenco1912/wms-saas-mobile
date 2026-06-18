import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/application/auth_controller.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).value?.session;
    final shortUser = _shortSubject(session?.subject);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel operacional'),
        actions: [
          IconButton(
            tooltip: 'Ler etiqueta',
            onPressed: () {},
            icon: const Icon(Icons.qr_code_scanner),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: [
            _OperationalHeader(shortUser: shortUser),
            const SizedBox(height: 18),
            Text(
              'Indicadores de hoje',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 520;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: isWide ? 4 : 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: isWide ? 1.12 : 1.22,
                  children: const [
                    _MetricCard(
                      label: 'Pedidos',
                      value: '128',
                      caption: 'em separação',
                      icon: Icons.assignment_outlined,
                      color: Color(0xFF2563EB),
                    ),
                    _MetricCard(
                      label: 'Docas',
                      value: '7/12',
                      caption: 'ocupadas',
                      icon: Icons.local_shipping_outlined,
                      color: Color(0xFFF59E0B),
                    ),
                    _MetricCard(
                      label: 'Acurácia',
                      value: '98,4%',
                      caption: 'inventário',
                      icon: Icons.fact_check_outlined,
                      color: Color(0xFF0F766E),
                    ),
                    _MetricCard(
                      label: 'Alertas',
                      value: '4',
                      caption: 'prioridade alta',
                      icon: Icons.priority_high_rounded,
                      color: Color(0xFFB42318),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 22),
            Text(
              'Fila operacional',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const _TaskTile(
              icon: Icons.move_to_inbox_outlined,
              title: 'Recebimento BR-2041',
              subtitle: '12 pallets aguardando conferência',
              status: 'Prioridade',
              color: Color(0xFFB42318),
            ),
            const SizedBox(height: 10),
            const _TaskTile(
              icon: Icons.route_outlined,
              title: 'Onda de picking 18',
              subtitle: '32 pedidos liberados para separação',
              status: 'Em curso',
              color: Color(0xFF2563EB),
            ),
            const SizedBox(height: 10),
            const _TaskTile(
              icon: Icons.inventory_2_outlined,
              title: 'Inventário cíclico A-07',
              subtitle: 'Endereços com divergência recente',
              status: 'Hoje',
              color: Color(0xFF0F766E),
            ),
          ],
        ),
      ),
    );
  }

  String _shortSubject(String? subject) {
    if (subject == null || subject.isEmpty) {
      return 'usuário';
    }
    return subject.length <= 8 ? subject : subject.substring(0, 8);
  }
}

class _OperationalHeader extends StatelessWidget {
  const _OperationalHeader({required this.shortUser});

  final String shortUser;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF12201E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF203A35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 9, color: colorScheme.secondary),
                    const SizedBox(width: 8),
                    const Text(
                      'Operação ativa',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '#$shortUser',
                style: const TextStyle(
                  color: Color(0xFFB7C7C2),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Visão rápida do armazém',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Monitore gargalos, prioridades e tarefas críticas antes de entrar nos módulos operacionais.',
            style: TextStyle(color: Color(0xFFD5DEDB), height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 19),
                ),
                const Spacer(),
                Icon(Icons.trending_up, size: 18, color: color),
              ],
            ),
            const Spacer(),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: const Color(0xFF12201E),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF63706C), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF63706C),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
