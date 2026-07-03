import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meshly/services/contact_store.dart';

class BlockedNodesScreen extends StatelessWidget {
  const BlockedNodesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Заблокированные')),
      body: ListenableBuilder(
        listenable: ContactStore.instance,
        builder: (context, _) {
          final blocked = ContactStore.instance.blockedNodes;
          if (blocked.isEmpty) {
            return const Center(
              child: Text(
                'Нет заблокированных нод',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }
          return ListView.builder(
            itemCount: blocked.length,
            itemBuilder: (_, i) {
              final nodeId = blocked[i];
              return ListTile(
                leading: const Icon(Icons.block, color: Colors.orange),
                title: Text(
                  nodeId,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                trailing: TextButton(
                  onPressed: () =>
                      unawaited(ContactStore.instance.unblockNode(nodeId)),
                  child: const Text('Разблокировать'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
