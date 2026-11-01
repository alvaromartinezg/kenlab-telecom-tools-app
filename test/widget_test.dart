import 'package:flutter_test/flutter_test.dart';
import 'package:kenlab_telecom_tools/app/app.dart';

void main() {
  testWidgets('shows KenLab home and opens the microwave module',
      (tester) async {
    await tester.pumpWidget(const KenLabApp());

    expect(find.text('KenLab'), findsOneWidget);
    expect(find.text('Bienvenido a KenLab'), findsOneWidget);
    expect(find.text('Herramientas de campo'), findsOneWidget);
    expect(find.text('Alineación microondas'), findsOneWidget);
    expect(find.text('Fibra óptica'), findsOneWidget);
    expect(find.text('Mantenimiento'), findsOneWidget);

    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();

    expect(
        find.text(
            'La pantalla inicial está lista. El flujo de alineación se añadirá en la siguiente etapa.'),
        findsOneWidget);
  });
}
