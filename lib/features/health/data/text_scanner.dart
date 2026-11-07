// Reconnaissance du texte d'une photo (ordonnance, vignette vaccinale) sur le téléphone, avec Google ML Kit :
// gratuit, hors ligne, sans quota. ML Kit n'existe que sur Android et iOS ; ailleurs (web, Windows),
// [isTextScanSupported] est faux et le bouton « Scanner » n'est pas affiché.
export 'text_scanner_stub.dart' if (dart.library.io) 'text_scanner_mlkit.dart';
