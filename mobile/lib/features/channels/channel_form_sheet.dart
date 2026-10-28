import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../state/actions.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/toast.dart';

final _slugPattern = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

/// Create a channel, or edit [channel] (the slug is fixed once created).
class ChannelFormSheet extends ConsumerStatefulWidget {
  const ChannelFormSheet({super.key, this.channel});

  final Channel? channel;

  @override
  ConsumerState<ChannelFormSheet> createState() => _ChannelFormSheetState();
}

class _ChannelFormSheetState extends ConsumerState<ChannelFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.channel?.name);
  late final _slug = TextEditingController(text: widget.channel?.slug);
  late final _description = TextEditingController(text: widget.channel?.description);
  late bool _enabled = widget.channel?.enabled ?? true;
  bool _saving = false;

  bool get _editing => widget.channel != null;

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    final actions = ref.read(channelActionsProvider);
    try {
      if (_editing) {
        await actions.update(
          widget.channel!.id,
          name: _name.text.trim(),
          slug: _slug.text.trim(),
          description: _description.text,
          enabled: _enabled,
        );
      } else {
        await actions.create(name: _name.text.trim(), slug: _slug.text.trim(), description: _description.text);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      Toast.success('Channel saved');
    } catch (_) {
      Toast.error('Failed to save channel');
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: _editing ? 'Edit Channel' : 'Create Channel',
      okText: 'OK',
      onOk: _save,
      loading: _saving,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) => (value ?? '').trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _slug,
              enabled: !_editing,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Slug',
                hintText: 'tech',
                helperText: 'Lowercase letters, numbers and dashes',
              ),
              validator: (value) {
                final slug = (value ?? '').trim();
                if (slug.isEmpty) {
                  return 'Slug is required';
                }
                return _slugPattern.hasMatch(slug) ? null : 'Use lowercase letters, numbers and single dashes';
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            if (_editing)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enabled'),
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
          ],
        ),
      ),
    );
  }
}
