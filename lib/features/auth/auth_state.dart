// This file now re-exports from the main auth provider for backward compatibility
// All auth state management is now centralized in supabase_auth_provider.dart

export 'supabase_auth_provider.dart' show AuthState, AuthStateNotifier, authStateProvider, authInitializationProvider, userProvider, isAuthenticatedProvider, accessTokenProvider, isLoadingAuthProvider, authErrorProvider;