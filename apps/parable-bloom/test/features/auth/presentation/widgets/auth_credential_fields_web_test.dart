@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:parable_bloom/features/auth/presentation/widgets/auth_credential_fields.dart';

void main() {
  testWidgets('web credential fields mount', (WidgetTester tester) async {
    final email = TextEditingController();
    final password = TextEditingController();
    addTearDown(email.dispose);
    addTearDown(password.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthCredentialFields(
            emailController: email,
            passwordController: password,
            isLogin: true,
            onSubmit: () {},
          ),
        ),
      ),
    );

    expect(find.byType(HtmlElementView), findsOneWidget);
  });
}
