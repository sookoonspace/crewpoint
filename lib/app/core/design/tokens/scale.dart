/// The raw numbers of CrewPoint's look: spacing, corner radius, sizes, type
/// sizes and motion, from the approved mockups (Spec #186).
///
/// This is the one place such a number changes. Screens never read this
/// file: they read [CpSpacing], [CpRadii], [CpSizes], [CpType] and
/// [CpMotion] through the theme.
abstract final class CpScale {
  // ===== Spacing =====
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space48 = 48;

  // ===== Corner radius =====
  static const double radius4 = 4;
  static const double radius8 = 8;
  static const double radius12 = 12;
  static const double radius16 = 16;
  static const double radius24 = 24;
  static const double radiusPill = 999;

  // ===== Sizes =====
  static const double icon14 = 14;
  static const double icon16 = 16;
  static const double icon20 = 20;
  static const double icon24 = 24;
  static const double icon32 = 32;
  static const double icon64 = 64;
  static const double avatar16 = 16;
  static const double avatar18 = 18;
  static const double avatar20 = 20;
  static const double avatar42 = 42;
  static const double emoji22 = 22;
  static const double emoji28 = 28;
  static const double emoji32 = 32;
  static const double rowIndent = 56;
  static const double ring48 = 48;

  /// The smallest tap target (Material and Apple guidance).
  static const double tapMin = 48;

  // Component sizes from the Round 2 mockups.
  static const double avatar32 = 32;
  static const double avatar40 = 40;
  static const double avatar64 = 64;
  static const double ring40 = 40;
  static const double ring52 = 52;
  static const double ringStroke = 5;
  static const double chip28 = 28;
  static const double row60 = 60;
  static const double topBar52 = 52;
  static const double stat104 = 104;
  static const double iconTile40 = 40;
  static const double skeletonLine = 12;
  static const double hairline = 1;
  static const double avatarRing = 2;
  static const double avatarOverlap = 6;

  /// The widest a phone-style column grows before it is centred (L16).
  static const double phoneColumn = 600;

  /// The sign-in column, narrower so its fields and buttons stay short.
  static const double signIn480 = 480;

  /// The laptop sidebar, and the list beside a detail panel.
  static const double sidebar = 248;
  static const double listPane = 400;

  /// The cover banner on an event's home, and its laptop height.
  static const double cover156 = 156;
  static const double cover180 = 180;
  static const double coverIcon56 = 56;

  // A schedule row's time column.
  static const double time56 = 56;

  // The widest a chat message grows, four fifths of the phone column.
  static const double bubble480 = 480;

  // An invite's QR code, big enough to scan from another phone.
  static const double qr200 = 200;

  // ===== Type sizes =====
  static const double type11 = 11;
  static const double type12 = 12;
  static const double type13 = 13;
  static const double type15 = 15;
  static const double type16 = 16;
  static const double type17 = 17;
  static const double type20 = 20;
  static const double type22 = 22;
  static const double type26 = 26;
  static const double type28 = 28;
  static const double type32 = 32;

  // ===== Motion (milliseconds) =====
  static const int motionFast = 150;
  static const int motionMedium = 250;
  static const int motionSlow = 350;
  static const int snackbarSeconds = 4;
}
