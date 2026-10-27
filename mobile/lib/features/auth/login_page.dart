import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../state/auth_controller.dart';
import '../../widgets/toast.dart';
import 'auth_layout.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(authProvider.notifier).login(_email.text.trim(), _password.text);
      Toast.success('Welcome back!');
      if (mounted) {
        context.go('/');
      }
    } catch (_) {
      Toast.error('Invalid email or password');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: Form(
        key: _formKey,
        autovalidateMode: _autovalidate,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('PostInTime', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            const Text('Sign in to your account', style: AppText.secondary),
            const SizedBox(height: 20),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Email', hintText: 'you@example.com'),
              validator: validateEmail,
            ),
            const SizedBox(height: 16),
            PasswordField(
              controller: _password,
              label: 'Password',
              hint: 'Password',
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              validator: (value) => (value ?? '').isEmpty ? 'Password is required' : null,
              onSubmitted: _submit,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Sign In'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('No account?'),
                TextButton(onPressed: () => context.go('/register'), child: const Text('Register')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
