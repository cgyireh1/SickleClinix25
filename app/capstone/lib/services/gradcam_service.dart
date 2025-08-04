import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

class GradCAMService {
  static const String _baseUrl =
      'https://sickleclinix-gradcam-server.onrender.com/predict';
  static Future<Map<String, dynamic>> generateServerGradCAM(
    File imageFile,
    String prediction,
    double confidence,
  ) async {
    try {
      // Convert image to base64
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      // Prepare request payload
      final payload = {
        'image': base64Image,
        'prediction': prediction,
        'confidence': confidence,
        'model_type': 'sickle_cell_detection',
      };

      // Send request to server
      final response = await http.post(
        Uri.parse('$_baseUrl/gradcam'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer YOUR_API_KEY',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        // Decode base64 heatmap and superimposed image
        final heatmapBytes = base64Decode(result['heatmap']);
        final superimposedBytes = base64Decode(result['superimposed']);

        return {
          'heatmap': img.decodeImage(heatmapBytes),
          'superimposed': img.decodeImage(superimposedBytes),
          'analysis': result['analysis'],
          'success': true,
        };
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> generatePrecomputedGradCAM(
    File imageFile,
    String prediction,
    double confidence,
  ) async {
    try {
      return {
        'success': false,
        'error': 'Precomputed Grad-CAM not implemented yet',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
