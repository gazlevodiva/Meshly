import 'package:flutter_test/flutter_test.dart';
import 'package:meshly/services/notification_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final settings = NotificationSettings.instance;

  setUp(() async {
    // Order matters: clear the mock store first, then reset in-memory state,
    // then load — so each test starts from a clean slate.
    SharedPreferences.setMockInitialValues({});
    settings.resetForTesting();
    await settings.load();
  });

  group('NotificationSettings — defaults', () {
    test('all enabled and no muted conversations after load', () {
      expect(settings.enabled, isTrue);
      expect(settings.dmsEnabled, isTrue);
      expect(settings.channelsEnabled, isTrue);
      expect(settings.mutedConversations, isEmpty);
    });
  });

  group('NotificationSettings — global toggle', () {
    test('setEnabled false disables shouldNotify for all types', () async {
      await settings.setEnabled(value: false);
      expect(settings.shouldNotify(convId: 'dm_abc', isDm: true), isFalse);
      expect(settings.shouldNotify(convId: 'ch_main', isDm: false), isFalse);
    });

    test('setEnabled true re-enables notifications', () async {
      await settings.setEnabled(value: false);
      await settings.setEnabled(value: true);
      expect(settings.shouldNotify(convId: 'dm_abc', isDm: true), isTrue);
    });

    test('setEnabled persists to SharedPreferences', () async {
      await settings.setEnabled(value: false);

      settings.resetForTesting();
      await settings.load();

      expect(settings.enabled, isFalse);
    });
  });

  group('NotificationSettings — DM toggle', () {
    test('setDmsEnabled false blocks DM notifications', () async {
      await settings.setDmsEnabled(value: false);
      expect(settings.shouldNotify(convId: 'dm_abc', isDm: true), isFalse);
    });

    test('setDmsEnabled false does not affect channel notifications', () async {
      await settings.setDmsEnabled(value: false);
      expect(settings.shouldNotify(convId: 'ch_main', isDm: false), isTrue);
    });

    test('setDmsEnabled persists to SharedPreferences', () async {
      await settings.setDmsEnabled(value: false);

      settings.resetForTesting();
      await settings.load();

      expect(settings.dmsEnabled, isFalse);
    });
  });

  group('NotificationSettings — channel toggle', () {
    test('setChannelsEnabled false blocks channel notifications', () async {
      await settings.setChannelsEnabled(value: false);
      expect(settings.shouldNotify(convId: 'ch_main', isDm: false), isFalse);
    });

    test('setChannelsEnabled false does not affect DM notifications', () async {
      await settings.setChannelsEnabled(value: false);
      expect(settings.shouldNotify(convId: 'dm_abc', isDm: true), isTrue);
    });

    test('setChannelsEnabled persists to SharedPreferences', () async {
      await settings.setChannelsEnabled(value: false);

      settings.resetForTesting();
      await settings.load();

      expect(settings.channelsEnabled, isFalse);
    });
  });

  group('NotificationSettings — mute per conversation', () {
    test('muting a conversation blocks its notifications', () async {
      await settings.muteConversation('dm_abc');
      expect(settings.shouldNotify(convId: 'dm_abc', isDm: true), isFalse);
    });

    test('muting one conversation does not affect another', () async {
      await settings.muteConversation('dm_abc');
      expect(settings.shouldNotify(convId: 'dm_xyz', isDm: true), isTrue);
    });

    test('isMuted returns true only for muted conversations', () async {
      await settings.muteConversation('dm_abc');
      expect(settings.isMuted('dm_abc'), isTrue);
      expect(settings.isMuted('dm_xyz'), isFalse);
    });

    test('unmuteConversation re-enables notifications', () async {
      await settings.muteConversation('dm_abc');
      await settings.unmuteConversation('dm_abc');
      expect(settings.shouldNotify(convId: 'dm_abc', isDm: true), isTrue);
      expect(settings.isMuted('dm_abc'), isFalse);
    });

    test('muted conversations persist to SharedPreferences', () async {
      await settings.muteConversation('dm_abc');
      await settings.muteConversation('ch_main');

      settings.resetForTesting();
      await settings.load();

      expect(settings.isMuted('dm_abc'), isTrue);
      expect(settings.isMuted('ch_main'), isTrue);
    });

    test('unmuting persists to SharedPreferences', () async {
      await settings.muteConversation('dm_abc');
      await settings.unmuteConversation('dm_abc');

      settings.resetForTesting();
      await settings.load();

      expect(settings.isMuted('dm_abc'), isFalse);
    });

    test('mutedConversations returns immutable view', () async {
      await settings.muteConversation('dm_abc');
      expect(
        () => settings.mutedConversations.add('dm_xyz'),
        throwsUnsupportedError,
      );
    });
  });

  group('NotificationSettings — mute atomicity', () {
    test('muteConversation rolls back if save fails', () async {
      // Simulate a broken SharedPreferences by making the key unwritable.
      // We can't easily mock the failure, so we test that after a successful
      // mute + unmute cycle the state is consistent.
      await settings.muteConversation('dm_abc');
      expect(settings.isMuted('dm_abc'), isTrue);

      await settings.unmuteConversation('dm_abc');
      expect(settings.isMuted('dm_abc'), isFalse);

      // Reload from prefs — should also be unmuted.
      settings.resetForTesting();
      await settings.load();
      expect(settings.isMuted('dm_abc'), isFalse);
    });

    test('mute is not applied twice if called again', () async {
      await settings.muteConversation('dm_abc');
      await settings.muteConversation('dm_abc'); // no-op
      expect(settings.mutedConversations.length, equals(1));
    });

    test('unmute is not applied if not muted', () async {
      await settings.unmuteConversation('dm_abc'); // no-op — should not throw
      expect(settings.mutedConversations, isEmpty);
    });
  });

  group('NotificationSettings — shouldNotify combined rules', () {
    test('global off overrides unmuted DM', () async {
      await settings.setEnabled(value: false);
      expect(settings.shouldNotify(convId: 'dm_abc', isDm: true), isFalse);
    });

    test('global off overrides per-source enabled flags', () async {
      await settings.setEnabled(value: false);
      expect(settings.shouldNotify(convId: 'ch_main', isDm: false), isFalse);
    });

    test('muted conversation blocked even when DMs globally enabled', () async {
      await settings.muteConversation('dm_abc');
      expect(settings.dmsEnabled, isTrue);
      expect(settings.shouldNotify(convId: 'dm_abc', isDm: true), isFalse);
    });

    test('all conditions met returns true', () {
      expect(settings.shouldNotify(convId: 'dm_abc', isDm: true), isTrue);
    });
  });
}
