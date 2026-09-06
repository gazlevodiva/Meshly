import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshly/l10n/app_localizations.dart';
import 'package:meshly/models/contact.dart';
import 'package:meshly/screens/contacts_screen.dart';
import 'package:meshly/services/app_database.dart'
    hide Channel, Contact, Conversation, Message;
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/mesh_service.dart';

void main() {
  final store = ContactStore.instance;

  setUp(() async {
    store.resetForTesting(AppDatabase.forTesting(NativeDatabase.memory()));
    await store.init();
    await store.saveContact(Contact(nodeId: '!00000001', displayName: 'Мама'));
    await store.saveContact(Contact(nodeId: '!00000002', displayName: 'Папа'));
    await store.saveContact(
      Contact(nodeId: '!00000003', displayName: 'Сестра'),
    );
  });

  Future<void> pumpContacts(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: ContactsScreen(meshService: MeshService()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('search filters contacts by displayName', (tester) async {
    await pumpContacts(tester);

    expect(find.text('Мама'), findsOneWidget);
    expect(find.text('Папа'), findsOneWidget);
    expect(find.text('Сестра'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'мам');
    await tester.pumpAndSettle();

    expect(find.text('Мама'), findsOneWidget);
    expect(find.text('Папа'), findsNothing);
    expect(find.text('Сестра'), findsNothing);
  });

  testWidgets('search shows empty state and close restores list', (
    tester,
  ) async {
    await pumpContacts(tester);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pumpAndSettle();

    expect(find.text('Ничего не найдено'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Мама'), findsOneWidget);
    expect(find.text('Папа'), findsOneWidget);
    expect(find.text('Сестра'), findsOneWidget);
  });
}
