import 'package:flutter/material.dart';

import '../features/geo_camera/presentation/field_camera_page.dart';
import '../features/field_map/presentation/field_map_page.dart';
import '../features/mw_alignment/presentation/alignment_page.dart';
import '../shared/widgets/kenlab_mark.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const tools = <ToolItem>[
    ToolItem(
      title: 'Alineación microondas',
      subtitle: 'Apunta usando cámara, GPS y sensores',
      icon: Icons.settings_input_antenna,
      color: Color(0xFFC62828),
    ),
    ToolItem(
      title: 'Cámara de campo',
      subtitle: 'Fotos con datos de ubicación y hora',
      icon: Icons.add_a_photo_outlined,
      color: Color(0xFF3568A8),
    ),
    ToolItem(
      title: 'Mapa de trabajo',
      subtitle: 'Sitios y evidencias de campo',
      icon: Icons.map_outlined,
      color: Color(0xFF8B5A20),
    ),
    ToolItem(
      title: 'Fibra óptica',
      subtitle: 'Rutas, postes y mediciones',
      icon: Icons.cable,
      color: Color(0xFF7751A3),
    ),
    ToolItem(
      title: 'Mantenimiento',
      subtitle: 'Reporta y sigue trabajos',
      icon: Icons.view_kanban_outlined,
      color: Color(0xFFB14E45),
    ),
    ToolItem(
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
            KenLabMark(
                size: 36, color: Color(0xFFC62828), accent: Color(0xFF263746)),
            SizedBox(width: 9),
            Text('KenLab', style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Información',
            onPressed: () => showAboutDialog(
              context: context,
              applicationName: 'KenLab',
              applicationVersion: 'Beta',
              applicationLegalese:
                  'Herramientas colaborativas para técnicos de campo',
            ),
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
                _WelcomeCard(
                  onTap: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const AlignmentPage(),
                  )),
                ),
                const SizedBox(height: 28),
                Text('Herramientas de campo',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Selecciona una herramienta para tu trabajo.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: const Color(0xFF66736B))),
                const SizedBox(height: 16),
                LayoutBuilder(builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 560 ? 2 : 1;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: tools.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 104,
                    ),
                    itemBuilder: (context, index) => _ToolCard(
                      item: tools[index],
                      onTap: () => _openTool(context, index),
                    ),
                  );
                }),
                const SizedBox(height: 20),
                const Center(
                  child: Text('Herramientas para trabajar mejor, en equipo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF66736B))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openTool(BuildContext context, int index) {
    final page = switch (index) {
      0 => const AlignmentPage(),
      1 => const FieldCameraPage(),
      2 => const FieldMapPage(),
      _ => ToolPlaceholderPage(item: tools[index]),
    };
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFFC62828), Color(0xFF263746)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const KenLabMark(
              size: 55, color: Colors.white, accent: Color(0xFFFFD9D9)),
          const SizedBox(height: 16),
          Text('Listos para el trabajo de campo',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  )),
          const SizedBox(height: 8),
          const Text(
              'Coordina tus trabajos de telecomunicaciones desde el teléfono.',
              style: TextStyle(color: Color(0xFFECEFF1), height: 1.4)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onTap,
            style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF263746)),
            icon: const Icon(Icons.my_location),
            label: const Text('Probar alineación beta'),
          ),
        ]),
      );
}

class ToolItem {
  const ToolItem(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.color});
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.item, required this.onTap});
  final ToolItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
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
            child: Row(children: [
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
                      Text(item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(item.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xFF66736B), fontSize: 12)),
                    ]),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios,
                  size: 18, color: Color(0xFF77827B)),
            ]),
          ),
        ),
      );
}

class ToolPlaceholderPage extends StatelessWidget {
  const ToolPlaceholderPage({required this.item, super.key});
  final ToolItem item;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(item.title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(item.icon, size: 56, color: item.color),
              const SizedBox(height: 16),
              Text(item.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Este módulo se incorporará en una próxima etapa.',
                  textAlign: TextAlign.center),
            ]),
          ),
        ),
      );
}
