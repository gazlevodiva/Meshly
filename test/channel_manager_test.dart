import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshly/services/app_database.dart';
import 'package:meshly/services/channel_manager.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/mesh_service.dart';

void main() {
  final store = ContactStore.instance;
  final manager = ChannelManager.instance;

  setUp(() async {
    store.resetForTesting(AppDatabase.forTesting(NativeDatabase.memory()));
    await store.init();
  });

  group('ChannelManager.create', () {
    test('generates 32-byte PSK and persists the channel', () async {
      final meshService = MeshService();
      final ch = await manager.create(
        name: 'Семья',
        avatarEmoji: '🏠',
        meshService: meshService,
      );

      expect(ch.psk.length, equals(32));
      expect(ch.name, equals('Семья'));
      expect(ch.avatarEmoji, equals('🏠'));

      // Persisted in the store.
      expect(store.channelById(ch.id), isNotNull);
      expect(store.channels.map((c) => c.id), contains(ch.id));
    });

    test(
      'not connected MeshService: create does not throw (no device write)',
      () async {
        final meshService = MeshService();
        expect(meshService.isConnected, isFalse);

        expect(
          () => manager.create(
            name: 'Test',
            avatarEmoji: null,
            meshService: meshService,
          ),
          returnsNormally,
        );
      },
    );

    // Slots no longer limit conversations: the seventh used to be the last
    // one created, now there can be any number of them (see the sprint
    // report "decoupling conversations from Meshtastic slots").
    test('more than seven conversations can be created', () async {
      final meshService = MeshService();
      for (var i = 0; i < 10; i++) {
        final ch = await manager.create(
          name: 'ch$i',
          avatarEmoji: null,
          meshService: meshService,
        );
        expect(ch.name, equals('ch$i'));
      }
      expect(store.channels, hasLength(10));
    });
  });

  group('ChannelManager.addFromQr', () {
    Uint8List psk() => Uint8List.fromList(List.generate(32, (i) => i));

    test('adds a channel without any slot argument', () async {
      final meshService = MeshService();
      final ch = await manager.addFromQr(
        name: 'Any',
        psk: psk(),
        avatarEmoji: null,
        meshService: meshService,
      );
      expect(ch.name, equals('Any'));
      expect(store.channels, hasLength(1));
    });

    test('preserves the given PSK bytes exactly', () async {
      final meshService = MeshService();
      final givenPsk = psk();
      final ch = await manager.addFromQr(
        name: 'PskCheck',
        psk: givenPsk,
        avatarEmoji: null,
        meshService: meshService,
      );
      expect(ch.psk, equals(givenPsk));
    });
  });
}
