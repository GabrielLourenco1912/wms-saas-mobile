import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/application/auth_controller.dart';
import '../widgets/operational_modules.dart';

class OperationsPage extends ConsumerWidget {
  const OperationsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).value;
    final modules = operationalModules.where((module) => module.visible(auth));
    return Scaffold(
      appBar: AppBar(title: const Text('Operação')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.barcode_reader, size: 30),
                    SizedBox(height: 12),
                    Text(
                      'Leitura durante a operação',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Abra a tarefa e informe os códigos nos campos de conferência. Você pode digitar ou usar um leitor conectado como teclado.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Módulos disponíveis',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (modules.isEmpty)
              const Text(
                'Seu perfil ainda não possui acesso aos módulos operacionais. Consulte o gestor.',
              ),
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
    );
  }
}
