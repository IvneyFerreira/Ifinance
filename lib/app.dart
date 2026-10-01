import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/models/models.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'state/app_controller.dart';
import 'ui/auth/lock_screen.dart';
import 'ui/auth/login_screen.dart';
import 'ui/onboarding/onboarding_screen.dart';
import 'ui/shell/app_shell.dart';

/// Raiz do IFinance. Decide entre autenticação, onboarding e o app principal.
class IFinanceApp extends StatelessWidget {
  const IFinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppController>(
      builder: (context, controller, _) {
        final mode = controller.themeMode;
        return MaterialApp(
          title: 'IFinance',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: switch (mode) {
            AppThemeMode.light => ThemeMode.light,
            AppThemeMode.dark => ThemeMode.dark,
            AppThemeMode.system => ThemeMode.system,
          },
          // Datas no padrão brasileiro em TODO o app, inclusive nos diálogos do
          // sistema (date picker, etc.): pt-BR como idioma e localidade fixos.
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: _Root(controller: controller),
        );
      },
    );
  }
}

class _Root extends StatefulWidget {
  final AppController controller;
  const _Root({required this.controller});

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-bloqueia ao sair do app (proteção de privacidade — cap. 71).
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      widget.controller.lockNow();
    }
    // Garante a foto automática dos dados quando o app sai de cena (cap. 73),
    // para que nenhuma alteração recente se perca entre versões/atualizações.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      widget.controller.flushSnapshot();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (controller.loading) {
      return const _Splash();
    }
    if (!controller.isAuthenticated) {
      return const LoginScreen();
    }
    if (!(controller.user?.onboardingCompleted ?? false)) {
      return const OnboardingScreen();
    }
    if (controller.locked) {
      return const LockScreen();
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
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: 88,
                height: 88,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'IFinance',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Controle financeiro na palma da sua mão',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 2),
            Text(
              'By Ivoney Ferreira',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.gray400,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
