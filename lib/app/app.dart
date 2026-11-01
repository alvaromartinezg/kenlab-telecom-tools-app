import 'package:flutter/material.dart';

import '../shared/widgets/kenlab_mark.dart';
import 'home_screen.dart';

class KenLabApp extends StatelessWidget {
  const KenLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    const brandRed = Color(0xFFC62828);
    return MaterialApp(
      title: 'KenLab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: brandRed,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F6F7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F6F7),
          foregroundColor: Color(0xFF17212B),
          elevation: 0,
        ),
      ),
      home: const _AppEntry(),
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
    return const Scaffold(
      backgroundColor: Color(0xFFC62828),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KenLabMark(
                size: 120, color: Colors.white, accent: Color(0xFFFFD9D9)),
            SizedBox(height: 18),
            Text(
              'KenLab',
              style: TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'HERRAMIENTAS DE CAMPO',
              style: TextStyle(
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
