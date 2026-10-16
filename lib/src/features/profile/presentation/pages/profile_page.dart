import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../auth/application/auth_controller.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});
  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _refreshing = false;
  bool _loggingOut = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value?.user;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Meu perfil')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: colors.primaryContainer,
                            child: Icon(
                              Icons.person_outline,
                              color: colors.onPrimaryContainer,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.name ?? 'Seu perfil',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user?.email ?? '',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.badge_outlined),
                        title: const Text('Perfil de acesso'),
                        subtitle: Text(_profile(user?.profileCode)),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.verified_user_outlined),
                        title: const Text('Situação da conta'),
                        subtitle: Text(_status(user?.status)),
                      ),
                      OutlinedButton.icon(
                        onPressed: _refreshing || _loggingOut ? null : _reload,
                        icon: _refreshing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh),
                        label: const Text('Atualizar permissões'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.security_outlined),
                  title: const Text('Minhas permissões'),
                  subtitle: Text(
                    '${user?.permissions.length ?? 0} permissões concedidas pelo gestor',
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: (user?.permissions.toList() ?? [])
                            .map(
                              (permission) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Text(
                                  _permissionLabel(permission),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.onError,
                ),
                onPressed: _loggingOut ? null : _logout,
                icon: const Icon(Icons.logout),
                label: Text(_loggingOut ? 'Saindo...' : 'Sair da conta'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _profile(String? code) => switch (code) {
    'GESTOR' => 'Gestor',
    'OPERADOR' => 'Operador',
    _ => code ?? 'Não disponível',
  };

  String _permissionLabel(String code) {
    const resources = {
      'WAREHOUSE': 'estrutura do armazém',
      'PRODUCT': 'produtos',
      'ORDER': 'pedidos',
      'PRE_RECEIPT': 'pré-recebimento',
      'RECEIPT': 'recebimento',
      'PUTAWAY': 'armazenagem',
      'PICKING': 'separação',
      'SHIPMENT': 'expedição',
      'STOCK': 'estoque',
      'WAVE': 'ondas',
      'TRANSFER': 'transferências',
      'TASK': 'tarefas',
      'INVENTORY': 'inventário',
      'AUDIT': 'auditoria',
      'USER': 'usuários',
      'PROFILE': 'perfis de acesso',
    };
    const actions = {
      'VIEW': 'Consultar',
      'CREATE': 'Criar',
      'EDIT': 'Editar',
      'EXECUTE': 'Executar',
      'CANCEL': 'Cancelar',
      'RELEASE': 'Liberar',
      'APPROVE': 'Autorizar',
      'PROFILE_ASSIGN': 'Atribuir perfil a',
      'ASSIGN': 'Atribuir',
    };
    for (final resource
        in resources.keys.toList()
          ..sort((a, b) => b.length.compareTo(a.length))) {
      if (code.startsWith('${resource}_')) {
        final action = code.substring(resource.length + 1);
        return '${actions[action] ?? action.toLowerCase().replaceAll('_', ' ')} ${resources[resource]}';
      }
    }
    return code.toLowerCase().replaceAll('_', ' ');
  }

  String _status(String? value) => switch (value) {
    'ACTIVE' => 'Ativa',
    'INVITED' => 'Aguardando verificação',
    'DISABLED' => 'Desativada',
    'LOCKED' => 'Bloqueada',
    _ => value ?? 'Não disponível',
  };

  Future<void> _reload() async {
    setState(() {
      _refreshing = true;
    });
    try {
      await ref.read(authControllerProvider.notifier).reloadUser();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is ApiException
                  ? error.displayMessage
                  : 'Não foi possível atualizar o perfil.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    setState(() {
      _loggingOut = true;
    });
    try {
      await ref.read(authControllerProvider.notifier).logout();
    } catch (_) {
      // Local credentials have already been removed, even without connectivity.
    } finally {
      if (mounted) {
        setState(() {
          _loggingOut = false;
        });
      }
    }
  }
}
