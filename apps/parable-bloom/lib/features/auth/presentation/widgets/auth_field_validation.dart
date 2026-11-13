/// Client checks shared by the native and web sign-in fields.
String? validateAuthEmail(String? value) {
  if (value == null || value.isEmpty || !value.contains('@')) {
    return 'Please enter a valid email address.';
  }
  return null;
}

/// Client checks shared by the native and web sign-in fields.
String? validateAuthPassword(String? value) {
  if (value == null || value.length < 6) {
    return 'Password must be at least 6 characters.';
  }
  return null;
}
