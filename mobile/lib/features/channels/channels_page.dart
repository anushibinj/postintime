import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../app/theme.dart';
import '../../models/models.dart';
import '../../state/actions.dart';
import '../../state/data_providers.dart';
import '../../widgets/account_menu.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/error_view.dart';
import '../../widgets/toast.dart';
import 'channel_form_sheet.dart';

class ChannelsPage extends ConsumerWidget {
  const ChannelsPage({super.key});

  void _openForm(BuildContext context, [Channel? channel]) {
    showFormSheet<void>(context, builder: (_) => ChannelFormSheet(channel: channel));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Channel channel) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Delete channel?',
      content: 'This will delete all posts and social accounts in this channel.',
      okText: 'Delete',
      danger: true,
    );
    if (!confirmed) {
      return;
    }
    try {
      await ref.read(channelActionsProvider).delete(channel.id);
      Toast.success('Channel deleted');
    } catch (error) {
      Toast.error(errorMessage(error, 'Failed to delete channel'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(channelsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Channels'), actions: const [AccountMenuButton()]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('New Channel'),
      ),
      body: AsyncValueView<List<Channel>>(
        value: channels,
        onRetry: () => ref.invalidate(channelsProvider),
        data: (items) {
          if (items.isEmpty) {
            return _EmptyChannels(onCreate: () => _openForm(context));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(channelsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) => _ChannelCard(
                channel: items[index],
                onView: () => context.go('/channels/${items[index].id}'),
                onEdit: () => _openForm(context, items[index]),
                onDelete: () => _delete(context, ref, items[index]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyChannels extends StatelessWidget {
  const _EmptyChannels({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 48, color: AppColors.disabledText),
          const SizedBox(height: 8),
          const Text('No channels yet', style: AppText.secondary),
          const SizedBox(height: 16),
          FilledButton(onPressed: onCreate, child: const Text('Create Channel')),
        ],
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.channel, required this.onView, required this.onEdit, required this.onDelete});

  final Channel channel;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final description = channel.description;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onView,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          channel.name,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: 8),
                      AppTag(channel.enabled ? 'Enabled' : 'Disabled', tone: channel.enabled ? TagTone.green : TagTone.neutral),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('/${channel.slug}', style: AppText.secondary),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.secondary),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    '${channel.postCount} posts · ${channel.socialAccountCount} social accounts',
                    style: AppText.secondary,
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          Row(
            children: [
              Expanded(child: TextButton.icon(onPressed: onView, icon: const Icon(Icons.visibility_outlined, size: 18), label: const Text('View'))),
              Expanded(child: TextButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Edit'))),
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
