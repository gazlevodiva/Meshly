import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshly/l10n/app_localizations.dart';
import 'package:meshly/models/conversation.dart';
import 'package:meshly/screens/chat_screen.dart';
import 'package:meshly/services/mesh_service.dart'
    show MeshConnectionStatus, MeshService;

void main() {
  Future<MeshService> pumpChat(WidgetTester tester) async {
    final mesh = MeshService();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: ChatScreen(
          meshService: mesh,
          conversation: Conversation.dm('!1f8e42c9'),
        ),
      ),
    );
    await tester.pump();
    return mesh;
  }

  testWidgets('shows header, unknown-DM banner, input and empty state', (
    tester,
  ) async {
    final mesh = await pumpChat(tester);

    // Header title (unknown contact → node id) and stranger banner.
    expect(find.text('!1f8e42c9'), findsOneWidget);
    expect(find.textContaining('Незнакомец'), findsOneWidget);
    expect(find.text('Добавить'), findsOneWidget);

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
    // Fresh MeshService defaults to disconnected → banner visible.
    final mesh = await pumpChat(tester);
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
}
