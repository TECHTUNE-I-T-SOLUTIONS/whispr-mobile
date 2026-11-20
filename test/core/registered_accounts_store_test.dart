import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:whispr/core/models/chronicles.dart';
import 'package:whispr/core/services/registered_accounts_store.dart';

Creator creator({
  required String id,
  required String email,
  String displayName = 'Writer',
}) =>
    Creator(
      id: id,
      userId: id,
      email: email,
      penName: displayName,
      displayName: displayName,
      bio: '',
      contentType: PostType.blog,
      categories: const [],
      socialLinks: const {},
      profileVisibility: ProfileVisibility.public,
      pushNotificationsEnabled: true,
      postCount: 0,
      engagementCount: 0,
      currentStreak: 0,
      totalPoints: 0,
      verifiedBadge: false,
      lastActivityAt: '2026-01-01T00:00:00.000Z',
      createdAt: '2026-01-01T00:00:00.000Z',
      updatedAt: '2026-01-01T00:00:00.000Z',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('upsert de-duplicates by id then email and refreshes metadata', () async {
    final store = RegisteredAccountsStore.instance;

    await store.upsert(
        creator(id: 'a', email: 'a@example.com', displayName: 'Old Name'));
    await store.upsert(
        creator(id: 'a', email: 'a+new@example.com', displayName: 'New Name'));
    await store.upsert(creator(id: 'b', email: 'b@example.com'));

    var accounts = await store.load();
    expect(accounts.length, 2);
    final first = accounts.firstWhere((account) => account.id == 'a');
    expect(first.email, 'a+new@example.com');
    expect(first.displayName, 'New Name');

    await store.upsert(creator(id: 'c', email: 'A+NEW@example.com'));
    accounts = await store.load();
    expect(accounts.length, 2);
    expect(
      accounts.any((account) => account.email.toLowerCase() == 'a+new@example.com'),
      isTrue,
    );
  });

  test('registry survives session-key cleanup and remove only drops one row', () async {
    final store = RegisteredAccountsStore.instance;
    await store.upsert(creator(id: 'a', email: 'a@example.com'));
    await store.upsert(creator(id: 'b', email: 'b@example.com'));

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('whispr_auth_session_v3');
    await prefs.remove('auth_user_profile');
    await prefs.remove('auth_session_bundle');

    expect((await store.load()).length, 2);

    await store.remove('a');
    final remaining = await store.load();
    expect(remaining.length, 1);
    expect(remaining.single.id, 'b');
  });
}
