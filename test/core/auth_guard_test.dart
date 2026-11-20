import 'package:flutter_test/flutter_test.dart';

import 'package:whispr/core/utils/auth_guard.dart';

void main() {
  tearDown(() => AuthGuard.signedIn.value = null);

  test('notifier drives router readiness and login state', () {
    expect(AuthGuard.signedIn.value, isNull);
    expect(AuthGuard.isReady, isFalse);
    expect(AuthGuard.isLoggedInNow, isFalse);

    final transitions = <bool?>[];
    AuthGuard.signedIn.addListener(() => transitions.add(AuthGuard.signedIn.value));

    AuthGuard.setSignedIn(true);
    expect(AuthGuard.isReady, isTrue);
    expect(AuthGuard.isLoggedInNow, isTrue);

    AuthGuard.setSignedIn(false);
    expect(AuthGuard.isReady, isTrue);
    expect(AuthGuard.isLoggedInNow, isFalse);

    expect(transitions, [true, false]);
  });
}
