import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  static const availableColors = <Color>[
    Color(0xFFC62828),
    Color(0xFFB23A48),
    Color(0xFF176B70),
    Color(0xFF315A8C),
    Color(0xFF7353A6),
    Color(0xFFD07824),
    Color(0xFF263746),
  ];

  String languageCode = 'es';
  String companyName = '';
  Color primaryColor = availableColors.first;
  Color accentColor = const Color(0xFF263746);
  List<String> quickNotes = <String>[];

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    languageCode = preferences.getString('settings.language') ?? 'es';
    companyName = preferences.getString('settings.company') ?? '';
    primaryColor = Color(preferences.getInt('settings.primary_color') ??
        availableColors.first.toARGB32());
    accentColor = Color(preferences.getInt('settings.accent_color') ??
        const Color(0xFF263746).toARGB32());
    quickNotes = preferences.getStringList('settings.quick_notes') ??
        _defaultQuickNotes(isEnglish);
  }

  bool get isEnglish => languageCode == 'en';

  Future<void> setLanguage(String value) async {
    final preferences = await SharedPreferences.getInstance();
    languageCode = value == 'en' ? 'en' : 'es';
    if (!preferences.containsKey('settings.quick_notes')) {
      quickNotes = _defaultQuickNotes(isEnglish);
    }
    notifyListeners();
    await preferences.setString('settings.language', languageCode);
  }

  Future<void> setCompanyName(String value) async {
    companyName = value.trim();
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('settings.company', companyName);
  }

  Future<void> setPrimaryColor(Color value) async {
    primaryColor = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt('settings.primary_color', value.toARGB32());
  }

  Future<void> setAccentColor(Color value) async {
    accentColor = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt('settings.accent_color', value.toARGB32());
  }

  Future<void> setQuickNotes(List<String> value) async {
    quickNotes = value
        .map((note) => note.trim())
        .where((note) => note.isNotEmpty)
        .toList();
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList('settings.quick_notes', quickNotes);
  }

  static List<String> _defaultQuickNotes(bool english) => english
      ? <String>[
          'Installation complete',
          'Adjustment pending',
          'Maintenance required',
        ]
      : <String>[
          'Instalación completa',
          'Pendiente de ajuste',
          'Requiere mantenimiento',
        ];
}
