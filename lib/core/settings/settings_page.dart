import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'app_text.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _companyController = TextEditingController();
  final _noteController = TextEditingController();
  final _primaryHexController = TextEditingController();
  final _accentHexController = TextEditingController();
  final _settings = AppSettings.instance;

  @override
  void initState() {
    super.initState();
    _companyController.text = _settings.companyName;
    _primaryHexController.text = _hex(_settings.primaryColor);
    _accentHexController.text = _hex(_settings.accentColor);
  }

  @override
  void dispose() {
    _companyController.dispose();
    _noteController.dispose();
    _primaryHexController.dispose();
    _accentHexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) => Scaffold(
        appBar:
            AppBar(title: Text(appText(context, 'Configuración', 'Settings'))),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _section(
              icon: Icons.translate,
              title: appText(context, 'Idioma'),
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'es',
                    label: Text(appText(context, 'Español')),
                  ),
                  ButtonSegment(
                    value: 'en',
                    label: Text(appText(context, 'Inglés', 'English')),
                  ),
                ],
                selected: {_settings.languageCode},
                onSelectionChanged: (value) =>
                    _settings.setLanguage(value.first),
              ),
            ),
            const SizedBox(height: 14),
            _section(
              icon: Icons.palette_outlined,
              title: appText(context, 'Apariencia'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(appText(context, 'Color principal')),
                  const SizedBox(height: 9),
                  _colorChoices(
                    _settings.primaryColor,
                    _settings.setPrimaryColor,
                    _primaryHexController,
                  ),
                  _customColorInput(
                      _primaryHexController, _settings.setPrimaryColor),
                  const SizedBox(height: 18),
                  Text(appText(context, 'Color de acento')),
                  const SizedBox(height: 9),
                  _colorChoices(
                    _settings.accentColor,
                    _settings.setAccentColor,
                    _accentHexController,
                  ),
                  _customColorInput(
                      _accentHexController, _settings.setAccentColor),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _section(
              icon: Icons.business_outlined,
              title: appText(context, 'Empresa'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _companyController,
                    maxLength: 48,
                    decoration: InputDecoration(
                      labelText: appText(context, 'Nombre de empresa'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  Text(
                    appText(context,
                        'Aparecerá como marca de agua en las fotos y reportes.'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () async {
                      await _settings.setCompanyName(_companyController.text);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(appText(context, 'Guardado', 'Saved')),
                        ));
                      }
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: Text(appText(context, 'Guardar')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _section(
              icon: Icons.text_snippet_outlined,
              title: appText(context, 'Textos rápidos de cámara'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appText(context,
                        'Agrega frases para reutilizarlas en las fotos de campo.'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final note in _settings.quickNotes)
                        InputChip(
                          label: Text(note),
                          onDeleted: () => _settings.setQuickNotes(
                            _settings.quickNotes
                                .where((item) => item != note)
                                .toList(),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _noteController,
                        maxLength: 100,
                        decoration: InputDecoration(
                          labelText: appText(context, 'Añadir texto rápido'),
                          border: const OutlineInputBorder(),
                          counterText: '',
                        ),
                        onSubmitted: (_) => _addNote(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _addNote,
                      tooltip: appText(context, 'Añadir texto rápido'),
                      icon: const Icon(Icons.add),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(
          {required IconData icon,
          required String title,
          required Widget child}) =>
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: _settings.primaryColor),
              const SizedBox(width: 9),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800))
            ]),
            const SizedBox(height: 16),
            child,
          ]),
        ),
      );

  Widget _colorChoices(Color selected, Future<void> Function(Color) onSelected,
          TextEditingController hexController) =>
      Wrap(
        spacing: 10,
        children: [
          for (final color in AppSettings.availableColors)
            Semantics(
              button: true,
              label: 'Color ${color.toARGB32().toRadixString(16)}',
              child: InkWell(
                onTap: () async {
                  await onSelected(color);
                  hexController.text = _hex(color);
                },
                customBorder: const CircleBorder(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected == color
                          ? Colors.black87
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: selected == color
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              ),
            ),
        ],
      );

  Widget _customColorInput(TextEditingController controller,
          Future<void> Function(Color) onSelected) =>
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: appText(context, 'Código de color HEX', 'HEX color'),
                prefixText: '#',
                counterText: '',
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _applyCustomColor(controller, onSelected),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: () => _applyCustomColor(controller, onSelected),
            tooltip: appText(context, 'Aplicar color', 'Apply color'),
            icon: const Icon(Icons.check),
          ),
        ]),
      );

  Future<void> _applyCustomColor(TextEditingController controller,
      Future<void> Function(Color) onSelected) async {
    final raw = controller.text.trim().replaceFirst('#', '');
    final value = int.tryParse(raw, radix: 16);
    if (raw.length != 6 || value == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(appText(
            context,
            'Escribe un código hexadecimal de 6 caracteres.',
            'Enter a 6-character hexadecimal color.')),
      ));
      return;
    }
    await onSelected(Color(0xFF000000 | value));
  }

  String _hex(Color color) => color
      .toARGB32()
      .toRadixString(16)
      .padLeft(8, '0')
      .substring(2)
      .toUpperCase();

  void _addNote() {
    final note = _noteController.text.trim();
    if (note.isEmpty || _settings.quickNotes.contains(note)) return;
    _settings.setQuickNotes([..._settings.quickNotes, note]);
    _noteController.clear();
  }
}
