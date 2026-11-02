import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenlab_telecom_tools/core/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists language, brand, palette and camera quick notes', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings.instance;
    await settings.load();

    await settings.setLanguage('en');
    await settings.setCompanyName('Northwave Telecom');
    await settings.setPrimaryColor(const Color(0xFF176B70));
    await settings.setAccentColor(const Color(0xFF7353A6));
    await settings.setQuickNotes(['Inspection complete', 'Cable replaced']);
    await settings.load();

    expect(settings.languageCode, 'en');
    expect(settings.companyName, 'Northwave Telecom');
    expect(settings.primaryColor, const Color(0xFF176B70));
    expect(settings.accentColor, const Color(0xFF7353A6));
    expect(settings.quickNotes, ['Inspection complete', 'Cable replaced']);
  });
}
