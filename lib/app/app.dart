import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/settings/app_settings.dart';
import '../core/settings/app_text.dart';
import '../shared/widgets/kenlab_mark.dart';
import 'home_screen.dart';

class KenLabApp extends StatelessWidget {
  const KenLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final scheme = ColorScheme.fromSeed(
          seedColor: settings.primaryColor,
          brightness: Brightness.light,
        ).copyWith(secondary: settings.accentColor);
        return MaterialApp(
          title: 'KenLab',
          locale: Locale(settings.languageCode),
          supportedLocales: const [Locale('es'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: scheme,
            scaffoldBackgroundColor: const Color(0xFFF3F5F7),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFF3F5F7),
              foregroundColor: Color(0xFF17212B),
              elevation: 0,
            ),
            cardTheme: CardThemeData(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0xFFE5E9ED)),
              ),
            ),
          ),
          home: const _AppEntry(),
        );
      },
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: _showSplash
          ? const StartupSplash(key: ValueKey('splash'))
          : const HomeScreen(key: ValueKey('home')),
    );
  }
}

class StartupSplash extends StatelessWidget {
  const StartupSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFC62828),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const KenLabMark(
                size: 120, color: Colors.white, accent: Color(0xFFFFD9D9)),
            const SizedBox(height: 18),
            Text(
              'KenLab',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              appText(context, 'HERRAMIENTAS DE CAMPO', 'FIELD TOOLS'),
              style: const TextStyle(
                color: Color(0xFFFFD9D9),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
