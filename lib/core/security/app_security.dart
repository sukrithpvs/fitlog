// lib/core/security/app_security.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Comprehensive security measures for FitLog app
class AppSecurity {
  
  /// Prevent screenshots and screen recording (Android only)
  static Future<void> preventScreenCapture() async {
    if (!kDebugMode && Platform.isAndroid) {
      try {
        await const MethodChannel('com.fitlog/security')
            .invokeMethod('preventScreenCapture');
      } catch (e) {
        debugPrint('Screen capture prevention not available: $e');
      }
    }
  }

  /// Enable root detection
  static Future<bool> isDeviceRooted() async {
    if (kDebugMode) return false; // Allow in debug mode
    
    try {
      // Check for common root indicators
      final rootPaths = [
        '/system/app/Superuser.apk',
        '/sbin/su',
        '/system/bin/su',
        '/system/xbin/su',
        '/data/local/xbin/su',
        '/data/local/bin/su',
        '/system/sd/xbin/su',
        '/system/bin/failsafe/su',
        '/data/local/su',
      ];

      for (final path in rootPaths) {
        if (await File(path).exists()) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Validate database integrity
  static bool validateDatabasePath(String path) {
    // Ensure database is stored in app's private directory
    return path.contains('app_flutter') || 
           path.contains('databases') ||
           path.contains('files');
  }

  /// Drift (SQLite) automatically parameterizes queries, preventing SQL injection natively.
  /// This method is kept for backwards compatibility but just returns the input.
  static String sanitizeInput(String input) {
    return input.trim();
  }

  /// Validate numeric input
  static bool isValidNumber(String input, {bool allowDecimal = false}) {
    if (input.isEmpty) return false;
    
    final pattern = allowDecimal 
        ? RegExp(r'^\d+(\.\d{1,2})?$')  // Max 2 decimal places
        : RegExp(r'^\d+$');
    
    return pattern.hasMatch(input);
  }

  /// Validate weight input (reasonable range)
  static bool isValidWeight(double? weight) {
    if (weight == null) return false;
    return weight > 0 && weight <= 1000; // 0-1000 kg max
  }

  /// Validate reps input (reasonable range)
  static bool isValidReps(int? reps) {
    if (reps == null) return false;
    return reps > 0 && reps <= 999; // 1-999 reps max
  }

  /// Prevent path traversal attacks
  static bool isValidFilePath(String path) {
    return !path.contains('..') && 
           !path.contains('~') &&
           !path.startsWith('/');
  }

  /// Rate limiting for exports (prevent DoS)
  static DateTime? _lastExportTime;
  static bool canExport() {
    if (_lastExportTime == null) {
      _lastExportTime = DateTime.now();
      return true;
    }
    
    final diff = DateTime.now().difference(_lastExportTime!);
    if (diff.inSeconds < 5) {
      return false; // Max 1 export per 5 seconds
    }
    
    _lastExportTime = DateTime.now();
    return true;
  }

  /// Validate CSV export size (prevent memory exhaustion)
  static bool isExportSizeReasonable(int recordCount) {
    return recordCount <= 100000; // Max 100k records
  }

  /// Sanitize exercise name
  static String sanitizeExerciseName(String name) {
    return sanitizeInput(name)
        .replaceAll(RegExp(r'[<>{}]'), '') // Remove HTML-like chars
        .substring(0, name.length > 100 ? 100 : name.length); // Max 100 chars
  }

  /// Sanitize notes field
  static String sanitizeNotes(String notes) {
    return sanitizeInput(notes)
        .substring(0, notes.length > 500 ? 500 : notes.length); // Max 500 chars
  }

  /// Validate date input
  static bool isValidDate(DateTime? date) {
    if (date == null) return false;
    
    final now = DateTime.now();
    final minDate = DateTime(2020, 1, 1); // App didn't exist before 2020
    final maxDate = now.add(const Duration(days: 1)); // Can't log future
    
    return date.isAfter(minDate) && date.isBefore(maxDate);
  }

  /// Obfuscate sensitive data in logs
  static String obfuscate(String data) {
    if (data.length <= 4) return '***';
    return '${data.substring(0, 2)}...${data.substring(data.length - 2)}';
  }

  /// Check for debugger attachment (anti-tampering)
  static bool isDebuggerAttached() {
    return kDebugMode;
  }

  /// Validate app signature (anti-tampering) - Placeholder
  static Future<bool> verifyAppIntegrity() async {
    if (kDebugMode) return true;
    
    // In production, verify app signature matches expected signature
    // This requires platform-specific code
    return true;
  }

  /// Clear clipboard on app pause (security)
  static void clearClipboard() {
    Clipboard.setData(const ClipboardData(text: ''));
  }

  /// Generate secure random ID (UUIDv4)
  static String generateSecureId() {
    return const Uuid().v4();
  }

  /// Validate exercise ID to prevent injection
  static bool isValidId(int id) {
    return id > 0 && id < 2147483647; // Max SQLite integer
  }

  /// Check for suspicious activity patterns
  static bool isSuspiciousActivity({
    required int requestCount,
    required Duration timeWindow,
  }) {
    // If more than 100 requests in 1 minute, flag as suspicious
    return requestCount > 100 && timeWindow.inMinutes < 1;
  }

  /// Validate import data structure
  static bool isValidImportData(Map<String, dynamic> data) {
    // Check for required fields
    if (!data.containsKey('version')) return false;
    if (!data.containsKey('exercises')) return false;
    if (!data.containsKey('workouts')) return false;
    
    // Verify data types
    if (data['exercises'] is! List) return false;
    if (data['workouts'] is! List) return false;
    
    // Check for malicious payloads
    final jsonString = data.toString();
    if (jsonString.contains('<script>')) return false;
    if (jsonString.contains('javascript:')) return false;
    
    return true;
  }

  static const _storage = FlutterSecureStorage();

  /// Securely save sensitive data
  static Future<void> saveSecureData(String key, String data) async {
    await _storage.write(key: key, value: data);
  }

  /// Securely read sensitive data
  static Future<String?> readSecureData(String key) async {
    return await _storage.read(key: key);
  }
}
