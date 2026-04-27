import 'package:flutter_test/flutter_test.dart';

import 'package:e_crono_app/main.dart';

void main() {
  testWidgets('Muestra la pantalla inicial de e-Crono', (
    WidgetTester tester,
  ) async {
    // Monta el widget principal real de la aplicacion.
    await tester.pumpWidget(const ECronoApp());

    expect(find.text('e-Crono'), findsOneWidget);
  });
}
