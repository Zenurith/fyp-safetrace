# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SafeTrace is a Flutter mobile application for community-based incident reporting and safety alerts. Users can report incidents on a map, join location-based communities, vote on reports, and receive proximity-based notifications for nearby incidents.

## Common Commands

```bash
# Run the app
flutter run

# Run on specific device
flutter run -d windows
flutter run -d chrome

# Build
flutter build apk
flutter build ios

# Run tests
flutter test
flutter test test/widget_test.dart  # Run single test file

# Analyze code
flutter analyze

# Get dependencies
flutter pub get
```

## Architecture

The app follows a clean architecture pattern with Provider for state management:

```
lib/
├── main.dart                  # App entry, Firebase init, MultiProvider setup
├── config/                    # App constants
├── data/
│   ├── models/               # Data models with Firestore serialization
│   ├── repositories/         # Firestore CRUD operations
│   └── services/             # Location, media upload, notifications
├── presentation/
│   ├── providers/            # ChangeNotifier state management
│   ├── screens/              # Full-page UI components
│   └── widgets/              # Reusable UI components
└── utils/                    # Theme configuration
```

### Data Flow

1. **Repositories** (`data/repositories/`) handle direct Firestore operations with `watchAll()` streams and CRUD methods
2. **Providers** (`presentation/providers/`) wrap repositories, manage state with `ChangeNotifier`, and expose data to widgets
3. **Screens** use `context.watch<Provider>()` for reactive UI updates and `context.read<Provider>()` for actions

### Key Models

- `IncidentModel`: Core entity with category (enum), severity, status workflow, location, and voting
- `CommunityModel`: Location-based groups with radius using Haversine formula for membership
- `UserModel`: User profile with gamification (points, levels, trusted status) and role-based access
- `CategoryModel`: Admin-configurable incident categories with icons and colors

### Firebase Collections

- `incidents` - Incident reports
- `users` - User profiles
- `communities` - Location-based communities
- `members` (subcollection) - Community membership
- `posts` (subcollection) - Community posts
- `votes` - User votes on incidents
- `categories` - Configurable incident categories

### Services

- `LocationService`: GPS positioning with Google Places API for autocomplete
- `IncidentNotificationService`: Stream-based proximity alerts using user's alert settings
- `MediaUploadService`: Firebase Storage image uploads
- `ImageVerificationService` (`data/services/image_verification_service.dart`): Gemini AI image verification called during incident reporting. Checks that uploaded photos match the reported category before submission. API key from `AppConstants.geminiApiKey`. If unconfigured or API fails, defaults to `serviceUnavailable()` (isValid=false, sent for manual review). **Working model: `gemini-3.1-flash-lite-preview`** — do NOT change this model name, other names cause 503 errors.

## Reputation System

### Points
| Action | Points |
|--------|--------|
| Create a report | +10 |
| Receive upvote | +5 |
| Receive downvote | -3 |
| Change vote (upvote→downvote) | -8 |
| Change vote (downvote→upvote) | +8 |

### Levels
| Level | Title | Points Required |
|-------|-------|-----------------|
| 1 | Newcomer | 0 |
| 2 | Observer | 100 |
| 3 | Reporter | 300 |
| 4 | Contributor | 600 |
| 5 | Guardian | 1000 |
| 6 | Protector | 1500 |
| 7 | Sentinel | 2500 |
| 8 | Champion | 4000 |
| 9 | Hero | 6000 |
| 10 | Legend | 10000 |

### Trusted Status
- Users with 500+ points automatically get `isTrusted: true`
- Level and trusted status recalculate after every point-affecting action

### Implementation
- `UserRepository.incrementReportCount()` - Called when creating incident
- `UserRepository.recalculateReputation()` - Called after vote transactions
- `UserProvider.refreshCurrentUser()` - Call to refresh UI after reputation changes

## Key Patterns

- Models use `toMap()`/`fromMap()` for Firestore serialization
- Most enums stored as indices in Firestore; `MemberRole` stored as string `.name` for forward compatibility
- Real-time updates via Firestore `snapshots()` streams
- Auth gate in `main.dart` handles Firebase Auth state
- Admin features conditionally rendered based on `UserModel.isAdmin`

## UI & Design Guidelines

### Assets
- Font family: **Avenir** (registered in `pubspec.yaml` under `assets/font/`)
  - Weights: Light (300), Book (400), Regular (500), Heavy (700), Black (900)
- Custom PNG icons in `assets/icon/` — prefer these over Material Icons where available:
  - `map.png`, `community.png`, `warning.png`, `report.png`, `user.png`, `eye.png`

### Design Principles
- **Minimal info density**: Show only the 2–3 most important data points on a card. Secondary details belong in a detail screen or expandable section.
- **One card style**: Use border-only cards (`Border.all(color: AppTheme.cardBorder)`) with **no** `BoxShadow`. Do not mix shadows + borders.
- **Consistent spacing**: 16px horizontal padding on all screens, 12px gap between list cards.
- **Two accent colors max**: `AppTheme.primaryRed` is the primary accent. Use `AppTheme.successGreen` and `AppTheme.warningOrange` only for semantic states (success/warning), never decoration.
- Avoid using `profilePurple` and `accentBlue` for new UI work — use `primaryDark` for AppBars/headers instead.

### Typography (Avenir)
- Headings: Avenir Heavy (700)
- Body text: Avenir Book (400)
- Captions / metadata: Avenir Light (300), `Colors.grey[500]`
- Never use more than 3 font weights on a single screen.

### Navigation
- Bottom nav **max 4 items**. Profile goes in the AppBar as an avatar `IconButton`.
- Use `ImageIcon(AssetImage('assets/icon/xxx.png'))` for custom PNG icons in the nav bar.

### Do NOT
- Add new full-page screens for content that fits in a bottom sheet or dialog.
- Add new bottom nav items without removing an existing one first.
- Use `Colors.purple`, `Colors.teal`, or `Colors.blue` directly — always use `AppTheme` constants.
- Create new color constants without a clear semantic purpose.

## Known Bugs & Issues

### Communities Feature
Communities are **location-based groups** (center point + radius). Membership eligibility uses the **Haversine formula**. Members can create posts/discussions within the community. Joining is currently **auto-approved** (no admin approval) for testing.

#### Community Role Hierarchy
```
owner > headModerator > moderator > member
```

| Role | Label | Stored as |
|------|-------|-----------|
| `MemberRole.owner` | Owner | `"owner"` |
| `MemberRole.headModerator` | Head Mod | `"headModerator"` |
| `MemberRole.moderator` | Moderator | `"moderator"` |
| `MemberRole.member` | Member | `"member"` |

Roles are stored as **string names** in Firestore (migrated from legacy int indices — backward-compat via `_parseRole()`).

#### Permission Matrix
| Action | Owner | Head Mod | Moderator | Member |
|--------|:-----:|:--------:|:---------:|:------:|
| Approve/reject join requests | ✓ | ✓ | ✓ | |
| Edit community settings | ✓ | ✓ | | |
| Delete community | ✓ | | | |
| Promote member → moderator | ✓ | ✓ | | |
| Promote moderator → head mod | ✓ | | | |
| Demote head mod → moderator | ✓ | | | |
| Demote moderator → member | ✓ | ✓ | | |
| Remove member | ✓ | ✓ | ✓ | |
| Remove moderator | ✓ | ✓ | | |
| Remove head mod | ✓ | | | |
| Transfer ownership | ✓ | | | |

`isStaff` = true for owner, headModerator, moderator (all roles except member).

**Admin management is web-only.** The mobile admin screen has been removed. Access the admin panel via `flutter run -d chrome`.

### Security Issues (Open)
- `lib/config/secrets.dart` — API keys committed to repo (geminiApiKey, googleMapsApiKey). Rotate keys and move to environment variables or Firebase Remote Config.

> **Note**: Web admin shell access control: `admin_web_shell.dart` and `admin_auth_screen.dart` both **verified** to check `user.isAdmin` — secure. Mobile admin screen removed; system admin is web-only.

### Design Violations (Open — fix opportunistically)
- `community_detail_screen.dart`: Hardcoded colors in membership state UI → use AppTheme constants
- `admin_auth_screen.dart`: Uses `BoxShadow` on login card → replace with `AppTheme.cardDecoration`
- `admin_dashboard_page.dart`: Uses `Colors.teal` and `Colors.amber` in avatar UI

### Logic Bugs (Open)

### Performance Issues (Open)
- `community_repository.dart`: `getNearbyCommunities()` is O(n) client-side — fetches all communities then filters. Will degrade at scale; consider GeoFlutterFire or geohashing.
- Edit profile dialog (`profile_screen.dart`): `TextEditingController`s created on every open, not disposed if dismissed via back gesture (memory leak risk).

---

## Self-Improve Loop

> **Purpose**: Before starting any task, consult this section. After finishing, update it with new findings.

### How to Use This Loop

1. **Before each task**: Scan the "Open Issues" lists above. If your task touches a file with known violations, fix them in the same PR unless it would significantly expand scope.
2. **After each task**: If you discover a new bug, design violation, or anti-pattern not listed here, add it to the relevant section above.
3. **After fixing an issue**: Remove it from the list above. Do not leave stale fixed items.
4. **On each new screen/feature**: Run the checklist below before marking done.

### Pre-Commit Checklist (run mentally before finishing any UI task)

```
[ ] No raw Colors.xxx used — all colors via AppTheme constants
[ ] No BoxShadow on cards — AppTheme.cardDecoration used
[ ] No AppTheme.profilePurple or AppTheme.accentBlue in new code
[ ] AppBar background uses AppTheme.primaryDark (not profilePurple)
[ ] All grey text uses AppTheme.textSecondary (not Colors.grey)
[ ] Card borders consistent — use AppTheme.cardDecoration, not manual Border.all
[ ] No debugPrint() left in production paths (wrap in kDebugMode)
[ ] Admin screens guard entry with isAdmin check
[ ] Async operations in UI wrapped in try-catch with error feedback
[ ] No N+1 Firestore queries — batch or cache user lookups
[ ] Provider state cleared in dispose() if screen-specific
[ ] No hardcoded hex color values in widget trees
```

### Recurring Patterns to Watch

- **Admin access control**: Every admin screen/page must check `user.isAdmin` at entry and redirect if false.
- **Card styling**: Always `AppTheme.cardDecoration`. Never mix border + shadow.
- **Color usage**: Only `AppTheme.*` constants. When adding a new semantic state, add to AppTheme first, then use it.
- **Community filtering**: When filtering communities by membership, exclude ALL non-null statuses (approved, pending, rejected) — not just approved.
- **Firestore reads in loops**: Never call `.get()` or `.load()` inside a `ListView.builder` or `initState` of a list item widget — batch-fetch at the provider level.
- **Debug code**: Any `debugPrint` / `print` in production path must be wrapped: `if (kDebugMode) { debugPrint(...); }`

## Common Mistakes to Avoid

### Flutter API Changes
- Use `CardThemeData` not `CardTheme` in ThemeData (Flutter 3.x)
- Use `activeTrackColor` not `activeColor` on Switch (deprecated)
- Use `Switch.adaptive()` for cross-platform switches

### Styling
- Never use `BoxShadow` on cards — use `AppTheme.cardDecoration` (border-only)
- Never use `Divider` between list items — use `SizedBox(height: 12)` with cards
- Never use raw colors (`Colors.orange`, `Colors.blue`) — use AppTheme constants
- Always specify `fontFamily: AppTheme.fontFamily` in custom TextStyles

### UI Components
- Bottom nav icons must have labels below them for clarity
- Use `ImageIcon(AssetImage('assets/icon/xxx.png'))` for custom icons
- Use `AppTheme.textSecondary` for grey text, not `Colors.grey`

### State Management
- Community joining is currently **auto-approved** (no admin approval needed) for testing
- Call `setState()` or reload data after async operations that change UI state
- **Never call `context.read()` inside `dispose()`** — Flutter invalidates the BuildContext during widget teardown, so the provider lookup silently fails. Cache the provider reference in `initState()` instead:
  ```dart
  // WRONG — context may be invalid in dispose()
  @override
  void dispose() {
    context.read<MyProvider>().doSomething(); // silently fails
    super.dispose();
  }

  // CORRECT — cache in initState while context is valid
  late final MyProvider _myProvider;

  @override
  void initState() {
    super.initState();
    _myProvider = context.read<MyProvider>();
  }

  @override
  void dispose() {
    _myProvider.doSomething(); // reliable
    super.dispose();
  }
  ```

## AppTheme Quick Reference

```dart
// Colors
AppTheme.primaryDark      // Headers, primary text
AppTheme.primaryRed       // Primary accent, errors, destructive actions
AppTheme.successGreen     // Success states only
AppTheme.warningOrange    // Warning states only
AppTheme.textSecondary    // Grey text, captions
AppTheme.cardBorder       // Border color for cards
AppTheme.backgroundGrey   // Screen backgrounds

// Text Styles
AppTheme.headingLarge     // 24px, Heavy (700)
AppTheme.headingMedium    // 20px, Heavy (700)
AppTheme.headingSmall     // 16px, Heavy (700)
AppTheme.bodyLarge        // 16px, Book (400)
AppTheme.bodyMedium       // 14px, Book (400)
AppTheme.caption          // 12px, Light (300), grey

// Card styling
AppTheme.cardDecoration   // Border-only BoxDecoration
```
