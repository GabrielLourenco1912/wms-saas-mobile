import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_session.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_page_frame.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  AuthChallenge? _challenge;
  Object? _error;
  bool _loading = false;
  bool _obscure = true;
  bool _complete = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final challenge = _challenge;
    return AuthPageFrame(
      title: _complete ? 'Senha redefinida' : 'Recuperar acesso',
      subtitle: _complete
          ? 'Sua nova senha está pronta. Entre novamente para confirmar o acesso.'
          : challenge == null
          ? 'Informe o e-mail cadastrado para receber um código de recuperação.'
          : 'Digite o código enviado para ${challenge.maskedEmail} e escolha uma nova senha.',
      footer: TextButton(
        onPressed: _loading ? null : () => context.go('/login'),
        child: const Text('Voltar para entrar'),
      ),
      child: _complete
          ? FilledButton(
              onPressed: () => context.go('/login'),
              child: const Text('Entrar com a nova senha'),
            )
          : Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthErrorBanner(error: _error),
                  if (_error != null) const SizedBox(height: 16),
                  if (challenge == null)
                    TextFormField(
                      key: const ValueKey('recovery-email'),
                      controller: _email,
                      enabled: !_loading,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      onFieldSubmitted: (_) {
                        if (!_loading) _submit();
                      },
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      validator: (value) =>
                          RegExp(
                            r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                          ).hasMatch(value?.trim() ?? '')
                          ? null
                          : 'Informe um e-mail válido.',
                    )
                  else ...[
                    TextFormField(
                      key: const ValueKey('recovery-code'),
                      controller: _code,
                      enabled: !_loading,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Código de recuperação',
                        hintText: '000000',
                      ),
                      validator: (value) =>
                          RegExp(r'^\d{6}$').hasMatch(value ?? '')
                          ? null
                          : 'Informe os seis dígitos do código.',
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const ValueKey('recovery-password'),
                      controller: _password,
                      enabled: !_loading,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'Nova senha',
                        helperText: 'Use pelo menos 8 caracteres.',
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
                          onPressed: () => setState(() {
                            _obscure = !_obscure;
                          }),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if ((value ?? '').length < 8) {
                          return 'Use pelo menos 8 caracteres.';
                        }
                        if (utf8.encode(value!).length > 72) {
                          return 'A senha deve ter até 72 bytes (acentos contam mais).';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const ValueKey('recovery-confirmation'),
                      controller: _confirmation,
                      enabled: !_loading,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      onFieldSubmitted: (_) {
                        if (!_loading) _submit();
                      },
                      decoration: const InputDecoration(
                        labelText: 'Confirme a nova senha',
                      ),
                      validator: (value) => value == _password.text
                          ? null
                          : 'As senhas precisam ser iguais.',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Código válido até ${_time(challenge.expiresAt)}. Até ${challenge.maxAttempts} tentativas.',
                    ),
                  ],
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: _loading ? null : _submit,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_reset),
                    label: Text(
                      _loading
                          ? 'Aguarde...'
                          : challenge == null
                          ? 'Enviar código'
                          : 'Redefinir senha',
                    ),
                  ),
                  if (challenge != null)
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() {
                              _challenge = null;
                              _error = null;
                              _code.clear();
                            }),
                      child: const Text('Solicitar outro código'),
                    ),
                ],
              ),
            ),
    );
  }

  static String _time(DateTime date) {
    final local = date.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    final repository = ref.read(authRepositoryProvider);
    try {
      final challenge = _challenge;
      if (challenge == null) {
        final result = await repository.forgotPassword(_email.text.trim());
        if (mounted) {
          setState(() {
            _challenge = result;
          });
        }
      } else {
        if (challenge.isExpired) {
          throw const FormatException(
            'O código expirou. Solicite outro código.',
          );
        }
        await repository.resetPassword(
          challengeId: challenge.id,
          code: _code.text,
          newPassword: _password.text,
        );
        if (mounted) {
          setState(() {
            _complete = true;
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }
}
