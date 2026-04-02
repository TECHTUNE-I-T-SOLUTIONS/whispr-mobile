# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-04-01

### Added
- Screenshot prevention service to protect sensitive content on AI chat screen
- Platform-specific implementation on iOS (overlay-based) and Android (FLAG_SECURE)
- Comment reactions system with like/unlike functionality
- Ability to view existing likes on comments when loading post details
- New API endpoint `/api/chronicles/posts/[slug]/comments/[commentId]/reactions` for fetching comment reactions
- Theme support for screenshot prevention across light and dark modes

### Changed
- Improved AI chat screen lifecycle with proper screenshot protection on init/dispose
- Enhanced comment loading to include reaction status for authenticated users
- Optimized platform channel communication for screenshot prevention

### Fixed
- Fixed duplicate `initState()` and `dispose()` methods in AI chat screen
- Resolved print() statements in production code (replaced with debugPrint)

## [1.0.3] - 2026-03-25

### Added
- Initial mobile app release
- Basic authentication and user management
- Timeline feed functionality
- Chronicles feature
- Poems browsing
- Media sharing capabilities
- Admin dashboard

### Security
- Supabase authentication integration
- Secure token management
- RLS (Row Level Security) policies
