import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../api/api_client.dart';
import '../../app/theme.dart';
import '../../models/models.dart';
import '../../state/actions.dart';
import '../../state/auth_controller.dart';
import '../../state/data_providers.dart';
import '../../widgets/account_menu.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/error_view.dart';
import '../../widgets/toast.dart';
import 'api_token_sheets.dart';
import 'token_expiry.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _create(BuildContext context) async {
    final secret = await showFormSheet<String>(context, builder: (_) => const CreateApiTokenSheet());
    if (secret != null && secret.isNotEmpty && context.mounted) {
      await _showSecret(context, secret);
    }
  }

  Future<void> _showSecret(BuildContext context, String secret) {
    return showFormSheet<void>(context, builder: (_) => ApiTokenSecretSheet(secret: secret));
  }

  Future<void> _refresh(BuildContext context, WidgetRef ref, ApiToken token) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Refresh this token?',
      content: 'The current secret will stop working immediately. A new secret will be shown once.',
      okText: 'Refresh',
    );
    if (!confirmed) {
      return;
    }
    try {
      final refreshed = await ref.read(apiTokenActionsProvider).refresh(token.id);
      Toast.success('API token refreshed');
      if (context.mounted && refreshed.token != null) {
        await _showSecret(context, refreshed.token!);
      }
    } catch (_) {
      Toast.error('Failed to refresh API token');
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, ApiToken token) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Delete this token?',
      content: 'Requests using this token will fail immediately.',
      okText: 'Delete',
      danger: true,
    );
    if (!confirmed) {
      return;
    }
    try {
      await ref.read(apiTokenActionsProvider).remove(token.id);
    } catch (error) {
      Toast.error(errorMessage(error, 'Failed to delete API token'));
    }
  }

  Future<void> _changeExpiry(WidgetRef ref, ApiToken token, String preset) async {
    try {
      final actions = ref.read(apiTokenActionsProvider);
      if (preset == 'never') {
        await actions.updateExpiry(token.id, neverExpires: true);
      } else {
        await actions.updateExpiry(token.id, expiresAt: expiryFromPreset(preset));
      }
      Toast.success('Expiry updated');
    } catch (_) {
      Toast.error('Failed to update expiry');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final tokens = ref.watch(apiTokensProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), actions: const [AccountMenuButton()]),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(apiTokensProvider.future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text('Email: ${user?.email ?? ''}'),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('API tokens', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      const Text(
                        'Use a token as a Bearer credential for REST calls to the PostInTime API.',
                        style: AppText.secondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () => _create(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New token'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (tokens.hasError && !tokens.hasValue)
              ErrorView(
                message: errorMessage(tokens.error!, 'Could not load API tokens'),
                onRetry: () => ref.invalidate(apiTokensProvider),
              )
            else if (!tokens.hasValue)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (tokens.requireValue.isEmpty)
              const Text('No API tokens yet.', style: AppText.secondary)
            else
              for (final token in tokens.requireValue)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _TokenCard(
                    token: token,
                    onRefresh: () => _refresh(context, ref, token),
                    onDelete: () => _delete(context, ref, token),
                    onExpiryChanged: (preset) => _changeExpiry(ref, token, preset),
                  ),
                ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => ref.read(authProvider.notifier).logout(),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TokenCard extends StatelessWidget {
  const _TokenCard({
    required this.token,
    required this.onRefresh,
    required this.onDelete,
    required this.onExpiryChanged,
  });

  final ApiToken token;
  final VoidCallback onRefresh;
  final VoidCallback onDelete;
  final ValueChanged<String> onExpiryChanged;

  @override
  Widget build(BuildContext context) {
    final lastUsed = token.lastUsedAt;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.vpn_key_outlined, size: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(token.name, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.rowBorder),
                        ),
                        child: Text(
                          '${token.tokenPrefix}…',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(formatExpiry(token.expiresAt), style: AppText.secondary),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        // Picking an option applies it straight away.
                        initialValue: null,
                        isDense: true,
                        hint: const Text('Change expiry'),
                        decoration: const InputDecoration(isDense: true),
                        items: [
                          for (final option in expiryOptions)
                            DropdownMenuItem(value: option.value, child: Text(option.label)),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            onExpiryChanged(value);
                          }
                        },
                      ),
                      if (lastUsed != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Last used ${DateFormat('MMM d, yyyy', 'en_US').format(lastUsed.toLocal())}',
                            style: AppText.secondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh secret'),
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
