# SickleClinix

A Flutter-based healthcare application designed for sickle cell disease detection in rural sub-Saharan Africa. The app assists healthcare workers in diagnosing sickle cell disease from blood smear images using automated image analysis.

## Features

- **Automated Sickle Cell Detection**: Uses TensorFlow Lite models for blood smear analysis
- **Offline-First Design**: Works without internet connectivity for remote areas
- **Patient Management**: Comprehensive patient history and data tracking
- **Grad-CAM Visualization**: Model interpretability features for healthcare professionals
- **Secure Data Storage**: Encrypted local storage with Firebase cloud sync
- **Privacy Compliant**: HIPAA-compliant data handling with user consent

## Technology Stack

- **Framework**: Flutter
- **Database**: SQLite + Firebase Firestore
- **Authentication**: Firebase Auth
- **Storage**: Firebase Storage
- **ML Models**: TensorFlow Lite
- **Local Storage**: Hive with AES encryption

## App Flow

### 1. Authentication & Setup

- **Landing Screen**: App introduction and privacy consent
- **Login/Signup**: Healthcare worker authentication via Firebase
- **Facility Selection**: Choose healthcare facility for data organization
- **Profile Setup**: Complete user profile with professional credentials

### 2. Patient Management

- **Patient List**: View all registered patients with search and filter options
- **Add New Patient**: Capture patient demographics and medical history
- **Patient Profile**: Detailed patient information and prediction history
- **Edit Patient**: Update patient information as needed

### 3. Sickle Cell Detection

- **Prediction Screen**: Main interface for blood smear analysis
- **Image Capture**: Take photos using device camera or select from gallery
- **Single/Bulk Mode**: Toggle between individual and batch processing
- **Model Analysis**: Automated detection using TensorFlow Lite models
- **Grad-CAM Visualization**: AI interpretability with highlighted regions of interest

### 4. Results & Interpretation

- **Result Screen**: Display prediction results with confidence scores
- **Grad-CAM Images**: Visual explanation of model decisions
- **Clinical Recommendations**: AI-suggested next steps for healthcare workers
- **Save Results**: Store predictions with patient association

### 5. Data Management

- **History Screen**: View all predictions with filtering and search
- **Export Options**: Generate PDF reports for patient records
- **Data Sync**: Automatic Firebase synchronization when online
- **Bulk Operations**: Manage multiple predictions efficiently

### 6. Settings & Support

- **Profile Management**: Update user information and preferences
- **Connectivity Status**: Real-time internet connection monitoring
- **Help & Support**: Access to app documentation and support
- **Privacy Settings**: Manage data collection and storage preferences

### 7. Offline Functionality

- **Local Storage**: All data stored locally using SQLite and Hive
- **Offline Predictions**: ML models work without internet connection
- **Sync Queue**: Automatic data synchronization when connectivity returns
- **Data Integrity**: Ensures no data loss during connectivity issues

## User Journey

### For Healthcare Workers:

1. **Initial Setup**: Download app → Create account → Select facility
2. **Daily Workflow**:
   - Register new patients
   - Capture blood smear images
   - Get AI-assisted predictions
   - Review Grad-CAM visualizations
   - Make clinical decisions
   - Export reports for patient records
3. **Data Management**: Sync data when internet is available

### For Rural Healthcare:

- **Low Connectivity**: App functions completely offline
- **Simple Interface**: Designed for healthcare professionals
- **Reliable Results**: Consistent ML model performance
- **Data Security**: Encrypted local storage with cloud backup

## Key Workflows

### Single Patient Analysis:

```
Patient Registration → Image Capture → AI Analysis → Results Review → Save & Export
```

### Batch Processing:

```
Multiple Images → Bulk Analysis → Summary Report → Individual Results → Export All
```

### Data Synchronization:

```
Local Storage → Connectivity Check → Firebase Sync → Conflict Resolution → Update Local
```

### Prerequisites

- Flutter SDK (latest stable version)
- Dart SDK
- Android Studio / VS Code
- Firebase project setup

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Configure Firebase:
   - Add `google-services.json` to `android/app/`
   - Add `GoogleService-Info.plist` to `ios/Runner/`
4. Run the app:
   ```bash
   flutter run
   ```

### Building for Production

To build an APK for distribution:

```bash
# Debug build (for testing)
flutter build apk --debug

# Release build (for production)
flutter build apk --release

# Split APKs by architecture (smaller downloads)
flutter build apk --split-per-abi --release
```

The APK will be generated at: `build/app/outputs/flutter-apk/app-release.apk`

https://drive.google.com/file/d/1BpUeyMVodZEpuPlSYew0wywne5IbgzIy/view?usp=drive_link
