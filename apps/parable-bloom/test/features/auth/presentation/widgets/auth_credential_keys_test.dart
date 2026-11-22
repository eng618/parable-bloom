import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/features/auth/presentation/widgets/auth_credential_keys.dart';

void main() {
  AuthFieldMove? move({
    bool onEmail = false,
    bool onPassword = false,
    required String key,
    bool shift = false,
    bool alt = false,
    bool control = false,
    bool meta = false,
    bool composing = false,
    bool repeat = false,
    int keyCode = 0,
  }) {
    return authCredentialFieldMove(
      onEmail: onEmail,
      onPassword: onPassword,
      key: key,
      shift: shift,
      alt: alt,
      control: control,
      meta: meta,
      composing: composing,
      repeat: repeat,
      keyCode: keyCode,
    );
  }

  test('tab walks email, password, then out of the pair', () {
    expect(move(onEmail: true, key: 'Tab'), AuthFieldMove.toPassword);
    expect(move(onPassword: true, key: 'Tab'), AuthFieldMove.leaveForward);
    expect(
      move(onPassword: true, key: 'Tab', shift: true),
      AuthFieldMove.toEmail,
    );
    expect(
      move(onEmail: true, key: 'Tab', shift: true),
      AuthFieldMove.leaveBackward,
    );
  });

  test('up and down switch between the fields', () {
    expect(move(onEmail: true, key: 'ArrowDown'), AuthFieldMove.toPassword);
    expect(move(onPassword: true, key: 'ArrowUp'), AuthFieldMove.toEmail);
    expect(move(onEmail: true, key: 'NavigateNext'), AuthFieldMove.toPassword);
    expect(
      move(onPassword: true, key: 'NavigatePrevious'),
      AuthFieldMove.toEmail,
    );
    expect(move(onPassword: true, key: 'ArrowDown'), isNull);
    expect(move(onEmail: true, key: 'ArrowUp'), isNull);
    expect(move(onEmail: true, key: 'ArrowDown', shift: true), isNull);
  });

  test('enter on email moves to password and leaves an ime alone', () {
    expect(move(onEmail: true, key: 'Enter'), AuthFieldMove.toPassword);
    expect(move(onPassword: true, key: 'Enter'), isNull);
    expect(move(onEmail: true, key: 'Enter', composing: true), isNull);
    expect(move(onEmail: true, key: 'Enter', keyCode: 229), isNull);
    expect(move(onEmail: true, key: 'Enter', repeat: true), isNull);
  });

  test('modified keys and keys from outside the fields stay put', () {
    expect(move(onEmail: true, key: 'Tab', control: true), isNull);
    expect(move(onEmail: true, key: 'ArrowDown', alt: true), isNull);
    expect(move(key: 'Tab'), isNull);
    expect(move(onEmail: true, key: 'ArrowLeft'), isNull);
  });
}
