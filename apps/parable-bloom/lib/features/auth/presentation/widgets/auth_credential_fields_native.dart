import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'auth_credential_keys.dart';
import 'auth_field_validation.dart';

/// Email and password fields for iOS, Android, and desktop.
///
/// [AutofillGroup] plus hints is what those platforms' password managers read.
/// The web build uses a different implementation with real HTML inputs.
///
/// The email keyboard action is Next. Arrow Up, Arrow Down, and the platform
/// previous and next keys move between the two fields. Tab uses the normal
/// focus order, so it also continues on to the next control.
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
  final _emailFocus = FocusNode(debugLabel: 'auth-email');
  final _passwordFocus = FocusNode(debugLabel: 'auth-password');
  late final OnKeyEventCallback _earlyKeyHandler = _handleEarlyKey;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addEarlyKeyEventHandler(_earlyKeyHandler);
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_earlyKeyHandler);
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// Arrow and navigate keys move between the fields before the text field
  /// treats them as caret motion. Tab still uses Flutter's focus order.
  KeyEventResult _handleEarlyKey(KeyEvent event) {
    if (event is! KeyDownEvent || !widget.enabled) {
      return KeyEventResult.ignored;
    }
    final primary = FocusManager.instance.primaryFocus;
    final onEmail = identical(primary, _emailFocus);
    final onPassword = identical(primary, _passwordFocus);
    if (!onEmail && !onPassword) {
      return KeyEventResult.ignored;
    }
    final key = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowDown => 'ArrowDown',
      LogicalKeyboardKey.arrowUp => 'ArrowUp',
      LogicalKeyboardKey.navigateNext => 'NavigateNext',
      LogicalKeyboardKey.navigatePrevious => 'NavigatePrevious',
      _ => null,
    };
    if (key == null) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    final move = authCredentialFieldMove(
      onEmail: onEmail,
      onPassword: onPassword,
      key: key,
      shift: keyboard.isShiftPressed,
      alt: keyboard.isAltPressed,
      control: keyboard.isControlPressed,
      meta: keyboard.isMetaPressed,
    );
    switch (move) {
      case AuthFieldMove.toPassword:
        _passwordFocus.requestFocus();
        return KeyEventResult.handled;
      case AuthFieldMove.toEmail:
        _emailFocus.requestFocus();
        return KeyEventResult.handled;
      case AuthFieldMove.leaveForward:
      case AuthFieldMove.leaveBackward:
      case null:
        return KeyEventResult.ignored;
      case AuthFieldMove.submit:
        widget.onSubmit();
        return KeyEventResult.handled;
    }
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
                focusNode: _emailFocus,
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
