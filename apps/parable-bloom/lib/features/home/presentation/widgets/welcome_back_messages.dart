/// Welcome-back lines under the Home brand title (prior calendar day).
const List<String> kWelcomeBackMessages = [
  'Welcome back. The garden missed your hands.',
  'Good to see you again.',
];

/// Time-based pick so consecutive returns vary the welcome line.
String pickWelcomeBackMessage([List<String> messages = kWelcomeBackMessages]) {
  if (messages.isEmpty) return '';
  return messages[DateTime.now().millisecondsSinceEpoch % messages.length];
}
