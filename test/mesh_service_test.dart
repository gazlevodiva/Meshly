import 'package:flutter_test/flutter_test.dart';
import 'package:meshly/services/mesh_service.dart';

void main() {
  group('MeshService', () {
    test('fresh instance has no device name and is not connected', () {
      final service = MeshService();
      expect(service.deviceName.value, isNull);
      expect(service.isConnected, isFalse);
    });
  });
}
