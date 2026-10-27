import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_config.dart';
import '../../app/theme.dart';
import '../../state/core_providers.dart';
import '../../widgets/async_button.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/toast.dart';

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Validates like the web form's zod email rule.
String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  return _emailPattern.hasMatch(email) ? null : 'Enter a valid email';
}

/// A centred card on the grey background, used by the sign in and register screens.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(child: Padding(padding: const EdgeInsets.all(24), child: child)),
                  const SizedBox(height: 8),
                  const ServerAddressButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A password field with a show / hide toggle.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.autofillHints,
    this.onSubmitted,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;
  final VoidCallback? onSubmitted;
  final TextInputAction? textInputAction;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscured,
      validator: widget.validator,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted == null ? null : (_) => widget.onSubmitted!(),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        suffixIcon: IconButton(
          tooltip: _obscured ? 'Show password' : 'Hide password',
          icon: Icon(_obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
    );
  }
}

/// Shows which server the app talks to and lets the user point it elsewhere.
class ServerAddressButton extends ConsumerWidget {
  const ServerAddressButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(apiBaseUrlProvider);
    return TextButton.icon(
      onPressed: () => showFormSheet<void>(context, builder: (_) => const _ServerAddressSheet()),
      icon: const Icon(Icons.dns_outlined, size: 16),
      label: Text('Server: $url', overflow: TextOverflow.ellipsis),
      style: TextButton.styleFrom(foregroundColor: AppColors.secondaryText),
    );
  }
}

class _ServerAddressSheet extends ConsumerStatefulWidget {
  const _ServerAddressSheet();

  @override
  ConsumerState<_ServerAddressSheet> createState() => _ServerAddressSheetState();
}

class _ServerAddressSheetState extends ConsumerState<_ServerAddressSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller = TextEditingController(text: ref.read(apiBaseUrlProvider));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(String url) async {
    await ref.read(apiBaseUrlProvider.notifier).set(url);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
    Toast.success('Server address saved');
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: 'Server address',
      okText: 'Save',
      onOk: () {
        if (_formKey.currentState!.validate()) {
          _save(_controller.text);
        }
      },
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The PostInTime API this app signs in to. Use your computer\'s address (not localhost) when '
              'testing on a real phone.',
              style: AppText.secondary,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _controller,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'API base URL', hintText: 'https://api.example.com'),
              validator: (value) =>
                  ApiConfig.isValid(value ?? '') ? null : 'Enter a full http:// or https:// address',
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: AsyncButton(
                kind: AsyncButtonKind.text,
                label: 'Use default (${ApiConfig.defaultBaseUrl})',
                onPressed: () => _save(ApiConfig.defaultBaseUrl),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
