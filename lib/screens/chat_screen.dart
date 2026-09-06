import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:meshly/l10n/l10n.dart';
import 'package:meshly/models/conversation.dart';
import 'package:meshly/models/message.dart';
import 'package:meshly/screens/add_contact_screen.dart';
import 'package:meshly/screens/channel_info_screen.dart';
import 'package:meshly/screens/edit_contact_screen.dart';
import 'package:meshly/screens/my_card_screen.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/mesh_service.dart';
import 'package:meshly/theme/app_theme.dart';
import 'package:meshly/utils/date_format.dart';
import 'package:meshly/utils/system_event_text.dart';
import 'package:meshly/widgets/conversation_tile.dart' show ListAvatar;
import 'package:meshly/widgets/section_card.dart';
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

  /// Measured height of the floating bottom area (input bar and/or the
  /// key-exchange card), used as the list's bottom padding so nothing is ever
  /// hidden behind it. Null until the first measurement lands: the list is not
  /// drawn before that, because a guessed padding would show the conversation
  /// at the wrong offset for one frame and then visibly jerk into place (the
  /// key-exchange card is several times taller than the input bar).
  double? _bottomAreaHeight;

  /// Previous value of `secureOk`, so the "restored" confirmation fires on the
  /// transition only — never when a healthy chat is simply opened.
  late bool _wasSecureOk;

  /// Set once this screen has scheduled its own close because the channel
  /// conversation it shows vanished from the store (deleted here, or — soon
  /// — by an owner removing this device from the group). Guards against
  /// scheduling the close more than once across repeated store notifications.
  ///
  /// DMs are deliberately excluded: a contact is only ever removed through a
  /// screen this one already reads the result of (`_openEditContact`), so
  /// there is no known path where the DM conversation disappears out from
  /// under an open chat. Auto-closing DMs too would risk popping the chat on
  /// a transient absence with no way to tell it apart from a real deletion.
  bool _channelGoneHandled = false;

  /// Whether the view is following the tail of the conversation. Flipped only
  /// by user-driven scrolling, so a bottom area that grows (or the very first
  /// measurement of it) can safely re-align to the real end of the list.
  bool _pinnedToBottom = true;

  List<Message> get _messages => _store.messagesFor(widget.conversation.id);

  /// `widget.conversation` is a snapshot taken when the screen was pushed —
  /// the secure-chat flags can change while we are here, so always re-read the
  /// live object from the store.
  Conversation get _conversation =>
      _store.conversationById(widget.conversation.id) ?? widget.conversation;

  @override
  void initState() {
    super.initState();
    _wasSecureOk = _conversation.secureOk;
    _store.addListener(_onStoreChanged);
    _scrollController.addListener(_onScroll);
    unawaited(_store.markRead(widget.conversation.id));
    _sub = widget.meshService.incomingMessages.listen((msg) {
      if (msg.conversationId == widget.conversation.id && mounted) {
        setState(() {});
        // Never yank a user who is reading older messages down to the tail.
        if (_pinnedToBottom) _scrollToBottom();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToBottom(animated: false),
    );
    _retryVerifyPing();
  }

  /// Occasion (b) of [MeshService.announceSecureState]: we opened a chat we
  /// consider broken, so our view may have drifted from the peer's.
  ///
  /// LoRa acknowledges nothing: the ping sent right after a QR scan can
  /// simply evaporate, and then both sides stay blocked until someone
  /// re-scans a QR in person. Opening the chat is the natural moment to try
  /// again.
  void _retryVerifyPing() {
    final conv = _conversation;
    final peerId = conv.peerId;
    if (!conv.isDm || peerId == null || conv.secureOk) return;
    // Nothing to encrypt to: the QR card is the only way forward.
    if (_store.contactByNodeId(peerId)?.publicKey == null) return;
    // Fire and forget: announceSecureState swallows its own failures, and the
    // chat must open regardless of what the radio is doing.
    unawaited(widget.meshService.announceSecureState(peerId));
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    _store.removeListener(_onStoreChanged);
    _scrollController.removeListener(_onScroll);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Confirms the repair the moment both halves line up: the card simply
  /// vanishing looks the same as accidentally dismissing it.
  void _onStoreChanged() {
    final conv = _conversation;
    if (conv.isChannel &&
        !_channelGoneHandled &&
        _store.conversationById(widget.conversation.id) == null) {
      _channelGoneHandled = true;
      // Never pop mid-notification: the store can call this while it is
      // itself mid-frame (e.g. right after `deleteChannel`'s notifyListeners,
      // while the channel-info screen above us is still on screen). Popping
      // one frame later lets that screen finish popping itself first, so the
      // two closes never race for the same top-of-stack route.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pop(context);
      });
      return;
    }
    if (!conv.isDm) return;
    final ok = conv.secureOk;
    final restored = ok && !_wasSecureOk;
    _wasSecureOk = ok;
    if (!restored) return;
    // The store can notify mid-frame; showing a snack bar then would assert.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.secureChatRestored)),
      );
    });
  }

  /// Tracks whether the user has scrolled away from the tail. Programmatic
  /// scrolls report an idle direction and are ignored.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.userScrollDirection == ScrollDirection.idle) return;
    _pinnedToBottom = pos.extentAfter < AppSpacing.chatTailSlack;
  }

  /// The bottom area changed height (card ⇄ input bar, connection banner,
  /// text scale, keyboard): re-pad the list so the tail of the conversation
  /// stays reachable.
  void _onBottomAreaSize(Size size) {
    final previous = _bottomAreaHeight;
    if (!mounted ||
        (previous != null && (size.height - previous).abs() < 0.5)) {
      return;
    }
    setState(() => _bottomAreaHeight = size.height);
    // Re-align to the real end. Never animated: this scroll is a side effect
    // of a layout measurement, not of anything the user did — animating it
    // reads as the conversation lurching on its own (it did, on every open of
    // a broken chat, and on every blink of the reconnect banner). Skipped once
    // the user has deliberately scrolled up, so a growing card never yanks
    // them away.
    if (_pinnedToBottom) _scrollToBottom(animated: false);
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (!animated) {
        _scrollController.jumpTo(target);
        return;
      }
      unawaited(
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  String _shortNodeId(String nodeId) {
    if (nodeId.startsWith('!') && nodeId.length > 9) {
      return '!${nodeId.substring(nodeId.length - 8)}';
    }
    return nodeId;
  }

  /// Only a scanned QR carries the peer's public key, so the key-exchange
  /// card sends the user to the scanner instead of a name-only "add contact"
  /// dialog (which would look like success while messaging still stays
  /// broken). Hence `qrOnly`: the manual tab on that screen adds a contact by
  /// node id, without a key — from here that is a trap, it reports success and
  /// leaves the chat just as unreadable.
  Future<void> _openQrScanner() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddContactScreen(meshService: widget.meshService, qrOnly: true),
      ),
    );
    if (mounted) setState(() {});
  }

  /// The other half of the exchange: the peer has to scan *our* code before
  /// they can encrypt anything we are able to read.
  Future<void> _openMyCard() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MyCardScreen(meshService: widget.meshService),
      ),
    );
    if (mounted) setState(() {});
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
          builder: (_) =>
              ChannelInfoScreen(channel: ch, meshService: widget.meshService),
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || utf8.encode(text).length > _maxPayloadBytes) return;
    final result = await widget.meshService.sendText(
      text,
      _conversation,
      force: _conversation.writeAnyway,
    );
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
        _conversation,
        force: _conversation.writeAnyway,
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

  /// State of the two-sided key exchange for this DM, or null when there is
  /// nothing to fix.
  ///
  /// Both halves are read straight off the conversation — never derived from
  /// the message history: unreadable messages are no longer stored, and the
  /// old ones that remain must not resurrect the card.
  _KeyExchangeState? get _keyExchangeState {
    final conv = _conversation;
    if (!conv.isDm || conv.peerId == null) return null;
    if (conv.secureOk) return null;
    return _KeyExchangeState(
      scanned: conv.iCanReadPeer,
      shown: conv.peerCanReadUs,
    );
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
              _ConnectionBanner(meshService: widget.meshService),
              Expanded(
                // The bottom area floats over the list: messages scroll
                // behind it, so the list is padded by exactly its measured
                // height (the key-exchange card is several times taller than
                // the input bar, and used to hide the last messages).
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    children: [
                      ListenableBuilder(
                        listenable: _store,
                        builder: (context, _) {
                          final bottomPadding = _bottomAreaHeight;
                          final messages = _messages;
                          // One frame of nothing while the bottom area is
                          // measured — cheaper than drawing the conversation
                          // at a guessed offset and jerking it into place.
                          if (bottomPadding == null) {
                            return const SizedBox.expand();
                          }
                          if (messages.isEmpty) {
                            // "Write the first message" would contradict the
                            // card that just took the input bar away.
                            // expand, not shrink: this is the Stack's only
                            // unpositioned child, so it also gives the stack
                            // its size.
                            if (!_conversation.secureOk) {
                              return const SizedBox.expand();
                            }
                            return Center(
                              child: Text(
                                context.l10n.writeFirstMessage,
                                style: AppTextStyles.secondary(context),
                              ),
                            );
                          }
                          return ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.fromLTRB(
                              AppSpacing.s12,
                              AppSpacing.s12,
                              AppSpacing.s12,
                              bottomPadding,
                            ),
                            itemCount: messages.length,
                            itemBuilder: (_, i) {
                              final msg = messages[i];
                              final prev = i > 0 ? messages[i - 1] : null;
                              final newDay =
                                  prev == null ||
                                  !_sameDay(prev.time, msg.time);
                              // A join/leave announcement is not a message
                              // from a person: no avatar, no bubble, no
                              // delivery ticks — just a centred, muted line.
                              if (msg.isSystemEvent) {
                                return Column(
                                  children: [
                                    if (newDay) _DateChip(date: msg.time),
                                    _SystemEventLine(msg: msg),
                                  ],
                                );
                              }
                              // In channels the sender avatar + name are shown
                              // once per run of consecutive same-sender
                              // messages (and again after a date chip).
                              final showSender =
                                  conv.isChannel &&
                                  !msg.isMe &&
                                  (newDay ||
                                      prev.isMe ||
                                      // A system event carries the node id of
                                      // whoever announced it, so without this
                                      // the next message from that person is
                                      // taken for a continuation and loses its
                                      // avatar and name.
                                      prev.isSystemEvent ||
                                      prev.fromNodeId != msg.fromNodeId);
                              return Column(
                                children: [
                                  if (newDay) _DateChip(date: msg.time),
                                  _MessageBubble(
                                    msg: msg,
                                    store: _store,
                                    inChannel: conv.isChannel,
                                    ackMeansDelivered: conv.ackMeansDelivered,
                                    showSender: showSender,
                                    onRetry: _retry,
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                      // Bottom slot: normally the input bar. While the secure
                      // chat is broken the card takes its place (writing into
                      // the void is pointless), and once we hold a fresh key
                      // it shrinks to a compact reminder above the input.
                      //
                      // Capped at a fraction of the chat area so a huge system
                      // font can never swallow the whole conversation — the
                      // card scrolls inside the cap instead.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight:
                                constraints.maxHeight *
                                AppSizes.chatBottomAreaMaxFraction,
                          ),
                          child: _MeasureSize(
                            onChange: _onBottomAreaSize,
                            child: ListenableBuilder(
                              listenable: _store,
                              builder: (context, _) =>
                                  _buildBottomArea(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The bottom slot of the chat: the input bar, the key-exchange card in its
  /// place, or both (compact card as a reminder above a usable input).
  ///
  /// While either direction is broken the input bar is replaced by the full
  /// card — mirroring `sendText`, which refuses the same messages. The escape
  /// hatch ("send anyway") always exists because the breakage signal can be
  /// unauthenticated and could be forged over the air; taking it swaps the
  /// card for its compact form above a usable input.
  Widget _buildBottomArea(BuildContext context) {
    final state = _keyExchangeState;
    if (state == null) {
      return _InputBar(controller: _controller, onSend: _send);
    }
    // Sticky per conversation: the breakage signal is unauthenticated, so a
    // repeated forged packet must not re-block a chat the user unblocked.
    final canWrite = _conversation.writeAnyway;
    final vPadding = AppSpacing.s8 + (canWrite ? 0 : AppSpacing.s8);
    // The card has to be told how tall it may be: `SectionCard` wraps its
    // content in a Column, and a Column hands its children an unbounded main
    // axis — the constraint from the chat's height cap dies there, and the
    // card's own scroll view has nothing left to shrink against.
    Widget card(double available) => Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s12,
        AppSpacing.s8,
        AppSpacing.s12,
        canWrite ? 0 : AppSpacing.s8,
      ),
      child: _KeyExchangeCard(
        state: state,
        meshService: widget.meshService,
        maxHeight: available - vPadding,
        compact: canWrite,
        onScan: _openQrScanner,
        onShowMyQr: _openMyCard,
        // The escape hatch is pointless once the input bar is back: reaching
        // that state is exactly what using it does.
        onSendAnyway: canWrite
            ? null
            : () => unawaited(
                _store.setWriteAnyway(_conversation.id, value: true),
              ),
      ),
    );
    if (canWrite) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The reminder gives way first: the input bar must stay reachable
          // no matter how tall the card grows. Below the height its own head
          // needs it disappears entirely — with the keyboard up on a small
          // screen at a large font the slot was down to 8–40 px, i.e. a
          // meaningless slice of a card, and the field matters more.
          Flexible(
            child: LayoutBuilder(
              builder: (context, constraints) =>
                  constraints.maxHeight < _reminderMinHeight(context)
                  ? const SizedBox.shrink()
                  : card(constraints.maxHeight),
            ),
          ),
          _InputBar(controller: _controller, onSend: _send),
        ],
      );
    }
    // The card itself scrolls its tail inside whatever height the cap leaves;
    // its head (title + action) always stays in frame.
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => card(constraints.maxHeight),
      ),
    );
  }

  /// Height the compact reminder needs before it is worth drawing: its pinned
  /// head (title line + action button) plus the card's own padding, scaled
  /// with the system font.
  double _reminderMinHeight(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(AppSizes.chatReminderMinHeight);

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

/// Reports its child's laid-out size to [onChange] (after the frame, so the
/// callback may call setState). Used to pad the message list by exactly the
/// height of whatever floats over its bottom edge.
class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({required this.onChange, required Widget super.child});

  final ValueChanged<Size> onChange;

  @override
  _RenderMeasureSize createRenderObject(BuildContext context) =>
      _RenderMeasureSize(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureSize renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onChange);

  ValueChanged<Size> onChange;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    final measured = child?.size ?? Size.zero;
    if (_last == measured) return;
    _last = measured;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(measured));
  }
}

/// Which halves of the mutual key exchange are already done.
class _KeyExchangeState {
  const _KeyExchangeState({required this.scanned, required this.shown});

  /// We scanned the peer's QR after the breakage → we can read them.
  final bool scanned;

  /// The peer scanned our QR → they can encrypt something we can read.
  /// May rest on an unauthenticated hint (see Conversation.peerCanReadUs).
  final bool shown;
}

/// Names the task ("exchange QR codes"), and — crucially — shows that the fix
/// is *two-sided*: each side must scan the other's code.
///
/// Layout order is deliberate and driven by what fits above the fold: title,
/// one-line explanation, then the single accented button, and only after it
/// the checklist. The bottom area is capped at a fraction of the chat, and on
/// a 320x568 screen that leaves barely 250 logical pixels — with the button
/// last (as it used to be) it sat below the fold on *every* phone, inside a
/// scroll view with no affordance. The steps are pure status (checkmark +
/// label, never a button), so pushing them under the button loses nothing.
///
/// Full form replaces the input bar (writing is pointless while the peer
/// cannot read us) and offers the "send anyway" escape hatch; [compact] form
/// sits above a usable input bar and shrinks to a bare reminder: title plus
/// the same one action.
class _KeyExchangeCard extends StatelessWidget {
  const _KeyExchangeCard({
    required this.state,
    required this.meshService,
    required this.maxHeight,
    required this.onScan,
    required this.onShowMyQr,
    this.compact = false,
    this.onSendAnyway,
  });

  final _KeyExchangeState state;

  /// Height the card may occupy; its tail scrolls inside whatever is left
  /// after the pinned head. Passed in because the enclosing [SectionCard]
  /// swallows the incoming height constraint (see the call site).
  final double maxHeight;

  /// Watched for the connection status: the verify packet that checks step 2
  /// never leaves the phone while the radio is down.
  final MeshService meshService;

  final VoidCallback onScan;
  final VoidCallback onShowMyQr;

  final bool compact;

  /// Null hides the escape hatch (already used, or not applicable).
  final VoidCallback? onSendAnyway;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: ConstrainedBox(
          // maxFinite, not infinity: an unbounded box would turn the Flexible
          // children below into an assertion instead of a scroll.
          constraints: BoxConstraints(
            maxHeight: maxHeight.isFinite
                ? math.max(maxHeight - AppSpacing.s16 * 2, 0)
                : double.maxFinite,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Pinned head ──────────────────────────────────────────────
              // The task and the button that performs it never scroll: capping
              // the whole card by a fraction of the chat and letting everything
              // scroll inside meant that at a x2 system font the button sat
              // 30–370 px below the visible window, with no scrollbar to hint
              // at it. The title is Flexible so that in the extreme case the
              // head gives up title lines (clipped by the card) rather than
              // overflowing the box the button lives in.
              Flexible(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: AppIconSizes.info,
                      color: context.appColors.iconSecondary,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        context.l10n.secureChatBrokenTitle,
                        style: AppTextStyles.cardTitle,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              // Exactly one action, always accented and always in the same
              // place, directly under the title so it survives any screen:
              // whichever step is next.
              SizedBox(width: double.infinity, child: _nextAction(context)),
              // The compact reminder hides every hint but this one: a greyed-out
              // button with no explanation is the worst of both worlds, and
              // offline is exactly when the user cannot act.
              if (compact) ?_actionCaption(context, offlineOnly: true),
              // ── Scrolling tail ───────────────────────────────────────────
              // Explanation, checklist, hints and the escape hatch: everything
              // that can wait until the user has read the first two lines.
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!compact) ...[
                        // The one caption slot under the button. Offline it
                        // explains the dead button; otherwise it answers the
                        // question people actually get stuck on — the camera
                        // needs a code to point at.
                        ?_actionCaption(context),
                        const SizedBox(height: AppSpacing.s12),
                        Text(
                          context.l10n.secureChatBrokenBody,
                          style: AppTextStyles.caption(context),
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        // Steps are status only — all rendered identically, so
                        // the list reads as one checklist instead of a pile of
                        // controls. Both are impersonal: Russian would need the
                        // genitive for "Anna's code" and ICU cannot decline, so
                        // mixing a name into one of them made the two lines read
                        // as being about different people.
                        _KeyExchangeStep(
                          done: state.scanned,
                          label: context.l10n.keyExchangeStepScan,
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        _KeyExchangeStep(
                          done: state.shown,
                          label: context.l10n.keyExchangeStepShow,
                        ),
                        // Only meaningful in the gap between the two checkmarks:
                        // at that point the user is staring at step 2 waiting
                        // for a button that does not exist. Before that it is
                        // noise.
                        if (state.scanned && !state.shown) ...[
                          const SizedBox(height: AppSpacing.s8),
                          Text(
                            context.l10n.keyExchangeHint,
                            style: AppTextStyles.caption(context),
                          ),
                        ],
                      ],
                      // Deliberately understated: the QR exchange is the real
                      // fix, this is only for the case where the "chat is
                      // broken" signal was a forgery.
                      if (onSendAnyway != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: onSendAnyway,
                            style: TextButton.styleFrom(
                              foregroundColor: context.appColors.textSecondary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s8,
                              ),
                              minimumSize: const Size(
                                0,
                                AppSizes.linkButtonHeight,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              context.l10n.sendAnywayButton,
                              style: AppTextStyles.caption(context),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Caption under the main button, or null when there is nothing to add.
  ///
  /// With [offlineOnly] the caption exists only while the radio is down — the
  /// compact reminder has room for the reason a button is dead, but not for
  /// general advice.
  Widget? _actionCaption(BuildContext context, {bool offlineOnly = false}) {
    if (state.scanned) return null;
    return ValueListenableBuilder<MeshConnectionStatus>(
      valueListenable: meshService.connectionStatus,
      builder: (context, status, _) {
        final connected = status == MeshConnectionStatus.connected;
        if (offlineOnly && connected) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s8),
          child: Text(
            connected
                ? context.l10n.keyExchangeAskPeer
                : context.l10n.connectDeviceFirst,
            style: AppTextStyles.caption(context),
          ),
        );
      },
    );
  }

  /// The single call to action for the current state.
  ///
  /// The card is only built while `!secureOk`, so at least one of the two
  /// steps is always outstanding and one of the two buttons below is always
  /// the one returned; the empty tail is unreachable and exists only to keep
  /// the function total.
  ///
  /// Scanning without a radio is theatre — the scan would succeed locally and
  /// the peer would never learn about it — so that button goes inert (the
  /// reason is spelled out by [_actionCaption], instead of overwriting the
  /// label and leaving the user guessing what the button did). Showing our own
  /// code, on the other hand, needs no radio at all: the *peer's* camera reads
  /// it, so that button is never disabled.
  Widget _nextAction(BuildContext context) {
    if (!state.scanned) {
      return ValueListenableBuilder<MeshConnectionStatus>(
        valueListenable: meshService.connectionStatus,
        builder: (context, status, _) {
          final connected = status == MeshConnectionStatus.connected;
          return FilledButton.icon(
            onPressed: connected ? onScan : null,
            icon: Icon(
              connected ? Icons.qr_code_scanner : Icons.bluetooth_disabled,
            ),
            label: Text(context.l10n.scanQrButton),
          );
        },
      );
    }
    if (!state.shown) {
      return FilledButton.icon(
        onPressed: onShowMyQr,
        icon: const Icon(Icons.qr_code_2),
        label: Text(context.l10n.showMyQrButton),
      );
    }
    return const SizedBox.shrink();
  }
}

/// One checklist row: state icon + wrapped label. Purely presentational —
/// the card owns the single action button, never the steps.
class _KeyExchangeStep extends StatelessWidget {
  const _KeyExchangeStep({required this.done, required this.label});

  final bool done;
  final String label;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          size: AppIconSizes.info,
          color: done ? appColors.online : appColors.iconSecondary,
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Text(
            label,
            style: done ? AppTextStyles.secondary(context) : AppTextStyles.body,
          ),
        ),
      ],
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

/// Centred, muted line for a join/leave announcement — never a bubble: no
/// avatar, no delivery ticks, since a system event has neither a sender to
/// portray nor a delivery state to track (see `Message.systemEvent`).
class _SystemEventLine extends StatelessWidget {
  const _SystemEventLine({required this.msg});

  final Message msg;

  @override
  Widget build(BuildContext context) {
    final text = systemEventText(context, msg);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
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
    required this.ackMeansDelivered,
    required this.showSender,
    required this.onRetry,
  });

  final Message msg;
  final ContactStore store;
  final bool inChannel;

  /// Whether a routing-ack in this conversation means the peer actually got
  /// the message (see `Conversation.ackMeansDelivered`) — decides whether
  /// `MessageStatus.acked` may draw as a second checkmark.
  final bool ackMeansDelivered;

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
          _StatusIcon(status: msg.status, ackMeansDelivered: ackMeansDelivered),
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
                  context.l10n.undecryptableBubble,
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
///
/// `MessageStatus.acked` is only a transport fact — the radio got a
/// ROUTING_APP confirmation. Whether that confirmation actually means the
/// peer received the message depends on the conversation (see
/// `Conversation.ackMeansDelivered`), so the caller passes that decision in
/// rather than this widget re-deriving it from conversation state it doesn't
/// have.
class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status, required this.ackMeansDelivered});

  final MessageStatus status;
  final bool ackMeansDelivered;

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
        // A routing-ack that doesn't mean the peer got it (channel
        // broadcast, or a DM kept open via writeAnyway) is only worth
        // "left the antenna" — the same single checkmark as `sent`, never a
        // second one implying delivery that was never confirmed.
        if (!ackMeansDelivered) {
          return Icon(Icons.check, size: AppIconSizes.status, color: dimmed);
        }
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
