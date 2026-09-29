import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/models/models.dart';
import 'core/theme/app_theme.dart';
import 'state/app_controller.dart';
import 'ui/auth/login_screen.dart';
import 'ui/onboarding/onboarding_screen.dart';
import 'ui/shell/app_shell.dart';

/// Raiz do NeyFlow. Decide entre autenticação, onboarding e o app principal.
class NeyFlowApp extends StatelessWidget {
  const NeyFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppController>(
      builder: (context, controller, _) {
        final mode = controller.themeMode;
        return MaterialApp(
          title: 'NeyFlow',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: switch (mode) {
            AppThemeMode.light => ThemeMode.light,
            AppThemeMode.dark => ThemeMode.dark,
            AppThemeMode.system => ThemeMode.system,
          },
          home: _Root(controller: controller),
        );
      },
    );
  }
}

class _Root extends StatelessWidget {
  final AppController controller;
  const _Root({required this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller.loading) {
      return const _Splash();
    }
    if (!controller.isAuthenticated) {
      return const LoginScreen();
    }
    if (!(controller.user?.onboardingCompleted ?? false)) {
      return const OnboardingScreen();
    }
    return const AppShell();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Text(
                  'N',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'NeyFlow',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sua vida financeira em movimento. Sob controle.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
