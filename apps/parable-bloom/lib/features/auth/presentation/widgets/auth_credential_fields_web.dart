import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:material_ui/material_ui.dart';
import 'package:web/web.dart' as web;

import 'auth_field_validation.dart';

/// View type for the sign-in platform view. One factory serves every visit.
const String _viewType = 'parable-bloom-auth-fields';

const double _fieldHeight = 56;
const double _fieldGap = 16;
const double _errorBlockHeight = 22;

bool _factoryRegistered = false;
final Map<int, _AuthFieldDom> _domByViewId = <int, _AuthFieldDom>{};

/// Email and password fields that password-manager extensions can fill.
///
/// Flutter's web engine draws [TextFormField] on a canvas. It only mounts one
/// HTML input, for the focused field, and parks the rest at 0×0 or off-screen.
/// Bitwarden skips any control under 10px or outside the viewport, then reports
/// that it cannot autofill the page. These inputs stay visible for the life of
/// the screen, with the autocomplete tokens those extensions look for.
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

  /// When false, the inputs are taken out of view. Dialogs paint in the
  /// canvas behind a platform view, so a covered form would sit on top.
  final bool visible;

  @override
  State<AuthCredentialFields> createState() => AuthCredentialFieldsState();
}

class AuthCredentialFieldsState extends State<AuthCredentialFields> {
  _AuthFieldDom? _dom;
  int? _viewId;
  String? _emailError;
  String? _passwordError;
  web.Element? _platformViewHost;
  web.MutationObserver? _ariaObserver;

  late final JSFunction _emailInputListener = _handleEmailInput.toJS;
  late final JSFunction _passwordInputListener = _handlePasswordInput.toJS;
  late final JSFunction _emailKeyListener = _handleEmailKeyDown.toJS;
  late final JSFunction _submitListener = _handleSubmit.toJS;

  @override
  void initState() {
    super.initState();
    _ensureFactory();
    widget.emailController.addListener(_onEmailController);
    widget.passwordController.addListener(_onPasswordController);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyTheme();
  }

  @override
  void didUpdateWidget(AuthCredentialFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLogin != widget.isLogin) {
      _applyAutocomplete();
    }
    if (oldWidget.enabled != widget.enabled) {
      _applyEnabled();
    }
    if (oldWidget.visible != widget.visible) {
      _syncPasswordManagerVisibility();
    }
    if (oldWidget.emailController != widget.emailController) {
      oldWidget.emailController.removeListener(_onEmailController);
      widget.emailController.addListener(_onEmailController);
      _onEmailController();
    }
    if (oldWidget.passwordController != widget.passwordController) {
      oldWidget.passwordController.removeListener(_onPasswordController);
      widget.passwordController.addListener(_onPasswordController);
      _onPasswordController();
    }
  }

  @override
  void dispose() {
    widget.emailController.removeListener(_onEmailController);
    widget.passwordController.removeListener(_onPasswordController);
    final dom = _dom;
    if (dom != null) {
      dom.email.removeEventListener('input', _emailInputListener);
      dom.email.removeEventListener('change', _emailInputListener);
      dom.password.removeEventListener('input', _passwordInputListener);
      dom.password.removeEventListener('change', _passwordInputListener);
      dom.email.removeEventListener('keydown', _emailKeyListener);
      dom.form.removeEventListener('submit', _submitListener);
    }
    final viewId = _viewId;
    if (viewId != null) {
      _domByViewId.remove(viewId);
    }
    _ariaObserver?.disconnect();
    super.dispose();
  }

  /// Runs the email and password checks and shows their messages.
  bool validate() {
    final emailError = validateAuthEmail(widget.emailController.text);
    final passwordError = validateAuthPassword(widget.passwordController.text);
    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
    });
    _paintErrors();
    return emailError == null && passwordError == null;
  }

  /// Asks the browser to submit the real form, which runs [AuthCredentialFields.onSubmit].
  void submit() {
    final form = _dom?.form;
    if (form == null) {
      widget.onSubmit();
      return;
    }
    form.requestSubmit();
  }

  double get _height =>
      (_fieldHeight * 2) +
      _fieldGap +
      (_emailError == null ? 0 : _errorBlockHeight) +
      (_passwordError == null ? 0 : _errorBlockHeight);

  void _onViewCreated(int viewId) {
    if (_viewId == viewId) {
      return;
    }
    final dom = _domByViewId[viewId];
    if (dom == null) {
      return;
    }
    _viewId = viewId;
    _dom = dom;
    dom.email.addEventListener('input', _emailInputListener);
    dom.email.addEventListener('change', _emailInputListener);
    dom.password.addEventListener('input', _passwordInputListener);
    dom.password.addEventListener('change', _passwordInputListener);
    dom.email.addEventListener('keydown', _emailKeyListener);
    dom.form.addEventListener('submit', _submitListener);
    _applyTheme();
    _applyAutocomplete();
    _applyEnabled();
    _onEmailController();
    _onPasswordController();
    _paintErrors();
    _syncPasswordManagerVisibility();
  }

  /// Shows the inputs to password managers, or puts `aria-hidden` back while
  /// a dialog covers them. In-flight retries come through here too.
  void _syncPasswordManagerVisibility([int attempt = 0]) {
    final viewId = _viewId;
    if (!mounted || viewId == null) {
      return;
    }
    final host =
        _platformViewHost ?? web.document.getElementById('flt-pv-$viewId');
    if (!widget.visible) {
      host?.setAttribute('aria-hidden', 'true');
      return;
    }
    if (host == null) {
      if (attempt > 30) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _viewId == viewId) {
          _syncPasswordManagerVisibility(attempt + 1);
        }
      });
      return;
    }
    if (host.getAttribute('aria-hidden') != null) {
      host.removeAttribute('aria-hidden');
    }
    if (!identical(_platformViewHost, host)) {
      _ariaObserver?.disconnect();
      _platformViewHost = host;
      _ariaObserver = web.MutationObserver(_onAriaHidden.toJS);
      _ariaObserver!.observe(
        host,
        web.MutationObserverInit(attributes: true),
      );
    }
  }

  void _onAriaHidden(JSObject _, JSObject __) {
    if (!mounted || !widget.visible) {
      return;
    }
    final host = _platformViewHost;
    if (host != null && host.getAttribute('aria-hidden') != null) {
      host.removeAttribute('aria-hidden');
    }
  }

  void _handleEmailInput(web.Event _) {
    final dom = _dom;
    if (dom == null) {
      return;
    }
    final value = dom.email.value;
    if (widget.emailController.text != value) {
      widget.emailController.text = value;
    }
  }

  void _handlePasswordInput(web.Event _) {
    final dom = _dom;
    if (dom == null) {
      return;
    }
    final value = dom.password.value;
    if (widget.passwordController.text != value) {
      widget.passwordController.text = value;
    }
  }

  void _handleEmailKeyDown(web.KeyboardEvent event) {
    if (event.key != 'Enter') {
      return;
    }
    event.preventDefault();
    _dom?.password.focus();
  }

  void _handleSubmit(web.Event event) {
    event.preventDefault();
    widget.onSubmit();
  }

  void _onEmailController() {
    final dom = _dom;
    if (dom == null) {
      return;
    }
    final value = widget.emailController.text;
    if (dom.email.value != value) {
      dom.email.value = value;
    }
  }

  void _onPasswordController() {
    final dom = _dom;
    if (dom == null) {
      return;
    }
    final value = widget.passwordController.text;
    if (dom.password.value != value) {
      dom.password.value = value;
    }
  }

  void _applyAutocomplete() {
    final dom = _dom;
    if (dom == null) {
      return;
    }
    if (widget.isLogin) {
      dom.email.autocomplete = 'username';
      dom.password.autocomplete = 'current-password';
    } else {
      dom.email.autocomplete = 'email';
      dom.password.autocomplete = 'new-password';
    }
  }

  void _applyEnabled() {
    final dom = _dom;
    if (dom == null) {
      return;
    }
    final disabled = !widget.enabled;
    dom.email.disabled = disabled;
    dom.password.disabled = disabled;
  }

  void _paintErrors() {
    final dom = _dom;
    if (dom == null) {
      return;
    }
    _paintError(
      field: dom.emailField,
      message: dom.emailError,
      text: _emailError,
    );
    _paintError(
      field: dom.passwordField,
      message: dom.passwordError,
      text: _passwordError,
    );
  }

  void _paintError({
    required web.HTMLElement field,
    required web.HTMLElement message,
    required String? text,
  }) {
    if (text == null) {
      field.className = 'pb-auth-field';
      message.className = 'pb-auth-error';
      message.textContent = '';
      return;
    }
    field.className = 'pb-auth-field pb-auth-field--error';
    message.className = 'pb-auth-error pb-auth-error--show';
    message.textContent = text;
  }

  void _applyTheme() {
    final dom = _dom;
    if (dom == null || !mounted) {
      return;
    }
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final font = theme.textTheme.bodyLarge?.fontFamily;
    final labelBackground = theme.cardTheme.color ?? colors.surfaceContainerLow;
    final formStyle = dom.form.style;
    formStyle.setProperty('--pb-outline', _cssColor(colors.outline));
    formStyle.setProperty('--pb-primary', _cssColor(colors.primary));
    formStyle.setProperty('--pb-on-surface', _cssColor(colors.onSurface));
    formStyle.setProperty(
      '--pb-on-surface-variant',
      _cssColor(colors.onSurfaceVariant),
    );
    formStyle.setProperty('--pb-error', _cssColor(colors.error));
    formStyle.setProperty('--pb-label-bg', _cssColor(labelBackground));
    formStyle.setProperty(
      '--pb-font',
      font == null ? 'Roboto, sans-serif' : '$font, Roboto, sans-serif',
    );
    formStyle.setProperty(
      'color-scheme',
      theme.brightness == Brightness.dark ? 'dark' : 'light',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: widget.visible,
      maintainState: true,
      child: SizedBox(
        height: _height,
        child: HtmlElementView(
          key: const ValueKey<String>(_viewType),
          viewType: _viewType,
          onPlatformViewCreated: _onViewCreated,
        ),
      ),
    );
  }
}

class _AuthFieldDom {
  _AuthFieldDom({
    required this.form,
    required this.emailField,
    required this.passwordField,
    required this.email,
    required this.password,
    required this.emailError,
    required this.passwordError,
  });

  final web.HTMLFormElement form;
  final web.HTMLElement emailField;
  final web.HTMLElement passwordField;
  final web.HTMLInputElement email;
  final web.HTMLInputElement password;
  final web.HTMLElement emailError;
  final web.HTMLElement passwordError;
}

void _ensureFactory() {
  if (_factoryRegistered) {
    return;
  }
  final registered = ui_web.platformViewRegistry.registerViewFactory(
    _viewType,
    (int viewId) {
      final dom = _buildDom(viewId);
      _domByViewId[viewId] = dom;
      return dom.form;
    },
  );
  if (registered) {
    _factoryRegistered = true;
  }
}

_AuthFieldDom _buildDom(int viewId) {
  final emailId = 'parable-bloom-username-$viewId';
  final passwordId = 'parable-bloom-password-$viewId';

  final form = web.HTMLFormElement()
    ..className = 'pb-auth-form'
    ..method = 'post'
    ..action = '#'
    ..noValidate = true
    ..autocomplete = 'on';
  form.style
    ..width = '100%'
    ..height = '100%'
    ..margin = '0';

  final style = web.HTMLStyleElement()..textContent = _fieldCss;
  form.append(style);

  final emailField = _fieldShell(
    inputId: emailId,
    label: 'Email',
    iconSvg: _emailIconSvg,
  );
  final passwordField = _fieldShell(
    inputId: passwordId,
    label: 'Password',
    iconSvg: _lockIconSvg,
  );
  final email = emailField.input
    ..type = 'email'
    ..name = 'username'
    ..autocomplete = 'username'
    ..inputMode = 'email'
    ..spellcheck = false
    ..placeholder = ' ';
  email.setAttribute('autocapitalize', 'none');
  email.setAttribute('autocorrect', 'off');
  email.setAttribute('aria-label', 'Email');

  final password = passwordField.input
    ..type = 'password'
    ..name = 'password'
    ..autocomplete = 'current-password'
    ..spellcheck = false
    ..placeholder = ' ';
  password.setAttribute('autocapitalize', 'none');
  password.setAttribute('autocorrect', 'off');
  password.setAttribute('aria-label', 'Password');

  final emailError = web.HTMLParagraphElement()..className = 'pb-auth-error';
  final passwordError = web.HTMLParagraphElement()..className = 'pb-auth-error';
  final gap = web.HTMLDivElement()..className = 'pb-auth-gap';

  form.append(emailField.field);
  form.append(emailError);
  form.append(gap);
  form.append(passwordField.field);
  form.append(passwordError);

  return _AuthFieldDom(
    form: form,
    emailField: emailField.field,
    passwordField: passwordField.field,
    email: email,
    password: password,
    emailError: emailError,
    passwordError: passwordError,
  );
}

class _FieldShell {
  _FieldShell({required this.field, required this.input});

  final web.HTMLElement field;
  final web.HTMLInputElement input;
}

_FieldShell _fieldShell({
  required String inputId,
  required String label,
  required String iconSvg,
}) {
  final field = web.HTMLDivElement()..className = 'pb-auth-field';
  final input = web.HTMLInputElement()..id = inputId;
  final caption = web.HTMLLabelElement()
    ..htmlFor = inputId
    ..textContent = label;
  final icon = web.HTMLSpanElement()
    ..className = 'pb-auth-icon'
    ..innerHTML = iconSvg.toJS;
  field.append(input);
  field.append(caption);
  field.append(icon);
  return _FieldShell(field: field, input: input);
}

String _cssColor(Color color) {
  final int argb = color.toARGB32();
  final int r = (argb >> 16) & 0xFF;
  final int g = (argb >> 8) & 0xFF;
  final int b = argb & 0xFF;
  final double a = ((argb >> 24) & 0xFF) / 255;
  return 'rgba($r, $g, $b, ${a.toStringAsFixed(3)})';
}

const String _emailIconSvg =
    '<svg viewBox="0 0 24 24" width="24" height="24" fill="currentColor" aria-hidden="true">'
    '<path d="M20 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 4-8 5-8-5V6l8 5 8-5v2z"/>'
    '</svg>';

const String _lockIconSvg =
    '<svg viewBox="0 0 24 24" width="24" height="24" fill="currentColor" aria-hidden="true">'
    '<path d="M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm3.1-9H8.9V6c0-1.71 1.39-3.1 3.1-3.1 1.71 0 3.1 1.39 3.1 3.1v2z"/>'
    '</svg>';

const String _fieldCss = '''
.pb-auth-form {
  display: flex;
  flex-direction: column;
  box-sizing: border-box;
  width: 100%;
  height: 100%;
  margin: 0;
  padding: 0;
}
.pb-auth-field {
  position: relative;
  height: 56px;
  flex: 0 0 56px;
}
.pb-auth-field input {
  box-sizing: border-box;
  width: 100%;
  height: 56px;
  margin: 0;
  padding: 16px 16px 16px 48px;
  border: 1px solid var(--pb-outline);
  border-radius: 4px;
  background: transparent;
  color: var(--pb-on-surface);
  font: 16px/24px var(--pb-font);
  outline: none;
  caret-color: var(--pb-primary);
}
.pb-auth-field input:focus {
  border-color: var(--pb-primary);
  box-shadow: inset 0 0 0 1px var(--pb-primary);
}
.pb-auth-field--error input {
  border-color: var(--pb-error);
}
.pb-auth-field label {
  position: absolute;
  left: 48px;
  top: 16px;
  color: var(--pb-on-surface-variant);
  font: 16px/24px var(--pb-font);
  pointer-events: none;
  background: transparent;
}
.pb-auth-field input:focus + label,
.pb-auth-field input:not(:placeholder-shown) + label {
  top: -8px;
  left: 12px;
  padding: 0 4px;
  background: var(--pb-label-bg);
  color: var(--pb-primary);
  font-size: 12px;
  line-height: 16px;
}
.pb-auth-field--error input:focus + label,
.pb-auth-field--error input:not(:placeholder-shown) + label {
  color: var(--pb-error);
}
.pb-auth-icon {
  position: absolute;
  left: 12px;
  top: 16px;
  width: 24px;
  height: 24px;
  color: var(--pb-on-surface-variant);
  pointer-events: none;
}
.pb-auth-gap {
  height: 16px;
  flex: 0 0 16px;
}
.pb-auth-error {
  display: none;
  margin: 0;
}
.pb-auth-error--show {
  display: block;
  box-sizing: border-box;
  height: 22px;
  margin: 0;
  padding: 4px 16px 2px;
  color: var(--pb-error);
  font: 12px/16px var(--pb-font);
}
''';
