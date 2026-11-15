import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_twitter_clone/supabase/screens/auth_widgets.dart';
import 'package:flutter_twitter_clone/supabase/supabase_auth_service.dart';

enum _ResetStep { email, code, password }

/// Password reset flow: email -> 6-digit code -> new password.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _service = SupabaseAuthService.instance;
  final _emailKey = GlobalKey<FormState>();
  final _passwordKey = GlobalKey<FormState>();

  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  _ResetStep _step = _ResetStep.email;
  bool _busy = false;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _timer?.cancel();
    setState(() => _resendIn = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendIn <= 1) {
        t.cancel();
        setState(() => _resendIn = 0);
      } else {
        setState(() => _resendIn--);
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on SwiflyAuthError catch (e) {
      if (mounted) showAuthMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() async {
    if (!_emailKey.currentState!.validate()) return;
    await _run(() async {
      final wait = await _service.sendCode(
        email: _email.text.trim(),
        purpose: 'password_reset',
      );
      if (!mounted) return;
      setState(() => _step = _ResetStep.code);
      _startCooldown(wait);
      showAuthMessage(
        context,
        'If an account exists for this email, a code has been sent.',
      );
    });
  }

  Future<void> _resendCode() async {
    await _run(() async {
      final wait = await _service.sendCode(
        email: _email.text.trim(),
        purpose: 'password_reset',
      );
      if (mounted) _startCooldown(wait);
    });
  }

  Future<void> _verifyCode() async {
    final code = _code.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      showAuthMessage(context, 'Enter the 6-digit code from your email.');
      return;
    }
    await _run(() async {
      await _service.checkCode(
        email: _email.text.trim(),
        code: code,
        purpose: 'password_reset',
      );
      if (mounted) setState(() => _step = _ResetStep.password);
    });
  }

  Future<void> _resetPassword() async {
    if (!_passwordKey.currentState!.validate()) return;
    await _run(() async {
      await _service.resetPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      // Signed in: close this flow and let the auth gate show the app.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Reset password',
      child: switch (_step) {
        _ResetStep.email => _emailStep(),
        _ResetStep.code => _codeStep(),
        _ResetStep.password => _passwordStep(),
      },
    );
  }

  Widget _emailStep() {
    return Form(
      key: _emailKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Enter the email for your account and we will send a 6-digit code.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: validateEmail,
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: 'Send code',
            busy: _busy,
            onPressed: _sendCode,
          ),
        ],
      ),
    );
  }

  Widget _codeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter the 6-digit code sent to ${_email.text.trim()}.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 8),
          decoration: const InputDecoration(counterText: ''),
          onSubmitted: (_) => _verifyCode(),
        ),
        const SizedBox(height: 16),
        AuthPrimaryButton(
          label: 'Verify',
          busy: _busy,
          onPressed: _verifyCode,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: (_busy || _resendIn > 0) ? null : _resendCode,
          child: Text(
            _resendIn > 0 ? 'Resend code in ${_resendIn}s' : 'Resend code',
          ),
        ),
      ],
    );
  }

  Widget _passwordStep() {
    return Form(
      key: _passwordKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Code verified. Choose a new password.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New password'),
            validator: validatePassword,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirm,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirm new password'),
            validator: (v) =>
                v != _password.text ? 'Passwords do not match' : null,
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: 'Set new password',
            busy: _busy,
            onPressed: _resetPassword,
          ),
        ],
      ),
    );
  }
}




