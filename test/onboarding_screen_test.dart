import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshly/l10n/app_localizations.dart';
import 'package:meshly/screens/onboarding_screen.dart';
import 'package:meshly/services/app_database.dart'
    hide Channel, Contact, Conversation, Message;
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/mesh_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Wording comes from the ARB files, never from literals here: a test that
// hard-codes the phrasing goes green on wrong grammar rather than catching
// it.
late AppLocalizations l10n;

// FromRadio { my_info: MyNodeInfo { my_node_num } } — the frame the radio
// sends on connect that tells the app its own node id. Mirrors the helper
// in mesh_service_test.dart; kept local so this file has no cross-test-file
// dependency.
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
    SharedPreferences.setMockInitialValues({});
    store.resetForTesting(AppDatabase.forTesting(NativeDatabase.memory()));
    await store.init();
  });

  Future<MeshService> pumpOnboarding(WidgetTester tester) async {
    final mesh = MeshService();
    addTearDown(mesh.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: OnboardingScreen(meshService: mesh),
      ),
    );
    await tester.pumpAndSettle();
    return mesh;
  }

  group('OnboardingScreen', () {
    testWidgets('shows three informational pages, no name step among them', (
      tester,
    ) async {
      await pumpOnboarding(tester);

      expect(find.text(l10n.onboardingTitle1), findsOneWidget);
      await tester.tap(find.text(l10n.onboardingNext));
      await tester.pumpAndSettle();
      expect(find.text(l10n.onboardingTitle2), findsOneWidget);
      await tester.tap(find.text(l10n.onboardingNext));
      await tester.pumpAndSettle();
      expect(find.text(l10n.onboardingTitle3), findsOneWidget);

      // The last page offers "Начать", not another "Далее" — three pages,
      // not four: the name step no longer lives in this flow.
      expect(find.text(l10n.onboardingStart), findsOneWidget);
      expect(find.text(l10n.onboardingNameTitle), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('"Начать" on the last page finishes onboarding', (
      tester,
    ) async {
      await pumpOnboarding(tester);

      await tester.tap(find.text(l10n.onboardingNext));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.onboardingNext));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.onboardingStart));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsNothing);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_done_v1'), isTrue);
    });

    testWidgets('Skip finishes onboarding immediately from the first page', (
      tester,
    ) async {
      await pumpOnboarding(tester);

      await tester.tap(find.text(l10n.onboardingSkip));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_done_v1'), isTrue);
    });
  });

  group('NameStepScreen', () {
    Future<MeshService> pumpNameStep(WidgetTester tester) async {
      final mesh = MeshService();
      addTearDown(mesh.dispose);
      // Simulates what ScanScreen only pushes this screen after: a device
      // has already reported its node id.
      await mesh.handleIncomingBytes(myNodeInfoFrame(0x1f8e42c9));
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ru'),
          home: NameStepScreen(meshService: mesh),
        ),
      );
      await tester.pumpAndSettle();
      return mesh;
    }

    testWidgets('shows the name step wording and field', (tester) async {
      await pumpNameStep(tester);

      expect(find.text(l10n.onboardingNameTitle), findsOneWidget);
      expect(find.text(l10n.onboardingNameText), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(l10n.onboardingStart), findsOneWidget);
    });

    testWidgets('saving a name creates the self-contact, keyed by the '
        'already-known node id', (tester) async {
      await pumpNameStep(tester);

      await tester.enterText(find.byType(TextField), 'Алекс');
      await tester.tap(find.text(l10n.onboardingStart));
      await tester.pumpAndSettle();

      final saved = store.contactByNodeId('!1f8e42c9');
      expect(saved, isNotNull);
      expect(saved!.displayName, 'Алекс');
    });

    testWidgets('Skip finishes without creating a contact', (tester) async {
      await pumpNameStep(tester);

      await tester.enterText(find.byType(TextField), 'Алекс');
      await tester.tap(find.text(l10n.onboardingSkip));
      await tester.pumpAndSettle();

      expect(find.byType(NameStepScreen), findsNothing);
      expect(store.contactByNodeId('!1f8e42c9'), isNull);
      expect(store.contacts, isEmpty);
    });

    testWidgets(
      'an empty or whitespace-only name is treated as skipping, not saved',
      (tester) async {
        await pumpNameStep(tester);

        await tester.enterText(find.byType(TextField), '   ');
        await tester.tap(find.text(l10n.onboardingStart));
        await tester.pumpAndSettle();

        expect(store.contacts, isEmpty);
      },
    );

    testWidgets(
      'no overflow at 2x text scale with the keyboard shown on a small screen',
      (tester) async {
        tester.view
          ..physicalSize = const Size(320, 568)
          ..devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final mesh = MeshService();
        addTearDown(mesh.dispose);
        await mesh.handleIncomingBytes(myNodeInfoFrame(0x1f8e42c9));
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ru'),
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  viewInsets: const EdgeInsets.only(bottom: 300),
                ),
                child: NameStepScreen(meshService: mesh),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // The field (focused as soon as this screen opens) must end up
        // inside the visible area above the keyboard, not stranded below
        // the fold where the user would have to guess it exists.
        final visibleBottom =
            tester.view.physicalSize.height / tester.view.devicePixelRatio -
            300;
        final field = tester.getRect(find.byType(TextField));

        expect(field.bottom, lessThanOrEqualTo(visibleBottom));
      },
    );
  });
}
