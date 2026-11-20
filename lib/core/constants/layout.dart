/// Shared layout constants.
///
/// The app shell floats its navigation bar over the content (`extendBody`),
/// so every scrollable screen has to reserve room for it or its last rows sit
/// underneath the bar. Import this instead of hard-coding a magic number.
library;

/// Height of the floating navigation bar itself.
///
/// Kept deliberately small: the bar is a compact pill, not a full-width
/// bottom app bar, so it must not eat the bottom of reading screens.
const double kBottomNavHeight = 52;

/// Space a scrollable screen should leave at the bottom so its final item
/// clears the floating bar plus the system gesture inset.
const double kBottomNavClearance = 92;

/// Horizontal inset used by the floating bar.
const double kBottomNavHorizontalInset = 10;

/// Extra bottom offset for a floating action button owned by a screen *inside*
/// the shell.
///
/// The shell draws its bar over the body (`extendBody`), but a nested
/// `Scaffold` places its FAB against its own bottom edge, so without this the
/// bar sits on top of the button. 52 (bar) + 8 (bar margin) + gesture inset.
const double kShellFabClearance = 76;
