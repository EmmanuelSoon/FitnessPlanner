# Fitness Planner - Kotlin Android App

A modern Android application built with Kotlin and Jetpack Compose, targeting Android 14 (API 34).

## Project Setup

### Requirements
- Android Studio Flamingo or later
- JDK 11 or higher
- Android SDK with API 34 installed
- Kotlin 1.9.22 or later

### Getting Started

1. Clone the repository
2. Open the project in Android Studio
3. Wait for Gradle sync to complete
4. Build and run the app on an Android 14 device or emulator

### Project Structure

```
fitnessPlanner/
├── app/
│   ├── src/
│   │   └── main/
│   │       ├── kotlin/com/fitnessplanner/
│   │       │   ├── MainActivity.kt
│   │       │   └── ui/theme/
│   │       │       ├── Color.kt
│   │       │       └── Theme.kt
│   │       ├── res/
│   │       │   ├── values/
│   │       │   │   ├── strings.xml
│   │       │   │   └── themes.xml
│   │       │   └── xml/
│   │       │       ├── data_extraction_rules.xml
│   │       │       └── backup_rules.xml
│   │       └── AndroidManifest.xml
│   ├── build.gradle.kts
│   └── proguard-rules.pro
├── gradle/
│   └── libs.versions.toml
├── build.gradle.kts
├── settings.gradle.kts
└── gradle.properties
```

### Technology Stack

- **Language**: Kotlin 1.9.22
- **UI Framework**: Jetpack Compose
- **Material Design**: Material3
- **Target API**: 34 (Android 14)
- **Minimum API**: 24 (Android 7.0)
- **Build System**: Gradle 8.2.0 with Version Catalog

### Key Features

✅ Android 14 Support (API 34)
✅ Modern Jetpack Compose UI
✅ Dynamic Color Support
✅ Material3 Design System
✅ Lifecycle-aware Components
✅ Kotlin Coroutines Ready

### Build & Run

```bash
# Build the project
./gradlew build

# Run on device/emulator
./gradlew installDebug

# Run specific Android version
./gradlew runOnAllDevices
```

### Next Steps

1. Implement core features for fitness tracking
2. Add data persistence (Room database)
3. Implement user authentication
4. Add navigation between screens
5. Integrate health APIs

## License

MIT License

