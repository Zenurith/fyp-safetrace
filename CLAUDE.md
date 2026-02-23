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

## Key Patterns

- Models use `toMap()`/`fromMap()` for Firestore serialization
- Enums stored as indices in Firestore
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
