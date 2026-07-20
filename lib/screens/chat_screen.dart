import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:meshly/l10n/l10n.dart';
import 'package:meshly/models/contact.dart';
import 'package:meshly/models/conversation.dart';
import 'package:meshly/models/message.dart';
import 'package:meshly/screens/channel_info_screen.dart';
import 'package:meshly/screens/edit_contact_screen.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/mesh_service.dart';
import 'package:meshly/theme/app_theme.dart';
import 'package:meshly/utils/date_format.dart';
import 'package:meshly/widgets/conversation_tile.dart' show ListAvatar;
import 'package:meshly/widgets/tab_header.dart' show TabGradientBackground;

/// Meshtastic text payload limit, bytes of UTF-8.
const int _maxPayloadBytes = 200;

/// Extra bytes consumed by the Meshly AEAD envelope (version + 24-byte nonce +
/// 16-byte MAC, XChaCha20-Poly1305) on every outgoing message. Both DMs and
/// channels are encrypted, so the same overhead applies to both.
const int kEnvelopeOverhead = 41;

/// Show the remaining-bytes counter once this few bytes are left.
const int _counterThreshold = 40;

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    required this.meshService,
    required this.conversation,
    super.key,
  });

  final MeshService meshService;
  final Conversation conversation;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final ContactStore _store = ContactStore.instance;
  StreamSubscription<Message>? _sub;

  List<Message> get _messages => _store.messagesFor(widget.conversation.id);

  @override
  void initState() {
    super.initState();
    unawaited(_store.markRead(widget.conversation.id));
    _sub = widget.meshService.incomingMessages.listen((msg) {
      if (msg.conversationId == widget.conversation.id && mounted) {
        setState(() {});
        _scrollToBottom();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        unawaited(
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          ),
        );
      }
    });
  }

  String _shortNodeId(String nodeId) {
    if (nodeId.startsWith('!') && nodeId.length > 9) {
      return '!${nodeId.substring(nodeId.length - 8)}';
    }
    return nodeId;
  }

  Future<void> _showAddContactDialog() async {
    final nodeId = widget.conversation.peerId!;

    // The dialog owns its TextEditingController (disposed by the framework
    // after the closing animation) and returns the picked name + emoji.
    final result = await showDialog<({String name, String emoji})>(
      context: context,
      builder: (_) => _AddContactDialog(nodeId: nodeId),
    );

    if (result != null && mounted) {
      final contact = Contact(
        nodeId: nodeId,
        displayName: result.name,
        avatarEmoji: result.emoji,
      );
      await _store.saveContact(contact);
      if (mounted) setState(() {});
    }
  }

  Future<void> _openEditContact() async {
    final conv = widget.conversation;
    if (conv.peerId == null) return;
    final contact = _store.contactByNodeId(conv.peerId!);
    if (contact == null) return;
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => EditContactScreen(
          contact: contact,
          meshService: widget.meshService,
        ),
      ),
    );
    if (!mounted) return;
    if (result == 'deleted') {
      Navigator.pop(context);
    } else {
      setState(() {});
    }
  }

  void _openChannelInfo() {
    final conv = widget.conversation;
    if (conv.channelId == null) return;
    final ch = _store.channelById(conv.channelId!);
    if (ch == null) return;
    unawaited(
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ChannelInfoScreen(channel: ch),
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || utf8.encode(text).length > _maxPayloadBytes) return;
    final result = await widget.meshService.sendText(text, widget.conversation);
    if (!mounted) return;
    if (result == SendResult.sent) {
      _controller.clear();
      setState(() {});
      _scrollToBottom();
    } else if (result == SendResult.needsKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.rescanForSecureChat)),
      );
    }
  }

  /// Tapping a failed outgoing message offers to resend it
  /// (resending creates a new message).
  Future<void> _retry(Message msg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.notDeliveredTitle),
        content: Text(ctx.l10n.resendQuestion),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.retrySend),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final result = await widget.meshService.sendText(
        msg.text,
        widget.conversation,
      );
      if (!mounted) return;
      if (result == SendResult.needsKey) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.rescanForSecureChat)),
        );
      }
      setState(() {});
      _scrollToBottom();
    }
  }

  bool get _isUnknownDm {
    final conv = widget.conversation;
    return conv.isDm &&
        conv.peerId != null &&
        _store.contactByNodeId(conv.peerId!) == null;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final conv = widget.conversation;
    return Scaffold(
      body: TabGradientBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(context),
              if (_isUnknownDm)
                Container(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16,
                    vertical: AppSpacing.s10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.strangerNodeId(
                            _shortNodeId(conv.peerId!),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _showAddContactDialog,
                        child: Text(context.l10n.add),
                      ),
                    ],
                  ),
                ),
              _ConnectionBanner(meshService: widget.meshService),
              Expanded(
                // The input bar floats over the list: messages scroll
                // behind it, so the list gets extra bottom padding.
                child: Stack(
                  children: [
                    ListenableBuilder(
                      listenable: _store,
                      builder: (context, _) {
                        final messages = _messages;
                        return messages.isEmpty
                            ? Center(
                                child: Text(
                                  context.l10n.writeFirstMessage,
                                  style: AppTextStyles.secondary(context),
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.s12,
                                  AppSpacing.s12,
                                  AppSpacing.s12,
                                  AppSpacing.chatListBottomPadding,
                                ),
                                itemCount: messages.length,
                                itemBuilder: (_, i) {
                                  final msg = messages[i];
                                  final prev = i > 0 ? messages[i - 1] : null;
                                  final newDay =
                                      prev == null ||
                                      !_sameDay(prev.time, msg.time);
                                  // In channels the sender avatar + name are shown
                                  // once per run of consecutive same-sender
                                  // messages (and again after a date chip).
                                  final showSender =
                                      conv.isChannel &&
                                      !msg.isMe &&
                                      (newDay ||
                                          prev.isMe ||
                                          prev.fromNodeId != msg.fromNodeId);
                                  return Column(
                                    children: [
                                      if (newDay) _DateChip(date: msg.time),
                                      _MessageBubble(
                                        msg: msg,
                                        store: _store,
                                        inChannel: conv.isChannel,
                                        showSender: showSender,
                                        onRetry: _retry,
                                      ),
                                    ],
                                  );
                                },
                              );
                      },
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _InputBar(
                        controller: _controller,
                        onSend: _send,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Custom header: back arrow, avatar with online dot, name + presence
  /// line, and a context action (channel info / edit contact).
  Widget _buildHeader(BuildContext context) {
    final conv = widget.conversation;
    var name = context.l10n.chatFallbackTitle;
    String? emoji;
    var showDot = false;
    Widget? statusLine;
    VoidCallback? onTapInfo;
    Widget? action;

    if (conv.isDm && conv.peerId != null) {
      final peerId = conv.peerId!;
      final contact = _store.contactByNodeId(peerId);
      name = contact?.displayName ?? _shortNodeId(peerId);
      emoji = contact?.avatarEmoji;
      final online = widget.meshService.isOnline(peerId);
      showDot = online;
      final lastHeard = widget.meshService.lastHeardFor(peerId);
      if (online) {
        statusLine = Text(
          context.l10n.online,
          style: AppTextStyles.caption(
            context,
          ).copyWith(color: context.appColors.online),
        );
      } else if (lastHeard != null) {
        statusLine = Text(
          context.l10n.lastSeen(formatLastHeard(context.l10n, lastHeard)),
          style: AppTextStyles.caption(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      }
      if (contact != null) {
        onTapInfo = _openEditContact;
        action = IconButton(
          icon: const Icon(Icons.more_vert),
          tooltip: context.l10n.editContactTooltip,
          onPressed: _openEditContact,
        );
      }
    } else if (conv.isChannel && conv.channelId != null) {
      final ch = _store.channelById(conv.channelId!);
      if (ch != null) {
        name = ch.name;
        emoji = ch.avatarEmoji;
        onTapInfo = _openChannelInfo;
        action = IconButton(
          icon: const Icon(Icons.info_outline),
          tooltip: context.l10n.aboutChannelTooltip,
          onPressed: _openChannelInfo,
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        AppSpacing.s4,
        AppSpacing.s4,
        AppSpacing.s4,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: context.l10n.backTooltip,
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onTapInfo,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  ListAvatar(
                    title: name,
                    emoji: emoji,
                    isOnline: showDot,
                    size: AppSizes.avatarChatHeader,
                    emojiSize: AppSizes.emojiSmall,
                  ),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: AppTextStyles.cardTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (statusLine != null) ...[
                          const SizedBox(height: AppSpacing.s2),
                          statusLine,
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Full-width slim banner pinned to the top of the message list while the
/// radio link is down, so the user sees they are writing "into the void".
/// Collapses to zero height when connected. Reuses the same tokens/colors as
/// the home-screen status pill (warning while reconnecting, error otherwise).
class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.meshService});

  final MeshService meshService;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MeshConnectionStatus>(
      valueListenable: meshService.connectionStatus,
      builder: (context, status, _) {
        if (status == MeshConnectionStatus.connected) {
          return const SizedBox.shrink();
        }
        final scheme = Theme.of(context).colorScheme;
        final reconnecting = status == MeshConnectionStatus.reconnecting;
        final background = reconnecting
            ? scheme.surfaceContainer
            : scheme.errorContainer;
        final textColor = reconnecting
            ? scheme.onSurface
            : scheme.onErrorContainer;
        final label = reconnecting
            ? context.l10n.statusReconnecting
            : context.l10n.statusNoConnection;

        return Container(
          width: double.infinity,
          color: background,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
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
                    color: context.appColors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: AppSpacing.s8),
              Text(
                label,
                style: AppTextStyles.statusPill.copyWith(color: textColor),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Centered pill chip between messages from different days.
class _DateChip extends StatelessWidget {
  const _DateChip({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s4,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          chatDate(context.l10n, date),
          style: AppTextStyles.caption(context),
        ),
      ),
    );
  }
}

/// Telegram-style message bubble: incoming — surface color, left-aligned;
/// outgoing — primary blue, right-aligned. Time (and status for outgoing)
/// flows inline at the bottom-right of the bubble. In channels, incoming
/// messages show a small sender avatar and a tinted sender name.
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.msg,
    required this.store,
    required this.inChannel,
    required this.showSender,
    required this.onRetry,
  });

  final Message msg;
  final ContactStore store;
  final bool inChannel;

  /// Show the sender avatar + name (channels only; collapsed for consecutive
  /// messages from the same sender).
  final bool showSender;

  final void Function(Message msg) onRetry;

  static String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isMe = msg.isMe;
    final scheme = Theme.of(context).colorScheme;
    final appColors = context.appColors;

    const round = Radius.circular(AppRadius.bubble);
    const tail = Radius.circular(AppRadius.bubbleTail);
    final borderRadius = BorderRadius.only(
      topLeft: round,
      topRight: round,
      bottomLeft: isMe ? round : tail,
      bottomRight: isMe ? tail : round,
    );

    final meta = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _time(msg.time),
          style: AppTextStyles.label(context).copyWith(
            color: isMe
                ? appColors.onAccent.withValues(alpha: AppOpacities.bubbleMeta)
                : appColors.textSecondary,
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: AppSpacing.s4),
          _StatusIcon(status: msg.status),
        ],
      ],
    );

    final showSenderName = inChannel && !isMe && showSender;
    final isUndecryptable = msg.text == kUndecryptableSentinel;

    Widget bubble = Container(
      constraints: BoxConstraints(
        maxWidth:
            MediaQuery.of(context).size.width * AppSizes.bubbleMaxWidthFraction,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: isMe ? scheme.primary : scheme.surfaceContainer,
        borderRadius: borderRadius,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showSenderName) ...[
            Text(
              store.displayNameFor(msg.fromNodeId),
              style: AppTextStyles.caption(context).copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
          ],
          // The trailing meta block flows on the same line after the text
          // when it fits, otherwise wraps to its own right-aligned line.
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: AppSpacing.s8,
            children: [
              if (isUndecryptable)
                Text(
                  context.l10n.undecryptableMessage,
                  style: AppTextStyles.secondary(context).copyWith(
                    fontStyle: FontStyle.italic,
                    color: isMe ? appColors.onAccent : null,
                  ),
                )
              else
                Text(
                  msg.text,
                  style: TextStyle(color: isMe ? appColors.onAccent : null),
                ),
              meta,
            ],
          ),
        ],
      ),
    );

    if (isMe && msg.status == MessageStatus.failed) {
      bubble = GestureDetector(onTap: () => onRetry(msg), child: bubble);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && inChannel) ...[
            if (showSender)
              ListAvatar(
                title: store.displayNameFor(msg.fromNodeId),
                emoji: store.contactByNodeId(msg.fromNodeId)?.avatarEmoji,
                size: AppSizes.avatarChatBubble,
                emojiSize: AppSizes.emojiChatBubble,
                initialStyle: AppTextStyles.body,
              )
            else
              const SizedBox(width: AppSizes.avatarChatBubble),
            const SizedBox(width: AppSpacing.s8),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

/// Delivery status icon drawn on the accent-colored outgoing bubble.
class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final dimmed = appColors.onAccent.withValues(
      alpha: AppOpacities.bubbleMeta,
    );
    switch (status) {
      case MessageStatus.sending:
        return Icon(
          Icons.access_time,
          size: AppIconSizes.status,
          color: dimmed,
        );
      case MessageStatus.sent:
        return Icon(Icons.check, size: AppIconSizes.status, color: dimmed);
      case MessageStatus.acked:
        return Icon(
          Icons.done_all,
          size: AppIconSizes.status,
          color: appColors.onAccent,
        );
      case MessageStatus.failed:
        return Icon(
          Icons.error_outline,
          size: AppIconSizes.status,
          color: appColors.danger,
        );
    }
  }
}

/// Rounded pill input + circular primary send button, with a remaining-bytes
/// counter that appears near the payload limit and blocks sending over it.
class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
  });

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s12,
          AppSpacing.s8,
          AppSpacing.s12,
          AppSpacing.s8,
        ),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            const budget = _maxPayloadBytes - kEnvelopeOverhead;
            final remaining = budget - utf8.encode(value.text).length;
            final overLimit = remaining < 0;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (remaining <= _counterThreshold)
                  Padding(
                    padding: const EdgeInsets.only(
                      right: AppSpacing.s8,
                      bottom: AppSpacing.s4,
                    ),
                    child: Text(
                      '$remaining',
                      style: AppTextStyles.label(context).copyWith(
                        color: overLimit ? context.appColors.danger : null,
                      ),
                    ),
                  ),
                Row(
                  // Keep the send button pinned to the bottom of the pill as
                  // the text field grows to multiple lines.
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s16,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(AppRadius.input),
                          boxShadow: [
                            BoxShadow(
                              color: context.appColors.islandShadow,
                              blurRadius: AppSizes.inputShadowBlur,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: controller,
                          // Grows downward with the text up to 6 lines, then
                          // scrolls internally. Enter inserts a newline; the
                          // send button sends.
                          minLines: 1,
                          maxLines: 6,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: context.l10n.messageHint,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.s12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    _SendButton(
                      enabled: !overLimit,
                      onPressed: onSend,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Circular primary send button; greyed out and inert while over the limit.
class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: enabled ? scheme.primary : scheme.surfaceContainerHighest,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: context.appColors.islandShadow,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: AppSizes.headerButton,
          height: AppSizes.headerButton,
          child: Icon(
            Icons.send,
            color: enabled
                ? context.appColors.onAccent
                : context.appColors.iconSecondary,
          ),
        ),
      ),
    );
  }
}

/// "Добавить контакт" dialog for unknown DM senders. Owns its controller so
/// the framework disposes it only after the dialog's exit animation.
class _AddContactDialog extends StatefulWidget {
  const _AddContactDialog({required this.nodeId});

  final String nodeId;

  @override
  State<_AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<_AddContactDialog> {
  final _nameCtrl = TextEditingController();
  String _emoji = '😊';

  static const _emojis = [
    '😊',
    '👩',
    '👨',
    '👵',
    '👴',
    '👦',
    '👧',
    '🐕',
    '🐈',
    '🏕️',
    '🏠',
    '❤️',
    '⭐',
    '🔥',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.addContact),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.nodeId, style: AppTextStyles.monoCaption(context)),
          const SizedBox(height: AppSpacing.s16),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(labelText: context.l10n.nameLabel),
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.s12),
          Wrap(
            spacing: AppSpacing.s6,
            children: _emojis
                .map(
                  (e) => GestureDetector(
                    onTap: () => setState(() => _emoji = e),
                    child: Container(
                      width: AppSizes.emojiCellSmall,
                      height: AppSizes.emojiCellSmall,
                      decoration: BoxDecoration(
                        color: e == _emoji
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(
                          AppRadius.chipSmall,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          e,
                          style: const TextStyle(fontSize: AppSizes.emojiSmall),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: _nameCtrl.text.trim().isNotEmpty
              ? () => Navigator.pop(context, (
                  name: _nameCtrl.text.trim(),
                  emoji: _emoji,
                ))
              : null,
          child: Text(context.l10n.add),
        ),
      ],
    );
  }
}
