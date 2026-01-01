## Brief overview

Project-specific coding standards for the Parable Bloom Flutter application, focusing on clean architecture, immutability, and maintainable code practices.

## Architecture patterns

- Use clean architecture with feature-based organization: data/domain/presentation layers
- Implement dependency injection using the injection_container.dart pattern
- Use Riverpod for state management with providers defined in dedicated provider files
- Follow repository pattern for data access abstraction

## Code style conventions

- Use double quotes for all string literals
- Use const constructors for immutable classes and static constants
- Implement copyWith methods for data classes to maintain immutability
- Override == operator and hashCode for proper object comparison
- Use descriptive, camelCase variable and method names
- Use PascalCase for class names and UPPER_SNAKE_CASE for constants

## Documentation and comments

- Use /// for class and method documentation comments
- Add inline comments for complex business logic
- Document public APIs with clear parameter and return descriptions

## State management

- Use Riverpod providers for state management
- Define providers in dedicated provider files (e.g., game_providers.dart)
- Use ProviderScope overrides for dependency injection in main.dart

## Data persistence

- Use Hive for local data storage with proper box initialization
- Use Firebase for cloud services with proper initialization in main.dart
- Implement repository interfaces for data abstraction

## UI and theming

- Use Material 3 design with ThemeData configuration
- Centralize theme colors and styling in app_theme.dart
- Support both light and dark themes with proper color schemes
- Use brightness-aware color selection for game components

## Testing and analysis

- Include flutter_lints in analysis_options.yaml for code quality
- Write unit tests for domain logic and repositories
- Use widget tests for UI components

## Async programming

- Use async/await pattern consistently
- Initialize asynchronous services (Firebase, Hive) before runApp()
- Handle errors appropriately in async operations