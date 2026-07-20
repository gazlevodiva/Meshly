import 'package:flutter_test/flutter_test.dart';
import 'package:meshly/screens/scan_screen.dart';
import 'package:meshly/services/mesh_service.dart';

void main() {
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
