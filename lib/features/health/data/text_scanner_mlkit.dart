import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Android et iOS seulement (ML Kit n'a pas d'implémentation Windows, macOS ni Linux).
bool get isTextScanSupported =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

/// Texte reconnu sur l'image [path], ligne par ligne (écriture latine : français, anglais).
Future<String> recognizeTextFromImage(String path) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final recognized = await recognizer.processImage(InputImage.fromFilePath(path));
    return recognized.text;
  } finally {
    await recognizer.close();
  }
}
