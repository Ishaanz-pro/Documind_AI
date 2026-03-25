class AppConstants {
  static const String openAiApiKey =
    String.fromEnvironment('OPENAI_API_KEY', defaultValue: '');
  static const String openAiVisionModel =
    String.fromEnvironment('OPENAI_VISION_MODEL', defaultValue: 'gpt-4o');
  static const String openAiTextModel =
    String.fromEnvironment('OPENAI_TEXT_MODEL', defaultValue: 'gpt-4o-mini');
  static const String revenueCatApiKey = 'test_WrLuBPjSzBFYyiwdPUwolpkZAke';
  
  // AdMob IDs (Replace with actual IDs for production)
  static const String bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111'; // Test Banner ID
  static const String interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712'; // Test Interstitial ID

  static const List<String> documentCategories = [
    'All',
    'Receipt',
    'Medical',
    'Warranty',
    'Personal',
    'Finance',
    'Other'
  ];
}
