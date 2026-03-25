import 'package:flutter/foundation.dart';

class DiagnosticLogEntry {
  final DateTime timestamp;
  final String level;
  final String source;
  final String message;

  const DiagnosticLogEntry({
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
  });
}

class SupportDiagnosticsService extends ChangeNotifier {
  SupportDiagnosticsService._();

  static final SupportDiagnosticsService instance =
      SupportDiagnosticsService._();

  final List<DiagnosticLogEntry> _entries = <DiagnosticLogEntry>[];
  static const int _maxEntries = 120;

  int? _lastAiLatencyMs;
  String _lastAiOperation = 'none';
  bool _lastUsedFallback = false;
  int _aiSuccessCount = 0;
  int _aiFailureCount = 0;

  int? get lastAiLatencyMs => _lastAiLatencyMs;
  String get lastAiOperation => _lastAiOperation;
  bool get lastUsedFallback => _lastUsedFallback;
  int get aiSuccessCount => _aiSuccessCount;
  int get aiFailureCount => _aiFailureCount;

  List<DiagnosticLogEntry> get entriesNewestFirst =>
      List<DiagnosticLogEntry>.unmodifiable(_entries.reversed);

  double get aiSuccessRate {
    final total = _aiSuccessCount + _aiFailureCount;
    if (total == 0) return 0;
    return (_aiSuccessCount / total) * 100;
  }

  void recordAiSuccess({
    required String operation,
    required int latencyMs,
    required bool usedFallback,
    String? note,
  }) {
    _lastAiOperation = operation;
    _lastAiLatencyMs = latencyMs;
    _lastUsedFallback = usedFallback;
    _aiSuccessCount += 1;

    _addEntry(
      level: 'INFO',
      source: 'AI',
      message:
          '${operation} succeeded in ${latencyMs}ms${usedFallback ? ' (fallback)' : ''}${note == null ? '' : ' - $note'}',
    );
    notifyListeners();
  }

  void recordAiFailure({
    required String operation,
    required int latencyMs,
    required String error,
    required bool usedFallback,
  }) {
    _lastAiOperation = operation;
    _lastAiLatencyMs = latencyMs;
    _lastUsedFallback = usedFallback;
    _aiFailureCount += 1;

    _addEntry(
      level: 'ERROR',
      source: 'AI',
      message:
          '${operation} failed in ${latencyMs}ms: $error${usedFallback ? ' (fallback)' : ''}',
    );
    notifyListeners();
  }

  void logInfo({required String source, required String message}) {
    _addEntry(level: 'INFO', source: source, message: message);
    notifyListeners();
  }

  void logError({required String source, required String message}) {
    _addEntry(level: 'ERROR', source: source, message: message);
    notifyListeners();
  }

  void clearLogs() {
    _entries.clear();
    notifyListeners();
  }

  void _addEntry({
    required String level,
    required String source,
    required String message,
  }) {
    _entries.add(
      DiagnosticLogEntry(
        timestamp: DateTime.now(),
        level: level,
        source: source,
        message: message,
      ),
    );
    if (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
  }
}
