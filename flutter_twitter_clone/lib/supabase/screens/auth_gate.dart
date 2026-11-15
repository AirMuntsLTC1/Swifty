import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_twitter_clone/config/supabase_config.dart';
import 'package:flutter_twitter_clone/supabase/screens/sign_in_page.dart';
import 'package:flutter_twitter_clone/ui/page/homePage.dart';

/// Shows the app when a Supabase session exists, otherwise the sign-in screen.
class SupabaseAuthGate extends StatelessWidget {
  const SupabaseAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (!SupabaseConfig.isConfigured) {
      return const _NotConfiguredView();
    }
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, _) {
        final signedIn = auth.currentSession != null;
        return signedIn ? const HomePage() : const SignInPage();
      },
    );
  }
}

class _NotConfiguredView extends StatelessWidget {
  const _NotConfiguredView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Supabase is not configured.\n\n'
            'Set SUPABASE_URL and SUPABASE_ANON_KEY in\n'
            'lib/config/supabase_config.dart, then rebuild.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}


