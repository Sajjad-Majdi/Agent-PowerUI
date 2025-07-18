# Technology Stack

## Framework & Language
- **Flutter** (SDK >=3.0.0 <4.0.0) - Cross-platform UI framework
- **Dart** - Primary programming language

## Key Dependencies
- `flutter_bloc` - State management (partially implemented for learning)
- `google_generative_ai` - Integration with Gemini AI (online mode)
- `google_fonts` - Custom font loading
- `flutter_highlight` - Code syntax highlighting
- `flutter_math_fork` - Mathematical expression rendering
- `gpt_markdown` - Markdown processing
- `window_manager` - Desktop window management
- `url_launcher` - External URL handling
- `intl` - Internationalization support

## AI Integration Strategy
- **Online Mode**: Cloud-based models (Gemini API) for enhanced capabilities
- **Offline Mode**: Local Small Language Models (SLMs) for privacy and offline use
- Python backend integration for AI model management

## Build System
- **Gradle** (Kotlin DSL) for Android builds
- **CMake** for Windows builds
- Standard Flutter build system

## Common Commands
```bash
# Development
flutter run                    # Run in debug mode
flutter run --release         # Run in release mode
flutter hot-reload            # Hot reload during development

# Building
flutter build apk             # Build Android APK
flutter build windows        # Build Windows executable
flutter build web            # Build for web deployment

# Testing & Analysis
flutter test                  # Run unit tests
flutter analyze              # Static code analysis
flutter doctor               # Check Flutter installation

# Dependencies
flutter pub get              # Install dependencies
flutter pub upgrade          # Update dependencies
flutter clean                # Clean build artifacts
```

## Development Tools
- Flutter Lints for code quality
- Material 3 design system
- Custom theming with dark/light mode support