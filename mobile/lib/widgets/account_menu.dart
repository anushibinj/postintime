import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../state/auth_controller.dart';

/// The header of the web app (who is signed in, plus Logout) as an app bar menu.
class AccountMenuButton extends ConsumerWidget {
  const AccountMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final name = user == null || user.displayName.isEmpty ? user?.email ?? '' : user.displayName;
    return PopupMenuButton<String>(
      tooltip: 'Account',
      icon: const Icon(Icons.account_circle_outlined),
      onSelected: (value) {
        if (value == 'logout') {
          ref.read(authProvider.notifier).logout();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Text(name, style: const TextStyle(color: AppColors.secondaryText)),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(children: [Icon(Icons.logout, size: 18), SizedBox(width: 12), Text('Logout')]),
        ),
      ],
    );
  }
}
