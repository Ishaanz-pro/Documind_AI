import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/document_model.dart';
import '../core/constants.dart';
import 'support_diagnostics_service.dart';

class OpenAIService {
  static const String _endpoint = 'https://api.openai.com/v1/chat/completions';
  final SupportDiagnosticsService _diagnostics =
      SupportDiagnosticsService.instance;

  bool get isConfigured => AppConstants.openAiApiKey.trim().isNotEmpty;

  Future<Map<String, dynamic>> analyzeDocument(
    Uint8List fileBytes, {
    required String fileName,
  }) async {
    final stopwatch = Stopwatch()..start();
    final operation = 'analyzeDocument';
    final lower = fileName.toLowerCase();

    try {
      if (!isConfigured) {
        final fallbackResult = lower.endsWith('.pdf')
            ? _fallbackAnalyzePdf(fileBytes, fileName: fileName)
            : _fallbackAnalyzeFromText('', sourceName: fileName);
        _diagnostics.recordAiSuccess(
          operation: operation,
          latencyMs: stopwatch.elapsedMilliseconds,
          usedFallback: true,
          note: 'OpenAI key missing',
        );
        return fallbackResult;
      }

      final result = lower.endsWith('.pdf')
          ? await _analyzePdfDocument(fileBytes)
          : await _analyzeImageDocument(fileBytes);

      _diagnostics.recordAiSuccess(
        operation: operation,
        latencyMs: stopwatch.elapsedMilliseconds,
        usedFallback: false,
      );
      return result;
    } catch (e) {
      _diagnostics.recordAiFailure(
        operation: operation,
        latencyMs: stopwatch.elapsedMilliseconds,
        error: e.toString(),
        usedFallback: !isConfigured,
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _analyzeImageDocument(
      Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AppConstants.openAiApiKey}',
      },
      body: jsonEncode({
        'model': AppConstants.openAiVisionModel,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text':
                    '''Please analyze this document. Identify document type (Receipt, Medical, Warranty, Personal, Finance, Other), extract Key Date (YYYY-MM-DD if found), Total Amount (numeric value if applicable, otherwise null), and provide a 2-sentence summary.
Return ONLY a valid JSON object with the following keys:
{
  "documentType": "string",
  "keyDate": "string or null",
  "totalAmount": number or null,
  "summary": "string"
}'''
              },
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}
              }
            ]
          }
        ],
        'max_tokens': 300,
      }),
    );

    if (response.statusCode == 200) {
      return _parseJsonResponse(response.body);
    } else {
      throw Exception(
          'Failed to analyze document: ${response.statusCode} - ${response.body}');
    }
  }

  Future<Map<String, dynamic>> _analyzePdfDocument(Uint8List pdfBytes) async {
    final document = PdfDocument(inputBytes: pdfBytes);
    final extracted = PdfTextExtractor(document).extractText();
    document.dispose();

    final safeText = extracted.trim();
    if (safeText.isEmpty) {
      throw Exception('No extractable text found in PDF.');
    }

    final clippedText =
        safeText.length > 14000 ? safeText.substring(0, 14000) : safeText;

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AppConstants.openAiApiKey}',
      },
      body: jsonEncode({
        'model': AppConstants.openAiTextModel,
        'messages': [
          {
            'role': 'system',
            'content': 'You analyze text extracted from PDF documents. '
                'Use only provided content and return strict JSON.'
          },
          {
            'role': 'user',
            'content':
                '''Analyze this PDF text and identify document type (Receipt, Medical, Warranty, Personal, Finance, Other), key date if present, total amount if present, and a concise 2-sentence summary.
Return ONLY a valid JSON object with keys:
{
  "documentType": "string",
  "keyDate": "string or null",
  "totalAmount": number or null,
  "summary": "string"
}

PDF text:
$clippedText'''
          }
        ],
        'max_tokens': 320,
        'temperature': 0.2,
      }),
    );

    if (response.statusCode == 200) {
      return _parseJsonResponse(response.body);
    }

    throw Exception(
      'Failed to analyze PDF: ${response.statusCode} - ${response.body}',
    );
  }

  Future<String> generatePortfolioInsight(List<DocumentModel> docs) async {
    final stopwatch = Stopwatch()..start();
    const operation = 'generatePortfolioInsight';
    if (docs.isEmpty) {
      return 'No documents yet. Upload or scan at least one document to unlock AI insights.';
    }
    if (!isConfigured) {
      final result = _fallbackPortfolioInsight(docs);
      _diagnostics.recordAiSuccess(
        operation: operation,
        latencyMs: stopwatch.elapsedMilliseconds,
        usedFallback: true,
        note: 'OpenAI key missing',
      );
      return result;
    }

    final payload = _docsToJson(docs);
    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AppConstants.openAiApiKey}',
      },
      body: jsonEncode({
        'model': AppConstants.openAiTextModel,
        'messages': [
          {
            'role': 'system',
            'content':
                'You are an assistant for a document intelligence dashboard. '
                    'Provide concise, practical insights and mention uncertainty when data is missing.'
          },
          {
            'role': 'user',
            'content':
                'Analyze this document set and return 4 bullet points: spending trend, category concentration, key dates to watch, and one recommended action. Data: $payload'
          }
        ],
        'max_tokens': 350,
        'temperature': 0.4,
      }),
    );

    if (response.statusCode != 200) {
      _diagnostics.recordAiFailure(
        operation: operation,
        latencyMs: stopwatch.elapsedMilliseconds,
        error: 'HTTP ${response.statusCode}',
        usedFallback: false,
      );
      return 'Unable to generate AI insights right now (${response.statusCode}).';
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _diagnostics.recordAiSuccess(
      operation: operation,
      latencyMs: stopwatch.elapsedMilliseconds,
      usedFallback: false,
    );
    return (data['choices'][0]['message']['content'] as String).trim();
  }

  Future<String> answerAboutDocuments(
      List<DocumentModel> docs, String question) async {
    final stopwatch = Stopwatch()..start();
    const operation = 'answerAboutDocuments';
    if (question.trim().isEmpty) {
      return 'Ask a question about your documents first.';
    }
    if (docs.isEmpty) {
      return 'No documents available yet. Add documents, then ask your question.';
    }
    if (!isConfigured) {
      final result = _fallbackAnswer(docs, question);
      _diagnostics.recordAiSuccess(
        operation: operation,
        latencyMs: stopwatch.elapsedMilliseconds,
        usedFallback: true,
        note: 'OpenAI key missing',
      );
      return result;
    }

    final payload = _docsToJson(docs);
    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AppConstants.openAiApiKey}',
      },
      body: jsonEncode({
        'model': AppConstants.openAiTextModel,
        'messages': [
          {
            'role': 'system',
            'content':
                'You answer questions about user documents. Keep responses factual '
                    'and only use supplied data. If the answer is uncertain, say so explicitly.'
          },
          {
            'role': 'user',
            'content': 'Question: $question\n\nDocuments JSON: $payload'
          }
        ],
        'max_tokens': 320,
        'temperature': 0.2,
      }),
    );

    if (response.statusCode != 200) {
      _diagnostics.recordAiFailure(
        operation: operation,
        latencyMs: stopwatch.elapsedMilliseconds,
        error: 'HTTP ${response.statusCode}',
        usedFallback: false,
      );
      return 'Unable to answer right now (${response.statusCode}).';
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _diagnostics.recordAiSuccess(
      operation: operation,
      latencyMs: stopwatch.elapsedMilliseconds,
      usedFallback: false,
    );
    return (data['choices'][0]['message']['content'] as String).trim();
  }

  String _docsToJson(List<DocumentModel> docs) {
    final mapped = docs
        .take(120)
        .map(
          (d) => {
            'documentType': d.documentType,
            'summary': d.summary,
            'keyDate': d.keyDate,
            'totalAmount': d.totalAmount,
            'createdAt': d.createdAt.toIso8601String(),
          },
        )
        .toList();
    return jsonEncode(mapped);
  }

  Map<String, dynamic> _parseJsonResponse(String responseBody) {
    final data = jsonDecode(responseBody) as Map<String, dynamic>;
    final content = data['choices'][0]['message']['content'] as String;

    String cleanContent = content.trim();
    if (cleanContent.startsWith('```json')) {
      cleanContent =
          cleanContent.replaceAll('```json', '').replaceAll('```', '').trim();
    }

    return jsonDecode(cleanContent) as Map<String, dynamic>;
  }

  Map<String, dynamic> _fallbackAnalyzePdf(
    Uint8List pdfBytes, {
    required String fileName,
  }) {
    try {
      final document = PdfDocument(inputBytes: pdfBytes);
      final extracted = PdfTextExtractor(document).extractText();
      document.dispose();
      return _fallbackAnalyzeFromText(extracted, sourceName: fileName);
    } catch (_) {
      return _fallbackAnalyzeFromText('', sourceName: fileName);
    }
  }

  Map<String, dynamic> _fallbackAnalyzeFromText(
    String text, {
    required String sourceName,
  }) {
    final lower = ('$sourceName\n$text').toLowerCase();

    String documentType = 'Other';
    if (RegExp(r'receipt|invoice|subtotal|tax|total').hasMatch(lower)) {
      documentType = 'Receipt';
    } else if (RegExp(r'medical|hospital|clinic|diagnosis|prescription')
        .hasMatch(lower)) {
      documentType = 'Medical';
    } else if (RegExp(r'warranty|serial|coverage|replacement')
        .hasMatch(lower)) {
      documentType = 'Warranty';
    } else if (RegExp(r'bank|statement|finance|loan|account').hasMatch(lower)) {
      documentType = 'Finance';
    } else if (RegExp(r'id|passport|license|personal').hasMatch(lower)) {
      documentType = 'Personal';
    }

    final dateMatch = RegExp(
      r'\b(\d{4}-\d{2}-\d{2}|\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\b',
    ).firstMatch(text);
    final amountMatch = RegExp(
      r'(?:\$|₹|€|£)?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)',
    ).firstMatch(text);

    final amount = amountMatch == null
        ? null
        : double.tryParse(amountMatch.group(1)!.replaceAll(',', ''));

    final cleaned = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final summary = cleaned.isEmpty
        ? 'Document processed in local fallback mode. Configure OPENAI_API_KEY for richer extraction quality.'
        : 'Local fallback analysis detected this as $documentType. Preview: ${cleaned.substring(0, cleaned.length > 160 ? 160 : cleaned.length)}';

    return {
      'documentType': documentType,
      'keyDate': dateMatch?.group(1),
      'totalAmount': amount,
      'summary': summary,
    };
  }

  String _fallbackPortfolioInsight(List<DocumentModel> docs) {
    final totalAmount = docs.fold<double>(
      0,
      (sum, d) => sum + (d.totalAmount ?? 0),
    );
    final types = <String, int>{};
    for (final doc in docs) {
      types[doc.documentType] = (types[doc.documentType] ?? 0) + 1;
    }

    final dominant = types.entries.isEmpty
        ? 'N/A'
        : (types.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;

    return '''- Total documents analyzed: ${docs.length}
- Dominant category: $dominant
- Tracked amount: ${totalAmount > 0 ? '\$${totalAmount.toStringAsFixed(2)}' : 'N/A'}
- Recommendation: Configure OPENAI_API_KEY to unlock deeper trend and anomaly insights.''';
  }

  String _fallbackAnswer(List<DocumentModel> docs, String question) {
    final q = question.toLowerCase();
    if (q.contains('total') || q.contains('spend') || q.contains('amount')) {
      final total =
          docs.fold<double>(0, (sum, d) => sum + (d.totalAmount ?? 0));
      return total > 0
          ? 'The current tracked total across your documents is \$${total.toStringAsFixed(2)}.'
          : 'No numeric totals were detected in the saved documents yet.';
    }

    if (q.contains('category') || q.contains('type')) {
      final categories = docs.map((d) => d.documentType).toSet().toList()
        ..sort();
      return 'Detected categories: ${categories.join(', ')}.';
    }

    return 'Local Q&A mode is active. I can answer totals, categories, and basic counts without OpenAI. Configure OPENAI_API_KEY for richer responses.';
  }
}
