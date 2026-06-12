// lib/core/security/input_validator.dart
import 'app_security.dart';

/// Input validation with security checks
class InputValidator {
  
  /// Validate and sanitize exercise name
  static ValidationResult validateExerciseName(String name) {
    if (name.isEmpty) {
      return ValidationResult(false, 'Exercise name cannot be empty');
    }
    
    if (name.length < 2) {
      return ValidationResult(false, 'Exercise name too short (min 2 characters)');
    }
    
    if (name.length > 100) {
      return ValidationResult(false, 'Exercise name too long (max 100 characters)');
    }
    
    final sanitized = AppSecurity.sanitizeExerciseName(name);
    if (sanitized != name) {
      return ValidationResult(false, 'Exercise name contains invalid characters');
    }
    
    return ValidationResult(true, 'Valid', sanitized);
  }

  /// Validate weight input
  static ValidationResult validateWeight(String input) {
    if (input.isEmpty) {
      return ValidationResult(true, 'Optional'); // Weight can be empty
    }
    
    if (!AppSecurity.isValidNumber(input, allowDecimal: true)) {
      return ValidationResult(false, 'Weight must be a valid number');
    }
    
    final weight = double.tryParse(input);
    if (!AppSecurity.isValidWeight(weight)) {
      return ValidationResult(false, 'Weight must be between 0.1 and 1000 kg');
    }
    
    return ValidationResult(true, 'Valid', input);
  }

  /// Validate reps input
  static ValidationResult validateReps(String input) {
    if (input.isEmpty) {
      return ValidationResult(true, 'Optional'); // Reps can be empty
    }
    
    if (!AppSecurity.isValidNumber(input, allowDecimal: false)) {
      return ValidationResult(false, 'Reps must be a whole number');
    }
    
    final reps = int.tryParse(input);
    if (!AppSecurity.isValidReps(reps)) {
      return ValidationResult(false, 'Reps must be between 1 and 999');
    }
    
    return ValidationResult(true, 'Valid', input);
  }

  /// Validate notes field
  static ValidationResult validateNotes(String notes) {
    if (notes.length > 500) {
      return ValidationResult(false, 'Notes too long (max 500 characters)');
    }
    
    final sanitized = AppSecurity.sanitizeNotes(notes);
    return ValidationResult(true, 'Valid', sanitized);
  }

  /// Validate routine name
  static ValidationResult validateRoutineName(String name) {
    if (name.isEmpty) {
      return ValidationResult(false, 'Routine name cannot be empty');
    }
    
    if (name.length < 2) {
      return ValidationResult(false, 'Routine name too short (min 2 characters)');
    }
    
    if (name.length > 50) {
      return ValidationResult(false, 'Routine name too long (max 50 characters)');
    }
    
    final sanitized = AppSecurity.sanitizeInput(name);
    if (sanitized != name) {
      return ValidationResult(false, 'Routine name contains invalid characters');
    }
    
    return ValidationResult(true, 'Valid', sanitized);
  }

  /// Validate body weight
  static ValidationResult validateBodyWeight(String input) {
    if (input.isEmpty) {
      return ValidationResult(false, 'Body weight cannot be empty');
    }
    
    if (!AppSecurity.isValidNumber(input, allowDecimal: true)) {
      return ValidationResult(false, 'Body weight must be a valid number');
    }
    
    final weight = double.tryParse(input);
    if (weight == null || weight <= 0 || weight > 500) {
      return ValidationResult(false, 'Body weight must be between 1 and 500 kg');
    }
    
    return ValidationResult(true, 'Valid', input);
  }

  /// Validate body fat percentage
  static ValidationResult validateBodyFat(String input) {
    if (input.isEmpty) {
      return ValidationResult(true, 'Optional'); // Body fat is optional
    }
    
    if (!AppSecurity.isValidNumber(input, allowDecimal: true)) {
      return ValidationResult(false, 'Body fat must be a valid number');
    }
    
    final bodyFat = double.tryParse(input);
    if (bodyFat == null || bodyFat < 0 || bodyFat > 100) {
      return ValidationResult(false, 'Body fat must be between 0 and 100%');
    }
    
    return ValidationResult(true, 'Valid', input);
  }

  /// Validate rest timer duration
  static ValidationResult validateRestDuration(int seconds) {
    if (seconds < 0 || seconds > 600) {
      return ValidationResult(false, 'Rest duration must be between 0 and 600 seconds');
    }
    
    return ValidationResult(true, 'Valid');
  }

  /// Validate set order
  static ValidationResult validateSetOrder(int order) {
    if (order < 0 || order > 100) {
      return ValidationResult(false, 'Invalid set order');
    }
    
    return ValidationResult(true, 'Valid');
  }

  /// Validate workout title
  static ValidationResult validateWorkoutTitle(String title) {
    if (title.isEmpty) {
      return ValidationResult(false, 'Workout title cannot be empty');
    }
    
    if (title.length > 100) {
      return ValidationResult(false, 'Workout title too long (max 100 characters)');
    }
    
    final sanitized = AppSecurity.sanitizeInput(title);
    return ValidationResult(true, 'Valid', sanitized);
  }
}

/// Result of validation
class ValidationResult {
  final bool isValid;
  final String message;
  final String? sanitizedValue;

  ValidationResult(this.isValid, this.message, [this.sanitizedValue]);

  @override
  String toString() => 'ValidationResult(isValid: $isValid, message: $message)';
}
