import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshly/l10n/app_localizations.dart';
import 'package:meshly/models/contact.dart';
import 'package:meshly/models/conversation.dart';
import 'package:meshly/models/message.dart';
import 'package:meshly/screens/add_contact_screen.dart';
import 'package:meshly/screens/chat_screen.dart';
import 'package:meshly/services/app_database.dart'
    hide Channel, Contact, Conversation, Message;
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/mesh_service.dart'
    show MeshConnectionStatus, MeshService, kUndecryptableSentinel;
import 'package:meshly/widgets/conversation_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final store = ContactStore.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store.resetForTesting(AppDatabase.forTesting(NativeDatabase.memory()));
    await store.init();
  });

  /// Pumps the chat screen. The radio counts as connected by default: the
  /// key-exchange card disables its main button without one, and most tests
  /// are about the card's normal state.
  Future<MeshService> pumpChat(
    WidgetTester tester, {
    Conversation? conversation,
    bool connected = true,
    TextScaler textScaler = TextScaler.noScaling,
    double keyboardHeight = 0,
  }) async {
    final mesh = MeshService();
    if (connected) mesh.connectionStatus.value = MeshConnectionStatus.connected;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: textScaler,
              viewInsets: EdgeInsets.only(bottom: keyboardHeight),
            ),
            child: ChatScreen(
              meshService: mesh,
              conversation: conversation ?? Conversation.dm('!1f8e42c9'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return mesh;
  }

  /// One hour ago — timestamp for the leftover unreadable bubble.
  final badTime = DateTime.now().subtract(const Duration(hours: 1));

  /// A distinct 32-byte key per test, so "same key" vs "different key" is
  /// unambiguous.
  Uint8List key(int seed) =>
      Uint8List.fromList(List<int>.generate(32, (i) => (i + seed) & 0xFF));

  /// Seeds a DM conversation whose secure chat is broken in the given
  /// direction(s) — that is what drives the key-exchange card; optionally with
  /// one leftover unreadable message.
  Future<Conversation> seedBrokenDm(
    String nodeId, {
    bool withUndecryptableMessage = false,
    bool iCanReadPeer = false,
    bool peerCanReadUs = false,
  }) async {
    final conv = store.dmForNode(nodeId) ?? Conversation.dm(nodeId);
    await store.saveConversation(conv);
    if (withUndecryptableMessage) {
      await store.addMessage(
        Message(
          meshId: 1,
          fromNodeId: nodeId,
          conversationId: conv.id,
          text: kUndecryptableSentinel,
          time: badTime,
          isMe: false,
        ),
      );
    }
    await store.setICanReadPeer(conv.id, value: iCanReadPeer);
    await store.setPeerCanReadUs(conv.id, value: peerCanReadUs);
    return conv;
  }

  testWidgets('shows header, input and empty state; no key-exchange card', (
    tester,
  ) async {
    final mesh = await pumpChat(tester);

    // Header title (unknown contact → node id).
    expect(find.text('!1f8e42c9'), findsOneWidget);
    // The chat is healthy (secureOk) → no card at all.
    expect(find.text('Нужно обменяться QR-кодами'), findsNothing);
    expect(find.text('Отсканировать QR-код'), findsNothing);

    // Input bar and empty state.
    expect(find.text('Сообщение...'), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);
    expect(find.text('Напишите первое сообщение!'), findsOneWidget);

    // No byte counter while the field is short.
    expect(find.text('200'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    mesh.dispose();
  });

  testWidgets(
    'byte counter appears near the limit, accounting for DM encryption overhead',
    (tester) async {
      final mesh = await pumpChat(tester);

      // DM budget is 200 - 41 (envelope overhead) = 159 bytes.
      // 124 ASCII bytes → 35 left (≤ 40 → counter visible).
      await tester.enterText(find.byType(TextField), 'a' * 124);
      await tester.pump();
      expect(find.text('35'), findsOneWidget);

      // 164 bytes → over the limit, negative counter shown.
      await tester.enterText(find.byType(TextField), 'a' * 164);
      await tester.pump();
      expect(find.text('-5'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      mesh.dispose();
    },
  );

  testWidgets('shows the no-connection banner and hides it once connected', (
    tester,
  ) async {
    final mesh = await pumpChat(tester, connected: false);
    expect(find.text('Нет подключения'), findsOneWidget);

    // Reconnecting swaps the label.
    mesh.connectionStatus.value = MeshConnectionStatus.reconnecting;
    await tester.pump();
    expect(find.text('Нет подключения'), findsNothing);
    expect(find.text('Переподключение…'), findsOneWidget);

    // Connected collapses the banner entirely.
    mesh.connectionStatus.value = MeshConnectionStatus.connected;
    await tester.pump();
    expect(find.text('Нет подключения'), findsNothing);
    expect(find.text('Переподключение…'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    mesh.dispose();
  });

  testWidgets(
    'a broken secure chat replaces the input bar with the key-exchange card, '
    'both steps unfinished',
    (tester) async {
      await store.saveContact(
        Contact(nodeId: '!deadbeef', displayName: 'Борис', publicKey: key(1)),
      );
      final conv = await seedBrokenDm(
        '!deadbeef',
        withUndecryptableMessage: true,
      );
      final mesh = await pumpChat(tester, conversation: conv);

      expect(find.text('Нужно обменяться QR-кодами'), findsOneWidget);
      expect(
        find.textContaining('новый телефон'),
        findsOneWidget,
      );
      // Both steps impersonal (no names, no gendered pronouns), neither done.
      expect(find.text('Вы сканируете код собеседника'), findsOneWidget);
      expect(find.text('Собеседник сканирует ваш код'), findsOneWidget);
      // Before step 1 the useful hint is what to ask the peer for; the
      // "checkmark arrives by itself" line belongs to the next state.
      expect(
        find.text('Попросите собеседника открыть «Мой контакт» в приложении'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Галочка появится сама, когда собеседник отсканирует ваш код',
        ),
        findsNothing,
      );
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(2));
      expect(find.byIcon(Icons.check_circle), findsNothing);
      // Exactly one action: the next step. Step rows carry no buttons.
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text('Отсканировать QR-код'), findsOneWidget);
      expect(find.text('Показать мой код'), findsNothing);
      expect(
        find.descendant(
          of: find
              .ancestor(
                of: find.text('Вы сканируете код собеседника'),
                matching: find.byType(Row),
              )
              .first,
          matching: find.byType(ButtonStyleButton),
        ),
        findsNothing,
      );

      // Writing is blocked: the card sits where the input bar used to be,
      // with the escape hatch as a quiet secondary action.
      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.send), findsNothing);
      expect(find.text('Всё равно писать в этот чат'), findsOneWidget);

      // The raw sentinel is never shown; the bubble gets a short placeholder.
      expect(find.textContaining('meshly:undecryptable'), findsNothing);
      expect(find.text('🔒 Не удалось прочитать'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      mesh.dispose();
    },
  );

  testWidgets('"send anyway" brings the input bar back', (tester) async {
    final conv = await seedBrokenDm('!deadbee1');
    final mesh = await pumpChat(tester, conversation: conv);

    expect(find.byType(TextField), findsNothing);

    // The full card is capped to half the chat area and scrolls inside it, so
    // on a short screen the escape hatch may sit below the fold.
    await tester.ensureVisible(find.text('Всё равно писать в этот чат'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Всё равно писать в этот чат'));
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);
    // The reminder stays, now stripped to a title plus the one action: no
    // explanation, no checklist, no hint, no escape hatch.
    expect(find.text('Нужно обменяться QR-кодами'), findsOneWidget);
    expect(find.text('Отсканировать QR-код'), findsOneWidget);
    expect(find.text('Всё равно писать в этот чат'), findsNothing);
    expect(
      find.textContaining('новый телефон'),
      findsNothing,
    );
    expect(find.text('Вы сканируете код собеседника'), findsNothing);
    expect(find.text('Собеседник сканирует ваш код'), findsNothing);
    expect(
      find.text('Попросите собеседника открыть «Мой контакт» в приложении'),
      findsNothing,
    );
    expect(
      find.text('Галочка появится сама, когда собеседник отсканирует ваш код'),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox());
    mesh.dispose();
  });

  // Regression: the card sends the user to the scanner because only a scanned
  // QR carries the peer's key — but it used to open the screen with its manual
  // tab intact, and adding a contact by node id there reported success while
  // the chat stayed exactly as broken.
  testWidgets(
    'the add-contact screen opened from the card has no manual tab',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('ru'),
          home: AddContactScreen(qrOnly: true),
        ),
      );
      await tester.pump();

      expect(find.text('Скан QR'), findsOneWidget);
      expect(find.text('Вручную'), findsNothing);
      expect(find.byType(Tab), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'the add-contact screen keeps both tabs when opened normally',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('ru'),
          home: AddContactScreen(),
        ),
      );
      await tester.pump();

      expect(find.byType(Tab), findsNWidgets(2));

      await tester.pumpWidget(const SizedBox());
    },
  );

  // The compact reminder drops every hint but this one: offline the single
  // action is greyed out, and a dead button with no explanation is worse than
  // no button at all.
  testWidgets(
    'compact reminder still explains a button disabled by a missing radio',
    (tester) async {
      final conv = await seedBrokenDm('!deadbee2');
      await store.setWriteAnyway(conv.id, value: true);
      final mesh = await pumpChat(
        tester,
        conversation: conv,
        connected: false,
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Отсканировать QR-код'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.text('Сначала подключитесь к устройству'), findsOneWidget);

      // Connected the button works again and the compact form goes back to
      // being a bare reminder — no general advice in this little space.
      mesh.connectionStatus.value = MeshConnectionStatus.connected;
      await tester.pump();
      expect(find.text('Сначала подключитесь к устройству'), findsNothing);
      expect(
        find.text('Попросите собеседника открыть «Мой контакт» в приложении'),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox());
      mesh.dispose();
    },
  );

  // Regression: with the keyboard up on a small screen the reminder's slot
  // shrank to a few dozen pixels — a meaningless slice of a card sitting on
  // top of the field the user was typing in.
  testWidgets(
    'the compact reminder disappears rather than being sliced by the keyboard',
    (tester) async {
      tester.view
        ..physicalSize = const Size(320, 568)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final conv = await seedBrokenDm('!deadbee3');
      await store.setWriteAnyway(conv.id, value: true);
      final mesh = await pumpChat(
        tester,
        conversation: conv,
        textScaler: const TextScaler.linear(1.3),
        keyboardHeight: 300,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Нужно обменяться QR-кодами'), findsNothing);
      // The input bar — the reason the user opened the keyboard — is intact.
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      mesh.dispose();
    },
  );

  // The list preview trades the last message for a "exchange QR codes" notice
  // — but only while the user has not opted into writing anyway. Otherwise a
  // chat in daily use would show that notice forever instead of its messages.
  testWidgets(
    'the conversation tile stops nagging once the user writes anyway',
    (tester) async {
      final conv = Conversation.dm('!deadbee4')
        ..iCanReadPeer = false
        ..lastMessage = Message(
          meshId: 7,
          fromNodeId: '!deadbee4',
          conversationId: 'dm_!deadbee4',
          text: 'привет',
          time: DateTime.now(),
          isMe: false,
        );

      Future<void> pumpTile() => tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ru'),
          home: Scaffold(
            body: ConversationTile(
              conv: conv,
              title: 'Пётр',
              onTap: () {},
            ),
          ),
        ),
      );

      await pumpTile();
      expect(find.text('🔒 Нужно обменяться QR-кодами'), findsOneWidget);
      expect(find.textContaining('привет'), findsNothing);

      conv.writeAnyway = true;
      await pumpTile();
      expect(find.text('🔒 Нужно обменяться QR-кодами'), findsNothing);
      expect(find.textContaining('привет'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('key-exchange card fits a narrow screen without overflowing', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 568)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final conv = await seedBrokenDm('!deadbee0');
    final mesh = await pumpChat(tester, conversation: conv);

    expect(find.text('Нужно обменяться QR-кодами'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    mesh.dispose();
  });

  // Regression, twice over. First the accented button sat *below* the
  // checklist, outside the card's scroll viewport. Then the whole card — title
  // included — lived inside that scroll view, capped at a fraction of the
  // chat: at a x2 system font the button ended up 30–370 px below the screen
  // with no scrollbar to hint at it. Title and button are now pinned outside
  // the scroll view, so the assertion is the strongest one available: the
  // button is inside the physical screen, whatever the scale.
  const geometryCases = <(Size, double)>[
    (Size(320, 568), 1),
    (Size(320, 568), 1.3),
    (Size(320, 568), 2),
    (Size(375, 667), 1),
    (Size(375, 667), 1.3),
    (Size(375, 667), 2),
  ];
  var geometryCase = 0;
  for (final (size, scale) in geometryCases) {
    final nodeId = '!ca11${(geometryCase++).toString().padLeft(4, "0")}';
    testWidgets(
      'the main action is fully on screen at '
      '${size.width.toInt()}x${size.height.toInt()}, text scale $scale',
      (tester) async {
        tester.view
          ..physicalSize = size
          ..devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await store.saveContact(
          Contact(nodeId: nodeId, displayName: 'Ольга', publicKey: key(12)),
        );
        final conv = await seedBrokenDm(nodeId);
        final mesh = await pumpChat(
          tester,
          conversation: conv,
          textScaler: TextScaler.linear(scale),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final button = tester.getRect(find.byType(FilledButton));
        expect(button.top, greaterThanOrEqualTo(0.0));
        expect(button.bottom, lessThanOrEqualTo(size.height));
        expect(button.left, greaterThanOrEqualTo(0.0));
        expect(button.right, lessThanOrEqualTo(size.width));
        // The title is pinned next to it, not scrolled away.
        expect(
          tester.getRect(find.text('Нужно обменяться QR-кодами')).top,
          greaterThanOrEqualTo(0.0),
        );

        // The escape hatch is deliberately understated and may sit below the
        // fold on the smallest screens — but it must stay reachable, so the
        // card's tail has to actually scroll to it.
        final escape = find.text('Всё равно писать в этот чат');
        await tester.scrollUntilVisible(
          escape,
          80,
          scrollable: find.byType(Scrollable).last,
        );
        // One pixel of slack: scrollUntilVisible stops as soon as the target
        // is visible, so at fractional text scales it can land flush against
        // the edge and round a fraction of a pixel past it.
        expect(
          tester.getRect(escape).bottom,
          lessThanOrEqualTo(size.height + 1),
        );

        await tester.pumpWidget(const SizedBox());
        mesh.dispose();
      },
    );
  }

  // Regression: the peer deleted us, so only they can fix their half. We used
  // to keep a usable input bar here and silently write into the void.
  testWidgets(
    'peer cannot read us: step 1 checked, writing still blocked',
    (tester) async {
      await store.saveContact(
        Contact(nodeId: '!cafe0001', displayName: 'Анна', publicKey: key(0)),
      );
      final conv = await seedBrokenDm('!cafe0001', iCanReadPeer: true);
      final mesh = await pumpChat(tester, conversation: conv);

      expect(find.text('Нужно обменяться QR-кодами'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
      // The single action is the unfinished step.
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text('Отсканировать QR-код'), findsNothing);
      expect(find.text('Показать мой код'), findsOneWidget);
      // Sending is refused by MeshService while either half is broken, so the
      // card takes the input bar's place and offers the escape hatch instead.
      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.send), findsNothing);
      expect(find.text('Всё равно писать в этот чат'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      mesh.dispose();
    },
  );

  testWidgets(
    'a verify ping from the peer checks step 2 and removes its button',
    (tester) async {
      await store.saveContact(
        Contact(nodeId: '!cafe0004', displayName: 'Галина', publicKey: key(0)),
      );
      // We cannot read them (step 1 open), but their verify ping arrived: a
      // ping is only sent right after a scan, so step 2 counts as done.
      final conv = await seedBrokenDm('!cafe0004', peerCanReadUs: true);

      final mesh = await pumpChat(tester, conversation: conv);

      expect(find.text('Нужно обменяться QR-кодами'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
      // Exactly one action left, and it is the accented one — even though
      // the *unfinished* step is the first one.
      expect(find.text('Показать мой код'), findsNothing);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.text('Отсканировать QR-код'),
        ),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);

      await tester.pumpWidget(const SizedBox());
      mesh.dispose();
    },
  );

  // Opening a broken chat re-sends the verify ping (a lost one used to leave
  // both sides stuck forever). It is fire-and-forget: with no radio it must
  // no-op silently, and the screen must build exactly as before.
  testWidgets(
    'opening a broken chat re-pings without disturbing the screen',
    (tester) async {
      await store.saveContact(
        Contact(nodeId: '!cafe0007', displayName: 'Жанна', publicKey: key(3)),
      );
      final conv = await seedBrokenDm('!cafe0007');

      final mesh = await pumpChat(tester, conversation: conv);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Нужно обменяться QR-кодами'), findsOneWidget);
      // Nothing was written locally: a verify packet is not a message.
      expect(store.messagesFor(conv.id), isEmpty);

      await tester.pumpWidget(const SizedBox());
      mesh.dispose();
    },
  );

  testWidgets(
    'both halves healthy: no card at all, plain input bar',
    (tester) async {
      await store.saveContact(
        Contact(nodeId: '!cafe0005', displayName: 'Дмитрий', publicKey: key(0)),
      );
      final conv = await seedBrokenDm(
        '!cafe0005',
        iCanReadPeer: true,
        peerCanReadUs: true,
      );
      expect(conv.secureOk, isTrue);

      final mesh = await pumpChat(tester, conversation: conv);

      expect(find.text('Нужно обменяться QR-кодами'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      mesh.dispose();
    },
  );

  testWidgets(
    'a finished step is a plain status row, never a button',
    (tester) async {
      await store.saveContact(
        Contact(nodeId: '!cafe0006', displayName: 'Егор', publicKey: key(0)),
      );
      final conv = await seedBrokenDm('!cafe0006', iCanReadPeer: true);

      final mesh = await pumpChat(tester, conversation: conv);

      expect(
        find.descendant(
          of: find
              .ancestor(
                of: find.text('Вы сканируете код собеседника'),
                matching: find.byType(Row),
              )
              .first,
          matching: find.byType(ButtonStyleButton),
        ),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox());
      mesh.dispose();
    },
  );

  testWidgets(
    'card disappears once both halves are verified',
    (tester) async {
      await store.saveContact(
        Contact(
          nodeId: '!cafe0003',
          displayName: 'Вера',
          publicKey: key(0),
        ),
      );
      final conv = await seedBrokenDm(
        '!cafe0003',
        withUndecryptableMessage: true,
      );
      // A DM that decrypted proves both directions (ECDH is symmetric), so
      // MeshService marks the chat verified unconditionally.
      await store.markSecureVerified(conv.id);
      await store.addMessage(
        Message(
          meshId: 2,
          fromNodeId: '!cafe0003',
          conversationId: conv.id,
          text: 'снова читаемо',
          time: DateTime.now(),
          isMe: false,
        ),
      );

      final mesh = await pumpChat(tester, conversation: conv);

      expect(find.text('Нужно обменяться QR-кодами'), findsNothing);
      expect(find.text('Отсканировать QR-код'), findsNothing);
      expect(find.text('Показать мой код'), findsNothing);
      // Normal input bar is back.
      expect(find.byType(TextField), findsOneWidget);
      // The old unreadable bubble is still in history — it just no longer
      // keeps the card alive.
      expect(find.text('🔒 Не удалось прочитать'), findsOneWidget);
      expect(find.text('снова читаемо'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      mesh.dispose();
    },
  );

  // "Write the first message!" used to greet the user in a chat where the
  // input bar had just been taken away by the card.
  testWidgets(
    'a broken secure chat with no history shows no empty state',
    (tester) async {
      final conv = await seedBrokenDm('!cafe0008');
      final mesh = await pumpChat(tester, conversation: conv);

      expect(find.text('Нужно обменяться QR-кодами'), findsOneWidget);
      expect(find.text('Напишите первое сообщение!'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      mesh.dispose();
    },
  );

  // Regression: the card is several times taller than the input bar it
  // replaces, and the list's fixed bottom padding used to hide the last
  // messages behind it.
  testWidgets(
    'the key-exchange card never covers the end of the conversation',
    (tester) async {
      await store.saveContact(
        Contact(nodeId: '!cafe0009', displayName: 'Зоя', publicKey: key(5)),
      );
      final conv = await seedBrokenDm('!cafe0009');
      for (var i = 0; i < 12; i++) {
        await store.addMessage(
          Message(
            meshId: 100 + i,
            fromNodeId: '!cafe0009',
            conversationId: conv.id,
            text: 'сообщение $i',
            time: DateTime.now(),
            isMe: false,
          ),
        );
      }

      final mesh = await pumpChat(tester, conversation: conv);
      await tester.pumpAndSettle();

      final lastMessage = tester.getRect(find.text('сообщение 11'));
      final cardTop = tester
          .getRect(find.text('Нужно обменяться QR-кодами'))
          .top;
      expect(lastMessage.bottom, lessThanOrEqualTo(cardTop));

      await tester.pumpWidget(const SizedBox());
      mesh.dispose();
    },
  );

  testWidgets(
    'a huge system font neither overflows nor swallows the conversation',
    (tester) async {
      tester.view
        ..physicalSize = const Size(320, 568)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await store.saveContact(
        Contact(nodeId: '!cafe0010', displayName: 'Инна', publicKey: key(6)),
      );
      final conv = await seedBrokenDm('!cafe0010');
      await store.addMessage(
        Message(
          meshId: 200,
          fromNodeId: '!cafe0010',
          conversationId: conv.id,
          text: 'привет',
          time: DateTime.now(),
          isMe: false,
        ),
      );

      final mesh = await pumpChat(
        tester,
        conversation: conv,
        textScaler: const TextScaler.linear(2),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The card is capped, so the message is still on screen and above it.
      final message = tester.getRect(find.text('привет'));
      final cardTop = tester
          .getRect(find.text('Нужно обменяться QR-кодами'))
          .top;
      expect(message.bottom, lessThanOrEqualTo(cardTop));

      await tester.pumpWidget(const SizedBox());
      mesh.dispose();
    },
  );

  // Without a radio the verify packet never leaves the phone: scanning would
  // look like success while the peer learns nothing.
  testWidgets(
    'no radio: the scan action is disabled, keeping its label, with the '
    'reason as a separate hint',
    (tester) async {
      await store.saveContact(
        Contact(nodeId: '!cafe0011', displayName: 'Клим', publicKey: key(7)),
      );
      final conv = await seedBrokenDm('!cafe0011');
      final mesh = await pumpChat(
        tester,
        conversation: conv,
        connected: false,
      );

      // The label never turns into an error message: the user must still be
      // able to tell what the button does.
      expect(find.text('Отсканировать QR-код'), findsOneWidget);
      expect(find.text('Сначала подключитесь к устройству'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);

      // Connecting swaps the hint back to the useful one.
      mesh.connectionStatus.value = MeshConnectionStatus.connected;
      await tester.pump();
      expect(find.text('Сначала подключитесь к устройству'), findsNothing);
      expect(
        find.text('Попросите собеседника открыть «Мой контакт» в приложении'),
        findsOneWidget,
      );
      expect(find.text('Отсканировать QR-код'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      mesh.dispose();
    },
  );

  // "Show my code" needs no radio at all: the peer's camera reads it, and the
  // same screen is reachable from the rest of the app unconditionally.
  testWidgets(
    'no radio: "show my code" stays enabled',
    (tester) async {
      await store.saveContact(
        Contact(nodeId: '!cafe0014', displayName: 'Нина', publicKey: key(11)),
      );
      final conv = await seedBrokenDm('!cafe0014', iCanReadPeer: true);
      final mesh = await pumpChat(
        tester,
        conversation: conv,
        connected: false,
      );

      expect(find.text('Показать мой код'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
      // No duplicate of the "no connection" banner sitting right above.
      expect(find.text('Сначала подключитесь к устройству'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      mesh.dispose();
    },
  );

  testWidgets(
    'the repair is confirmed once, on the transition only',
    (tester) async {
      await store.saveContact(
        Contact(nodeId: '!cafe0012', displayName: 'Лев', publicKey: key(8)),
      );
      final conv = await seedBrokenDm('!cafe0012', iCanReadPeer: true);
      final mesh = await pumpChat(tester, conversation: conv);

      // Opening a broken chat says nothing by itself.
      expect(find.text('Готово — теперь вы читаете друг друга'), findsNothing);

      await store.setPeerCanReadUs(conv.id, value: true);
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Готово — теперь вы читаете друг друга'),
        findsOneWidget,
      );
      expect(find.text('Нужно обменяться QR-кодами'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      mesh.dispose();
    },
  );

  testWidgets(
    'opening a healthy chat shows no restored confirmation',
    (tester) async {
      await store.saveContact(
        Contact(nodeId: '!cafe0013', displayName: 'Мила', publicKey: key(9)),
      );
      final conv = await seedBrokenDm(
        '!cafe0013',
        iCanReadPeer: true,
        peerCanReadUs: true,
      );
      final mesh = await pumpChat(tester, conversation: conv);
      await tester.pumpAndSettle();

      expect(find.text('Готово — теперь вы читаете друг друга'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      mesh.dispose();
    },
  );
}
