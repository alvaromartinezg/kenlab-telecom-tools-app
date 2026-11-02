import 'package:flutter_test/flutter_test.dart';
import 'package:kenlab_telecom_tools/app/app.dart';

void main() {
  testWidgets('shows the red KenLab splash before the tools menu',
      (tester) async {
    await tester.pumpWidget(const KenLabApp());

    expect(find.text('KenLab'), findsOneWidget);
    expect(find.text('HERRAMIENTAS DE CAMPO'), findsOneWidget);
    expect(find.text('Herramientas de campo'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Herramientas de campo'), findsOneWidget);
    expect(find.text('Alineación microondas'), findsOneWidget);
    expect(find.text('Cámara de campo'), findsOneWidget);
    expect(find.text('Fibra óptica'), findsOneWidget);
    expect(find.text('Mantenimiento'), findsOneWidget);
    expect(find.text('Probar alineación beta'), findsNothing);
  });
}
