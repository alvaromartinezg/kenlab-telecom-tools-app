import 'package:flutter/material.dart';

import '../core/settings/app_settings.dart';
import '../core/settings/app_text.dart';
import '../core/settings/settings_page.dart';
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
        icon: Icons.settings_input_antenna),
    ToolItem(
        title: 'Cámara de campo',
        subtitle: 'Fotos con datos de ubicación y hora',
        icon: Icons.add_a_photo_outlined),
    ToolItem(
        title: 'Mapa de trabajo',
        subtitle: 'Sitios y evidencias de campo',
        icon: Icons.map_outlined),
    ToolItem(
        title: 'Fibra óptica',
        subtitle: 'Rutas, postes y mediciones',
        icon: Icons.cable),
    ToolItem(
        title: 'Mantenimiento',
        subtitle: 'Reporta y sigue trabajos',
        icon: Icons.view_kanban_outlined),
    ToolItem(
        title: 'Crew Assist',
        subtitle: 'Ubicación compartida durante el trabajo',
        icon: Icons.groups_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 22,
        title: Text(
          'KENLAB',
          style: TextStyle(
            fontSize: 14,
            letterSpacing: 2.2,
            fontWeight: FontWeight.w900,
            color: settings.accentColor,
          ),
        ),
        actions: [
          IconButton.filledTonal(
            tooltip: appText(context, 'Ajustes'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
            ),
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 34),
              children: [
                _WelcomeCard(settings: settings),
                const SizedBox(height: 28),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(appText(context, 'Herramientas de campo'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -.3,
                                  )),
                          const SizedBox(height: 4),
                          Text(
                              appText(context,
                                  'Selecciona una herramienta para tu trabajo.'),
                              style: const TextStyle(color: Color(0xFF73808C))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: settings.primaryColor.withValues(alpha: .09),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                          '06  ${appText(context, 'HERRAMIENTAS', 'TOOLS')}',
                          style: TextStyle(
                            color: settings.primaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          )),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
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
                      mainAxisExtent: 108,
                    ),
                    itemBuilder: (context, index) => _ToolCard(
                      item: tools[index],
                      color: index == 0
                          ? settings.primaryColor
                          : (index == 1
                              ? settings.accentColor
                              : AppSettings.availableColors[
                                  index % AppSettings.availableColors.length]),
                      onTap: () => _openTool(context, index),
                    ),
                  );
                }),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                      appText(context,
                          'Herramientas para trabajar mejor, en equipo.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFF73808C), fontSize: 12)),
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
  const _WelcomeCard({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 196),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [settings.accentColor, settings.primaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
              color: settings.primaryColor.withValues(alpha: .2),
              blurRadius: 24,
              offset: const Offset(0, 12)),
        ],
      ),
      child: Stack(children: [
        Positioned(
          right: -14,
          top: -18,
          child: Opacity(
            opacity: .15,
            child: Container(
              width: 142,
              height: 142,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 18),
              ),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const KenLabMark(
                  size: 40, color: Colors.white, accent: Color(0xFFFFD9D9)),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(
                settings.companyName.isEmpty
                    ? appText(
                        context, 'OPERACIONES DE CAMPO', 'FIELD OPERATIONS')
                    : settings.companyName.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w900),
              )),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(30)),
                child: const Text('BETA',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4)),
              ),
            ]),
            const SizedBox(height: 23),
            Text(appText(context, 'Listos para el trabajo de campo'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.5)),
            const SizedBox(height: 7),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 370),
              child: Text(
                  appText(context,
                      'Coordina tus trabajos de telecomunicaciones desde el teléfono.'),
                  style: const TextStyle(
                      color: Color(0xFFE6EAF0), height: 1.45, fontSize: 13)),
            ),
          ],
        ),
      ]),
    );
  }
}

class ToolItem {
  const ToolItem(
      {required this.title, required this.subtitle, required this.icon});
  final String title;
  final String subtitle;
  final IconData icon;
}

class _ToolCard extends StatelessWidget {
  const _ToolCard(
      {required this.item, required this.color, required this.onTap});
  final ToolItem item;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(16)),
                child: Icon(item.icon, color: color, size: 25),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(appText(context, item.title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, letterSpacing: -.15)),
                    const SizedBox(height: 5),
                    Text(appText(context, item.subtitle),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF73808C),
                            fontSize: 12,
                            height: 1.25)),
                  ])),
              const SizedBox(width: 9),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 15, color: color.withValues(alpha: .75)),
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
        appBar: AppBar(title: Text(appText(context, item.title))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(item.icon,
                  size: 56, color: AppSettings.instance.primaryColor),
              const SizedBox(height: 16),
              Text(appText(context, item.title),
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                  appText(
                      context,
                      'Este módulo se incorporará en una próxima etapa.',
                      'This module will be added in a future release.'),
                  textAlign: TextAlign.center),
            ]),
          ),
        ),
      );
}
