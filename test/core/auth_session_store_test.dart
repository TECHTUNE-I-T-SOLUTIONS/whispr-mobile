import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:whispr/core/models/chronicles.dart';
import 'package:whispr/core/services/auth_session_store.dart';

Creator testCreator() => Creator(
      id: 'creator-1',
      userId: 'user-1',
      email: 'writer@example.com',
      penName: 'Quill',
      displayName: 'Quill Writer',
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
  test('secure bundle round-trips tokens, profile and session start', () {
    final savedAt = DateTime.utc(2026, 1, 2, 3, 4);
    final start = DateTime.utc(2025, 12, 30);
    final session = AuthSessionData(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      user: testCreator(),
      savedAt: savedAt,
      sessionStart: start,
    );

    final decoded = jsonDecode(session.toSecureJson()) as Map<String, dynamic>;
    expect(decoded['user_data'], isA<Map>());
    expect(decoded['access_token'], 'access-token');

    final restored = AuthSessionData.fromSecureJson(decoded);
    expect(restored.accessToken, 'access-token');
    expect(restored.refreshToken, 'refresh-token');
    expect(restored.user.id, 'creator-1');
    expect(restored.user.email, 'writer@example.com');
    expect(restored.savedAt, savedAt);
    expect(restored.sessionStart, start);
  });

  test('legacy tokens map with a separately stored profile', () {
    final session = AuthSessionData.fromLegacyJson(
      {
        'access_token': 'legacy-access',
        'refresh_token': 'legacy-refresh',
        'saved_at': '2026-02-01T00:00:00.000Z',
        'session_start': '2026-01-01T00:00:00.000Z',
      },
      testCreator(),
    );

    expect(session.accessToken, 'legacy-access');
    expect(session.refreshToken, 'legacy-refresh');
    expect(session.user.penName, 'Quill');
    expect(session.sessionStart, DateTime.utc(2026, 1, 1));
  });

  test('empty access tokens are rejected', () {
    expect(
      () => AuthSessionData.fromSecureJson({'user_data': testCreator().toJson()}),
      throwsFormatException,
    );
    expect(
      AuthSessionStore.save(accessToken: '', user: testCreator()),
      throwsArgumentError,
    );
    expect(
      AuthSessionStore.updateTokens(accessToken: ''),
      throwsArgumentError,
    );
  });
}
