import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/theme/app_theme.dart';
import 'package:meshly/widgets/section_card.dart';
import 'package:meshly/widgets/tab_header.dart';

class BlockedNodesScreen extends StatelessWidget {
  const BlockedNodesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Заблокированные'),
      ),
      body: TabGradientBackground(
        child: ListenableBuilder(
          listenable: ContactStore.instance,
          builder: (context, _) {
            final blocked = ContactStore.instance.blockedNodes;
            if (blocked.isEmpty) {
              return Center(
                child: Text(
                  'Нет заблокированных нод',
                  style: AppTextStyles.secondary(context),
                ),
              );
            }
            return ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.s16,
                topInset + AppSpacing.s8,
                AppSpacing.s16,
                AppSpacing.s32,
              ),
              children: [
                SectionCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < blocked.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        ListTile(
                          leading: Icon(
                            Icons.block,
                            color: context.appColors.warning,
                          ),
                          title: Text(
                            blocked[i],
                            style: AppTextStyles.mono,
                          ),
                          trailing: TextButton(
                            onPressed: () => unawaited(
                              ContactStore.instance.unblockNode(blocked[i]),
                            ),
                            child: const Text('Разблокировать'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
