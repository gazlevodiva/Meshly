import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshly/models/conversation.dart';
import 'package:meshly/screens/chat_screen.dart';
import 'package:meshly/services/mesh_service.dart';

void main() {
  Future<MeshService> pumpChat(WidgetTester tester) async {
    final mesh = MeshService();
    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(
        meshService: mesh,
        conversation: Conversation.dm('!1f8e42c9'),
      ),
    ));
    await tester.pump();
    return mesh;
  }

  testWidgets('shows header, unknown-DM banner, input and empty state',
      (tester) async {
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

  testWidgets('byte counter appears near the 200-byte limit', (tester) async {
    final mesh = await pumpChat(tester);

    // 165 ASCII bytes → 35 left (≤ 40 → counter visible).
    await tester.enterText(find.byType(TextField), 'a' * 165);
    await tester.pump();
    expect(find.text('35'), findsOneWidget);

    // 205 bytes → over the limit, negative counter shown.
    await tester.enterText(find.byType(TextField), 'a' * 205);
    await tester.pump();
    expect(find.text('-5'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    mesh.dispose();
  });
}
