import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_service.dart';
import '../../core/services/auth_session_store.dart';
import '../../core/services/live_update_service.dart';
import '../../core/services/session_bootstrap.dart';
import 'supabase_auth_provider.dart';

/// App-wide owner of session lifecycle and resume-time token sync.
///
/// Lives below [ProviderScope] and above the app, so every route sees the
/// same awaited bootstrap and no screen has to restore storage for itself.
class SessionScope extends ConsumerStatefulWidget {
  const SessionScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SessionScope> createState() => _SessionScopeState();
}

class _SessionScopeState extends ConsumerState<SessionScope>
    with WidgetsBindingObserver {
  Future<AuthSessionData?>? _bootstrap;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // ApiService refreshes tokens silently. Mirror them into auth state so
    // Supabase-backed screens never keep using the expired access token.
    ApiService.onTokensRefreshed = (accessToken, refreshToken) {
      ref.read(authStateProvider.notifier).acceptRefreshedTokens(
            accessToken,
            refreshToken,
          );
    };
    _bootstrap = ref.read(sessionBootstrapProvider.future);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ApiService.onTokensRefreshed = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed) return;

    await _bootstrap;
    if (!mounted) return;
    await ref.read(authStateProvider.notifier).syncSupabaseSession();
    unawaited(LiveUpdateService.instance.refreshIfDue());
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionBootstrapProvider);
    return widget.child;
  }
}
