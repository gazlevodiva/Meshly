import 'package:flutter/material.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/notification_settings.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Уведомления')),
      body: ListenableBuilder(
        listenable: NotificationSettings.instance,
        builder: (context, _) => _Body(settings: NotificationSettings.instance),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.settings});

  final NotificationSettings settings;

  @override
  Widget build(BuildContext context) {
    final store = ContactStore.instance;

    // Build label for any muted convId, even if the conversation isn't created yet.
    String labelForConvId(String convId) {
      if (convId.startsWith('dm_')) {
        final nodeId = convId.substring(3);
        final contact = store.contactByNodeId(nodeId);
        return contact?.displayLabel ?? nodeId;
      }
      if (convId.startsWith('ch_')) {
        final channelId = convId.substring(3);
        final channel = store.channelById(channelId);
        return '# ${channel?.name ?? channelId}';
      }
      return convId;
    }

    IconData iconForConvId(String convId) =>
        convId.startsWith('dm_') ? Icons.person_outline : Icons.tag;

    return ListView(
      children: [
        // ── Глобальный переключатель ────────────────────────
        SwitchListTile(
          secondary: const Icon(Icons.notifications_outlined),
          title: const Text('Все уведомления'),
          subtitle: const Text('Главный переключатель'),
          value: settings.enabled,
          onChanged: (v) => settings.setEnabled(value: v),
        ),
        const Divider(),

        // ── По источнику ────────────────────────────────────
        const _SectionHeader('Источники'),
        SwitchListTile(
          secondary: const Icon(Icons.person_outline),
          title: const Text('Личные сообщения'),
          value: settings.dmsEnabled && settings.enabled,
          onChanged: settings.enabled
              ? (v) => settings.setDmsEnabled(value: v)
              : null,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.tag),
          title: const Text('Каналы'),
          value: settings.channelsEnabled && settings.enabled,
          onChanged: settings.enabled
              ? (v) => settings.setChannelsEnabled(value: v)
              : null,
        ),

        // ── Замьюченные чаты ────────────────────────────────
        if (settings.mutedConversations.isNotEmpty) ...[
          const Divider(),
          const _SectionHeader('Замьюченные'),
          ...settings.mutedConversations.map(
            (convId) => ListTile(
              leading: Icon(iconForConvId(convId)),
              title: Text(labelForConvId(convId)),
              trailing: TextButton(
                onPressed: () => settings.unmuteConversation(convId),
                child: const Text('Включить'),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
