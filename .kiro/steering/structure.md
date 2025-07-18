# Project Structure

## Root Directory
```
├── lib/                    # Main Dart source code
├── android/               # Android-specific configuration
├── windows/               # Windows-specific configuration  
├── web/                   # Web deployment files
├── assets/                # Static assets (fonts, textures)
├── build/                 # Build output (generated)
├── .dart_tool/           # Dart tooling cache (generated)
└── pubspec.yaml          # Project configuration & dependencies
```

## Source Code Organization (`lib/`)
```
lib/
├── main.dart             # Application entry point
├── blocs/                # BLoC state management
│   ├── chat/            # Chat-related state management
│   └── code_block/      # Code block state management
├── components/           # Reusable UI components
│   ├── subunits/        # Smaller component parts
│   ├── app_bar.dart     # Custom app bar component
│   ├── input_bar.dart   # Chat input component
│   └── massage_bubble.dart # Chat message display
├── pages/                # Screen/page widgets
│   └── chat_interface.dart # Main chat interface
└── services/             # Business logic & external integrations
    ├── gemini.dart      # Gemini AI service integration
    ├── modules.dart     # Service modules
    └── *.py files       # Python integration scripts
```

## Architecture Patterns
- **Mixed State Management**: 
  - BLoC Pattern implemented for `chat/` and `code_block/` features as learning examples
  - Most other features currently use simple `setState()` - will migrate to BLoC as learning progresses
- **Component-Based**: Reusable UI components in `components/`
- **Service Layer**: External integrations and business logic in `services/`
- **Page-Based Routing**: Screen components in `pages/`

## Development Approach
This is a learning project where BLoC state management is being implemented incrementally:
1. Two features (`chat/` and `code_block/`) serve as BLoC learning examples
2. Other features use traditional `setState()` for now
3. Gradual migration to BLoC pattern as understanding develops

## Asset Organization
- **Fonts**: Custom Persian/Farsi fonts in `assets/fonts/`
- **Textures**: Visual assets in `assets/textures/`
- **Platform Assets**: Platform-specific icons and manifests in respective directories

## Naming Conventions
- **Files**: snake_case (e.g., `chat_interface.dart`, `massage_bubble.dart`)
- **Classes**: PascalCase (e.g., `ChatInterface`, `MainApp`)
- **Variables**: camelCase following Dart conventions
- **Constants**: SCREAMING_SNAKE_CASE for compile-time constants