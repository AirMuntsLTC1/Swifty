import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_twitter_clone/supabase/screens/auth_widgets.dart';
import 'package:flutter_twitter_clone/supabase/supabase_auth_service.dart';

enum _SignUpStep { details, code, password }

/// Sign-up flow: details -> 6-digit email code -> password.
class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final _service = SupabaseAuthService.instance;
  final _detailsKey = GlobalKey<FormState>();
  final _passwordKey = GlobalKey<FormState>();

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _displayName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  _SignUpStep _step = _SignUpStep.details;
  bool _busy = false;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [
      _firstName,
      _lastName,
      _displayName,
      _username,
      _email,
      _code,
      _password,
      _confirm,
    ]) {
      c.dispose();
    }
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
    if (!_detailsKey.currentState!.validate()) return;
    await _run(() async {
      final wait = await _service.sendCode(
        email: _email.text.trim(),
        purpose: 'signup',
        username: _username.text.trim().toLowerCase(),
        displayName: _displayName.text.trim(),
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
      );
      if (!mounted) return;
      setState(() => _step = _SignUpStep.code);
      _startCooldown(wait);
      showAuthMessage(context, 'We sent a 6-digit code to ${_email.text.trim()}');
    });
  }

  Future<void> _resendCode() async {
    await _run(() async {
      final wait = await _service.sendCode(
        email: _email.text.trim(),
        purpose: 'signup',
        username: _username.text.trim().toLowerCase(),
        displayName: _displayName.text.trim(),
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
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
        purpose: 'signup',
      );
      if (mounted) setState(() => _step = _SignUpStep.password);
    });
  }

  Future<void> _createAccount() async {
    if (!_passwordKey.currentState!.validate()) return;
    await _run(() async {
      await _service.createAccount(
        email: _email.text.trim(),
        password: _password.text,
      );
      // Signed in: close this flow and let the auth gate show the app.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    });
  }

  String? _validateName(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Required';
    if (t.length > 40) return 'Keep it under 40 characters';
    return null;
  }

  String? _validateUsername(String? v) {
    final t = (v ?? '').trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_.]{3,30}$').hasMatch(t)) {
      return '3–30 letters, numbers, dots or underscores';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create account',
      child: switch (_step) {
        _SignUpStep.details => _details(),
        _SignUpStep.code => _codeStep(),
        _SignUpStep.password => _passwordStep(),
      },
    );
  }

  Widget _details() {
    return Form(
      key: _detailsKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _firstName,
                  decoration: const InputDecoration(labelText: 'First name'),
                  validator: _validateName,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _lastName,
                  decoration: const InputDecoration(labelText: 'Last name'),
                  validator: _validateName,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _displayName,
            decoration: const InputDecoration(labelText: 'Display name'),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Required'
                : (v.trim().length > 60 ? 'Keep it under 60 characters' : null),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _username,
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixText: '@',
            ),
            validator: _validateUsername,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: validateEmail,
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: 'Send verification code',
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
          'Enter the 6-digit code sent to ${_email.text.trim()}. '
          'It expires in 10 minutes.',
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
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() => _step = _SignUpStep.details),
          child: const Text('Change email'),
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
            'Email verified. Choose a password for your account.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
            validator: validatePassword,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirm,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirm password'),
            validator: (v) =>
                v != _password.text ? 'Passwords do not match' : null,
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: 'Create account',
            busy: _busy,
            onPressed: _createAccount,
          ),
        ],
      ),
    );
  }
}
