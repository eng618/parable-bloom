import 'package:material_ui/material_ui.dart';

import 'auth_field_validation.dart';

/// Email and password fields for iOS, Android, and desktop.
///
/// [AutofillGroup] plus hints is what those platforms' password managers read.
/// The web build uses a different implementation with real HTML inputs.
class AuthCredentialFields extends StatefulWidget {
  const AuthCredentialFields({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.isLogin,
    required this.onSubmit,
    this.enabled = true,
    this.visible = true,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLogin;
  final VoidCallback onSubmit;
  final bool enabled;

  /// Kept in step with the web fields, which must hide under dialogs.
  final bool visible;

  @override
  State<AuthCredentialFields> createState() => AuthCredentialFieldsState();
}

class AuthCredentialFieldsState extends State<AuthCredentialFields> {
  final _formKey = GlobalKey<FormState>();
  final _passwordFocus = FocusNode();

  @override
  void dispose() {
    _passwordFocus.dispose();
    super.dispose();
  }

  /// Runs the email and password checks and shows their messages.
  bool validate() => _formKey.currentState?.validate() ?? false;

  /// Submits the surrounding sign-in form.
  void submit() => widget.onSubmit();

  @override
  Widget build(BuildContext context) {
    final emailHints = widget.isLogin
        ? const [AutofillHints.username]
        : const [AutofillHints.email];
    final passwordHints = widget.isLogin
        ? const [AutofillHints.password]
        : const [AutofillHints.newPassword];

    return Visibility(
      visible: widget.visible,
      maintainState: true,
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: widget.emailController,
                enabled: widget.enabled,
                autofillHints: emailHints,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                validator: validateAuthEmail,
                onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: widget.passwordController,
                focusNode: _passwordFocus,
                enabled: widget.enabled,
                autofillHints: passwordHints,
                obscureText: true,
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: validateAuthPassword,
                onFieldSubmitted: (_) => widget.onSubmit(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
