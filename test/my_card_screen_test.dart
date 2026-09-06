import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshly/l10n/app_localizations.dart';
import 'package:meshly/models/contact.dart';
import 'package:meshly/screens/my_card_screen.dart';
import 'package:meshly/services/app_database.dart'
    hide Channel, Contact, Conversation, Message;
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/mesh_service.dart';
import 'package:meshly/services/qr_service.dart';
import 'package:meshly/widgets/qr_card.dart';

// Wording comes from the ARB files, never from literals here: a test that
// hard-codes the phrasing goes green on wrong grammar rather than catching
// it.
late AppLocalizations l10n;

// FromRadio { my_info: MyNodeInfo { my_node_num } } — the frame the radio
// sends on connect that tells the app its own node id. Mirrors the helper
// in onboarding_screen_test.dart; kept local so this file has no
// cross-test-file dependency.
List<int> myNodeInfoFrame(int nodeNum) {
  final numVarint = <int>[];
  var v = nodeNum;
  while (v > 0x7F) {
    numVarint.add((v & 0x7F) | 0x80);
    v >>>= 7;
  }
  numVarint.add(v);
  final myInfo = <int>[0x08, ...numVarint]; // field 1, varint
  return [26, myInfo.length, ...myInfo]; // field 3, wire type 2
}

void main() {
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('ru'));
  });

  final store = ContactStore.instance;

  setUp(() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    store.resetForTesting(db);
    await store.init();
  });

  Future<MeshService> pumpMyCard(WidgetTester tester) async {
    final mesh = MeshService();
    addTearDown(mesh.dispose);
    // A node id must be known before the screen can key a self-contact —
    // mirrors a device that's already paired.
    await mesh.handleIncomingBytes(myNodeInfoFrame(0x1f8e42c9));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: MyCardScreen(meshService: mesh),
      ),
    );
    await tester.pumpAndSettle();
    return mesh;
  }

  group('MyCardScreen — no name set yet', () {
    testWidgets(
      'no QR code is shown, and the person is told why instead of being '
      'handed a code that would misname them',
      (tester) async {
        await pumpMyCard(tester);

        expect(find.byType(QrCard), findsNothing);
        expect(find.text(l10n.copyLinkButton), findsNothing);
        expect(find.text(l10n.myCardNoNameTitle), findsOneWidget);
        expect(find.text(l10n.myCardNoNameMessage), findsOneWidget);
      },
    );

    testWidgets(
      'the defect this sprint fixes: picking an avatar emoji before a '
      'name is set must not silently create a self-contact named "Я" — '
      'regression test for the old defaultMyName fallback used by both '
      'the QR encoder and the emoji-picker save path',
      (tester) async {
        await pumpMyCard(tester);

        // Tap the avatar to open the emoji picker, then pick one — this
        // used to save `Contact(displayName: context.l10n.defaultMyName)`
        // (the literal "Я") whenever no name had been typed yet.
        await tester.tap(find.text('😊'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('👩'));
        await tester.pumpAndSettle();

        expect(store.contacts, isEmpty);
        expect(store.contactByNodeId('!1f8e42c9'), isNull);
      },
    );

    testWidgets('the name field opens automatically, ready to type', (
      tester,
    ) async {
      await pumpMyCard(tester);

      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('MyCardScreen — setting a name', () {
    testWidgets(
      'saving a name reveals the QR code, encoded with that exact name',
      (tester) async {
        await pumpMyCard(tester);

        await tester.enterText(find.byType(TextField), 'Борис');
        await tester.tap(find.byIcon(Icons.check));
        await tester.pumpAndSettle();

        expect(find.byType(QrCard), findsOneWidget);
        expect(find.text(l10n.myCardNoNameTitle), findsNothing);

        final saved = store.contactByNodeId('!1f8e42c9');
        expect(saved, isNotNull);
        expect(saved!.displayName, equals('Борис'));

        final qr = QrService.encodeContact(saved, myNodeId: '!1f8e42c9');
        expect(QrService.decodeContact(qr)!.displayName, equals('Борис'));
      },
    );

    testWidgets(
      'a name longer than kDisplayNameMaxLength cannot be entered — the '
      'field itself caps it, matching what an announcement would carry',
      (tester) async {
        await pumpMyCard(tester);

        final longName = '🐧' * 40;
        await tester.enterText(find.byType(TextField), longName);
        await tester.tap(find.byIcon(Icons.check));
        await tester.pumpAndSettle();

        final saved = store.contactByNodeId('!1f8e42c9');
        expect(saved, isNotNull);
        expect(saved!.displayName.runes.length, equals(kDisplayNameMaxLength));
        expect(
          saved.displayName,
          equals('🐧' * kDisplayNameMaxLength),
        );
      },
    );

    testWidgets(
      'a newline typed into the name field does not survive into the '
      'stored contact',
      (tester) async {
        await pumpMyCard(tester);

        await tester.enterText(find.byType(TextField), 'Ali\nce');
        await tester.tap(find.byIcon(Icons.check));
        await tester.pumpAndSettle();

        final saved = store.contactByNodeId('!1f8e42c9');
        expect(saved, isNotNull);
        expect(saved!.displayName.contains('\n'), isFalse);
      },
    );
  });
}
