import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../app/theme.dart';
import '../../core/external_links.dart';
import '../../models/models.dart';
import '../../state/actions.dart';
import '../../state/data_providers.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/error_view.dart';
import '../../widgets/toast.dart';
import 'social_account_form_sheet.dart';

class SocialAccountsPage extends ConsumerWidget {
  const SocialAccountsPage({super.key, required this.channelId});

  final String channelId;

  void _openForm(BuildContext context, [SocialAccount? account]) {
    showFormSheet<void>(context, builder: (_) => SocialAccountFormSheet(channelId: channelId, account: account));
  }

  Future<void> _toggleEnabled(WidgetRef ref, SocialAccount account) async {
    final actions = ref.read(socialAccountActionsProvider(channelId));
    try {
      account.enabled ? await actions.disable(account.id) : await actions.enable(account.id);
    } catch (error) {
      Toast.error(errorMessage(error, 'Could not update the account'));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, SocialAccount account) async {
    final confirmed = await confirmDialog(context, title: 'Delete account?', okText: 'Delete', danger: true);
    if (!confirmed) {
      return;
    }
    try {
      await ref.read(socialAccountActionsProvider(channelId)).remove(account.id);
    } catch (error) {
      Toast.error(errorMessage(error, 'Could not delete the account'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(socialAccountsProvider(channelId));
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton(fallback: '/channels/$channelId'),
        title: const Text('Social Accounts'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Account'),
      ),
      body: AsyncValueView<List<SocialAccount>>(
        value: accounts,
        onRetry: () => ref.invalidate(socialAccountsProvider(channelId)),
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(socialAccountsProvider(channelId).future),
          child: items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    Center(child: Text('No social accounts yet', style: AppText.secondary)),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final account = items[index];
                    return _AccountCard(
                      account: account,
                      onEdit: () => _openForm(context, account),
                      onToggle: () => _toggleEnabled(ref, account),
                      onDelete: () => _delete(context, ref, account),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account, required this.onEdit, required this.onToggle, required this.onDelete});

  final SocialAccount account;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final profileUrl = account.profileUrl;
    final webhookUrl = account.webhookUrl;
    final details = [
      account.isWebhook ? 'Webhook' : 'Manual',
      if (account.isWebhook && account.webhookAuthType == WebhookAuthType.basic) 'Basic auth',
      account.enabled ? 'Enabled' : 'Disabled',
    ].join(' · ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(account.platform.label, style: AppText.secondary),
                if (profileUrl != null && profileUrl.isNotEmpty)
                  InkWell(
                    onTap: () => openExternal(profileUrl),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        profileUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.primary),
                      ),
                    ),
                  ),
                if (account.isWebhook && webhookUrl != null && webhookUrl.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(webhookUrl, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.secondary),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(details, style: AppText.secondary),
                ),
              ],
            ),
          ),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: onToggle,
                  icon: Icon(account.enabled ? Icons.power_off_outlined : Icons.power_settings_new, size: 18),
                  label: Text(account.enabled ? 'Disable' : 'Enable'),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: onDelete,
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
