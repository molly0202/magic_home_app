# Magic Home App

A Flutter mobile application for home management with a complete authentication system.

## Features

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

## Technical Overview

- Built with Flutter for cross-platform compatibility
- Clean architecture with separation of UI and business logic
- Custom UI components and animations
- Simulated authentication services (ready for backend integration)

## Getting Started

### Prerequisites

- Flutter SDK (latest version)
- Dart SDK (latest version)
- iOS simulator or device (for iOS testing)
- Android emulator or device (for Android testing)

### Installation

1. Clone this repository:
```
git clone https://github.com/molly0202/magic_home_app.git
cd magic_home_app
```

2. Install dependencies:
```
flutter pub get
```

3. Run the app:
```
flutter run
```

## Future Improvements

- Integration with real backend services
- Firebase Authentication for production-ready OTP verification
- State management with Provider or Bloc
- Unit and widget testing
- Theme customization options
- Multi-language support

## OTP Implementation Options

The app currently uses a simulated OTP system. For production use, consider these options:

1. **Firebase Authentication** - Easy to implement, handles phone verification globally
2. **Twilio Verify** - Enterprise-grade solution with SMS, call, email verification
3. **AWS SNS** - Reliable, highly scalable SMS service
4. **Custom Backend** - Complete control with your own verification system

## License

This project is licensed under the MIT License - see the LICENSE file for details.
