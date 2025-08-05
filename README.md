# Magic Home App

A Flutter mobile application for home management with AI-powered service requests and complete authentication system.

## Features

- **AI-Powered Service Requests**: Intelligent chatbot using Google Gemini AI for natural conversations
- **Dual-Mode Conversation**: Works with AI when configured, falls back to step-based flow when not
- **Smart Photo Upload**: Camera integration with Firebase Storage for service documentation
- **Interactive Calendar**: Date selection for service availability
- **Speech Recognition**: Voice input for hands-free interaction
- User authentication (login, registration, forgot password)
- Phone number verification with OTP
- Referral code system
- Modern UI design with custom animations

## Screens

- Welcome screen
- Login screen
- Registration screen
- Phone verification with OTP
- Forgot password
- Referral code entry
- Home screen
- **AI Task Intake Screen**: Smart conversation interface for service requests

## AI Chatbot Features

### Google Gemini Integration
- **Natural Conversations**: Powered by Google Gemini AI for intelligent, context-aware responses
- **Service Category Detection**: Automatically identifies service types (cleaning, plumbing, electrical, etc.)
- **Progressive Flow**: Guides users through questions → photos → scheduling → summary
- **Fallback Mode**: Step-based progression when AI is not configured

### Configuration
The app supports both Gemini and OpenAI configurations:
- **Gemini API**: Primary AI backend (configured)
- **OpenAI API**: Alternative backend (configurable)
- **Fallback Mode**: Predictable step-based flow when no AI is available

## Technical Overview

- Built with Flutter for cross-platform compatibility
- **Firebase Integration**: Authentication, Firestore, Storage
- **AI Service Architecture**: Modular AI conversation service with dual-mode support
- **API Configuration**: Centralized config for multiple AI providers
- Clean architecture with separation of UI and business logic
- Custom UI components and animations
- Comprehensive testing suite

## Getting Started

### Prerequisites

- Flutter SDK (latest version)
- Dart SDK (latest version)
- iOS simulator or device (for iOS testing)
- Android emulator or device (for Android testing)
- **Google Gemini API Key** (for AI features)

### Installation

1. Clone this repository:
```bash
git clone https://github.com/molly0202/magic_home_app.git
cd magic_home_app
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure AI API (optional):
   - Open `lib/config/api_config.dart`
   - Replace `YOUR_GEMINI_API_KEY` with your actual Gemini API key
   - Or replace `YOUR_OPENAI_API_KEY` with your OpenAI API key

4. Run the app:
```bash
flutter run
```

## Testing

### Running All Tests
```bash
flutter test
```

### Running AI Conversation Service Tests
```bash
flutter test test/services/ai_conversation_service_test.dart
```

### Running Tests with Verbose Output
```bash
flutter test test/services/ai_conversation_service_test.dart --verbose
```

### Test Coverage
The AI conversation service includes comprehensive tests:
- **Functional Tests**: Service initialization, conversation flow, callbacks
- **Gemini API Tests**: Connection testing, real conversation handling
- **Configuration Tests**: API key validation, fallback mode verification
- **Multi-turn Conversations**: Complex conversation flows

Example test output:
```
✅ 12/12 tests passed
✅ Gemini API connection successful
✅ Real AI responses verified
✅ Fallback mode working
```

## AI Conversation Service API

### Basic Usage
```dart
final aiService = AIConversationService();
aiService.startConversation();

// Process user input
final response = await aiService.processUserInput('I need cleaning service');

// Handle photo upload
aiService.onPhotoUploaded('https://example.com/photo.jpg');

// Handle availability selection
aiService.onAvailabilitySelected({'selectedDates': ['2024-01-15']});

// Get service request summary
final summary = aiService.getServiceRequestSummary();
```

### Configuration Check
```dart
if (ApiConfig.isAnyAiConfigured) {
  // Use AI-driven conversation
} else {
  // Use step-based fallback
}
```

## Project Structure

```
lib/
├── config/
│   └── api_config.dart          # AI API configuration
├── screens/
│   └── ai_task_intake_screen.dart  # Main AI chat interface
├── services/
│   └── ai_conversation_service.dart # AI conversation logic
└── models/
    └── service_request.dart      # Data models

test/
└── services/
    └── ai_conversation_service_test.dart # Comprehensive AI tests
```

## Future Improvements

- Integration with more AI providers (Claude, etc.)
- Enhanced voice recognition with multiple languages
- Real-time provider matching and quotes
- Advanced calendar integration with availability sync
- Machine learning for improved service categorization
- Unit and widget testing expansion
- Theme customization options
- Multi-language support

## AI Provider Options

The app supports multiple AI backends:

1. **Google Gemini** (Primary) - Advanced conversational AI with excellent context understanding
2. **OpenAI GPT** (Alternative) - Reliable AI with consistent responses  
3. **Fallback Mode** (Always Available) - Step-based flow ensuring functionality without AI

## License

This project is licensed under the MIT License - see the LICENSE file for details.
