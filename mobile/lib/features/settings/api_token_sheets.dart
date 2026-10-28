import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/actions.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/toast.dart';
import 'token_expiry.dart';

/// Name and expiry for a new API token. Pops with the created token's secret.
class CreateApiTokenSheet extends ConsumerStatefulWidget {
  const CreateApiTokenSheet({super.key});

  @override
  ConsumerState<CreateApiTokenSheet> createState() => _CreateApiTokenSheetState();
}

class _CreateApiTokenSheetState extends ConsumerState<CreateApiTokenSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  String _expiry = 'never';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final created = await ref
          .read(apiTokenActionsProvider)
          .create(name: _name.text.trim(), expiresAt: expiryFromPreset(_expiry));
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(created.token ?? '');
      Toast.success('API token created');
    } catch (_) {
      Toast.error('Failed to create API token');
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: 'Create API token',
      okText: 'OK',
      onOk: _create,
      loading: _saving,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'CI pipeline'),
              validator: (value) => (value ?? '').trim().isEmpty ? 'Give this token a name' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _expiry,
              decoration: const InputDecoration(labelText: 'Expiry'),
              items: [
                for (final option in expiryOptions) DropdownMenuItem(value: option.value, child: Text(option.label)),
              ],
              onChanged: (value) => setState(() => _expiry = value ?? 'never'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows a freshly issued secret, which the API never returns again.
class ApiTokenSecretSheet extends StatelessWidget {
  const ApiTokenSecretSheet({super.key, required this.secret});

  final String secret;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Copy your API token', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          const Text('This secret is shown only once. Store it somewhere safe.'),
          const SizedBox(height: 12),
          TextFormField(initialValue: secret, readOnly: true, minLines: 1, maxLines: 4),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: secret));
              Toast.success('Token copied');
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy token'),
          ),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
        ],
      ),
    );
  }
}
