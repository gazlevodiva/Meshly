import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meshly/models/contact.dart';
import 'package:meshly/screens/add_contact_screen.dart';
import 'package:meshly/screens/chat_screen.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/mesh_service.dart';
import 'package:meshly/theme/app_theme.dart';
import 'package:meshly/widgets/conversation_tile.dart';
import 'package:meshly/widgets/tab_header.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({required this.meshService, super.key});

  final MeshService meshService;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
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

  void _openChat(BuildContext context, Contact contact) {
    final store = ContactStore.instance;
    final conv = store.dmForNode(contact.nodeId);
    if (conv == null) return;
    unawaited(store.markRead(conv.id));
    unawaited(Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          meshService: widget.meshService,
          conversation: conv,
        ),
      ),
    ));
    // No setState — ContactStore.notifyListeners() drives rebuilds.
  }

  void _openAddContact(BuildContext context) {
    unawaited(Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const AddContactScreen()),
    ));
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
                padding: const EdgeInsets.fromLTRB(AppSpacing.s20,
                    AppSpacing.s12, AppSpacing.s20, AppSpacing.s12),
                child: _searching
                    ? TabSearchRow(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _query = value),
                        onClose: _stopSearch,
                      )
                    : TabHeader(
                        title: 'Контакты',
                        onSearch: _startSearch,
                        onAdd: () => _openAddContact(context),
                      ),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: ContactStore.instance,
                  builder: (context, _) {
                    final query = _query.trim().toLowerCase();
                    final all = ContactStore.instance.contacts;
                    final contacts = query.isEmpty
                        ? all
                        : all
                            .where((c) =>
                                c.displayName.toLowerCase().contains(query))
                            .toList();
                    if (contacts.isEmpty) {
                      return Center(
                        child: Text(
                          query.isNotEmpty
                              ? 'Ничего не найдено'
                              : 'Нет контактов. Добавьте через +',
                          style: AppTextStyles.secondary(context),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.s16,
                          AppSpacing.s4,
                          AppSpacing.s16,
                          AppSpacing.listBottomPadding),
                      itemCount: contacts.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.s10),
                      itemBuilder: (_, i) {
                        final contact = contacts[i];
                        return _ContactCard(
                          contact: contact,
                          isOnline:
                              widget.meshService.isOnline(contact.nodeId),
                          lastHeard:
                              widget.meshService.lastHeardFor(contact.nodeId),
                          onTap: () => _openChat(context, contact),
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
}

/// A contact rendered in the same rounded-card style as conversations:
/// 48px emoji avatar with online dot, name, and a presence line.
class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.contact,
    required this.isOnline,
    required this.onTap,
    this.lastHeard,
  });

  final Contact contact;
  final bool isOnline;
  final DateTime? lastHeard;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.cardLarge);
    final showPresence = isOnline || lastHeard != null;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s12),
          child: Row(
            children: [
              ListAvatar(
                emoji: contact.avatarEmoji,
                title: contact.displayName,
                isOnline: isOnline,
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.displayName,
                      style: AppTextStyles.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showPresence) ...[
                      const SizedBox(height: AppSpacing.s2),
                      PresenceLine(isOnline: isOnline, lastHeard: lastHeard),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
