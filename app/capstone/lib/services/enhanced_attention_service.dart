import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class EnhancedAttentionService {
  static Future<Map<String, dynamic>> generateEnhancedAttention(
    File imageFile,
    Interpreter interpreter,
    String prediction,
    double confidence,
  ) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final originalImage = img.decodeImage(imageBytes)!;
      final resizedImage = img.copyResize(
        originalImage,
        width: 224,
        height: 224,
      );
      final saliencyMap = _generateSaliencyMap(resizedImage);
      final edgeAttention = _generateEdgeAttention(resizedImage);
      final textureAttention = _generateTextureAttention(resizedImage);
      final colorAttention = _generateColorAttention(resizedImage);

      final combinedAttention = _combineAttentionMaps(
        saliencyMap,
        edgeAttention,
        textureAttention,
        colorAttention,
        prediction,
        confidence,
      );

      // Generate heatmap
      final heatmap = _createHeatmap(combinedAttention, prediction);
      final superimposed = _createSuperimposedImage(resizedImage, heatmap);

      // Generate analysis
      final analysis = _generateAnalysis(
        combinedAttention,
        confidence,
        prediction,
      );

      return {
        'heatmap': heatmap,
        'superimposed': superimposed,
        'analysis': analysis,
        'success': true,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static List<List<double>> _generateSaliencyMap(img.Image image) {
    final saliencyMap = List.generate(224, (y) => List.filled(224, 0.0));

    // Convert to grayscale
    final grayscale = img.grayscale(image);

    // Multi-scale analysis
    final scales = [1, 2, 4, 8];
    final intensityMaps = <List<List<double>>>[];
    final orientationMaps = <List<List<double>>>[];

    for (final scale in scales) {
      final scaledImage = img.copyResize(
        grayscale,
        width: 224 ~/ scale,
        height: 224 ~/ scale,
      );

      // Intensity map
      final intensityMap = List.generate(
        224 ~/ scale,
        (y) => List.generate(224 ~/ scale, (x) {
          final pixel = scaledImage.getPixel(x, y);
          return pixel.r / 255.0;
        }),
      );
      intensityMaps.add(intensityMap);

      final orientationMap = List.generate(
        224 ~/ scale,
        (y) => List.generate(224 ~/ scale, (x) {
          // Simple edge orientation
          if (x > 0 &&
              y > 0 &&
              x < (224 ~/ scale) - 1 &&
              y < (224 ~/ scale) - 1) {
            final dx = intensityMap[y][x + 1] - intensityMap[y][x - 1];
            final dy = intensityMap[y + 1][x] - intensityMap[y - 1][x];
            return math.atan2(dy, dx).abs() / math.pi;
          }
          return 0.0;
        }),
      );
      orientationMaps.add(orientationMap);
    }

    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        double saliency = 0.0;

        for (int i = 0; i < scales.length; i++) {
          final scaleX = (x * scales[i] / 224).floor();
          final scaleY = (y * scales[i] / 224).floor();

          if (scaleX < intensityMaps[i].length &&
              scaleY < intensityMaps[i][0].length) {
            saliency += intensityMaps[i][scaleY][scaleX] * 0.5;
            saliency += orientationMaps[i][scaleY][scaleX] * 0.5;
          }
        }

        saliencyMap[y][x] = saliency / scales.length;
      }
    }

    return saliencyMap;
  }

  static List<List<double>> _generateEdgeAttention(img.Image image) {
    final edgeMap = List.generate(224, (y) => List.filled(224, 0.0));

    final edges = img.sobel(image);

    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final pixel = edges.getPixel(x, y);
        edgeMap[y][x] = (pixel.r + pixel.g + pixel.b) / (3.0 * 255.0);
      }
    }

    return edgeMap;
  }

  static List<List<double>> _generateTextureAttention(img.Image image) {
    final textureMap = List.generate(224, (y) => List.filled(224, 0.0));

    for (int y = 1; y < 223; y++) {
      for (int x = 1; x < 223; x++) {
        final centerPixel = image.getPixel(x, y);
        final centerIntensity =
            (centerPixel.r + centerPixel.g + centerPixel.b) / 3.0;

        double lbp = 0.0;
        int bit = 0;

        final neighbors = [
          image.getPixel(x - 1, y - 1),
          image.getPixel(x, y - 1),
          image.getPixel(x + 1, y - 1),
          image.getPixel(x + 1, y),
          image.getPixel(x + 1, y + 1),
          image.getPixel(x, y + 1),
          image.getPixel(x - 1, y + 1),
          image.getPixel(x - 1, y),
        ];

        for (final neighbor in neighbors) {
          final neighborIntensity =
              (neighbor.r + neighbor.g + neighbor.b) / 3.0;
          if (neighborIntensity > centerIntensity) {
            lbp += math.pow(2, bit);
          }
          bit++;
        }

        textureMap[y][x] = lbp / 255.0;
      }
    }

    return textureMap;
  }

  static List<List<double>> _generateColorAttention(img.Image image) {
    final colorMap = List.generate(224, (y) => List.filled(224, 0.0));

    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final pixel = image.getPixel(x, y);
        double colorVariance = 0.0;
        final colors = <int>[];

        for (int dy = -2; dy <= 2; dy++) {
          for (int dx = -2; dx <= 2; dx++) {
            final nx = (x + dx).clamp(0, 223);
            final ny = (y + dy).clamp(0, 223);
            final neighborPixel = image.getPixel(nx, ny);
            colors.add(
              (neighborPixel.r + neighborPixel.g + neighborPixel.b) ~/ 3,
            );
          }
        }

        // Calculate variance
        final mean = colors.reduce((a, b) => a + b) / colors.length;
        colorVariance =
            colors.map((c) => math.pow(c - mean, 2)).reduce((a, b) => a + b) /
            colors.length;

        colorMap[y][x] = colorVariance / 10000.0; // Normalize
      }
    }

    return colorMap;
  }

  static List<List<double>> _combineAttentionMaps(
    List<List<double>> saliencyMap,
    List<List<double>> edgeAttention,
    List<List<double>> textureAttention,
    List<List<double>> colorAttention,
    String prediction,
    double confidence,
  ) {
    final combined = List.generate(224, (y) => List.filled(224, 0.0));

    double saliencyWeight, edgeWeight, textureWeight, colorWeight;

    if (prediction == "Sickle Cell Detected") {
      saliencyWeight = 0.2;
      edgeWeight = 0.3;
      textureWeight = 0.3;
      colorWeight = 0.2;
    } else {
      saliencyWeight = 0.4;
      edgeWeight = 0.3;
      textureWeight = 0.2;
      colorWeight = 0.1;
    }

    final confidenceFactor = confidence / 100.0;
    saliencyWeight *= confidenceFactor;
    edgeWeight *= confidenceFactor;
    textureWeight *= confidenceFactor;
    colorWeight *= confidenceFactor;

    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        combined[y][x] =
            saliencyMap[y][x] * saliencyWeight +
            edgeAttention[y][x] * edgeWeight +
            textureAttention[y][x] * textureWeight +
            colorAttention[y][x] * colorWeight;
      }
    }

    // Normalize
    double maxVal = 0.0;
    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        if (combined[y][x] > maxVal) maxVal = combined[y][x];
      }
    }

    if (maxVal > 0) {
      for (int y = 0; y < 224; y++) {
        for (int x = 0; x < 224; x++) {
          combined[y][x] /= maxVal;
        }
      }
    }

    return combined;
  }

  static img.Image _createHeatmap(
    List<List<double>> attention,
    String prediction,
  ) {
    final heatmap = img.Image(width: 224, height: 224);

    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final intensity = (attention[y][x] * 255).clamp(0, 255).toInt();

        final color = prediction == "Sickle Cell Detected"
            ? img.ColorRgb8(
                intensity,
                (intensity * 0.2).toInt(),
                (intensity * 0.2).toInt(),
              )
            : img.ColorRgb8(
                (intensity * 0.2).toInt(),
                intensity,
                (intensity * 0.2).toInt(),
              );

        heatmap.setPixel(x, y, color);
      }
    }

    return img.gaussianBlur(heatmap, radius: 2);
  }

  /// Create superimposed image
  static img.Image _createSuperimposedImage(
    img.Image original,
    img.Image heatmap,
  ) {
    final superimposed = img.Image(width: 224, height: 224);

    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final originalPixel = original.getPixel(x, y);
        final heatmapPixel = heatmap.getPixel(x, y);

        final attentionIntensity =
            (heatmapPixel.r + heatmapPixel.g + heatmapPixel.b) / (3.0 * 255.0);
        final blendFactor = 0.25 + (attentionIntensity * 0.5);

        final blendedR =
            (originalPixel.r * (1 - blendFactor) + heatmapPixel.r * blendFactor)
                .toInt();
        final blendedG =
            (originalPixel.g * (1 - blendFactor) + heatmapPixel.g * blendFactor)
                .toInt();
        final blendedB =
            (originalPixel.b * (1 - blendFactor) + heatmapPixel.b * blendFactor)
                .toInt();

        superimposed.setPixel(
          x,
          y,
          img.ColorRgb8(blendedR, blendedG, blendedB),
        );
      }
    }

    return superimposed;
  }

  /// Generate analysis data
  static Map<String, dynamic> _generateAnalysis(
    List<List<double>> attention,
    double confidence,
    String prediction,
  ) {
    double totalAttention = 0.0;
    int highAttentionPixels = 0;
    final attentionValues = <double>[];

    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        totalAttention += attention[y][x];
        attentionValues.add(attention[y][x]);

        if (attention[y][x] > 0.7) {
          highAttentionPixels++;
        }
      }
    }

    final avgAttention = totalAttention / (224 * 224);
    final highAttentionPercentage = (highAttentionPixels / (224 * 224)) * 100;

    attentionValues.sort();
    final medianAttention = attentionValues[attentionValues.length ~/ 2];

    return {
      'averageAttention': avgAttention,
      'highAttentionPercentage': highAttentionPercentage,
      'medianAttention': medianAttention,
      'confidenceScore': confidence / 100.0,
      'predictionClass': prediction,
      'attentionMethod': 'Enhanced Multi-Feature',
    };
  }
}
