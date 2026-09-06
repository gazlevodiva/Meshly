import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshly/models/contact.dart';
import 'package:meshly/screens/main_screen.dart';
import 'package:meshly/screens/onboarding_screen.dart';
import 'package:meshly/screens/scan_screen.dart';
import 'package:meshly/services/app_database.dart'
    hide Channel, Contact, Conversation, Message;
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/mesh_service.dart';

// FromRadio { my_info: MyNodeInfo { my_node_num } }, mirrored from
// mesh_service_test.dart — kept local so this file has no cross-test-file
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
  final store = ContactStore.instance;

  setUp(() async {
    store.resetForTesting(AppDatabase.forTesting(NativeDatabase.memory()));
    await store.init();
  });

  group('postConnectDestination', () {
    test(
      'a reconnect never asks for the name again: skipping it once has to '
      'mean skipping it, and no self-contact is what skipping leaves behind',
      () {
        final mesh = MeshService();
        addTearDown(mesh.dispose);

        expect(postConnectDestination(mesh), isA<MainScreen>());
      },
    );

    test('goes to the name step when no device has reported a node id yet', () {
      final mesh = MeshService();
      addTearDown(mesh.dispose);
      expect(
        postConnectDestination(mesh, askForName: true),
        isA<NameStepScreen>(),
      );
    });

    test(
      'goes to the name step when connected but no self-contact exists',
      () async {
        final mesh = MeshService();
        addTearDown(mesh.dispose);
        await mesh.handleIncomingBytes(myNodeInfoFrame(0x1f8e42c9));

        expect(
          postConnectDestination(mesh, askForName: true),
          isA<NameStepScreen>(),
        );
      },
    );

    test(
      'goes straight to MainScreen once a self-contact already exists',
      () async {
        final mesh = MeshService();
        addTearDown(mesh.dispose);
        await mesh.handleIncomingBytes(myNodeInfoFrame(0x1f8e42c9));
        await store.saveContact(
          Contact(nodeId: '!1f8e42c9', displayName: 'Алекс'),
        );

        expect(
          postConnectDestination(mesh, askForName: true),
          isA<MainScreen>(),
        );
      },
    );
  });

  group('isLikelyMeshtasticDevice', () {
    test('matches classic Meshtastic advertised name', () {
      expect(
        isLikelyMeshtasticDevice(name: 'Meshtastic_1a2b', serviceUuids: []),
        isTrue,
      );
    });

    test('matches known board vendors in the name (case-insensitive)', () {
      for (final name in [
        'Heltec V3',
        'LILYGO T-Beam',
        'RAK4631',
        'M5Stack Core',
        'Station G1',
      ]) {
        expect(
          isLikelyMeshtasticDevice(name: name, serviceUuids: []),
          isTrue,
          reason: 'expected "$name" to be recognized',
        );
      }
    });

    test(
      'matches by advertised Meshtastic service UUID regardless of name',
      () {
        expect(
          isLikelyMeshtasticDevice(
            name: 'unknown-node',
            serviceUuids: [kMeshtasticServiceUuid.toUpperCase()],
          ),
          isTrue,
        );
      },
    );

    test('rejects unrelated named BLE devices (headphones, TV, watch)', () {
      for (final name in ['LG TV', 'Galaxy Buds', 'Mi Band 7', 'AirPods']) {
        expect(
          isLikelyMeshtasticDevice(name: name, serviceUuids: []),
          isFalse,
          reason: 'expected "$name" to be filtered out',
        );
      }
    });

    test('rejects empty name without a matching service UUID', () {
      expect(
        isLikelyMeshtasticDevice(
          name: '',
          serviceUuids: ['0000180f-0000-1000-8000-00805f9b34fb'],
        ),
        isFalse,
      );
    });
  });
}
