import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meshly/l10n/l10n.dart';
import 'package:meshly/models/conversation.dart';
import 'package:meshly/screens/add_contact_screen.dart';
import 'package:meshly/screens/chat_screen.dart';
import 'package:meshly/screens/my_card_screen.dart';
import 'package:meshly/screens/new_channel_screen.dart';
import 'package:meshly/screens/scan_screen.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/mesh_service.dart';
import 'package:meshly/services/notification_service.dart';
import 'package:meshly/theme/app_theme.dart';
import 'package:meshly/widgets/conversation_tile.dart';
import 'package:meshly/widgets/tab_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.meshService, super.key});

  final MeshService meshService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ContactStore _store = ContactStore.instance;
  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    // List rebuilds via ListenableBuilder on ContactStore changes.
    // We still need the stream to drive scroll-to-bottom in ChatScreen,
    // but HomeScreen itself reacts to ContactStore notifications.
    NotificationService.instance.onNotificationTap = (convId) {
      if (!mounted) return;
      final conv = _store.conversations
          .where((c) => c.id == convId)
          .firstOrNull;
      if (conv != null) _openChat(conv);
    };
  }

  @override
  void dispose() {
    // Clear the callback so it doesn't reference this disposed widget.
    NotificationService.instance.onNotificationTap = null;
    _searchController.dispose();
    super.dispose();
  }

  void _startSearch() {
    setState(() => _searching = true);
  }

  void _stopSearch() {
    _searchController.clear();
    setState(() {
      _searching = false;
      _query = '';
    });
  }

  List<Conversation> get _conversations => _store.conversations;

  String _titleFor(Conversation conv) {
    if (conv.isDm && conv.peerId != null) {
      return _store.contactByNodeId(conv.peerId!)?.displayName ?? conv.peerId!;
    }
    if (conv.isChannel && conv.channelId != null) {
      return _store.channelById(conv.channelId!)?.name ?? conv.channelId!;
    }
    return '—';
  }

  String? _emojiFor(Conversation conv) {
    if (conv.isDm && conv.peerId != null) {
      return _store.contactByNodeId(conv.peerId!)?.avatarEmoji;
    }
    if (conv.isChannel && conv.channelId != null) {
      return _store.channelById(conv.channelId!)?.avatarEmoji;
    }
    return null;
  }

  void _openScan() {
    unawaited(
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ScanScreen(
            meshService: widget.meshService,
            isReconnect: true,
          ),
        ),
      ),
    );
  }

  void _openChat(Conversation conv) {
    unawaited(_store.markRead(conv.id));
    unawaited(
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(
            meshService: widget.meshService,
            conversation: conv,
          ),
        ),
      ),
    );
    // No setState needed — ContactStore.notifyListeners() triggers rebuild.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TabGradientBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s20,
                  AppSpacing.s12,
                  AppSpacing.s20,
                  AppSpacing.s12,
                ),
                child: _searching
                    ? TabSearchRow(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _query = value),
                        onClose: _stopSearch,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TabHeader(
                            title: 'Meshly',
                            onSearch: _startSearch,
                            onAdd: () => _showAddOptions(context),
                          ),
                          const SizedBox(height: AppSpacing.s16),
                          _StatusPill(
                            meshService: widget.meshService,
                            onReconnect: _openScan,
                          ),
                        ],
                      ),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: _store,
                  builder: (context, _) {
                    final query = _query.trim().toLowerCase();
                    final convs = query.isEmpty
                        ? _conversations
                        : _conversations
                              .where(
                                (c) =>
                                    _titleFor(c).toLowerCase().contains(query),
                              )
                              .toList();
                    if (convs.isEmpty) {
                      return query.isNotEmpty
                          ? Center(
                              child: Text(
                                context.l10n.nothingFound,
                                style: AppTextStyles.secondary(context),
                              ),
                            )
                          : _EmptyState(
                              onAddContact: () => _showAddOptions(context),
                            );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.s16,
                        AppSpacing.s4,
                        AppSpacing.s16,
                        AppSpacing.listBottomPadding,
                      ),
                      itemCount: convs.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.s10),
                      itemBuilder: (_, i) {
                        final conv = convs[i];
                        final peerId = conv.isDm ? conv.peerId : null;
                        return ConversationTile(
                          conv: conv,
                          title: _titleFor(conv),
                          emoji: _emojiFor(conv),
                          isOnline:
                              peerId != null &&
                              widget.meshService.isOnline(peerId),
                          lastHeard: peerId != null
                              ? widget.meshService.lastHeardFor(peerId)
                              : null,
                          onTap: () => _openChat(conv),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddOptions(BuildContext context) {
    unawaited(
      showModalBottomSheet(
        context: context,
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_add),
                title: Text(context.l10n.addContact),
                onTap: () {
                  Navigator.pop(context);
                  unawaited(
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const AddContactScreen(),
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.group_add),
                title: Text(context.l10n.createChannel),
                onTap: () {
                  Navigator.pop(context);
                  unawaited(
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            NewChannelScreen(meshService: widget.meshService),
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.qr_code),
                title: Text(context.l10n.myContact),
                onTap: () {
                  Navigator.pop(context);
                  unawaited(
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            MyCardScreen(meshService: widget.meshService),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Connection status capsule under the header: green dot + "Подключено"
/// with the device name alongside, or an error-colored "Нет подключения"
/// pill that opens the reconnect scan screen on tap.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.meshService, required this.onReconnect});

  final MeshService meshService;
  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.pill);
    return ValueListenableBuilder<MeshConnectionStatus>(
      valueListenable: meshService.connectionStatus,
      builder: (context, status, _) {
        final connected = status == MeshConnectionStatus.connected;
        final reconnecting = status == MeshConnectionStatus.reconnecting;
        final scheme = Theme.of(context).colorScheme;

        // Фон и цвета зависят от статуса: подключено — нейтральный контейнер,
        // переподключение — тот же нейтральный (акцент несёт точка/текст),
        // нет связи — errorContainer.
        final background = connected || reconnecting
            ? scheme.surfaceContainer
            : scheme.errorContainer;
        final dotColor = connected
            ? context.appColors.online
            : reconnecting
            ? context.appColors.warning
            : context.appColors.danger;
        final textColor = connected || reconnecting
            ? scheme.onSurface
            : scheme.onErrorContainer;
        final label = connected
            ? context.l10n.statusConnected
            : reconnecting
            ? context.l10n.statusReconnecting
            : context.l10n.statusNoConnection;

        return Row(
          children: [
            Material(
              color: background,
              borderRadius: radius,
              child: InkWell(
                // Ручной реконнект доступен, пока не подключены.
                onTap: connected ? null : onReconnect,
                borderRadius: radius,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s12,
                    vertical: AppSpacing.s6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (reconnecting)
                        SizedBox(
                          width: AppSizes.statusDotSmall,
                          height: AppSizes.statusDotSmall,
                          child: CircularProgressIndicator(
                            strokeWidth: AppSizes.spinnerStroke,
                            color: context.appColors.warning,
                          ),
                        )
                      else
                        Container(
                          width: AppSizes.statusDotSmall,
                          height: AppSizes.statusDotSmall,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      const SizedBox(width: AppSpacing.s6),
                      Text(
                        label,
                        style: AppTextStyles.statusPill.copyWith(
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (connected) ...[
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: Text(
                  meshService.deviceName.value ?? '',
                  style: AppTextStyles.caption(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddContact});

  final VoidCallback onAddContact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('👋', style: TextStyle(fontSize: AppSizes.emojiEmpty)),
          const SizedBox(height: AppSpacing.s16),
          Text(
            context.l10n.emptyChatsTitle,
            style: AppTextStyles.title,
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            context.l10n.emptyChatsSubtitle,
            style: AppTextStyles.secondary(context),
          ),
          const SizedBox(height: AppSpacing.s24),
          ElevatedButton.icon(
            onPressed: onAddContact,
            icon: const Icon(Icons.person_add),
            label: Text(context.l10n.addContact),
          ),
        ],
      ),
    );
  }
}
