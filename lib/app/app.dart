import 'package:flutter/material.dart';

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
        scaffoldBackgroundColor: const Color(0xFFF5F7F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F7F5),
          foregroundColor: Color(0xFF17211C),
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _tools = <_ToolItem>[
    _ToolItem(
      title: 'Alineación microondas',
      subtitle: 'Coordina Site A y Site B',
      icon: Icons.settings_input_antenna,
      color: Color(0xFFC62828),
      available: true,
    ),
    _ToolItem(
      title: 'Cámara de campo',
      subtitle: 'Fotos con ubicación y datos',
      icon: Icons.add_a_photo_outlined,
      color: Color(0xFF3568A8),
    ),
    _ToolItem(
      title: 'Mapa de trabajo',
      subtitle: 'Sitios y evidencias de campo',
      icon: Icons.map_outlined,
      color: Color(0xFF8B5A20),
    ),
    _ToolItem(
      title: 'Fibra óptica',
      subtitle: 'Rutas, postes y mediciones',
      icon: Icons.cable,
      color: Color(0xFF7751A3),
    ),
    _ToolItem(
      title: 'Mantenimiento',
      subtitle: 'Reporta y sigue trabajos',
      icon: Icons.view_kanban_outlined,
      color: Color(0xFFB14E45),
    ),
    _ToolItem(
      title: 'Crew Assist',
      subtitle: 'Ubicación compartida durante el trabajo',
      icon: Icons.groups_outlined,
      color: Color(0xFF367E86),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Row(
          children: [
            Icon(Icons.cell_tower, size: 28),
            SizedBox(width: 10),
            Text('KenLab', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Información',
            onPressed: () => _showAbout(context),
            icon: const Icon(Icons.info_outline),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                _WelcomeCard(onStart: () => _openTool(context, _tools.first)),
                const SizedBox(height: 28),
                Text(
                  'Herramientas de campo',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Selecciona una herramienta para tu trabajo.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF66736B),
                      ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 560 ? 2 : 1;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _tools.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: 104,
                      ),
                      itemBuilder: (context, index) => _ToolCard(
                        item: _tools[index],
                        onTap: () => _openTool(context, _tools[index]),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    'Herramientas para trabajar mejor, en equipo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF66736B)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openTool(BuildContext context, _ToolItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ToolPlaceholderPage(item: item),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'KenLab',
      applicationVersion: 'Vista inicial',
      applicationLegalese: 'Herramientas colaborativas para técnicos de campo',
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFC62828), Color(0xFF263746)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cell_tower, color: Colors.white, size: 32),
          const SizedBox(height: 18),
          Text(
            'Bienvenido a KenLab',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Coordina tus trabajos de telecomunicaciones desde el campo.',
            style: TextStyle(color: Color(0xFFE2F1E9), height: 1.4),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onStart,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF263746),
            ),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Empezar'),
          ),
        ],
      ),
    );
  }
}

class _ToolItem {
  const _ToolItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.available = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool available;
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.item, required this.onTap});

  final _ToolItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE5EAE6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(item.icon, color: item.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF66736B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                item.available ? Icons.arrow_forward_ios : Icons.more_horiz,
                size: 18,
                color: const Color(0xFF77827B),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ToolPlaceholderPage extends StatelessWidget {
  const ToolPlaceholderPage({required this.item, super.key});

  final _ToolItem item;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(item.title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 56, color: item.color),
              const SizedBox(height: 16),
              Text(
                item.title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                item.available
                    ? 'La pantalla inicial está lista. El flujo de alineación se añadirá en la siguiente etapa.'
                    : 'Este módulo estará disponible en una próxima etapa.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
