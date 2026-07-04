import 'package:flutter/material.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/notification_settings.dart';
import 'package:meshly/theme/app_theme.dart';
import 'package:meshly/widgets/section_card.dart';
import 'package:meshly/widgets/tab_header.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Уведомления'),
      ),
      body: TabGradientBackground(
        child: ListenableBuilder(
          listenable: NotificationSettings.instance,
          builder: (context, _) =>
              _Body(settings: NotificationSettings.instance),
        ),
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
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;

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

    final muted = settings.mutedConversations.toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s16,
        topInset + AppSpacing.s8,
        AppSpacing.s16,
        AppSpacing.s32,
      ),
      children: [
        // ── Глобальный переключатель ────────────────────────
        SectionCard(
          child: SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Все уведомления'),
            subtitle: const Text('Главный переключатель'),
            value: settings.enabled,
            onChanged: (v) => settings.setEnabled(value: v),
          ),
        ),

        // ── По источнику ────────────────────────────────────
        SectionCard(
          title: 'Источники',
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.person_outline),
                title: const Text('Личные сообщения'),
                value: settings.dmsEnabled && settings.enabled,
                onChanged: settings.enabled
                    ? (v) => settings.setDmsEnabled(value: v)
                    : null,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.tag),
                title: const Text('Каналы'),
                value: settings.channelsEnabled && settings.enabled,
                onChanged: settings.enabled
                    ? (v) => settings.setChannelsEnabled(value: v)
                    : null,
              ),
            ],
          ),
        ),

        // ── Замьюченные чаты ────────────────────────────────
        if (muted.isNotEmpty)
          SectionCard(
            title: 'Замьюченные',
            child: Column(
              children: [
                for (var i = 0; i < muted.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    leading: Icon(iconForConvId(muted[i])),
                    title: Text(labelForConvId(muted[i])),
                    trailing: TextButton(
                      onPressed: () => settings.unmuteConversation(muted[i]),
                      child: const Text('Включить'),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
