import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meshly/models/contact.dart';
import 'package:meshly/screens/add_contact_screen.dart';
import 'package:meshly/screens/chat_screen.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/mesh_service.dart';

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
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Поиск...',
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() => _query = value),
              )
            : const Text('Контакты'),
        actions: _searching
            ? [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _stopSearch,
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _startSearch,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _openAddContact(context),
                ),
              ],
      ),
      body: ListenableBuilder(
        listenable: ContactStore.instance,
        builder: (context, _) {
          final query = _query.trim().toLowerCase();
          final all = ContactStore.instance.contacts;
          final contacts = query.isEmpty
              ? all
              : all
                  .where((c) => c.displayName.toLowerCase().contains(query))
                  .toList();
          if (contacts.isEmpty) {
            return Center(
              child: Text(
                query.isNotEmpty
                    ? 'Ничего не найдено'
                    : 'Нет контактов. Добавьте через +',
                style: const TextStyle(color: Colors.grey),
              ),
            );
          }
          return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: contacts.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 72),
                  itemBuilder: (_, i) {
                    final contact = contacts[i];
                    final online = widget.meshService.isOnline(contact.nodeId);
                    return ListTile(
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.transparent,
                            child: Text(
                              contact.avatarEmoji ?? '👤',
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                          if (online)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color:
                                        Theme.of(context).scaffoldBackgroundColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Text(contact.displayName),
                      onTap: () => _openChat(context, contact),
                    );
                  },
                );
        },
      ),
    );
  }
}
