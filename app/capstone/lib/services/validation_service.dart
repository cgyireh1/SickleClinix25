import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'dart:math' as math;

class ValidationService {
  // Email validation
  static String? validateEmail(String? email) {
    if (email == null || email.trim().isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email.trim())) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  // Password validation
  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }

    if (password.length < 8) {
      return 'Password must be at least 8 characters long';
    }

    if (password.length > 128) {
      return 'Password is too long (max 128 characters)';
    }

    final weakPasswords = [
      'password',
      '123456',
      'qwerty',
      'admin',
      'user',
      'password123',
      '123456789',
      'abc123',
      'letmein',
    ];
    if (weakPasswords.contains(password.toLowerCase())) {
      return 'Password is too weak. Please choose a stronger password';
    }

    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasLowercase = password.contains(RegExp(r'[a-z]'));
    bool hasDigits = password.contains(RegExp(r'[0-9]'));
    bool hasSpecialCharacters = password.contains(
      RegExp(r'[!@#$%^&*(),.?":{}|<>]'),
    );

    if (!hasUppercase || !hasLowercase || !hasDigits) {
      return 'Password must contain uppercase, lowercase, and numbers';
    }

    return null;
  }

  // Name validation
  static String? validateName(String? name, {String fieldName = 'Name'}) {
    if (name == null || name.trim().isEmpty) {
      return '$fieldName is required';
    }

    if (name.trim().length < 2) {
      return '$fieldName must be at least 2 characters long';
    }

    if (name.trim().length > 50) {
      return '$fieldName is too long (max 50 characters)';
    }

    final nameRegex = RegExp(r"^[a-zA-Z\s\-']+$");
    if (!nameRegex.hasMatch(name.trim())) {
      return '$fieldName contains invalid characters';
    }

    return null;
  }

  // Age validation
  static String? validateAge(String? age) {
    if (age == null || age.trim().isEmpty) {
      return 'Age is required';
    }

    final ageNum = int.tryParse(age.trim());
    if (ageNum == null) {
      return 'Please enter a valid age';
    }

    if (ageNum < 0 || ageNum > 150) {
      return 'Please enter a valid age (0-150)';
    }

    return null;
  }

  // Phone number validation
  static String? validatePhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) {
      return null;
    }

    final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.length < 10 || digitsOnly.length > 15) {
      return 'Please enter a valid phone number';
    }

    return null;
  }

  // Blood type validation
  static String? validateBloodType(String? bloodType) {
    if (bloodType == null || bloodType.trim().isEmpty) {
      return null;
    }

    final validBloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

    if (!validBloodTypes.contains(bloodType.trim().toUpperCase())) {
      return 'Please enter a valid blood type';
    }

    return null;
  }

  // Medical information validation
  static String? validateMedicalInfo(
    String? info, {
    String fieldName = 'Medical information',
  }) {
    if (info == null || info.trim().isEmpty) {
      return null;
    }

    if (info.trim().length > 500) {
      return '$fieldName is too long (max 500 characters)';
    }

    return null;
  }

  // Facility name validation
  static String? validateFacilityName(String? facilityName) {
    if (facilityName == null || facilityName.trim().isEmpty) {
      return 'Facility name is required';
    }

    if (facilityName.trim().length < 2) {
      return 'Facility name must be at least 2 characters long';
    }

    if (facilityName.trim().length > 100) {
      return 'Facility name is too long (max 100 characters)';
    }

    return null;
  }

  // Specialty validation
  static String? validateSpecialty(String? specialty) {
    if (specialty == null || specialty.trim().isEmpty) {
      return null;
    }

    if (specialty.trim().length > 50) {
      return 'Specialty is too long (max 50 characters)';
    }

    return null;
  }

  // Address validation
  static String? validateAddress(String? address) {
    if (address == null || address.trim().isEmpty) {
      return null;
    }

    if (address.trim().length < 5) {
      return 'Address is too short';
    }

    if (address.trim().length > 200) {
      return 'Address is too long (max 200 characters)';
    }

    return null;
  }

  // Occupation validation
  static String? validateOccupation(String? occupation) {
    if (occupation == null || occupation.trim().isEmpty) {
      return null;
    }

    if (occupation.trim().length > 50) {
      return 'Occupation is too long (max 50 characters)';
    }

    return null;
  }

  // Patient ID validation
  static String? validatePatientId(String? id) {
    if (id == null || id.trim().isEmpty) {
      return 'Patient ID is required';
    }

    if (id.trim().length < 3) {
      return 'Patient ID must be at least 3 characters long';
    }

    if (id.trim().length > 20) {
      return 'Patient ID is too long (max 20 characters)';
    }

    final idRegex = RegExp(r'^[a-zA-Z0-9\-]+$');
    if (!idRegex.hasMatch(id.trim())) {
      return 'Patient ID contains invalid characters';
    }

    return null;
  }

  // Form validation helper
  static bool validateForm(GlobalKey<FormState> formKey) {
    if (formKey.currentState == null) {
      return false;
    }

    return formKey.currentState!.validate();
  }

  // Show validation error
  static void showValidationError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Show validation success
  static void showValidationSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Sanitize input
  static String sanitizeInput(String input) {
    return input.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  // Validate image file
  static String? validateImageFile(String? filePath) {
    if (filePath == null || filePath.isEmpty) {
      return 'Please select an image file';
    }

    final file = File(filePath);
    if (!file.existsSync()) {
      return 'Selected file does not exist';
    }

    final extension = filePath.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'bmp'].contains(extension)) {
      return 'Please select a valid image file (JPG, PNG, BMP)';
    }

    return null;
  }

  // Validate blood smear image
  static Future<Map<String, dynamic>> validateBloodSmearImage(
    File imageFile,
  ) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        return {
          'isValid': false,
          'error': 'Failed to decode image',
          'confidence': 0.0,
        };
      }

      // Basic blood smear validation checks
      final validation = await _performBloodSmearValidation(image);

      return {
        'isValid': validation['isValid'],
        'error': validation['error'],
        'confidence': validation['confidence'],
        'suggestions': validation['suggestions'],
      };
    } catch (e) {
      return {
        'isValid': false,
        'error': 'Image validation failed: $e',
        'confidence': 0.0,
      };
    }
  }

  // Perform blood smear validation
  static Future<Map<String, dynamic>> _performBloodSmearValidation(
    img.Image image,
  ) async {
    try {
      // Resize for analysis
      final resized = img.copyResize(image, width: 224, height: 224);

      // Calculate color distribution
      final colorStats = _analyzeColorDistribution(resized);

      // Calculate texture analysis
      final textureStats = _analyzeTexture(resized);

      // Calculate edge density
      final edgeDensity = _calculateEdgeDensity(resized);

      // Blood smear characteristics
      final isBloodSmear = _evaluateBloodSmearCharacteristics(
        colorStats,
        textureStats,
        edgeDensity,
      );

      String? error;
      List<String> suggestions = [];

      if (!isBloodSmear['isValid']) {
        error = isBloodSmear['error'];
        suggestions = isBloodSmear['suggestions'];
      }

      return {
        'isValid': isBloodSmear['isValid'],
        'error': error,
        'confidence': isBloodSmear['confidence'],
        'suggestions': suggestions,
      };
    } catch (e) {
      return {
        'isValid': false,
        'error': 'Validation analysis failed: $e',
        'confidence': 0.0,
        'suggestions': [],
      };
    }
  }

  // Analyze color distribution
  static Map<String, double> _analyzeColorDistribution(img.Image image) {
    int totalPixels = 0;
    int redPixels = 0;
    int pinkPixels = 0;
    int purplePixels = 0;
    int bluePixels = 0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        totalPixels++;

        if (_isReddish(pixel)) redPixels++;
        if (_isPinkish(pixel)) pinkPixels++;
        if (_isPurplish(pixel)) purplePixels++;
        if (_isBluish(pixel)) bluePixels++;
      }
    }

    return {
      'redRatio': redPixels / totalPixels,
      'pinkRatio': pinkPixels / totalPixels,
      'purpleRatio': purplePixels / totalPixels,
      'blueRatio': bluePixels / totalPixels,
    };
  }

  // Analyze texture
  static Map<String, double> _analyzeTexture(img.Image image) {
    double totalGradient = 0;
    int pixelCount = 0;

    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        final center = image.getPixel(x, y);
        final right = image.getPixel(x + 1, y);
        final down = image.getPixel(x, y + 1);

        final dx = _pixelDifference(center, right);
        final dy = _pixelDifference(center, down);
        final gradient = math.sqrt(dx * dx + dy * dy);

        totalGradient += gradient;
        pixelCount++;
      }
    }

    return {
      'averageGradient': totalGradient / pixelCount,
      'textureComplexity': totalGradient / (image.width * image.height),
    };
  }

  // Calculate edge density
  static double _calculateEdgeDensity(img.Image image) {
    int edgePixels = 0;
    int totalPixels = 0;

    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        final center = image.getPixel(x, y);
        final neighbors = [
          image.getPixel(x - 1, y),
          image.getPixel(x + 1, y),
          image.getPixel(x, y - 1),
          image.getPixel(x, y + 1),
        ];

        bool isEdge = false;
        for (final neighbor in neighbors) {
          if (_pixelDifference(center, neighbor) > 30) {
            isEdge = true;
            break;
          }
        }

        if (isEdge) edgePixels++;
        totalPixels++;
      }
    }

    return edgePixels / totalPixels;
  }

  // Evaluate blood smear characteristics
  static Map<String, dynamic> _evaluateBloodSmearCharacteristics(
    Map<String, double> colorStats,
    Map<String, double> textureStats,
    double edgeDensity,
  ) {
    // Blood smear characteristics
    final hasBloodColors =
        colorStats['redRatio']! > 0.1 ||
        colorStats['pinkRatio']! > 0.1 ||
        colorStats['purpleRatio']! > 0.05;

    final hasAppropriateTexture =
        textureStats['averageGradient']! > 10 &&
        textureStats['averageGradient']! < 100;

    final hasReasonableEdges = edgeDensity > 0.05 && edgeDensity < 0.3;

    // Calculate confidence
    double confidence = 0.0;
    if (hasBloodColors) confidence += 0.4;
    if (hasAppropriateTexture) confidence += 0.3;
    if (hasReasonableEdges) confidence += 0.3;

    final isValid = confidence > 0.6;

    String? error;
    List<String> suggestions = [];

    if (!isValid) {
      if (!hasBloodColors) {
        error =
            'Image does not appear to be a blood smear. Blood smears typically have red, pink, or purple colors.';
        suggestions.add(
          'Please ensure you are capturing a blood smear image under a microscope.',
        );
        suggestions.add('Check that the image shows red blood cells clearly.');
      } else if (!hasAppropriateTexture) {
        error = 'Image texture suggests this may not be a blood smear.';
        suggestions.add(
          'Ensure the image is focused and shows cellular details.',
        );
        suggestions.add('Avoid blurry or overexposed images.');
      } else if (!hasReasonableEdges) {
        error = 'Image edge pattern is unusual for a blood smear.';
        suggestions.add(
          'Make sure you are capturing a blood smear, not a person or other object.',
        );
        suggestions.add('Ensure proper microscope focus and lighting.');
      }
    }

    return {
      'isValid': isValid,
      'error': error,
      'confidence': confidence,
      'suggestions': suggestions,
    };
  }

  // Helper methods for color analysis
  static bool _isReddish(img.Color pixel) {
    return pixel.r > pixel.g * 1.5 && pixel.r > pixel.b * 1.5;
  }

  static bool _isPinkish(img.Color pixel) {
    return pixel.r > 150 &&
        pixel.g > 100 &&
        pixel.b > 100 &&
        pixel.r > pixel.g &&
        pixel.r > pixel.b;
  }

  static bool _isPurplish(img.Color pixel) {
    return pixel.r > 100 &&
        pixel.b > 100 &&
        (pixel.r + pixel.b) > pixel.g * 1.5;
  }

  static bool _isBluish(img.Color pixel) {
    return pixel.b > pixel.r * 1.5 && pixel.b > pixel.g * 1.5;
  }

  static double _pixelDifference(img.Color a, img.Color b) {
    return math.sqrt(
      (a.r - b.r) * (a.r - b.r) +
          (a.g - b.g) * (a.g - b.g) +
          (a.b - b.b) * (a.b - b.b),
    );
  }

  // Validate file size
  static String? validateFileSize(int fileSizeBytes, {int maxSizeMB = 10}) {
    final maxSizeBytes = maxSizeMB * 1024 * 1024;

    if (fileSizeBytes > maxSizeBytes) {
      return 'File size must be less than ${maxSizeMB}MB';
    }

    return null;
  }
}
