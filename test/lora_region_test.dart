import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshly/services/lora_region.dart';
import 'package:meshly/services/meshtastic_proto.dart';

// ── Minimal protobuf reader for checking what we encoded ──
// The test must not trust the encoder that it is itself verifying, so the
// parsing here is written independently of MeshtasticProto.

(int, int) _varint(Uint8List d, int pos) {
  var r = 0;
  var s = 0;
  var c = pos;
  while (c < d.length) {
    final b = d[c++];
    r |= (b & 0x7F) << s;
    if ((b & 0x80) == 0) break;
    s += 7;
  }
  return (r, c);
}

/// All message fields: number → value (varint as int, bytes as Uint8List).
Map<int, Object> _fields(Uint8List msg) {
  final out = <int, Object>{};
  var pos = 0;
  while (pos < msg.length) {
    final t = _varint(msg, pos);
    pos = t.$2;
    final field = t.$1 >> 3;
    switch (t.$1 & 7) {
      case 0:
        final v = _varint(msg, pos);
        out[field] = v.$1;
        pos = v.$2;
      case 1:
        pos += 8;
      case 2:
        final l = _varint(msg, pos);
        out[field] = msg.sublist(l.$2, l.$2 + l.$1);
        pos = l.$2 + l.$1;
      case 5:
        out[field] = ByteData.sublistView(
          msg,
          pos,
          pos + 4,
        ).getUint32(0, Endian.little);
        pos += 4;
      default:
        return out;
    }
  }
  return out;
}

Uint8List _encVarint(int v) {
  final out = <int>[];
  var value = v;
  while (value > 0x7F) {
    out.add((value & 0x7F) | 0x80);
    value >>>= 7;
  }
  out.add(value & 0x7F);
  return Uint8List.fromList(out);
}

Uint8List _tagVarint(int field, int value) =>
    Uint8List.fromList([..._encVarint(field << 3), ..._encVarint(value)]);

Uint8List _tagBytes(int field, Uint8List data) => Uint8List.fromList([
  ..._encVarint((field << 3) | 2),
  ..._encVarint(data.length),
  ...data,
]);

Uint8List _concat(List<Uint8List> parts) =>
    Uint8List.fromList(parts.expand((p) => p).toList());

/// LoRaConfig as the firmware would send it: preset, hop limit, power
/// and (optionally) region.
Uint8List _loraConfig({int? region}) => _concat([
  _tagVarint(1, 1), // use_preset = true
  _tagVarint(2, 3), // modem_preset
  if (region != null) _tagVarint(7, region),
  _tagVarint(8, 5), // hop_limit
  _tagVarint(10, 27), // tx_power
  _tagVarint(104, 1), // ignore_mqtt — a field from the "tail", beyond 1..15
]);

/// FromRadio { config { lora } }
Uint8List _fromRadio(Uint8List lora) => _tagBytes(5, _tagBytes(6, lora));

/// Unwraps a ToRadio frame down to AdminMessage.
Map<int, Object> _adminOf(Uint8List frame) {
  final toRadio = _fields(frame);
  final packet = _fields(toRadio[1]! as Uint8List);
  final data = _fields(packet[4]! as Uint8List);
  return _fields(data[2]! as Uint8List);
}

void main() {
  group('decodeLoraConfig', () {
    test('extracts the region and the raw config bytes', () {
      final got = MeshtasticProto.decodeLoraConfig(
        _fromRadio(_loraConfig(region: 3)),
      );

      expect(got, isNotNull);
      expect(got!.region, 3);
      expect(_fields(got.raw)[7], 3);
    });

    test('region not set → UNSET, not null', () {
      final got = MeshtasticProto.decodeLoraConfig(_fromRadio(_loraConfig()));

      expect(got!.region, LoraRegion.unset);
    });

    test('a frame without a config is ignored', () {
      expect(
        MeshtasticProto.decodeLoraConfig(_tagBytes(4, _loraConfig())),
        isNull,
      );
    });
  });

  group('encodeSetRegion', () {
    List<Uint8List> framesFor(Uint8List lora, int region) =>
        MeshtasticProto.encodeSetRegion(
          currentLora: lora,
          region: region,
          fromNode: 0x1f8e42c9,
        );

    test('three frames: begin_edit → set_config → commit_edit', () {
      final frames = framesFor(_loraConfig(region: 3), 15);

      expect(frames, hasLength(3));
      expect(_adminOf(frames[0]).keys, [64]); // begin_edit_settings
      expect(_adminOf(frames[1]).keys, [34]); // set_config
      expect(_adminOf(frames[2]).keys, [65]); // commit_edit_settings
    });

    test('the packet never goes over the air: hop_limit=1, ADMIN_APP port', () {
      final packet = _fields(
        _fields(framesFor(_loraConfig(), 3).first)[1]! as Uint8List,
      );

      expect(packet[2], 0x1f8e42c9, reason: 'addressed to the device itself');
      expect(packet[9], 1, reason: 'hop_limit');
      // ADMIN_APP = 6 (meshtastic/protobufs → portnums.proto). This used to
      // be 68 (ZPS_APP) — because of that the firmware's AdminModule never
      // saw our admin commands: the module dispatcher drops a packet whose
      // portnum has no subscriber, before it ever reaches
      // AdminModule::handleReceivedProtobuf. Hence the silence over the air
      // despite a GATT_SUCCESS on the characteristic write.
      expect(_fields(packet[4]! as Uint8List)[1], 6, reason: 'ADMIN_APP');
    });

    // The firmware only trusts an admin command when from == 0: it fills in
    // its own node number itself. With a nonzero from, the command is
    // treated as remote, requires a session key, and is silently rejected.
    test(
      'from = 0, otherwise the firmware rejects the command as unauthorized',
      () {
        for (final frame in framesFor(_loraConfig(), 3)) {
          final packet = _fields(_fields(frame)[1]! as Uint8List);
          expect(packet[1] ?? 0, 0);
        }
      },
    );

    test(
      'the three frames have different ids — otherwise the radio treats them as duplicates',
      () {
        final ids = framesFor(
          _loraConfig(),
          3,
        ).map((f) => _fields(_fields(f)[1]! as Uint8List)[6]).toSet();

        expect(ids, hasLength(3));
      },
    );

    // The key point: set_config replaces the entire LoRaConfig, so all
    // unrelated settings must survive the region change byte for byte.
    test('other settings are not wiped out', () {
      final frames = framesFor(_loraConfig(region: 3), 15);
      final config = _fields(_adminOf(frames[1])[34]! as Uint8List);
      final lora = _fields(config[6]! as Uint8List);

      expect(lora[7], 15, reason: 'the region changed');
      expect(lora[1], 1, reason: 'use_preset');
      expect(lora[2], 3, reason: 'modem_preset');
      expect(lora[8], 5, reason: 'hop_limit');
      expect(lora[10], 27, reason: 'tx_power');
      expect(lora[104], 1, reason: 'a tail field we do not know about');
    });

    test('the region is appended if it was missing from the config', () {
      final frames = framesFor(_loraConfig(), 3);
      final config = _fields(_adminOf(frames[1])[34]! as Uint8List);
      final lora = _fields(config[6]! as Uint8List);

      expect(lora[7], 3);
      expect(lora[8], 5, reason: 'the rest is unchanged');
    });

    test('a corrupted config is carried over as-is, not truncated', () {
      // The field length is larger than the message itself: better not to
      // change the region at all than to send the device a truncated
      // config.
      final broken = Uint8List.fromList([
        ..._encVarint((2 << 3) | 2),
        99,
        1,
        2,
      ]);
      final frames = framesFor(broken, 3);
      final config = _fields(_adminOf(frames[1])[34]! as Uint8List);

      expect(config[6], broken);
    });
  });

  group('device response diagnostics', () {
    test(
      'routingErrorName gives error names from mesh.proto Routing.Error',
      () {
        expect(MeshtasticProto.routingErrorName(0), 'NONE');
        expect(MeshtasticProto.routingErrorName(33), 'NOT_AUTHORIZED');
        expect(MeshtasticProto.routingErrorName(36), 'ADMIN_BAD_SESSION_KEY');
        expect(
          MeshtasticProto.routingErrorName(37),
          'ADMIN_PUBLIC_KEY_UNAUTHORIZED',
        );
        expect(MeshtasticProto.routingErrorName(999), 'UNKNOWN(999)');
      },
    );

    test('decodeRoutingAck attaches errorName to errorCode', () {
      // Data { portnum=5(ROUTING_APP), payload=Routing{error_reason=33},
      // request_id=fixed32 }
      final routing = _tagVarint(
        3,
        33,
      ); // Routing.error_reason = NOT_AUTHORIZED
      final data = _concat([
        _tagVarint(1, 5),
        _tagBytes(2, routing),
        Uint8List.fromList([
          ..._encVarint((6 << 3) | 5),
          0x0d,
          0x0c,
          0x0b,
          0x0a,
        ]),
      ]);
      final fromRadio = _tagBytes(2, _tagBytes(4, data));

      final ack = MeshtasticProto.decodeRoutingAck(fromRadio);

      expect(ack, isNotNull);
      expect(ack!.errorCode, 33);
      expect(ack.errorName, 'NOT_AUTHORIZED');
    });

    test(
      'decodeAdminResponse recognizes the ADMIN_APP portnum and variantTag',
      () {
        // Data { portnum=6(ADMIN_APP), payload=AdminMessage{get_config_response
        // (tag 90) = <empty>}, request_id }
        final admin = _tagBytes(90, Uint8List(0));
        final data = _concat([
          _tagVarint(1, 6),
          _tagBytes(2, admin),
          Uint8List.fromList([
            ..._encVarint((6 << 3) | 5),
            0x2a,
            0x00,
            0x00,
            0x00,
          ]),
        ]);
        final fromRadio = _tagBytes(2, _tagBytes(4, data));

        final resp = MeshtasticProto.decodeAdminResponse(fromRadio);

        expect(resp, isNotNull);
        expect(resp!.meshId, 0x2a);
        expect(resp.variantTag, 90);
      },
    );

    test('decodeAdminResponse ignores packets with a different portnum', () {
      final data = _concat([_tagVarint(1, 1), _tagBytes(2, Uint8List(0))]);
      final fromRadio = _tagBytes(2, _tagBytes(4, data));

      expect(MeshtasticProto.decodeAdminResponse(fromRadio), isNull);
    });
  });

  group('decodeHwModel', () {
    // FromRadio { metadata: DeviceMetadata { hw_model } } — field 13, field 9.
    Uint8List fromRadioWithMetadata(Uint8List metadata) =>
        _tagBytes(13, metadata);

    test('extracts the board model from its numeric code', () {
      // DeviceMetadata: firmware_version(1), hw_model(9)=43 (HELTEC_V3).
      final metadata = _concat([
        _tagBytes(1, Uint8List.fromList('2.5.0'.codeUnits)),
        _tagVarint(9, 43),
      ]);

      expect(
        MeshtasticProto.decodeHwModel(fromRadioWithMetadata(metadata)),
        'HELTEC_V3',
      );
    });

    test('an unfamiliar model code (new firmware) → null, not a guess', () {
      final metadata = _tagVarint(9, 9999);

      expect(
        MeshtasticProto.decodeHwModel(fromRadioWithMetadata(metadata)),
        isNull,
      );
    });

    test('a frame without metadata is ignored', () {
      expect(
        MeshtasticProto.decodeHwModel(_tagBytes(5, _tagVarint(9, 43))),
        isNull,
      );
    });

    test('UNSET (0) is recognized as a model, not as "no data"', () {
      final metadata = _tagVarint(9, 0);

      expect(
        MeshtasticProto.decodeHwModel(fromRadioWithMetadata(metadata)),
        'UNSET',
      );
    });
  });

  group('LoraRegion', () {
    test('codes are unique and match between common and all', () {
      final byValue = {for (final r in LoraRegion.all) r.value: r.code};

      expect(byValue.length, LoraRegion.all.length, reason: 'no duplicates');
      for (final r in LoraRegion.common) {
        expect(byValue[r.value], r.code, reason: 'common diverges from all');
      }
    });

    test(
      'codeOf does not know UNSET or unfamiliar codes from new firmware',
      () {
        expect(LoraRegion.codeOf(3), 'EU_868');
        expect(LoraRegion.codeOf(LoraRegion.unset), isNull);
        expect(LoraRegion.codeOf(999), isNull);
      },
    );

    test('common has no deprecated codes, including UA_868', () {
      // UA_868 is marked `deprecated = true` in config.proto → must not be
      // suggested as a first choice. It remains in all: some people may
      // already have devices configured for it.
      expect(LoraRegion.common.map((r) => r.code), isNot(contains('UA_868')));
      expect(LoraRegion.all.map((r) => r.code), contains('UA_868'));
    });
  });

  group('LoraRegion.suggestedFor', () {
    test('a known country with an unambiguous region', () {
      expect(LoraRegion.suggestedFor('ES')!.code, 'EU_868');
      expect(LoraRegion.suggestedFor('US')!.code, 'US');
      expect(LoraRegion.suggestedFor('JP')!.code, 'JP');
      expect(LoraRegion.suggestedFor('AU')!.code, 'ANZ');
      expect(LoraRegion.suggestedFor('BR')!.code, 'BR_902');
    });

    test('country case does not matter', () {
      expect(LoraRegion.suggestedFor('es')!.code, 'EU_868');
    });

    test('Ukraine — the current UA_433, not the deprecated UA_868', () {
      expect(LoraRegion.suggestedFor('UA')!.code, 'UA_433');
    });

    test('an unknown country → null', () {
      expect(LoraRegion.suggestedFor('ZZ'), isNull);
      expect(LoraRegion.suggestedFor(null), isNull);
      expect(LoraRegion.suggestedFor(''), isNull);
    });

    test(
      'Kazakhstan → null: KZ_433 and KZ_863 are equally valid, cannot guess',
      () {
        expect(LoraRegion.suggestedFor('KZ'), isNull);
      },
    );
  });

  group('LoraRegion.bandOf', () {
    test('numeric codes take the band from the suffix', () {
      expect(LoraRegion.bandOf('EU_868'), 868);
      expect(LoraRegion.bandOf('EU_433'), 433);
      expect(LoraRegion.bandOf('UA_433'), 433);
      expect(LoraRegion.bandOf('UA_868'), 868);
      expect(LoraRegion.bandOf('KZ_863'), 863);
      expect(LoraRegion.bandOf('BR_902'), 902);
      expect(LoraRegion.bandOf('EU_N_868'), 868, reason: 'EU_N_868 → 868');
    });

    test('LORA_24 is a special case, the "24" suffix is not MHz', () {
      expect(LoraRegion.bandOf('LORA_24'), 2400);
    });

    test(
      'named codes without a number come from the firmware regions[] table',
      () {
        // Values checked against meshtastic/firmware → RadioInterface.cpp:
        // RDEF(US, 902.0f, 928.0f, ...) → nominal 915 (US915), etc.
        expect(LoraRegion.bandOf('US'), 915);
        expect(LoraRegion.bandOf('CN'), 470);
        expect(LoraRegion.bandOf('ANZ'), 915);
        expect(LoraRegion.bandOf('RU'), 868);
        expect(LoraRegion.bandOf('IN'), 865);
      },
    );

    test(
      'ITU codes (wavelength, not MHz, and not implemented in firmware) → null',
      () {
        expect(LoraRegion.bandOf('ITU1_2M'), isNull);
        expect(LoraRegion.bandOf('ITU2_70CM'), isNull);
        expect(LoraRegion.bandOf('ITU2_125CM'), isNull);
      },
    );

    test('an unfamiliar code → null', () {
      expect(
        LoraRegion.bandOf('MARS'),
        isNull,
        reason: 'no suffix and no table entry',
      );
      expect(LoraRegion.bandOf('QQ'), isNull);
    });
  });

  group('LoraRegion.compatibleWith', () {
    test(
      'UNSET → offer the whole list, the board has not shown itself yet',
      () {
        expect(LoraRegion.compatibleWith(LoraRegion.unset), LoraRegion.all);
      },
    );

    test('an 868 board does not get 433 regions (and vice versa)', () {
      final euRegion = LoraRegion.all.firstWhere((r) => r.code == 'EU_868');
      final compatible = LoraRegion.compatibleWith(euRegion.value);

      expect(compatible.map((r) => r.code), contains('EU_868'));
      expect(compatible.map((r) => r.code), contains('UA_868'));
      expect(compatible.map((r) => r.code), isNot(contains('EU_433')));
      expect(compatible.map((r) => r.code), isNot(contains('UA_433')));
      // All results are actually on 868, not just "not 433".
      for (final r in compatible) {
        expect(LoraRegion.bandOf(r.code), 868);
      }
    });

    test('a board on 433 does not get 868/915 regions', () {
      final euRegion = LoraRegion.all.firstWhere((r) => r.code == 'EU_433');
      final compatible = LoraRegion.compatibleWith(euRegion.value);

      expect(compatible.map((r) => r.code), contains('EU_433'));
      expect(compatible.map((r) => r.code), isNot(contains('EU_868')));
      expect(compatible.map((r) => r.code), isNot(contains('US')));
    });

    test(
      'a code with an unknown range (ITU) → the whole list, nothing to narrow',
      () {
        final ituRegion = LoraRegion.all.firstWhere(
          (r) => r.code == 'ITU1_2M',
        );
        expect(
          LoraRegion.compatibleWith(ituRegion.value),
          LoraRegion.all,
        );
      },
    );
  });
}
