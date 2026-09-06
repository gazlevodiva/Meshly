import 'package:flutter/widgets.dart';
import 'package:meshly/l10n/l10n.dart';
import 'package:meshly/models/message.dart';
import 'package:meshly/services/contact_store.dart';

/// The line shown for a join/leave event, localized.
///
/// One function rather than a `switch` at each call site: the same line
/// appears in the chat timeline, in the conversation-list preview and in the
/// joins-and-leaves log, and each of those is covered by tests of its own
/// screen. A third event kind added to only two of the three would compile,
/// pass every test, and be wrong in the third place.
String systemEventText(BuildContext context, Message message) {
  final kind = message.eventKind;
  if (kind == null) return message.text;

  // Prefer the name we gave this person over the one they announced. Ours
  // came from scanning their code in person; theirs is whatever their
  // device happened to send — often just a node id, because the name is
  // only set once someone opens their own card. Showing "Мама" instead of
  // "!ce9eb39d" is also simply how every messenger behaves.
  final known = ContactStore.instance.contactByNodeId(message.fromNodeId);
  final name = known?.displayLabel ?? message.text;

  return switch (kind) {
    SystemEventKind.joined => context.l10n.systemEventJoined(name),
    SystemEventKind.left => context.l10n.systemEventLeft(name),
  };
}
