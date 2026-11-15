import 'package:material_ui/material_ui.dart';
import 'package:flutter_twitter_clone/widgets/brand/swifly_brand.dart';

/// Shared layout for the sign-in, sign-up and reset screens.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

void showAuthMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String? validateEmail(String? value) {
  final v = (value ?? '').trim();
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)) {
    return 'Enter a valid email address';
  }
  return null;
}

String? validatePassword(String? value) {
  final v = value ?? '';
  if (v.length < 8) return 'Password must be at least 8 characters';
  if (v.length > 128) return 'Password must be 128 characters or fewer';
  return null;
}

/// Big primary button that shows a spinner while [busy].
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: SwiflyBrand.blue, strokeWidth: 2),
              )
            : Text(label),
      ),
    );
  }
}
