import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshly/l10n/app_localizations.dart';
import 'package:meshly/models/conversation.dart';
import 'package:meshly/models/mesh_channel.dart';
import 'package:meshly/models/message.dart';
import 'package:meshly/screens/channel_info_screen.dart';
import 'package:meshly/services/app_database.dart'
    hide Channel, Conversation, Message;
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/mesh_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// FromRadio { my_info: MyNodeInfo { my_node_num } } — the first frame the
// radio sends after want_config. Lets a MeshService in this test know its
// own node id, which `announceChannelEvent` needs before it will send
// anything (see mesh_service.dart's `myAnnouncedName` check).
List<int> announceNodeInfoFrame(int nodeNum) {
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

// Wording comes from the ARB files, never from literals here: a test that
// hard-codes the phrasing goes green on wrong grammar and has to be
// rewritten whenever the text is improved.
late AppLocalizations l10n;

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

  MeshService newService() {
    final service = MeshService();
    addTearDown(service.dispose);
    return service;
  }

  Future<MeshService> pumpScreen(
    WidgetTester tester,
    MeshChannel channel, {
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    final mesh = newService();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: ChannelInfoScreen(channel: channel, meshService: mesh),
          ),
        ),
      ),
    );
    await tester.pump();
    return mesh;
  }

  // The joins/leaves card sits below the QR and "no member list" cards, off
  // the default test viewport. ListView's sliver marks off-viewport children
  // "offstage" (see RenderSliverMultiBoxAdaptorElement), which the default
  // `find.text`/`find.textContaining` skip — so these read the card's
  // content with `skipOffstage: false` instead of scrolling to it every time.
  Finder textAnywhere(String text) => find.text(text, skipOffstage: false);

  testWidgets('shows its empty state when no joins or leaves were seen', (
    tester,
  ) async {
    final ch = MeshChannel(id: 'evt1', name: 'Поход', psk: Uint8List(32));
    await store.saveChannel(ch);
    await store.saveConversation(Conversation.channel(ch.id));

    final mesh = await pumpScreen(tester, ch);

    expect(
      textAnywhere(l10n.channelEventsEmpty),
      findsOneWidget,
    );
    // The honest note is always shown, empty or not.
    expect(
      find.text(l10n.channelEventsNote, skipOffstage: false),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
    mesh.dispose();
  });

  testWidgets('lists seen joins and leaves newest first', (tester) async {
    final ch = MeshChannel(id: 'evt2', name: 'Поход', psk: Uint8List(32));
    await store.saveChannel(ch);
    final conv = Conversation.channel(ch.id);
    await store.saveConversation(conv);

    await store.addMessage(
      Message.systemEvent(
        kind: SystemEventKind.joined,
        announcedName: 'Аня',
        fromNodeId: '!aaaa0001',
        conversationId: conv.id,
        time: DateTime.now().subtract(const Duration(hours: 2)),
        isMe: false,
      ),
    );
    await store.addMessage(
      Message.systemEvent(
        kind: SystemEventKind.left,
        announcedName: 'Борис',
        fromNodeId: '!bbbb0002',
        conversationId: conv.id,
        time: DateTime.now().subtract(const Duration(minutes: 5)),
        isMe: false,
      ),
    );

    final mesh = await pumpScreen(tester, ch);

    final joined = textAnywhere(l10n.systemEventJoined('Аня'));
    final left = textAnywhere(l10n.systemEventLeft('Борис'));
    expect(joined, findsOneWidget);
    expect(left, findsOneWidget);
    expect(
      textAnywhere(l10n.channelEventsEmpty),
      findsNothing,
    );

    // Newest (the more recent "left" event) sits above the older "joined"
    // one. getRect needs the same skipOffstage:false treatment (see
    // textAnywhere), so it is called on the raw finder, not tester.getRect.
    final joinedTop = tester
        .renderObject<RenderBox>(joined)
        .localToGlobal(Offset.zero)
        .dy;
    final leftTop = tester
        .renderObject<RenderBox>(left)
        .localToGlobal(Offset.zero)
        .dy;
    expect(leftTop, lessThan(joinedTop));

    await tester.pumpWidget(const SizedBox());
    mesh.dispose();
  });

  testWidgets(
    'leaving from the info screen announces "left" over the mesh before '
    'deleting the conversation',
    (tester) async {
      final ch = MeshChannel(id: 'evt3', name: 'Поход', psk: Uint8List(32));
      await store.saveChannel(ch);
      await store.saveConversation(Conversation.channel(ch.id));

      final mesh = await pumpScreen(tester, ch);
      await mesh.handleIncomingBytes(
        Uint8List.fromList(announceNodeInfoFrame(0x1f8e42c9)),
      );
      final sent = <Uint8List>[];
      mesh.debugRadioSink = sent.add;

      final deleteFinder = find.text('Выйти из беседы');
      await tester.scrollUntilVisible(
        deleteFinder,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(deleteFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Выйти'));
      await tester.pumpAndSettle();

      // The announcement went out (best-effort broadcast)...
      expect(sent, hasLength(1));
      // ...and the conversation is gone locally, same as a bare delete.
      expect(store.channelById(ch.id), isNull);
      expect(store.conversationById(Conversation.channel(ch.id).id), isNull);

      mesh.dispose();
    },
  );

  testWidgets('the events log survives a x2 system font without overflowing', (
    tester,
  ) async {
    final ch = MeshChannel(id: 'evt4', name: 'Поход', psk: Uint8List(32));
    await store.saveChannel(ch);
    final conv = Conversation.channel(ch.id);
    await store.saveConversation(conv);
    await store.addMessage(
      Message.systemEvent(
        kind: SystemEventKind.joined,
        announcedName: 'Виктория Александровна',
        fromNodeId: '!cccc0003',
        conversationId: conv.id,
        time: DateTime.now(),
        isMe: false,
      ),
    );

    final mesh = await pumpScreen(
      tester,
      ch,
      textScaler: const TextScaler.linear(2),
    );
    await tester.pumpAndSettle();

    // Scroll the card into view: at x2 scale, and to measure its real
    // on-screen position, it must actually be laid out inside the viewport
    // rather than merely present in the (offstage-tolerant) element tree.
    final eventText = find.text(
      l10n.systemEventJoined('Виктория Александровна'),
    );
    await tester.scrollUntilVisible(
      eventText,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final rect = tester.getRect(eventText);
    expect(rect.left, greaterThanOrEqualTo(0.0));
    expect(rect.right, lessThanOrEqualTo(800.0));

    await tester.pumpWidget(const SizedBox());
    mesh.dispose();
  });
}
