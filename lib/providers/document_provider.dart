import 'package:flutter/foundation.dart';
import '../models/document_model.dart';
import '../services/firebase_service.dart';
import '../services/openai_service.dart';
import '../services/support_diagnostics_service.dart';

class DocumentProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final OpenAIService _openAIService = OpenAIService();
  final SupportDiagnosticsService _diagnostics =
      SupportDiagnosticsService.instance;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  bool _isGeneratingInsight = false;
  bool get isGeneratingInsight => _isGeneratingInsight;

  Stream<List<DocumentModel>> get documentsStream =>
      _firebaseService.userDocuments;

  Future<DocumentModel?> processAndSaveDocument(
    Uint8List fileBytes, {
    required String fileName,
  }) async {
    _isProcessing = true;
    notifyListeners();

    try {
      // 1. Analyze with AI
      final aiData = await _openAIService.analyzeDocument(
        fileBytes,
        fileName: fileName,
      );

      // 2. Save metadata and image
      final doc = await _firebaseService.saveDocument(
        imageBytes: fileBytes,
        fileName: fileName,
        aiData: aiData,
      );

      return doc;
    } catch (e) {
      debugPrint('Error processing document: $e');
      _diagnostics.logError(
        source: 'DocumentProvider',
        message: 'processAndSaveDocument failed: $e',
      );
      return null;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<String> generatePortfolioInsight(List<DocumentModel> docs) async {
    _isGeneratingInsight = true;
    notifyListeners();
    try {
      return await _openAIService.generatePortfolioInsight(docs);
    } finally {
      _isGeneratingInsight = false;
      notifyListeners();
    }
  }

  Future<String> askQuestionAboutDocuments(
    List<DocumentModel> docs,
    String question,
  ) async {
    _isGeneratingInsight = true;
    notifyListeners();
    try {
      return await _openAIService.answerAboutDocuments(docs, question);
    } finally {
      _isGeneratingInsight = false;
      notifyListeners();
    }
  }
}
