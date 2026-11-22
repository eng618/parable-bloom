/// Where a key should send focus from the email and password fields.
enum AuthFieldMove {
  /// Focus the email field.
  toEmail,

  /// Focus the password field.
  toPassword,

  /// Leave the pair toward the next control.
  leaveForward,

  /// Leave the pair toward the previous control.
  leaveBackward,
}

/// Decides how email and password should respond to a field-navigation key.
///
/// [key] is a DOM `KeyboardEvent.key` value such as `Tab` or `ArrowDown`.
/// [composing] and [keyCode] `229` are an IME confirming text. That Enter stays
/// in the field. Modifier combinations other than Shift+Tab stay with the
/// browser. A repeated Enter does not advance again.
AuthFieldMove? authCredentialFieldMove({
  required bool onEmail,
  required bool onPassword,
  required String key,
  bool shift = false,
  bool alt = false,
  bool control = false,
  bool meta = false,
  bool composing = false,
  bool repeat = false,
  int keyCode = 0,
}) {
  if (!onEmail && !onPassword) {
    return null;
  }
  if (alt || control || meta) {
    return null;
  }
  if (composing || keyCode == 229) {
    return null;
  }

  if (key == 'Enter') {
    if (repeat || shift || !onEmail) {
      return null;
    }
    return AuthFieldMove.toPassword;
  }

  final tabForward = key == 'Tab' && !shift;
  final tabBackward = key == 'Tab' && shift;
  if (tabForward) {
    return onEmail ? AuthFieldMove.toPassword : AuthFieldMove.leaveForward;
  }
  if (tabBackward) {
    return onPassword ? AuthFieldMove.toEmail : AuthFieldMove.leaveBackward;
  }

  // Up and down are the field keys on a single-line input. Shift would be a
  // selection gesture, so those stay with the field.
  if (shift) {
    return null;
  }
  final forward = key == 'ArrowDown' || key == 'NavigateNext';
  final backward = key == 'ArrowUp' || key == 'NavigatePrevious';
  if (forward && onEmail) {
    return AuthFieldMove.toPassword;
  }
  if (backward && onPassword) {
    return AuthFieldMove.toEmail;
  }
  return null;
}
