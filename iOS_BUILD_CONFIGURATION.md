# iOS Build Configuration for Firebase + Flutter

## Required Xcode Settings

### 1. Project Settings (Runner.xcodeproj)
```
Build Settings → Runner Target:
- iOS Deployment Target: 13.0 or higher
- Enable Bitcode: NO
- Excluded Architectures: arm64 (for simulators only)
- Valid Architectures: arm64, x86_64
- Allow Non-modular Includes: YES
- Define Module: YES
```

### 2. Build Phases Order (Critical)
```
1. Target Dependencies
2. [CP] Check Pods Manifest.lock
3. Compile Sources
4. [CP] Embed Pods Frameworks  ← This is where conflicts occur
5. Copy Bundle Resources
6. [CP] Copy Pods Resources
7. Thin Binary
```

### 3. Framework Search Paths
```
Framework Search Paths should include:
- $(inherited)
- $(PROJECT_DIR)/Flutter/Flutter.framework
- $(PODS_ROOT)/path/to/frameworks
```

## Firebase Configuration Files

### Required Files in iOS Directory:
```
ios/
├── GoogleService-Info.plist  ← MUST be exactly this name
├── Podfile                   ← With gRPC conflict fixes
├── Runner.xcworkspace/       ← Use this, not .xcodeproj
└── Runner/
    ├── Info.plist           ← Bundle ID must match Firebase
    └── AppDelegate.swift    ← Firebase initialization
```

### GoogleService-Info.plist Requirements:
```xml
<key>BUNDLE_ID</key>
<string>com.meijia.MagicHomeApp</string>  ← Must match Xcode Bundle ID

<key>PROJECT_ID</key>
<string>magic-home-01</string>           ← Must match Firebase project
```

## CocoaPods Configuration

### Podfile Requirements:
```ruby
platform :ios, '13.0'  # Minimum supported

# Use dynamic frameworks (required for Firebase)
use_frameworks!
use_modular_headers!

# Post-install fixes for gRPC conflicts
post_install do |installer|
  # Deployment target consistency
  # gRPC conflict resolution
  # Framework deduplication
end
```

## Build Environment Verification

### 1. Check Tool Versions:
```bash
flutter doctor -v
xcodebuild -version
pod --version
```

### 2. Clean Build Process:
```bash
# Complete clean
flutter clean
cd ios && rm -rf Pods Podfile.lock .symlinks
flutter pub get
pod install
```

### 3. Build Commands (in order):
```bash
# Method 1: Flutter CLI
flutter build ios --no-codesign

# Method 2: Xcode (recommended for debugging)
open ios/Runner.xcworkspace
# Build in Xcode with Command+B
```

## Common Conflict Resolution

### gRPC Framework Duplication:
- **Cause**: Multiple Firebase pods embedding same frameworks
- **Solution**: Podfile post_install hooks to remove duplicates
- **Alternative**: Use Firebase Realtime DB instead of Firestore

### Module Import Errors:
- **Cause**: Conflicting header paths
- **Solution**: Clean build, verify GoogleService-Info.plist
- **Check**: Bundle ID consistency across all config files

### Build Phase Errors:
- **Cause**: "[CP] Embed Pods Frameworks" duplicate outputs
- **Solution**: Xcode project cleanup, framework deduplication
- **Verify**: Framework search paths are correct

## Testing Build Success

### Step 1: Verify Configuration
```bash
# Check Firebase project registration
firebase projects:list

# Verify Bundle ID matches
grep -r "com.meijia.MagicHomeApp" ios/
```

### Step 2: Incremental Testing
```bash
# Test without Firestore first
# Comment out cloud_firestore in pubspec.yaml
flutter run -d [device-id] --debug

# Add Firestore back with fixes
# Use recommended Podfile configuration
```

### Step 3: Production Build
```bash
# Release build for App Store
flutter build ios --release
# Or build in Xcode with Archive
```

## Alternative Solutions if Conflicts Persist

### Option A: Firebase Realtime Database
- Replace Firestore with Realtime Database
- No gRPC dependencies
- Simpler data structure but less flexible

### Option B: Local + Cloud Sync
- Use SQLite for local storage
- Sync with Firebase Storage + Functions
- More complex but avoids framework conflicts

### Option C: Backend API
- Build REST API backend
- Use http package for communication
- Complete control over data layer
