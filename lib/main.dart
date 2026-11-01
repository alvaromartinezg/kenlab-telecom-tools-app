import 'package:flutter/material.dart';

void main() {
  runApp(const KenLabApp());
}

class KenLabApp extends StatelessWidget {
  const KenLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KenLab Telecom Tools',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _buttonPressed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KenLab Telecom Tools')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Welcome to KenLab'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                setState(() {
                  _buttonPressed = true;
                });
              },
              child: const Text('Test'),
            ),
            if (_buttonPressed) ...[
              const SizedBox(height: 16),
              const Text('Button works!'),
            ],
          ],
        ),
      ),
    );
  }
}
