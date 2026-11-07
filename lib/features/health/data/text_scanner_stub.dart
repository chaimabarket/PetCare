/// Web : pas de reconnaissance de texte sur l'appareil.
bool get isTextScanSupported => false;

Future<String> recognizeTextFromImage(String path) =>
    throw UnsupportedError("La lecture d'ordonnance n'est disponible que sur Android et iOS.");
