# DocuMind AI: Smart Document Manager

A production-ready Flutter application that can run on mobile and as a deployable web app to scan, categorize, and search documents.

## Features
- **Smart Scan**: Capture documents using the camera, process them via OpenAI's GPT-4o Vision API to identify document type, extract key date, total amount, and provide a 2-sentence summary.
- **Image + PDF Processing**: Upload JPG/PNG/WEBP images and PDF files; PDFs are parsed and analyzed using extracted text.
- **Categorized Gallery**: Filter chips ('All', 'Medical', 'Finance') and full-text search capabilities over the AI-generated summaries.
- **Web-ready Processing**: Image upload and document analysis flow works for Flutter Web builds.
- **Support Readiness Toolkit**: In-app health snapshot export for diagnostics and incident-style reporting demos.
- **Monetization**:
  - Google Mobile Ads (AdMob): Banner ads and Interstitial ads after every 2 scans.
  - RevenueCat: Premium monthly subscription ($2.99) that removes ads and enables unlimited scans.
- **Web Platform Behavior**: Ads and RevenueCat purchase flows are automatically disabled on web.
- **Authentication & Sync**: Firebase Auth for login, Firestore for document metadata, and Firebase Storage for storing captured images.

## Architecture
This project uses the **Provider** package for state management. The app structure follows Clean Architecture principles:
- `lib/models/`: Data models used across the app (e.g., DocumentModel)
- `lib/services/`: External API handlers (Local Camera, OpenAI, Firebase, AdMob, RevenueCat)
- `lib/providers/`: State management handlers mediating between services and UI
- `lib/screens/`: Flutter UI screens
- `lib/widgets/`: Reusable UI components

## Setup Instructions

### 1. Flutter Setup
Run `flutter pub get` from the `documind_ai/` directory.

### 2. Add Your Configuration Files / Keys

**Firebase**
You must link this project to your Firebase Console:
1. Initialize Firebase (e.g. `flutterfire configure`) and place the `google-services.json` file inside `android/app/`.

**OpenAI API Key**
Pass your OpenAI key securely at build/run time using dart-define:
```bash
flutter run -d chrome --dart-define=OPENAI_API_KEY=YOUR_OPENAI_API_KEY
```

Optional model overrides:
```bash
--dart-define=OPENAI_VISION_MODEL=gpt-4o --dart-define=OPENAI_TEXT_MODEL=gpt-4o-mini
```

**RevenueCat**
Update the RevenueCat public SDK key in `lib/core/constants.dart`:
```dart
const String revenueCatApiKey = 'YOUR_REVENUECAT_PUBLIC_SDK_KEY';
```

**AdMob**
To run production ads, update your AdMob App ID in:
- `android/app/src/main/AndroidManifest.xml` (Search for `com.google.android.gms.ads.APPLICATION_ID`)
- `lib/services/ad_service.dart` (Update banner and interstitial ad unit IDs)

## Running the App
After successfully completing the configuration steps above, run the app using:

Mobile/Desktop:
`flutter run`

Web (local):
`flutter run -d chrome --dart-define=OPENAI_API_KEY=YOUR_OPENAI_API_KEY`

## Deployable Web App

### Build for Production
Run:
`flutter build web --release --dart-define=OPENAI_API_KEY=YOUR_OPENAI_API_KEY`

The generated static site is available in `build/web/` and can be hosted on any static host.

### GitHub Pages Deployment (Included)
This repository now includes a CI workflow at `.github/workflows/deploy-web.yml`.

How it works:
1. On push to `main`, GitHub Actions builds Flutter Web.
2. It automatically computes the correct `--base-href` for GitHub Pages.
3. It publishes `build/web/` to GitHub Pages.

To enable it in your repo:
1. Go to GitHub repository settings.
2. Open `Pages`.
3. Set source to `GitHub Actions`.

Deploy now:
1. Commit your changes.
2. Push to `main`.
3. Wait for the `Deploy Flutter Web to GitHub Pages` workflow to pass.
4. Open your Pages URL from repository `Settings > Pages`.

### Render Free Deployment (Docker)
This repository includes:
- `Dockerfile` (builds Flutter web and serves static output)
- `render.yaml` (Render service blueprint)

Steps:
1. Push this repository to GitHub.
2. In Render, click `New +` -> `Blueprint`.
3. Connect your repository and deploy.
4. Render picks up `render.yaml` and creates a free Docker web service.
5. On successful deploy, open the generated Render URL.

## Notes for Production Web

- Never hardcode API keys in source control.
- Configure Firebase Web credentials using `flutterfire configure` so web builds can access Auth, Firestore, and Storage.
