import 'package:flutter/material.dart';

class OperationsPage extends StatelessWidget {
  const OperationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Operação')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: const [
            _ScannerAction(),
            SizedBox(height: 20),
            _ModuleTile(
              icon: Icons.move_to_inbox_outlined,
              title: 'Recebimento',
              subtitle: 'Conferência, divergências e liberação de doca',
              accent: Color(0xFF2563EB),
            ),
            SizedBox(height: 10),
            _ModuleTile(
              icon: Icons.shelves,
              title: 'Armazenagem',
              subtitle: 'Endereçamento, put-away e reposição',
              accent: Color(0xFF0F766E),
            ),
            SizedBox(height: 10),
            _ModuleTile(
              icon: Icons.shopping_cart_checkout_outlined,
              title: 'Picking',
              subtitle: 'Ondas, rotas, volumes e separação guiada',
              accent: Color(0xFFF59E0B),
            ),
            SizedBox(height: 10),
            _ModuleTile(
              icon: Icons.local_shipping_outlined,
              title: 'Expedição',
              subtitle: 'Packing, carga, romaneio e despacho',
              accent: Color(0xFF7C3AED),
            ),
            SizedBox(height: 10),
            _ModuleTile(
              icon: Icons.fact_check_outlined,
              title: 'Inventário',
              subtitle: 'Contagem cíclica e reconciliação de saldo',
              accent: Color(0xFFB42318),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerAction extends StatelessWidget {
  const _ScannerAction();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.qr_code_scanner,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Leitura rápida',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Preparado para código de barras, QR Code e etiqueta logística.',
                  style: TextStyle(color: Color(0xFFE4F2EF), height: 1.25),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white),
        ],
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accent),
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
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
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
              const Icon(Icons.chevron_right, color: Color(0xFF8A9692)),
            ],
          ),
        ),
      ),
    );
  }
}
