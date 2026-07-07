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

  group('ChannelManager.nextFreeSlot', () {
    test('returns 1 when no channels exist', () {
      expect(manager.nextFreeSlot(store), equals(1));
    });

    test('returns first free slot among 1..7', () async {
      await store.createChannel(name: 'A', slotIndex: 1);
      await store.createChannel(name: 'B', slotIndex: 2);

      expect(manager.nextFreeSlot(store), equals(3));
    });

    test('returns -1 when all slots 1..7 are taken', () async {
      for (var i = 1; i <= 7; i++) {
        await store.createChannel(name: 'ch$i', slotIndex: i);
      }
      expect(manager.nextFreeSlot(store), equals(-1));
    });
  });

  group('ChannelManager.create', () {
    test(
      'assigns first free slot, generates 32-byte PSK, persists channel',
      () async {
        final meshService = MeshService();
        final ch = await manager.create(
          name: 'Семья',
          avatarEmoji: '🏠',
          meshService: meshService,
        );

        expect(ch, isNotNull);
        expect(ch!.slotIndex, equals(1));
        expect(ch.psk.length, equals(32));
        expect(ch.name, equals('Семья'));
        expect(ch.avatarEmoji, equals('🏠'));

        // Persisted in the store.
        expect(store.channelById(ch.id), isNotNull);
        expect(store.channels.map((c) => c.id), contains(ch.id));
      },
    );

    test(
      'not connected MeshService: create does not throw (BLE write no-op)',
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

    test('returns null when all 7 slots are already taken', () async {
      for (var i = 1; i <= 7; i++) {
        await store.createChannel(name: 'ch$i', slotIndex: i);
      }
      final meshService = MeshService();
      final ch = await manager.create(
        name: 'Overflow',
        avatarEmoji: null,
        meshService: meshService,
      );
      expect(ch, isNull);
    });

    test('two consecutive creates take two different free slots', () async {
      final meshService = MeshService();
      final first = await manager.create(
        name: 'First',
        avatarEmoji: null,
        meshService: meshService,
      );
      final second = await manager.create(
        name: 'Second',
        avatarEmoji: null,
        meshService: meshService,
      );

      expect(first!.slotIndex, equals(1));
      expect(second!.slotIndex, equals(2));
    });
  });

  group('ChannelManager.addFromQr', () {
    Uint8List psk() => Uint8List.fromList(List.generate(32, (i) => i));

    test('rejects slotIndex 0 (reserved primary slot)', () async {
      final meshService = MeshService();
      final ch = await manager.addFromQr(
        name: 'Bad',
        psk: psk(),
        slotIndex: 0,
        avatarEmoji: null,
        meshService: meshService,
      );
      expect(ch, isNull);
      expect(store.channels, isEmpty);
    });

    test('rejects slotIndex 8 (out of range)', () async {
      final meshService = MeshService();
      final ch = await manager.addFromQr(
        name: 'Bad',
        psk: psk(),
        slotIndex: 8,
        avatarEmoji: null,
        meshService: meshService,
      );
      expect(ch, isNull);
      expect(store.channels, isEmpty);
    });

    test('rejects negative slotIndex', () async {
      final meshService = MeshService();
      final ch = await manager.addFromQr(
        name: 'Bad',
        psk: psk(),
        slotIndex: -1,
        avatarEmoji: null,
        meshService: meshService,
      );
      expect(ch, isNull);
    });

    test('accepts valid slotIndex boundaries 1 and 7', () async {
      final meshService = MeshService();
      final ch1 = await manager.addFromQr(
        name: 'Slot1',
        psk: psk(),
        slotIndex: 1,
        avatarEmoji: null,
        meshService: meshService,
      );
      final ch7 = await manager.addFromQr(
        name: 'Slot7',
        psk: psk(),
        slotIndex: 7,
        avatarEmoji: null,
        meshService: meshService,
      );

      expect(ch1, isNotNull);
      expect(ch1!.slotIndex, equals(1));
      expect(ch7, isNotNull);
      expect(ch7!.slotIndex, equals(7));
      expect(store.channels, hasLength(2));
    });

    test('preserves the given PSK bytes exactly', () async {
      final meshService = MeshService();
      final givenPsk = psk();
      final ch = await manager.addFromQr(
        name: 'PskCheck',
        psk: givenPsk,
        slotIndex: 3,
        avatarEmoji: null,
        meshService: meshService,
      );
      expect(ch!.psk, equals(givenPsk));
    });
  });
}
