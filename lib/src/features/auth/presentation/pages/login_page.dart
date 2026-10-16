import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/branding/brand_tokens.dart';

import '../../application/auth_controller.dart';
import '../../domain/entities/auth_session.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_page_frame.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  bool _obscurePassword = true;
  AuthChallenge? _challenge;
  String? _localError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isLoading = auth.isLoading;
    final challenge = _challenge;
    return AuthPageFrame(
      title: challenge == null ? 'Entrar no WMS' : 'Confirme seu acesso',
      subtitle: challenge == null
          ? 'Entre com sua conta para iniciar a operação do armazém.'
          : 'Enviamos um código de seis dígitos para $challengeEmail.',
      footer: challenge == null
          ? Column(
              children: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          ref
                              .read(authControllerProvider.notifier)
                              .clearTransientError();
                          context.go('/forgot-password');
                        },
                  child: const Text('Esqueci minha senha'),
                ),
                const Text(
                  'Precisa de acesso? Solicite uma conta ao gestor.',
                  textAlign: TextAlign.center,
                ),
              ],
            )
          : TextButton(
              onPressed: isLoading ? null : _restart,
              child: const Text('Entrar novamente ou usar outra conta'),
            ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthErrorBanner(error: auth.error),
              if (auth.hasError) const SizedBox(height: 16),
              if (_localError != null) ...[
                Text(
                  _localError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 16),
              ],
              if (challenge == null) ...[
                TextFormField(
                  key: const ValueKey('login-email'),
                  controller: _emailController,
                  enabled: !isLoading,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [
                    AutofillHints.username,
                    AutofillHints.email,
                  ],
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
                        ? null
                        : 'Informe um e-mail válido.';
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const ValueKey('login-password'),
                  controller: _passwordController,
                  enabled: !isLoading,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) {
                    if (!isLoading) _submit();
                  },
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Mostrar senha'
                          : 'Ocultar senha',
                      onPressed: () => setState(() {
                        _obscurePassword = !_obscurePassword;
                      }),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) =>
                      (value ?? '').isEmpty ? 'Informe sua senha.' : null,
                ),
              ] else ...[
                TextFormField(
                  key: const ValueKey('login-code'),
                  style: const TextStyle(
                    fontFamily: AppBrand.monoFont,
                    fontSize: 20,
                    letterSpacing: 2,
                  ),
                  controller: _codeController,
                  enabled: !isLoading,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  onFieldSubmitted: (_) {
                    if (!isLoading) _submit();
                  },
                  decoration: const InputDecoration(
                    labelText: 'Código de verificação',
                    hintText: '000000',
                    prefixIcon: Icon(Icons.verified_user_outlined),
                  ),
                  validator: (value) => RegExp(r'^\d{6}$').hasMatch(value ?? '')
                      ? null
                      : 'Informe os seis dígitos do código.',
                ),
                const SizedBox(height: 12),
                Text(
                  'Código válido até ${_time(challenge.expiresAt)}. Até ${challenge.maxAttempts} tentativas. Confira também a caixa de spam.',
                ),
              ],
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: isLoading ? null : _submit,
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(challenge == null ? Icons.login : Icons.check),
                label: Text(
                  isLoading
                      ? 'Aguarde...'
                      : challenge == null
                      ? 'Continuar'
                      : 'Verificar e entrar',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get challengeEmail => _challenge?.maskedEmail ?? '';
  static String _time(DateTime date) {
    final local = date.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  void _restart() {
    ref.read(authControllerProvider.notifier).clearTransientError();
    setState(() {
      _challenge = null;
      _localError = null;
      _codeController.clear();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _localError = null;
    });
    final controller = ref.read(authControllerProvider.notifier);
    final challenge = _challenge;
    if (challenge == null) {
      final result = await controller.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted && result != null) {
        setState(() {
          _challenge = result;
          _passwordController.clear();
        });
      }
    } else if (challenge.isExpired) {
      setState(() {
        _localError = 'O código expirou. Entre novamente para receber outro.';
      });
    } else {
      await controller.verifyChallenge(
        challengeId: challenge.id,
        code: _codeController.text,
      );
      if (mounted &&
          (ref.read(authControllerProvider).value?.isAuthenticated ?? false)) {
        TextInput.finishAutofillContext();
        context.go('/dashboard');
      }
    }
  }
}
