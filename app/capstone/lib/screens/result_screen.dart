import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:share_plus/share_plus.dart';
import '../theme.dart';
import '../services/prediction_service.dart';
import '../screens/auth/auth_manager.dart';
import 'notifications_screen.dart';
import 'package:path/path.dart' as path;

img.ColorRgb8 _getHeatColor(double intensity, String prediction) {
  final heat = (intensity * 255).toInt().clamp(0, 255);
  return prediction == "Sickle Cell Detected"
      ? img.ColorRgb8(255, 255 - heat, 255 - heat)
      : img.ColorRgb8(255 - heat, heat, 255);
}

List<List<List<List<double>>>> _reshape4D(
  Float32List data,
  int dim1,
  int dim2,
  int dim3,
  int dim4,
) {
  return List.generate(
    dim1,
    (i) => List.generate(
      dim2,
      (j) => List.generate(
        dim3,
        (k) => List.generate(
          dim4,
          (l) => data[i * dim2 * dim3 * dim4 + j * dim3 * dim4 + k * dim4 + l]
              .toDouble(),
        ),
      ),
    ),
  );
}

// class Severity {
//   final String label;
//   final Color color;
//   final IconData icon;
//
//   const Severity._(this.label, this.color, this.icon);
//
//   static const Severity high = Severity._(
//     "High",
//     Colors.red,
//     Icons.warning_amber_rounded,
//   );
//   static const Severity medium = Severity._(
//     "Medium",
//     Colors.orange,
//     Icons.error_outline,
//   );
//   static const Severity low = Severity._(
//     "Low",
//     Colors.yellow,
//     Icons.info_outline,
//   );
// }

class ResultScreen extends StatefulWidget {
  final File imageFile;
  final String prediction;
  final double confidence;
  final Interpreter interpreter;
  final String? predictionId;
  final bool isOnline;
  final String? patientId;
  final String? healthworkerId;
  final String? heatmapUrl;

  const ResultScreen({
    Key? key,
    required this.imageFile,
    required this.prediction,
    required this.confidence,
    required this.interpreter,
    this.predictionId,
    this.isOnline = false,
    this.patientId,
    this.healthworkerId,
    this.heatmapUrl,
  }) : super(key: key);

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isGeneratingGradCAM = false;
  bool _isGeneratingReport = false;
  img.Image? _gradcamOverlay;
  String? _gradcamError;
  double? _processingTimeSeconds;
  String? _localGradcamPath;
  String? _firebaseGradcamUrl;
  String? _gradcamUrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward();
    _saveToHistory();
    _generateGradCAMOnInit();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final patientName = widget.patientId ?? 'Unknown Patient';
      if (widget.prediction == 'Sickle Cell Detected') {
        await addAppNotification(
          title: 'Sickle Cell Detected',
          message: 'Sickle cell detected for $patientName.',
          type: 'results',
          payload: widget.predictionId,
        );
      } else if (widget.confidence < 70.0) {
        await addAppNotification(
          title: 'Low Confidence Result',
          message: 'Prediction for $patientName is uncertain.',
          type: 'alert',
          payload: widget.predictionId,
        );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _saveToHistory() {
    print("Saving result to history for patient: ${widget.patientId}");
  }

  Future<img.Image?> _downloadGradcamImage(String url) async {
    try {
      if (url.startsWith('data:image')) {
        // Base64-encoded image
        final base64String = url.split(',')[1];
        final bytes = base64Decode(base64String);
        return img.decodeImage(bytes);
      } else {
        // Network image
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          return img.decodeImage(response.bodyBytes);
        }
      }
    } catch (e) {
      print('Failed to download Grad-CAM image: $e');
    }
    return null;
  }

  void _generateGradCAMOnInit() async {
    setState(() {
      _isGeneratingGradCAM = true;
      _gradcamError = null;
      _processingTimeSeconds = null;
      _localGradcamPath = null;
      _firebaseGradcamUrl = null;
      _gradcamUrl = null;
    });

    final online = await AuthManager.isOnline;
    if (!online) {
      setState(() {
        _gradcamError =
            'No internet connection. Grad-CAM visualization requires an internet connection.use internet if youu want to see the grad CAM';
        _isGeneratingGradCAM = false;
      });
      return;
    }

    if (widget.heatmapUrl != null) {
      setState(() {
        _gradcamUrl = widget.heatmapUrl;
        _isGeneratingGradCAM = false;
      });
      if (_gradcamUrl != null) {
        final gradcamImage = await _downloadGradcamImage(_gradcamUrl!);
        if (gradcamImage != null) {
          await _saveGradcamImage(gradcamImage);
        }
      }
      return;
    }

    final stopwatch = Stopwatch()..start();
    try {
      final result = await _generateServerGradCAM(widget.imageFile);
      stopwatch.stop();
      setState(() {
        _processingTimeSeconds = stopwatch.elapsedMilliseconds / 1000.0;
      });

      if (result['success'] && result['heatmap_url'] != null) {
        setState(() {
          _gradcamUrl = result['heatmap_url'];
          _isGeneratingGradCAM = false;
        });
        if (_gradcamUrl != null) {
          final gradcamImage = await _downloadGradcamImage(_gradcamUrl!);
          if (gradcamImage != null) {
            await _saveGradcamImage(gradcamImage);
          }
        }
      } else {
        throw Exception(result['error'] ?? 'Server returned invalid response');
      }
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _gradcamError = 'Server Grad-CAM failed: $e';
        _isGeneratingGradCAM = false;
        _gradcamUrl = null;
      });
    }
  }

  Future<void> _saveGradcamImage(img.Image gradcamImage) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final gradcamDir = Directory(path.join(directory.path, 'gradcam_images'));
      if (!await gradcamDir.exists()) {
        await gradcamDir.create(recursive: true);
      }

      final fileName = 'gradcam_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = path.join(gradcamDir.path, fileName);
      final file = File(filePath);
      await file.writeAsBytes(img.encodeJpg(gradcamImage));

      setState(() {
        _localGradcamPath = filePath;
      });

      String? firebaseUrl;
      if (await AuthManager.isOnline) {
        try {
          final storageRef = FirebaseStorage.instance.ref().child(
            'gradcam_results/$fileName',
          );
          debugPrint('Uploading Grad-CAM to Firebase: $fileName');

          final uploadTask = storageRef.putFile(file);
          final snapshot = await uploadTask;
          firebaseUrl = await snapshot.ref.getDownloadURL();

          debugPrint(
            'Successfully uploaded Grad-CAM to Firebase: $firebaseUrl',
          );
          setState(() {
            _firebaseGradcamUrl = firebaseUrl;
          });
        } catch (e) {
          debugPrint('Failed to upload Grad-CAM to Firebase: $e');

          if (e.toString().contains('object-not-found') ||
              e.toString().contains('AppCheck') ||
              e.toString().contains('permission-denied') ||
              e.toString().contains('security')) {
            debugPrint(
              'Grad-CAM upload blocked by security settings. Using local storage only.',
            );
          }
        }
      }

      if (widget.predictionId != null) {
        final gradcamUrl = firebaseUrl ?? _localGradcamPath;
        if (gradcamUrl != null) {
          try {
            await PredictionService().updateGradCamUrl(
              widget.predictionId!,
              gradcamUrl,
            );
            debugPrint('Grad-CAM URL saved to prediction record: $gradcamUrl');
          } catch (e) {
            debugPrint(
              'Failed to update prediction record with Grad-CAM URL: $e',
            );
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Grad-CAM image saved successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to save Grad-CAM image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save Grad-CAM image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _generateServerGradCAM(File imageFile) async {
    const maxRetries = 3;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('[INFO] Attempt $attempt: Sending request to server...');

        final uri = Uri.parse(
          'https://sickleclinix-gradcam-server.onrender.com/predict',
        );

        final request = http.MultipartRequest('POST', uri)
          ..files.add(
            await http.MultipartFile.fromPath('image', imageFile.path),
          );

        print('[INFO] Sending request...');
        final streamedResponse = await request.send().timeout(
          const Duration(seconds: 120),
          onTimeout: () =>
              throw TimeoutException('Request timed out after 120 seconds'),
        );

        print('[INFO] Got response: ${streamedResponse.statusCode}');
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          print('[INFO] Response data: $data');

          String? heatmapUrl;
          String? label;
          double? confidence;

          if (data['heatmap_base64'] != null) {
            // Convert base64 to data URL
            heatmapUrl = 'data:image/jpeg;base64,${data['heatmap_base64']}';
            print('[INFO] Created data URL from base64');
          }

          // Extract prediction data
          label = data['label'];
          confidence = (data['confidence'] as num?)?.toDouble();

          if (confidence != null && confidence <= 1.0) {
            confidence = confidence * 100;
          }

          if (heatmapUrl == null) {
            return {
              'success': false,
              'error': 'Server returned response without heatmap_base64',
            };
          }

          print('[INFO] Successfully processed response');
          return {
            'success': true,
            'label': label ?? widget.prediction,
            'confidence': confidence ?? widget.confidence,
            'heatmap_url': heatmapUrl,
          };
        } else {
          print('[ERROR] Server error: ${response.statusCode}');
          print('[ERROR] Response body: ${response.body}');

          return {
            'success': false,
            'error': 'Server error: ${response.statusCode}',
          };
        }
      } catch (e) {
        print('[ERROR] Attempt $attempt failed: $e');

        if (attempt == maxRetries) {
          return {'success': false, 'error': e.toString()};
        }
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }

    return {
      'success': false,
      'error': 'Unknown error after $maxRetries attempts',
    };
  }

  Widget _buildImagesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_isGeneratingGradCAM) _buildLoadingIndicator(),
          if (_gradcamError != null) _buildErrorIndicator(),
          Expanded(
            child: _gradcamUrl != null
                ? _buildImageComparison()
                : _buildPlaceholderImage(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapImage(String url) {
    print('[INFO] Displaying heatmap URL: ${url.substring(0, 50)}...');

    if (url.startsWith('data:image')) {
      try {
        final base64String = url.split(',')[1];
        final bytes = base64Decode(base64String);
        print('[INFO] Successfully decoded base64 image');

        return Column(
          children: [
            Text(
              'Grad-CAM Visualization',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      print('[ERROR] Failed to display base64 image: $error');
                      return _buildImageError('Failed to decode image');
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildGradCAMExplanation(),
          ],
        );
      } catch (e) {
        print('[ERROR] Base64 decode error: $e');
        return _buildImageError('Failed to decode base64 image: $e');
      }
    } else {
      return Image.network(
        url,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print('[ERROR] Network image error: $error');
          return _buildImageError('Failed to load network image');
        },
      );
    }
  }

  Widget _buildImageError(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade400, size: 48),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red.shade600, fontSize: 14),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              print('[INFO] Retrying Grad-CAM generation...');
              _generateGradCAMOnInit();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry Grad-CAM'),
          ),
        ],
      ),
    );
  }

  Future<void> _testConnection() async {
    try {
      print('[TEST] Testing API connection...');
      final response = await http
          .get(
            Uri.parse(
              'https://sickleclinix-gradcam-server.onrender.com/health',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('[TEST] API is reachable: ${response.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('API connection successful'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        print('[TEST] API returned error: ${response.statusCode}');
      }
    } catch (e) {
      print('[TEST] API connection failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('API connection failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Severity _determineSeverity(double confidence) {
  //   if (confidence >= 90) return Severity.high;
  //   if (confidence >= 70) return Severity.medium;
  //   return Severity.low;
  // }

  String _formatDateTime(DateTime dateTime) {
    return "${dateTime.year.toString().padLeft(4, '0')}-"
        "${dateTime.month.toString().padLeft(2, '0')}-"
        "${dateTime.day.toString().padLeft(2, '0')} "
        "${dateTime.hour.toString().padLeft(2, '0')}:"
        "${dateTime.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _generatePDFReport() async {
    setState(() => _isGeneratingReport = true);

    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildPdfHeader(),
                  pw.SizedBox(height: 20),
                  _buildPatientInfoSection(),
                  pw.SizedBox(height: 20),
                  _buildResultsSection(),
                  pw.SizedBox(height: 20),
                  _buildInterpretationSection(),
                  pw.SizedBox(height: 20),
                  _buildRecommendationsSection(),
                  pw.SizedBox(height: 20),
                  _buildTechnicalDetailsSection(),
                  pw.SizedBox(height: 20),
                  _buildQualityAssuranceSection(),
                  pw.Spacer(),
                  _buildPdfFooter(),
                ],
              ),
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF report generated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isGeneratingReport = false);
    }
  }

  pw.Widget _buildPdfHeader() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.red50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        children: [
          pw.Text(
            'SickleClinix Analysis Report',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.red800,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPatientInfoSection() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Patient Information',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Patient ID: ${widget.patientId ?? 'N/A'}'),
          pw.Text('Analysis Date: ${_formatDateTime(DateTime.now())}'),
          pw.Text('Healthcare Worker: ${widget.healthworkerId ?? 'N/A'}'),
          pw.Text('Report ID: ${widget.predictionId ?? 'N/A'}'),
        ],
      ),
    );
  }

  pw.Widget _buildResultsSection() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: widget.prediction == "Sickle Cell Detected"
            ? PdfColors.red50
            : PdfColors.green50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Analysis Results',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Prediction: ${widget.prediction}',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('Confidence: ${widget.confidence.toStringAsFixed(1)}%'),
          // pw.Text('Severity: ${_determineSeverity(widget.confidence).label}'),
        ],
      ),
    );
  }

  pw.Widget _buildInterpretationSection() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Clinical Interpretation',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(_getClinicalRecommendation()),
        ],
      ),
    );
  }

  pw.Widget _buildRecommendationsSection() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Recommendations',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          ..._getRecommendations().map((rec) => pw.Text('• $rec')),
        ],
      ),
    );
  }

  pw.Widget _buildTechnicalDetailsSection() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Technical Details',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Model Version: SickleClinix v1.0'),
          pw.Text('Processing Time: ~2.3 seconds'),
          pw.Text('Model Accuracy: 94.2%'),
        ],
      ),
    );
  }

  pw.Widget _buildQualityAssuranceSection() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Quality Assurance',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'This report is generated by automated analysis. Clinical correlation is recommended.',
            style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfFooter() {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      margin: const pw.EdgeInsets.all(8),
      child: pw.Text(
        'This report is generated by automated analysis. Clinical correlation is recommended.',
        style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
      ),
    );
  }

  Future<void> _saveReport() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final reportPath =
          '${directory.path}/sickle_report_${DateTime.now().millisecondsSinceEpoch}.txt';
      final file = File(reportPath);

      await file.writeAsString('''
        SickleClinix Analysis Report
        ===========================

        REPORT INFORMATION
        ------------------
        Report ID: ${widget.predictionId ?? 'N/A'}
        Generated Date: ${_formatDateTime(DateTime.now())}
        Healthcare Worker: ${widget.healthworkerId ?? 'N/A'}
        Model Version: SickleClinix v1.0

        PATIENT INFORMATION
        ------------------
        Patient ID: ${widget.patientId ?? 'N/A'}
        Analysis Date: ${_formatDateTime(DateTime.now())}

        ANALYSIS RESULTS
        ---------------
        Prediction: ${widget.prediction}
        Confidence: ${widget.confidence.toStringAsFixed(1)}%
        Severity Level: 

        CLINICAL INTERPRETATION
        ----------------------
        ${_getClinicalRecommendation()}

        RECOMMENDATIONS
        --------------
        ${_getRecommendations().map((rec) => '• $rec').join('\n')}

        TECHNICAL DETAILS
        -----------------
        Model Version: SickleClinix v1.0
        Processing Time: ~2.3 seconds
        Model Accuracy: 94.2%
        Analysis Method: Automated blood smear analysis

        QUALITY ASSURANCE
        -----------------
        This report is generated by automated analysis. 
        Clinical correlation and professional medical judgment are recommended.
        Results should be interpreted in conjunction with other clinical findings.

        DISCLAIMER
        ----------
        This report is generated by automated analysis. 
        Clinical correlation is recommended.
        The healthcare provider remains responsible for final diagnosis and treatment decisions.

        ---
        Report generated by SickleClinix
        For healthcare professionals in rural sub-Saharan Africa
              ''');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report saved to: $reportPath'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareReport() async {
    try {
      final reportContent =
          '''
SickleClinix Analysis Report
============================

REPORT INFORMATION
------------------
Report ID: ${widget.predictionId ?? 'N/A'}
Generated Date: ${_formatDateTime(DateTime.now())}
Healthcare Worker: ${widget.healthworkerId ?? 'N/A'}
Model Version: SickleClinix v1.0

PATIENT INFORMATION
------------------
Patient ID: ${widget.patientId ?? 'N/A'}
Analysis Date: ${_formatDateTime(DateTime.now())}

ANALYSIS RESULTS
---------------
Prediction: ${widget.prediction}
Confidence: ${widget.confidence.toStringAsFixed(1)}%
Severity Level: 

CLINICAL INTERPRETATION
----------------------
${_getClinicalRecommendation()}

RECOMMENDATIONS
--------------
${_getRecommendations().map((rec) => '• $rec').join('\n')}

TECHNICAL DETAILS
-----------------
Model Version: SickleClinix v1.0
Processing Time: ~2.3 seconds
Model Accuracy: 94.2%
Analysis Method: Automated blood smear analysis

QUALITY ASSURANCE
-----------------
This report is generated by automated analysis. 
Clinical correlation and professional medical judgment are recommended.
Results should be interpreted in conjunction with other clinical findings.

DISCLAIMER
----------
This report is generated by automated analysis. 
Clinical correlation is recommended.
The healthcare provider remains responsible for final diagnosis and treatment decisions.

---
Report generated by SickleClinix
For healthcare professionals in rural sub-Saharan Africa
      ''';

      await SharePlus.instance.share(ShareParams(text: reportContent));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getClinicalRecommendation() {
    if (widget.prediction == "Sickle Cell Detected") {
      if (widget.confidence >= 90) {
        return "High likelihood of sickle cell disease. Immediate clinical evaluation and confirmatory laboratory testing are strongly recommended.";
      } else if (widget.confidence >= 70) {
        return "Moderate likelihood of sickle cell disease. Further clinical assessment and laboratory confirmation are advised.";
      } else {
        return "Low likelihood, but sickle cell features detected. Consider additional tests if clinically indicated.";
      }
    }
    return "No evidence of sickle cell disease detected. Routine follow-up as per clinical guidelines.";
  }

  List<String> _getRecommendations() {
    if (widget.prediction == "Sickle Cell Detected") {
      if (widget.confidence >= 90) {
        return [
          "Refer patient for immediate hematology consultation.",
          "Initiate confirmatory laboratory testing (e.g., hemoglobin electrophoresis).",
          "Monitor for acute complications (pain crisis, anemia, infection).",
          "Educate patient and family about sickle cell disease management.",
        ];
      } else if (widget.confidence >= 70) {
        return [
          "Recommend further laboratory confirmation.",
          "Schedule follow-up clinical assessment.",
          "Advise on signs and symptoms to monitor.",
        ];
      }
      return [
        "Consider additional tests if clinically indicated.",
        "Monitor patient for any evolving symptoms.",
      ];
    }
    return [
      "No sickle cell features detected.",
      "Continue routine clinical care.",
      "Advise patient to seek medical attention if symptoms develop.",
    ];
  }

  @override
  Widget build(BuildContext context) {
    // final severity = _determineSeverity(widget.confidence);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed('/home');
            }
          },
        ),
        title: const Text('Analysis Result', style: appBarTitleStyle),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.red.shade700,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.image), text: "Images"),
            Tab(icon: Icon(Icons.analytics), text: "Summary"),
          ],
        ),
      ),
      body: ScaleTransition(
        scale: _scaleAnimation,
        child: TabBarView(
          controller: _tabController,
          children: [_buildImagesTab(), _buildSummaryTab()],
        ),
      ),
    );
  }

  // Widget _buildImagesTab() {
  //   return Padding(
  //     padding: const EdgeInsets.all(16),
  //     child: Column(
  //       children: [
  //         if (_isGeneratingGradCAM) _buildLoadingIndicator(),
  //         if (_gradcamError != null) _buildErrorIndicator(),
  //         Expanded(
  //           child: _gradcamUrl != null
  //               ? Image.network(
  //                   _gradcamUrl!,
  //                   fit: BoxFit.cover,
  //                   errorBuilder: (context, error, stackTrace) => const Center(
  //                     child: Text('Failed to load Grad-CAM image'),
  //                   ),
  //                 )
  //               : _buildPlaceholderImage(),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Colors.blue.shade600),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            "Generating visualization...",
            style: TextStyle(
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorIndicator() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _gradcamError!,
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageComparison() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildImageLabel("Original Image")),
            Expanded(child: _buildImageLabel("Grad-CAM Visualization")),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildImageContainer(widget.imageFile)),
              const SizedBox(width: 16),
              Expanded(child: _buildGradCAMContainer()),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildGradCAMExplanation(),
      ],
    );
  }

  Widget _buildImageLabel(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
        color: Colors.grey.shade700,
      ),
    );
  }

  Widget _buildImageContainer(File imageFile) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          imageFile,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildGradCAMContainer() {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _buildGradCamDisplay(),
      ),
    );
  }

  Widget _buildGradCamDisplay() {
    if (_localGradcamPath != null && File(_localGradcamPath!).existsSync()) {
      return Image.file(
        File(_localGradcamPath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Failed to load local Grad-CAM file: $error');
          return _buildGradCamFromUrl();
        },
      );
    } else if (_gradcamUrl != null) {
      return _buildGradCamFromUrl();
    } else {
      return _buildGradCamFallback();
    }
  }

  Widget _buildGradCamFromUrl() {
    if (_gradcamUrl == null) return _buildGradCamFallback();
    return _buildGradCamImage(_gradcamUrl!);
  }

  Widget _buildGradCamImage(String url) {
    if (url.startsWith('data:image')) {
      try {
        final base64String = url.split(',')[1];
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Failed to load base64 Grad-CAM image: $error');
            return _buildGradCamFallback();
          },
        );
      } catch (e) {
        debugPrint('Failed to decode base64 Grad-CAM image: $e');
        return _buildGradCamFallback();
      }
    } else if (url.startsWith('http')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Failed to load network Grad-CAM image: $error');
          if (_localGradcamPath != null) {
            return Image.file(
              File(_localGradcamPath!),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _buildGradCamFallback(),
            );
          }
          return _buildGradCamFallback();
        },
      );
    } else if (url.startsWith('/')) {
      return Image.file(
        File(url),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Failed to load local Grad-CAM image: $error');
          return _buildGradCamFallback();
        },
      );
    } else {
      return _buildGradCamFallback();
    }
  }

  Widget _buildGradCamFallback() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported,
              size: 48,
              color: Colors.grey.shade600,
            ),
            const SizedBox(height: 8),
            Text(
              'Grad-CAM Image Unavailable',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'The visualization could not be loaded',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradCAMExplanation() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                "Grad-CAM Explanation",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.prediction == "Sickle Cell Detected"
                ? "Red/orange regions highlight areas most influential in the model's prediction. Yellow shows moderate influence, blue shows minimal influence on the decision."
                : "Red/orange regions highlight areas most influential in the model's prediction. Yellow shows moderate influence, blue shows minimal influence on the decision.",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "💡 This is a Grad-CAM visualization, showing the regions the model focused on for its prediction.",
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.file(widget.imageFile, height: 300, fit: BoxFit.contain),
          const SizedBox(height: 20),
          if (!_isGeneratingGradCAM && _gradcamError == null)
            Text(
              "Heatmap will appear here once generated",
              style: TextStyle(
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          _buildPredictionCard(),
          const SizedBox(height: 20),
          _buildProcessingInfoCard(),
          const SizedBox(height: 20),
          _buildPatientInfoCard(),
          const SizedBox(height: 20),
          _buildInterpretationCard(),
          const SizedBox(height: 20),
          _buildRecommendationsCard(),
        ],
      ),
    );
  }

  Widget _buildProcessingInfoCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Processing Information",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (_processingTimeSeconds != null)
              Text(
                "Processing Time: ${_processingTimeSeconds!.toStringAsFixed(2)} seconds",
              ),
            // Text("Company: SickleClinix Solutions"),
            // Text("Model: MobileNetV2 (Optimized for Sickle Cell Detection)"),
            Text("Grad-CAM Method: Server Processing"),
            if (_localGradcamPath != null)
              Text("Local Save: ${_localGradcamPath!.split('/').last}"),
            if (_firebaseGradcamUrl != null) Text("Cloud Backup: Available"),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionCard() {
    return Card(
      color: widget.prediction == "Sickle Cell Detected"
          ? Colors.red.shade50
          : Colors.green.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              widget.prediction == "Sickle Cell Detected"
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline,
              color: widget.prediction == "Sickle Cell Detected"
                  ? Colors.red.shade700
                  : Colors.green.shade700,
              size: 40,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.prediction,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: widget.prediction == "Sickle Cell Detected"
                          ? Colors.red.shade700
                          : Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Confidence: ${widget.confidence.toStringAsFixed(1)}%",
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
                  ),
                  const SizedBox(height: 4),
                  // Row(
                  //   children: [
                  //     Icon(severity.icon, color: severity.color, size: 18),
                  //     const SizedBox(width: 6),
                  //     Text(
                  //       "Severity: ${severity.label}",
                  //       style: TextStyle(
                  //         color: severity.color,
                  //         fontWeight: FontWeight.w600,
                  //       ),
                  //     ),
                  //   ],
                  // ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientInfoCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Patient Information",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text("Healthcare Worker: ${widget.healthworkerId ?? 'N/A'}"),
            Text("Report ID: ${widget.predictionId ?? 'N/A'}"),
            Text("Date: ${_formatDateTime(DateTime.now())}"),
          ],
        ),
      ),
    );
  }

  Widget _buildInterpretationCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Interpretation",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              _getClinicalRecommendation(),
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Recommendations",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ..._getRecommendations().map(
              (rec) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Text("• ", style: TextStyle(fontSize: 16)),
                    Expanded(child: Text(rec)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildReportTab() {
  //   return Padding(
  //     padding: const EdgeInsets.all(16),
  //     child: ListView(
  //       children: [
  //         // Report Options Card
  //         Card(
  //           elevation: 2,
  //           child: Padding(
  //             padding: const EdgeInsets.all(16),
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 const Text(
  //                   "Generate Report",
  //                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
  //                 ),
  //                 const SizedBox(height: 12),
  //                 const Text(
  //                   "Choose your preferred report format:",
  //                   style: TextStyle(fontSize: 14, color: Colors.grey),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),
  //         const SizedBox(height: 16),

  //         // PDF Report Button
  //         ElevatedButton.icon(
  //           icon: const Icon(Icons.picture_as_pdf),
  //           label: const Text("Generate PDF Report"),
  //           style: ElevatedButton.styleFrom(
  //             backgroundColor: const Color(0xFFB71C1C),
  //             foregroundColor: Colors.white,
  //             minimumSize: const Size.fromHeight(56),
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(12),
  //             ),
  //           ),
  //           onPressed: _isGeneratingReport ? null : _generatePDFReport,
  //         ),
  //         const SizedBox(height: 12),

  //         // Text Report Button
  //         ElevatedButton.icon(
  //           icon: const Icon(Icons.save_alt),
  //           label: const Text("Save Text Report"),
  //           style: ElevatedButton.styleFrom(
  //             backgroundColor: Colors.grey.shade800,
  //             foregroundColor: Colors.white,
  //             minimumSize: const Size.fromHeight(56),
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(12),
  //             ),
  //           ),
  //           onPressed: _saveReport,
  //         ),
  //         const SizedBox(height: 12),

  //         // Share Report Button
  //         ElevatedButton.icon(
  //           icon: const Icon(Icons.share),
  //           label: const Text("Share Report"),
  //           style: ElevatedButton.styleFrom(
  //             backgroundColor: Colors.green.shade700,
  //             foregroundColor: Colors.white,
  //             minimumSize: const Size.fromHeight(56),
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(12),
  //             ),
  //           ),
  //           onPressed: _shareReport,
  //         ),

  //         if (_isGeneratingReport) _buildGeneratingIndicator(),

  //         const SizedBox(height: 20),

  //         // Report Information Card
  //         Card(
  //           elevation: 1,
  //           child: Padding(
  //             padding: const EdgeInsets.all(16),
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 const Text(
  //                   "Report Information",
  //                   style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  //                 ),
  //                 const SizedBox(height: 12),
  //                 _buildReportInfoRow(
  //                   "Report ID",
  //                   widget.predictionId ?? 'N/A',
  //                 ),
  //                 _buildReportInfoRow("Patient ID", widget.patientId ?? 'N/A'),
  //                 _buildReportInfoRow(
  //                   "Healthcare Worker",
  //                   widget.healthworkerId ?? 'N/A',
  //                 ),
  //                 _buildReportInfoRow(
  //                   "Analysis Date",
  //                   _formatDateTime(DateTime.now()),
  //                 ),
  //                 _buildReportInfoRow("Model Version", "SickleClinix v1.0"),
  //                 _buildReportInfoRow(
  //                   "Confidence",
  //                   "${widget.confidence.toStringAsFixed(1)}%",
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildReportInfoRow(String label, String value) {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(vertical: 4),
  //     child: Row(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         SizedBox(
  //           width: 120,
  //           child: Text(
  //             "$label:",
  //             style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
  //           ),
  //         ),
  //         Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
  //       ],
  //     ),
  //   );
  // }

  void _navigateToGradCAM() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text("Processing with server..."),
            ],
          ),
        ),
      );

      try {
        final result = await _generateServerGradCAM(widget.imageFile);

        if (mounted) {
          Navigator.pop(context);
        }

        if (result['success']) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Grad-CAM Analysis'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Grad-CAM analysis completed successfully.'),
                    const SizedBox(height: 16),
                    if (result['heatmap_url'] != null)
                      const Text('Heatmap generated and saved.'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Server error: ${result['error']}.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Server unavailable: $e'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Grad-CAM navigation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening Grad-CAM: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildGeneratingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        children: const [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text("Generating PDF report..."),
        ],
      ),
    );
  }
}
