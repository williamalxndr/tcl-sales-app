import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/ui/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _registerView = false;
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(authControllerProvider.notifier)
        .login(
          email: _emailController.text,
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _BrandHeader(),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _AuthTabs(
                            isRegister: _registerView,
                            onLogin: () =>
                                setState(() => _registerView = false),
                            onRegister: () =>
                                setState(() => _registerView = true),
                          ),
                          const SizedBox(height: 22),
                          if (_registerView)
                            const _RegisterNotice()
                          else
                            Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (auth.error != null) ...[
                                    _LoginError(error: auth.error!),
                                    const SizedBox(height: 16),
                                  ],
                                  const _FieldLabel('Email'),
                                  TextFormField(
                                    controller: _emailController,
                                    enabled: !auth.isSubmitting,
                                    autofillHints: const [
                                      AutofillHints.username,
                                    ],
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      hintText: 'nama@perusahaan.com',
                                    ),
                                    validator: _validateEmail,
                                  ),
                                  const SizedBox(height: 14),
                                  const _FieldLabel('Kata sandi'),
                                  TextFormField(
                                    controller: _passwordController,
                                    enabled: !auth.isSubmitting,
                                    autofillHints: const [
                                      AutofillHints.password,
                                    ],
                                    obscureText: _obscurePassword,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _submit(),
                                    decoration: InputDecoration(
                                      hintText: 'Masukkan kata sandi',
                                      suffixIcon: TextButton(
                                        onPressed: auth.isSubmitting
                                            ? null
                                            : () => setState(
                                                () => _obscurePassword =
                                                    !_obscurePassword,
                                              ),
                                        child: Text(
                                          _obscurePassword
                                              ? 'Lihat'
                                              : 'Sembunyikan',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    validator: _validatePassword,
                                  ),
                                  const SizedBox(height: 20),
                                  FilledButton(
                                    onPressed: auth.isSubmitting
                                        ? null
                                        : _submit,
                                    child: auth.isSubmitting
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Masuk'),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email wajib diisi.';
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
        ? null
        : 'Masukkan alamat email yang valid.';
  }

  String? _validatePassword(String? value) =>
      value == null || value.isEmpty ? 'Kata sandi wajib diisi.' : null;
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();
  @override
  Widget build(BuildContext context) => const Column(
    children: [
      Text(
        'PT Total Chemindo Loka',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      SizedBox(height: 2),
      Text(
        'Pengajuan Program Sales & Marketing',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12.5, color: AppColors.faint),
      ),
    ],
  );
}

class _AuthTabs extends StatelessWidget {
  const _AuthTabs({
    required this.isRegister,
    required this.onLogin,
    required this.onRegister,
  });
  final bool isRegister;
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFE0E5EA)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        _tab('Masuk', !isRegister, onLogin),
        _tab('Daftar', isRegister, onRegister),
      ],
    ),
  );
  Widget _tab(String label, bool active, VoidCallback tap) => Expanded(
    child: TextButton(
      onPressed: tap,
      style: TextButton.styleFrom(
        backgroundColor: active ? AppColors.softNavy : Colors.transparent,
        foregroundColor: active ? AppColors.navy : AppColors.muted,
        minimumSize: const Size(0, 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.muted,
      ),
    ),
  );
}

class _RegisterNotice extends StatelessWidget {
  const _RegisterNotice();
  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Pendaftaran akun',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      SizedBox(height: 6),
      Text(
        'Akun karyawan dibuat oleh administrator perusahaan. Hubungi administrator untuk mendapatkan akses.',
        style: TextStyle(color: AppColors.muted),
      ),
    ],
  );
}

class _LoginError extends StatelessWidget {
  const _LoginError({required this.error});
  final ApiException error;
  @override
  Widget build(BuildContext context) {
    final message = error.statusCode == 401
        ? 'Email atau kata sandi tidak valid.'
        : error.message;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F0),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: const Color(0xFFF1C4C0)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            message,
            style: const TextStyle(color: Color(0xFF9B1C1C)),
          ),
        ),
      ),
    );
  }
}
