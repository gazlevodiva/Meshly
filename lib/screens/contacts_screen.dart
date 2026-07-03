import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meshly/models/contact.dart';
import 'package:meshly/screens/add_contact_screen.dart';
import 'package:meshly/screens/chat_screen.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/mesh_service.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({required this.meshService, super.key});

  final MeshService meshService;

  void _openChat(BuildContext context, Contact contact) {
    final store = ContactStore.instance;
    final conv = store.dmForNode(contact.nodeId);
    if (conv == null) return;
    unawaited(store.markRead(conv.id));
    unawaited(Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          meshService: meshService,
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
      appBar: AppBar(title: const Text('Контакты')),
      body: ListenableBuilder(
        listenable: ContactStore.instance,
        builder: (context, _) {
          final contacts = ContactStore.instance.contacts;
          return contacts.isEmpty
              ? const Center(
                  child: Text(
                    'Нет контактов. Добавьте через +',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: contacts.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 72),
                  itemBuilder: (_, i) {
                    final contact = contacts[i];
                    final online = meshService.isOnline(contact.nodeId);
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddContact(context),
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
