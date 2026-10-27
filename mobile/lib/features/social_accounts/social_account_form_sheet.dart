import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../api/social_accounts_api.dart';
import '../../models/models.dart';
import '../../state/actions.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/toast.dart';

/// Add a social account to a channel, or edit [account] (the platform is fixed once created).
class SocialAccountFormSheet extends ConsumerStatefulWidget {
  const SocialAccountFormSheet({super.key, required this.channelId, this.account});

  final String channelId;
  final SocialAccount? account;

  @override
  ConsumerState<SocialAccountFormSheet> createState() => _SocialAccountFormSheetState();
}

class _SocialAccountFormSheetState extends ConsumerState<SocialAccountFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.account?.name);
  late final _profileUrl = TextEditingController(text: widget.account?.profileUrl);
  late final _webhookUrl = TextEditingController(text: widget.account?.webhookUrl);
  late final _username = TextEditingController(text: widget.account?.webhookUsername);
  final _password = TextEditingController();
  late Platform? _platform = widget.account?.platform;
  late PostingMode _mode = widget.account?.postingMode ?? PostingMode.manual;
  late WebhookAuthType _authType = widget.account?.webhookAuthType ?? WebhookAuthType.none;
  bool _saving = false;

  bool get _editing => widget.account != null;
  bool get _webhook => _mode == PostingMode.webhook;
  bool get _basic => _webhook && _authType == WebhookAuthType.basic;

  @override
  void dispose() {
    _name.dispose();
    _profileUrl.dispose();
    _webhookUrl.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _nullIfEmpty(String value) => value.trim().isEmpty ? null : value.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    final data = SocialAccountInput(
      platform: _platform,
      name: _name.text.trim(),
      // Editing sends the field even when emptied, so a profile URL can be cleared.
      profileUrl: _editing ? _profileUrl.text.trim() : _nullIfEmpty(_profileUrl.text),
      postingMode: _mode,
      webhookUrl: _webhook ? _webhookUrl.text.trim() : null,
      webhookAuthType: _webhook ? _authType : WebhookAuthType.none,
      webhookUsername: _basic ? _username.text.trim() : null,
      webhookPassword: _basic && _password.text.isNotEmpty ? _password.text : null,
    );
    final actions = ref.read(socialAccountActionsProvider(widget.channelId));
    try {
      if (_editing) {
        await actions.update(widget.account!.id, data);
      } else {
        await actions.create(data);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      Toast.success('Account saved');
    } catch (error) {
      Toast.error(errorMessage(error, 'Failed to save account'));
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPassword = widget.account?.webhookHasPassword ?? false;
    return SheetScaffold(
      title: _editing ? 'Edit Account' : 'Add Account',
      okText: 'OK',
      onOk: _save,
      loading: _saving,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<Platform>(
              initialValue: _platform,
              decoration: const InputDecoration(labelText: 'Platform'),
              items: [for (final platform in Platform.values) DropdownMenuItem(value: platform, child: Text(platform.label))],
              onChanged: _editing ? null : (value) => setState(() => _platform = value),
              validator: (value) => value == null ? 'Platform is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) => (value ?? '').trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _profileUrl,
              keyboardType: TextInputType.url,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Profile URL', hintText: 'https://instagram.com/example'),
            ),
            const SizedBox(height: 16),
            const Text('Action type'),
            const SizedBox(height: 8),
            SegmentedButton<PostingMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: PostingMode.manual, label: Text('Manual')),
                ButtonSegment(value: PostingMode.webhook, label: Text('Webhook')),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) => setState(() => _mode = selection.first),
            ),
            if (_webhook) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _webhookUrl,
                keyboardType: TextInputType.url,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Webhook URL',
                  hintText: 'https://n8n.example.com/webhook/post',
                ),
                validator: (value) => (value ?? '').trim().isEmpty ? 'Webhook URL is required' : null,
              ),
              const SizedBox(height: 16),
              const Text('Credentials'),
              const SizedBox(height: 8),
              SegmentedButton<WebhookAuthType>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: WebhookAuthType.none, label: Text('None')),
                  ButtonSegment(value: WebhookAuthType.basic, label: Text('Basic')),
                ],
                selected: {_authType},
                onSelectionChanged: (selection) => setState(() => _authType = selection.first),
              ),
            ],
            if (_basic) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _username,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (value) => (value ?? '').trim().isEmpty ? 'Username is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                obscureText: true,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: hasPassword ? 'Leave blank to keep the current password' : null,
                ),
                validator: (value) => !hasPassword && (value ?? '').isEmpty ? 'Password is required' : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
