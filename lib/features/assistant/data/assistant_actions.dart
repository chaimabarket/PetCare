import 'package:firebase_ai/firebase_ai.dart';

import '../../appointments/data/appointment.dart';
import '../../appointments/data/reminder.dart';
import '../../health/data/treatment.dart';
import 'assistant_pet.dart';

/// Actions que l'assistant peut préparer. Rien n'est enregistré sans la confirmation de l'utilisateur.
enum AssistantActionType {
  healthEntry('ajouter_soin', 'Ajouter au carnet de santé', 'ajouter ce soin au carnet'),
  treatment('ajouter_traitement', 'Ajouter un traitement', 'ajouter ce traitement'),
  appointment('creer_rendez_vous', 'Créer un rendez-vous', 'créer ce rendez-vous'),
  weight('ajouter_pesee', 'Ajouter une pesée', 'ajouter cette pesée'),
  reminder('creer_rappel', 'Créer un rappel', 'créer ce rappel');

  const AssistantActionType(this.functionName, this.label, this.goal);

  final String functionName;
  final String label;

  /// Fin de la phrase « Pour …, il me manque … ».
  final String goal;

  static AssistantActionType? byName(String name) => values.where((t) => t.functionName == name).firstOrNull;
}

enum AssistantActionStatus { pending, done, cancelled }

enum _Kind { text, date, time, number, choice }

/// Champ d'une action : sert à décrire la fonction au modèle, à repérer ce qui manque et à afficher la carte.
class _Field {
  const _Field(this.key, this.label, this.description, {this.kind = _Kind.text, this.required = true, this.options});

  final String key;
  final String label;
  final String description;
  final _Kind kind;
  final bool required;
  final List<String>? options;
}

const _animal = _Field('animal', 'Animal', "Nom de l'animal, tel qu'il apparaît dans ANIMAUX DE L'UTILISATEUR.");

const _healthTypes = ['visite', 'vaccin', 'examen', 'allergie', 'note'];
const _treatmentForms = ['comprime', 'gouttes', 'injection', 'pipette', 'autre'];

final _fields = <AssistantActionType, List<_Field>>{
  AssistantActionType.healthEntry: [
    _animal,
    const _Field('type', 'Type', 'Type de soin.', kind: _Kind.choice, options: _healthTypes),
    const _Field('titre', 'Intitulé', 'Intitulé court, par exemple « Pollen » pour une allergie ou « Bilan annuel ».'),
    const _Field('date', 'Date', 'Date du soin (AAAA-MM-JJ), aujourd\'hui ou dans le passé.', kind: _Kind.date),
    const _Field('nom_vaccin', 'Vaccin', 'Nom du vaccin. Obligatoire si le type est « vaccin ».', required: false),
    const _Field('prochain_rappel', 'Prochain rappel',
        "Date du prochain rappel (AAAA-MM-JJ), après la date du soin. Obligatoire si le type est « vaccin ». "
        "Ne la calcule jamais toi-même : si l'utilisateur ne l'a pas donnée, n'appelle pas la fonction et demande-la.",
        kind: _Kind.date, required: false),
    const _Field('praticien', 'Praticien', 'Vétérinaire ou clinique.', required: false),
    const _Field('description', 'Notes', 'Détails donnés par l\'utilisateur.', required: false),
  ],
  AssistantActionType.treatment: [
    _animal,
    const _Field('nom', 'Médicament', 'Nom du médicament ou du produit.'),
    _Field('categorie', 'Catégorie', 'Catégorie du traitement.', kind: _Kind.choice, options: treatmentCategories),
    const _Field('posologie', 'Posologie', 'Posologie prescrite, recopiée telle que l\'utilisateur l\'a donnée.'),
    const _Field('debut', 'Début', 'Date de début (AAAA-MM-JJ).', kind: _Kind.date),
    const _Field('fin', 'Fin', 'Date de fin (AAAA-MM-JJ), le même jour ou après le début.', kind: _Kind.date),
    const _Field('forme', 'Forme', 'Forme du médicament.', kind: _Kind.choice, required: false, options: _treatmentForms),
  ],
  AssistantActionType.appointment: [
    _animal,
    const _Field('titre', 'Intitulé', 'Intitulé court, par exemple « Vaccin rage » ou « Toilettage ».'),
    _Field('type', 'Type', 'Type de rendez-vous.',
        kind: _Kind.choice, options: [for (final t in AppointmentType.values) t.firestoreValue]),
    const _Field('date', 'Date',
        "Date du rendez-vous (AAAA-MM-JJ), dans le futur, donnée par l'utilisateur (« demain » est accepté).",
        kind: _Kind.date),
    const _Field('heure', 'Heure',
        "Heure de début (HH:MM, sur 24 h), telle que l'utilisateur l'a donnée. "
        "Si l'utilisateur ne l'a pas donnée, n'appelle pas la fonction et demande-la.",
        kind: _Kind.time),
    const _Field('duree_minutes', 'Durée', 'Durée en minutes (30 par défaut).', kind: _Kind.number, required: false),
    const _Field('lieu', 'Lieu', 'Adresse, clinique ou lieu du rendez-vous.', required: false),
  ],
  AssistantActionType.weight: [
    _animal,
    const _Field('poids_kg', 'Poids', 'Poids en kilogrammes.', kind: _Kind.number),
    const _Field('date', 'Date', 'Date de la pesée (AAAA-MM-JJ), aujourd\'hui par défaut.', kind: _Kind.date, required: false),
  ],
  AssistantActionType.reminder: [
    _animal,
    const _Field('titre', 'Intitulé', 'Intitulé court qui contient le nom de l\'animal, par exemple « Vermifuger Rex ».'),
    const _Field('date', 'Date', 'Date du rappel (AAAA-MM-JJ), aujourd\'hui ou dans le futur.', kind: _Kind.date),
    _Field('categorie', 'Catégorie', 'Catégorie du rappel.',
        kind: _Kind.choice, required: false, options: [for (final c in ReminderCategory.values) c.firestoreValue]),
  ],
};

const _functionDescriptions = {
  AssistantActionType.healthEntry:
      'Prépare une entrée du carnet de santé (visite, vaccin, examen, allergie ou note) pour un animal de l\'utilisateur.',
  AssistantActionType.treatment: 'Prépare un traitement médicamenteux prescrit pour un animal de l\'utilisateur.',
  AssistantActionType.appointment: 'Prépare un rendez-vous personnel (vétérinaire, toilettage…) pour un animal.',
  AssistantActionType.weight: 'Prépare une pesée pour un animal de l\'utilisateur.',
  AssistantActionType.reminder: 'Prépare un rappel de soin à une date donnée pour un animal de l\'utilisateur.',
};

Schema _schemaOf(_Field f) => switch (f.kind) {
      _Kind.number => Schema.number(description: f.description),
      _Kind.choice => Schema.enumString(enumValues: f.options!, description: f.description),
      _ => Schema.string(description: f.description),
    };

/// Fonctions décrites au modèle : les champs obligatoires lui indiquent quoi demander.
final assistantTools = [
  Tool.functionDeclarations([
    for (final type in AssistantActionType.values)
      FunctionDeclaration(
        type.functionName,
        _functionDescriptions[type]!,
        parameters: {for (final f in _fields[type]!) f.key: _schemaOf(f)},
        optionalParameters: [for (final f in _fields[type]!) if (!f.required) f.key],
      ),
  ]),
];

/// Action préparée par l'assistant, enregistrée avec le message.
class AssistantAction {
  const AssistantAction({required this.type, required this.args, this.status = AssistantActionStatus.pending});

  /// Appel de fonction du modèle ; `null` si la fonction est inconnue.
  static AssistantAction? fromCall(String name, Map<String, Object?> args) {
    final type = AssistantActionType.byName(name);
    if (type == null) return null;
    final known = {for (final f in _fields[type]!) f.key};
    return AssistantAction(type: type, args: {
      for (final MapEntry(:key, :value) in args.entries)
        if (known.contains(key) && value != null && '$value'.trim().isNotEmpty) key: value is num ? value : '$value'.trim(),
    });
  }

  static AssistantAction? fromMap(Object? value) {
    if (value is! Map) return null;
    final type = AssistantActionType.byName('${value['type']}');
    final args = value['args'];
    if (type == null || args is! Map) return null;
    return AssistantAction(
      type: type,
      args: Map<String, Object?>.from(args),
      status: AssistantActionStatus.values.where((s) => s.name == value['status']).firstOrNull ??
          AssistantActionStatus.pending,
    );
  }

  final AssistantActionType type;
  final Map<String, Object?> args;
  final AssistantActionStatus status;

  String text(String key) => '${args[key] ?? ''}'.trim();

  DateTime? date(String key) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text(key));
    if (match == null) return null;
    final (y, m, d) = (int.parse(match[1]!), int.parse(match[2]!), int.parse(match[3]!));
    final value = DateTime(y, m, d);
    return value.month == m && value.day == d ? value : null;
  }

  double? number(String key) => switch (args[key]) {
        final num n => n.toDouble(),
        final Object v => double.tryParse('$v'.replaceAll(',', '.')),
        null => null,
      };

  /// Début du rendez-vous (date + heure).
  DateTime? get startsAt {
    final day = date('date');
    final match = RegExp(r'^(\d{1,2})[:hH](\d{2})$').firstMatch(text('heure'));
    if (day == null || match == null) return null;
    final (h, m) = (int.parse(match[1]!), int.parse(match[2]!));
    if (h > 23 || m > 59) return null;
    return DateTime(day.year, day.month, day.day, h, m);
  }

  AssistantAction withStatus(AssistantActionStatus status) => AssistantAction(type: type, args: args, status: status);

  Map<String, dynamic> toMap() => {'type': type.functionName, 'args': args, 'status': status.name};
}

/// Résultat de la vérification d'une action avant d'afficher la carte.
class ActionCheck {
  const ActionCheck({this.pet, this.missing = const [], this.error});

  final AssistantPet? pet;

  /// Libellés des informations obligatoires absentes.
  final List<String> missing;
  final String? error;

  bool get ok => pet != null && missing.isEmpty && error == null;

  /// Phrase affichée (et gardée dans l'historique) quand l'action ne peut pas être proposée.
  String problemText(AssistantAction action) => missing.isEmpty
      ? error ?? ''
      : 'Pour ${action.type.goal}, il me manque : ${missing.join(', ')}. Pouvez-vous me les donner ?';
}

/// Vérifie l'action comme le ferait le formulaire : informations manquantes, animal connu, dates cohérentes.
ActionCheck checkAction(AssistantAction a, List<AssistantPet> pets, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final startOfDay = DateTime(today.year, today.month, today.day);
  final fields = _fields[a.type]!;

  final missing = [
    for (final f in fields)
      if (f.required && a.text(f.key).isEmpty) f.label.toLowerCase(),
  ];
  if (a.type == AssistantActionType.healthEntry && a.text('type') == 'vaccin') {
    if (a.text('nom_vaccin').isEmpty) missing.add('nom du vaccin');
    if (a.text('prochain_rappel').isEmpty) missing.add('date du prochain rappel');
  }
  if (missing.isNotEmpty) return ActionCheck(missing: missing);

  final name = a.text('animal').toLowerCase();
  final pet = pets.where((p) => p.name.trim().toLowerCase() == name).firstOrNull;
  if (pet == null) {
    final names = pets.map((p) => p.name).join(', ');
    return ActionCheck(
      error: pets.isEmpty
          ? "Je ne trouve aucun animal dans votre compte. Ajoutez-le d'abord dans « Mes animaux »."
          : 'Je ne trouve pas « ${a.text('animal')} » parmi vos animaux ($names). Pour lequel est-ce ?',
    );
  }

  for (final f in fields) {
    final value = a.text(f.key);
    if (value.isEmpty) continue;
    final valid = switch (f.kind) {
      _Kind.date => a.date(f.key) != null,
      _Kind.time => a.startsAt != null,
      _Kind.number => a.number(f.key) != null,
      _Kind.choice => f.options!.contains(value),
      _Kind.text => value.length <= 120 || f.key == 'description' || f.key == 'posologie',
    };
    if (!valid) return ActionCheck(pet: pet, error: '${f.label} « $value » n\'est pas valide. Pouvez-vous le préciser ?');
  }

  String? error;
  switch (a.type) {
    case AssistantActionType.healthEntry:
      final date = a.date('date')!;
      final next = a.date('prochain_rappel');
      if (date.isAfter(today)) {
        error = 'Le carnet de santé note les soins déjà faits : la date ne peut pas être dans le futur. '
            'Voulez-vous plutôt un rendez-vous ou un rappel ?';
      } else if (next != null && !next.isAfter(date)) {
        error = 'Le prochain rappel doit être après la date du soin. Quelle date souhaitez-vous ?';
      }
    case AssistantActionType.treatment:
      if (a.date('fin')!.isBefore(a.date('debut')!)) error = 'La fin du traitement doit être après son début.';
    case AssistantActionType.appointment:
      if (!a.startsAt!.isAfter(today)) error = 'Le rendez-vous doit être dans le futur. Quelle date et quelle heure ?';
      final minutes = a.number('duree_minutes');
      if (minutes != null && (minutes < 5 || minutes > 24 * 60)) error = 'La durée doit être entre 5 minutes et 24 heures.';
    case AssistantActionType.weight:
      final kg = a.number('poids_kg')!;
      final date = a.date('date') ?? startOfDay;
      if (kg <= 0 || kg > 500) error = 'Le poids doit être compris entre 0 et 500 kg.';
      if (date.isAfter(today)) error = 'Une pesée ne peut pas être datée dans le futur.';
    case AssistantActionType.reminder:
      if (a.date('date')!.isBefore(startOfDay)) error = 'Le rappel doit être aujourd\'hui ou plus tard. Quelle date ?';
  }
  return ActionCheck(pet: pet, error: error);
}

String _day(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _choiceLabel(String key, String value) => switch (key) {
      'type' => AppointmentType.values.where((t) => t.firestoreValue == value).firstOrNull?.label ??
          {'visite': 'Visite', 'vaccin': 'Vaccin', 'examen': 'Examen', 'allergie': 'Allergie', 'note': 'Note'}[value] ??
          value,
      'categorie' => ReminderCategory.values.where((c) => c.firestoreValue == value).firstOrNull?.label ?? value,
      'forme' => TreatmentForm.values.where((f) => f.firestoreValue == value).firstOrNull?.label ?? value,
      _ => value,
    };

/// Lignes « libellé : valeur » de la carte de confirmation.
List<(String, String)> describeAction(AssistantAction a) => [
      for (final f in _fields[a.type]!)
        if (a.text(f.key).isNotEmpty)
          (
            f.label,
            switch (f.kind) {
              _Kind.date => a.date(f.key) == null ? a.text(f.key) : _day(a.date(f.key)!),
              _Kind.number when f.key == 'poids_kg' => '${a.text(f.key)} kg',
              _Kind.number when f.key == 'duree_minutes' => '${a.text(f.key)} min',
              _Kind.choice => _choiceLabel(f.key, a.text(f.key)),
              _ => a.text(f.key),
            }
          ),
    ];

/// Version texte envoyée au modèle avec l'historique, pour qu'il sache ce qui a été confirmé ou non.
String actionHistoryText(AssistantAction a) {
  final status = switch (a.status) {
    AssistantActionStatus.pending => "proposée, pas encore confirmée par l'utilisateur",
    AssistantActionStatus.done => "confirmée et enregistrée par l'utilisateur",
    AssistantActionStatus.cancelled => "annulée par l'utilisateur",
  };
  final details = describeAction(a).map((l) => '${l.$1} : ${l.$2}').join(', ');
  return '[Action « ${a.type.label} » $status — $details]';
}

/// Bloc « ANIMAUX DE L'UTILISATEUR » : les noms que l'assistant peut utiliser dans une action.
String buildPetsListContext(List<AssistantPet> pets) => pets.isEmpty
    ? "ANIMAUX DE L'UTILISATEUR : aucun animal enregistré."
    : "ANIMAUX DE L'UTILISATEUR : ${pets.map((p) => '${p.name} (${p.speciesLabel})').join(', ')}";
