# The Runner's Saga 🏃‍♂️📚

A story-driven running experience that transforms workouts into immersive adventures.

## 🎯 Project Overview

"The Runner's Saga" is a mobile application designed for iOS and Android that integrates compelling, audio-based narratives to transform routine workouts into immersive adventures. The app's core value proposition is to make running a habit-forming activity through storytelling.

### Key Features (MVP)
- **Story-Driven Running**: Complete "Fantasy Quest" saga with dynamic audio segments
- **GPS Tracking**: Real-time location, distance, and pace tracking
- **Audio Integration**: Seamless music and story audio playback
- **Sprint Intervals**: Story-triggered pace challenges
- **Progress Tracking**: Visual saga progress with mission completion
- **User Authentication**: Email/password and social login support

## 🏗️ Architecture

- **Frontend**: Flutter with Dart
- **State Management**: Riverpod
- **Backend**: Firebase (Firestore, Auth, Storage, Functions)
- **Navigation**: GoRouter
- **Local Storage**: Hive
- **Audio**: AudioPlayers
- **Maps**: Flutter Map

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.8.1+)
- Dart SDK (3.8.1+)
- iOS Simulator / Android Emulator
- Firebase Project (for backend services)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd runners_saga
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Set up Firebase**
   - Create a new Firebase project
   - Enable Authentication, Firestore, Storage, and Functions
   - Download and add configuration files:
     - `ios/Runner/GoogleService-Info.plist` (iOS)
     - `android/app/google-services.json` (Android)

4. **Run the app**
   ```bash
   flutter run
   ```

## 📱 Development Phases

### Phase 1: Foundation & Design (Month 1)
- [x] Project setup and environment configuration
- [ ] UI/UX mockups for core screens
- [ ] First saga script completion
- [ ] Basic Flutter app structure
- [ ] Firebase Authentication integration

### Phase 2: Core Functionality (Months 2-4)
- [ ] GPS tracking and run data storage
- [ ] Audio playback system
- [ ] Dynamic story logic (Cloud Functions)
- [ ] Saga Hub and progress tracking
- [ ] Post-run summary screens

### Phase 3: Testing & Launch (Months 5-6)
- [ ] Internal alpha testing
- [ ] Beta program launch
- [ ] Monetization integration
- [ ] App store submission

## 🗂️ Project Structure

```
lib/
├── core/                 # Core app functionality
│   ├── constants/        # App constants and configuration
│   ├── services/         # Core services (Firebase, GPS, Audio)
│   └── utils/           # Utility functions and helpers
├── features/            # Feature-specific modules
│   ├── auth/            # Authentication feature
│   ├── home/            # Saga Hub and home screen
│   ├── run/             # Running tracking and UI
│   └── story/           # Story management and audio
├── shared/              # Shared components
│   ├── models/          # Data models
│   ├── widgets/         # Reusable UI components
│   └── providers/       # Riverpod providers
└── main.dart            # App entry point
```

## 🔧 Development Commands

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run

# Build for production
flutter build apk --release
flutter build ios --release

# Generate code (Riverpod, Hive)
flutter packages pub run build_runner build

# Run tests
flutter test

# Analyze code
flutter analyze
```

## 📋 Current Tasks

### Immediate Next Steps
1. [ ] Set up Firebase project and configuration
2. [ ] Create basic app structure with navigation
3. [ ] Implement authentication flow
4. [ ] Design and create UI components
5. [ ] Set up GPS tracking service

### This Week's Goals
- [ ] Complete Firebase setup
- [ ] Create authentication screens
- [ ] Set up basic navigation structure
- [ ] Begin GPS tracking implementation

## 🤝 Contributing

This is an MVP development project. Development follows the phases outlined in the functional specification document.

## 📄 License

This project is proprietary and confidential.

---

**Built with ❤️ using Flutter and Firebase**
