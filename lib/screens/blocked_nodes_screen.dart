import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/theme/app_theme.dart';

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
                style: AppTextStyles.secondary,
              ),
            );
          }
          return ListView.builder(
            itemCount: blocked.length,
            itemBuilder: (_, i) {
              final nodeId = blocked[i];
              return ListTile(
                leading: const Icon(Icons.block, color: AppColors.warning),
                title: Text(
                  nodeId,
                  style: AppTextStyles.mono,
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
