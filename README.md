# Pass It

[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.11%2B-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11%2B-0175C2?logo=dart)](https://dart.dev)
[![Latest Release](https://img.shields.io/github/v/release/mahitoh/pass_it?label=release)](https://github.com/mahitoh/pass_it/releases)

A cross-platform Flutter app for sharing and accessing past exam papers across institutions.

## Try It Today (APK)

If you just want to install and test quickly:

1. Open the latest release: <https://github.com/mahitoh/pass_it/releases/latest>
2. Download the `app-arm64-v8a-release.apk` asset
3. On Android, allow **Install unknown apps** for your browser/files app
4. Open the APK and install

For best compatibility, also upload and share these split APKs from CI/local build:

- `app-arm64-v8a-release.apk` (most modern Android phones)
- `app-armeabi-v7a-release.apk` (older Android phones)
- `app-x86_64-release.apk` (emulators)

## Overview

Pass It is a community-driven platform that enables students and educators to share past exam papers. Users earn points by contributing papers, which can be redeemed for rewards. The app features a gamified experience with leaderboards, streaks, and tier-based rewards.

## Features

### Core Functionality

- **Paper Discovery**: Browse exam papers by educational level (University, High School, Secondary, Competitive Exams)
- **Search**: Full-text search across titles, institutions, courses, and tags
- **Paper Detail**: View paper metadata, download counts, views, and related information
- **PDF Viewer**: Integrated PDF viewing with Syncfusion Flutter PDF Viewer
- **Bookmarks**: Save papers for offline access
- **Document Scanner**: Scan physical papers using Google ML Kit Document Scanner
- **QR Code Scanning**: Quick-access papers via QR codes using mobile_scanner
- **Offline Support**: Cached papers accessible without internet

### User System

- **Authentication**: Supabase Auth with email/password and PKCE flow
- **Points System**: Earn 50 points per approved paper contribution
- **Tier Progression**: Bronze (0) → Silver (100) → Gold (300) → Platinum (600)
- **Streaks**: Daily login streak tracking
- **Leaderboard**: Top contributors by points

### Upload Workflow

- **File Upload**: Support for PDF files via file_picker
- **Metadata Entry**: Level, institution, course, year
- **Moderation**: Pending → Approved/Rejected workflow
- **Storage**: Supabase Storage bucket for files

### Admin Dashboard

- **Paper Moderation**: Approve or reject pending contributions
- **User Management**: View and manage user roles
- **Institution Management**: CRUD operations for institutions
- **Analytics**: View submission and approval metrics

### Technical Features

- **Theme Support**: Light and dark mode with Material 3
- **State Management**: Provider pattern with AppState
- **Database**: Supabase PostgreSQL with Row Level Security
- **Storage**: Supabase Storage for PDF files
- **HTTP**: RESTful communication via Supabase client

## Demo

Add screenshots and a short demo clip to make first-time visitors trust the app quickly.

- `docs/screenshots/home.png`
- `docs/screenshots/upload.png`
- `docs/screenshots/profile.png`
- `docs/demo.gif`

## Project Structure

```
lib/
├── main.dart                    # App entry point and auth gate
├── data/
│   ├── app_state.dart          # Global state management
│   ├── supabase_backend.dart   # Supabase API calls
│   ├── supabase_config.dart  # Supabase configuration
│   ├── document_scanner_service.dart
│   ├── upload_pipeline.dart
│   └── pdf_cache_manager.dart
├── screens/
│   ├── home_page.dart        # Main home with feed
│   ├── explore_page.dart     # Search and browse
│   ├── upload_page.dart    # Upload workflow
│   ├── paper_detail_page.dart
│   ├── paper_scanner_page.dart
│   ├── document_scanner_preview_page.dart
│   ├── pdf_viewer_page.dart
│   ├── profile_page.dart    # User profile
│   ├── points_page.dart    # Points and rewards
│   ├── bookmarks_page.dart
│   ├── leaderboard_page.dart
│   ├── notifications_page.dart
│   ├── auth_page.dart      # Login/signup
│   ├── onboarding_page.dart
│   ├── admin_page.dart
│   ├── admin_dashboard_page.dart
│   ├── admin_users_page.dart
│   ├── admin_institutions_page.dart
│   ├── level_papers_page.dart
│   └── competitive_exams_page.dart
├── widgets/
│   └── offline_banner.dart
├── theme/
│   └── app_theme.dart     # Material 3 theming
assets/
└── images/
  └── logo.png
```

## Tech Stack

- **Framework**: Flutter 3.11+
- **Language**: Dart 3.11+
- **Backend**: Supabase (PostgreSQL, Auth, Storage)
- **State**: Provider + ChangeNotifier

### Key Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| supabase_flutter | ^2.8.0 | Backend client |
| google_fonts | ^8.0.2 | Typography |
| file_picker | ^11.0.1 | File selection |
| path_provider | ^2.1.5 | File system paths |
| syncfusion_flutter_pdfviewer | ^33.1.46 | PDF rendering |
| google_mlkit_document_scanner | ^0.4.1 | Document scanning |
| mobile_scanner | ^7.2.0 | QR code scanning |
| permission_handler | ^12.0.1 | Runtime permissions |
| shared_preferences | ^2.5.5 | Local storage |
| url_launcher | ^6.3.1 | External links |
| connectivity_plus | ^6.1.5 | Network status |

## Getting Started

### Prerequisites

- Flutter 3.11 or later
- Dart 3.11 or later
- Supabase project (see Supabase Setup below)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/mahitoh/pass_it.git
cd pass_it
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure Supabase (see Supabase Setup below)

4. Run the app:
```bash
flutter run
```

### Environment Notes

- Android and iOS require platform setup for file access, scanner, and camera permissions.
- Ensure deep link callback `passit://auth-callback` matches your Supabase auth config.

## Supabase Setup

### Database Schema

Create the following tables in your Supabase project:

```sql
-- Profiles table
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  full_name TEXT,
  institution TEXT,
  department TEXT,
  user_type TEXT DEFAULT 'student',
  points_balance INTEGER DEFAULT 0,
  is_verified_uploader BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Paper uploads table
CREATE TABLE paper_uploads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uploader_id UUID REFERENCES auth.users(id),
  level TEXT NOT NULL,
  institution TEXT NOT NULL,
  course TEXT NOT NULL,
  year INTEGER NOT NULL,
  file_name TEXT NOT NULL,
  file_url TEXT,
  storage_path TEXT,
  status TEXT DEFAULT 'pending',
  downloads INTEGER DEFAULT 0,
  views INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE paper_uploads ENABLE ROW LEVEL SECURITY;
```

### Storage Bucket

Create a storage bucket named `uploads` in Supabase Storage.

### Row Level Security Policies

```sql
-- Profiles: Users can read all, update own
CREATE POLICY "Public profiles are viewable by everyone"
  ON profiles FOR SELECT USING (true);

-- Users can update own profile
CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE USING (auth.uid() = id);

-- Papers: Approved papers visible to all
CREATE POLICY "Approved papers visible to everyone"
  ON paper_uploads FOR SELECT USING (status = 'approved');

-- Uploaders can view own papers (all statuses)
CREATE POLICY "Owners can view own papers"
  ON paper_uploads FOR SELECT USING (auth.uid() = uploader_id);
```

### RPC Functions

```sql
-- Approve paper (admin only)
CREATE OR REPLACE FUNCTION admin_approve_paper(p_paper_id UUID)
RETURNS JSONB AS $$
BEGIN
  UPDATE paper_uploads
  SET status = 'approved'
  WHERE id = p_paper_id;

  UPDATE profiles
  SET points_balance = points_balance + 50
  WHERE id = (SELECT uploader_id FROM paper_uploads WHERE id = p_paper_id);

  RETURN jsonb_build_object('ok', true, 'status', 'approved');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Reject paper (admin only)
CREATE OR REPLACE FUNCTION admin_reject_paper(p_paper_id UUID, p_note TEXT)
RETURNS JSONB AS $$
BEGIN
  UPDATE paper_uploads
  SET status = 'rejected'
  WHERE id = p_paper_id;

  RETURN jsonb_build_object('ok', true, 'status', 'rejected');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Increment downloads
CREATE OR REPLACE FUNCTION increment_downloads(paper_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE paper_uploads
  SET downloads = downloads + 1
  WHERE id = paper_id;
END;
$$ LANGUAGE plpgsql;
```

### Auth Configuration

1. Enable Email Auth in Supabase Authentication
2. Configure redirect URL: `passit://auth-callback`
3. Add admin emails to `adminEmails` in `lib/data/supabase_config.dart`

## Configuration

### Supabase Config

Update `lib/data/supabase_config.dart`:

```dart
const String supabaseUrl = 'https://your-project.supabase.co';
const String supabaseAnonKey = 'your-anon-key';
const String supabaseStorageBucket = 'uploads';
const String supabaseTableName = 'paper_uploads';

const List<String> adminEmails = [
  'admin@example.com',
];
```

### App Configuration

Update `pubspec.yaml`:

```yaml
version: 1.0.0+1

flutter:
  uses-material-design: true

  assets:
    - assets/images/
```

## Building

### Debug Build

```bash
flutter build apk --debug
```

### Release Build

```bash
flutter build apk --release
```

### Optimized APKs For Sharing

```bash
flutter build apk --release --split-per-abi
```

Artifacts are generated in `build/app/outputs/flutter-apk/`.

### iOS Build

```bash
flutter build ios --release
```

## Architecture

### State Management

The app uses Provider pattern with a central `AppState` class:

- `papers`: Public feed of approved papers
- `myUploads`: User's own uploaded papers
- `user`: Current user profile
- `points`: User's points balance
- `streak`: Daily login streak
- `themeMode`: Light/dark theme preference

### Data Flow

1. App starts → Initialize Supabase
2. Auth gate checks session
3. If authenticated → Hydrate from Supabase
4. Load cached papers for offline access
5. Display home feed of approved papers

### Security

- Row Level Security on all tables
- PKCE auth flow for web compatibility
- Admin functions use SECURITY DEFINER
- Storage paths include user ID

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes following the existing code style
4. Test thoroughly
5. Submit a pull request

## Roadmap

- Play Store internal/open testing rollout
- Better moderation tooling for admins
- Smarter paper recommendation and tagging
- In-app release notes and update prompts

## License

See LICENSE file for details.

## Acknowledgments

- [Supabase](https://supabase.com) for backend services
- [Syncfusion](https://www.syncfusion.com/) for PDF viewer
- [Google ML Kit](https://developers.google.com/ml-kit) for document scanning
- [Google Fonts](https://fonts.google.com) for typography