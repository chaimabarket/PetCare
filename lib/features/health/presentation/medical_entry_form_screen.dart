import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../appointments/data/reminder.dart';
import '../../appointments/data/reminder_repository.dart';
import '../data/health_entry.dart';
import '../data/health_format.dart';
import '../data/health_pet.dart';
import '../data/health_repository.dart';
import 'widgets/health_ui.dart';

/// Suggestions sous « Nom ou Spécialité du vaccin » : libellé de la puce → texte inséré.
const _visitReasons = ['Contrôle annuel', 'Maladie', 'Blessure', 'Suivi après opération', 'Urgence'];
const _examTypes = ['Prise de sang', 'Radiographie', 'Échographie', 'Analyse d\'urine', 'Test allergique'];
const _allergens = ['Poulet', 'Bœuf', 'Pollen', 'Acariens', 'Puces', 'Médicament'];
const _severities = ['Légère', 'Modérée', 'Sévère'];

const _vaccineSuggestions = [
  ('CHPPiL', 'CHPPiL Rappel Annuel'),
  ('Rage', 'Rabisin (Rage)'),
  ('Leptospirose', 'Leptospirose (L4)'),
  ('Toux chenil', 'Toux du chenil (Bb/CPi)'),
];

/// Ajouter un soin médical au carnet (maquette Stitch « Ajouter un soin médical – Milo »).
///
/// Renvoie `true` quand le soin est enregistré.
class MedicalEntryFormScreen extends StatefulWidget {
  const MedicalEntryFormScreen({super.key, required this.petId});

  final String petId;

  @override
  State<MedicalEntryFormScreen> createState() => _MedicalEntryFormScreenState();
}

class _MedicalEntryFormScreenState extends State<MedicalEntryFormScreen> {
  final _repository = HealthRepository();
  final _formKey = GlobalKey<FormState>();
  late final _petStream = _repository.watchPet(widget.petId);

  final _vaccineName = TextEditingController();
  final _batchNumber = TextEditingController();
  final _practitioner = TextEditingController();
  final _cost = TextEditingController();
  final _description = TextEditingController();

  var _type = HealthEntryType.vaccine;
  var _careDate = dayOf(DateTime.now());
  late DateTime _nextReminder = DateTime(_careDate.year + 1, _careDate.month, _careDate.day);
  var _createAlert = true;
  final _subject = TextEditingController();
  var _severity = 'Modérée';

  /// Visite : date du prochain contrôle, ou null s'il n'y en a pas.
  DateTime? _followUp;
  final _attachments = <PendingAttachment>[];
  var _saving = false;

  HealthPet? _pet;
  String? _usualPractitioner;
  double? _latestWeight;
  double? _previousWeight;
  var _weightAdded = false;

  @override
  void initState() {
    super.initState();
    _description.addListener(() => setState(() {}));
    _practitioner.addListener(() => setState(() {}));
    _loadContext();
  }

  /// Praticien habituel (dernier soin du carnet) et dernières pesées pour « + Poids ».
  Future<void> _loadContext() async {
    final weights = await _repository.latestWeights(widget.petId);
    String? usual;
    try {
      final entries = await _repository.watchEntries(widget.petId).first;
      usual = entries.map((e) => e.practitioner).whereType<String>().firstOrNull;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _latestWeight = weights.$1;
      _previousWeight = weights.$2;
      _usualPractitioner = usual;
      if (usual != null && _practitioner.text.isEmpty) _practitioner.text = usual;
    });
  }

  @override
  void dispose() {
    for (final c in [_vaccineName, _batchNumber, _practitioner, _cost, _description, _subject]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickCareDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _careDate,
      firstDate: DateTime(2000),
      lastDate: dayOf(DateTime.now()),
      helpText: "Date d'administration",
    );
    if (picked == null) return;
    setState(() {
      _careDate = picked;
      if (!_nextReminder.isAfter(picked)) _nextReminder = DateTime(picked.year + 1, picked.month, picked.day);
      if (_followUp != null && !_followUp!.isAfter(picked)) _followUp = _defaultFollowUp(picked);
    });
  }

  Future<void> _pickReminderDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextReminder,
      firstDate: _careDate.add(const Duration(days: 1)),
      lastDate: DateTime(_careDate.year + 5, 12, 31),
      helpText: 'Prochain rappel vaccinal',
    );
    if (picked != null) setState(() => _nextReminder = picked);
  }

  DateTime _defaultFollowUp(DateTime from) => DateTime(from.year, from.month + 1, from.day);

  Future<void> _pickFollowUp() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _followUp ?? _defaultFollowUp(_careDate),
      firstDate: _careDate.add(const Duration(days: 1)),
      lastDate: DateTime(_careDate.year + 5, 12, 31),
      helpText: 'Prochain contrôle',
    );
    if (picked != null) setState(() => _followUp = picked);
  }

  void _appendNote(String note) {
    final text = _description.text.trimRight();
    final next = text.isEmpty ? note : '$text $note';
    if (next.length > 1000) return;
    _description.text = next;
  }

  Future<void> _addAttachment() async {
    if (_attachments.length >= maxAttachments) {
      showHealthToast(context, '$maxAttachments pièces jointes au maximum.', icon: Symbols.info);
      return;
    }
    final source = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Symbols.photo_camera, color: HealthColors.primary),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Symbols.image, color: HealthColors.primary),
              title: const Text('Choisir une photo'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Symbols.picture_as_pdf, color: HealthColors.primary),
              title: const Text('Choisir un PDF'),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      PendingAttachment? file;
      if (source == 'pdf') {
        final picked = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['pdf']);
        if (picked != null) {
          file = PendingAttachment(name: picked.name, mimeType: 'application/pdf', bytes: await picked.readAsBytes());
        }
      } else {
        final picked = await ImagePicker().pickImage(
          source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 1600,
          imageQuality: 70,
        );
        if (picked != null) {
          final name = source == 'camera'
              ? 'Photo_${formatSlashDate(DateTime.now()).replaceAll(' / ', '-')}.jpg'
              : picked.name;
          file = PendingAttachment(name: name, mimeType: picked.mimeType ?? 'image/jpeg', bytes: await picked.readAsBytes());
        }
      }
      if (file == null || !mounted) return;
      if (file.bytes.length > maxAttachmentBytes) {
        showHealthToast(context, '« ${file.name} » dépasse 900 Ko. Choisissez un fichier plus léger.', icon: Symbols.error);
        return;
      }
      setState(() => _attachments.add(file!));
    } catch (e) {
      if (mounted) showHealthToast(context, friendlyHealthError(e), icon: Symbols.error);
    }
  }

  /// Titre affiché dans le carnet : le nom du vaccin, sinon la première phrase de la description
  /// (le reste devient le texte de la carte).
  (String, String?) _titleAndBody() {
    final text = _description.text.trim();
    if (_type == HealthEntryType.vaccine) return (_vaccineName.text.trim(), text.isEmpty ? null : text);
    // Les autres types ont leur propre champ : motif, type d'examen, allergène ou titre de la note.
    final title = _subject.text.trim();
    if (_type == HealthEntryType.allergy) {
      final severity = 'Gravité : $_severity';
      return (title, text.isEmpty ? severity : '$severity\n$text');
    }
    return (title, text.isEmpty ? null : text);
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final cost = double.tryParse(_cost.text.replaceAll('€', '').replaceAll(' ', '').replaceAll(',', '.'));
    final (title, body) = _titleAndBody();
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      // Aujourd'hui : on garde l'heure actuelle pour trier les soins du jour.
      final date = dayOf(_careDate) == dayOf(now) ? now : _careDate;
      await _repository.addEntry(
        petId: widget.petId,
        type: _type,
        title: title,
        date: date,
        description: body,
        practitioner: _practitioner.text,
        cost: cost,
        vaccineName: _vaccineName.text,
        batchNumber: _batchNumber.text,
        nextReminderAt: switch (_type) {
          HealthEntryType.vaccine => _nextReminder,
          HealthEntryType.visit => _followUp,
          _ => null,
        },
        weightKg: _weightAdded ? _latestWeight : null,
        weightDeltaKg: _weightAdded && _latestWeight != null && _previousWeight != null
            ? _latestWeight! - _previousWeight!
            : null,
        attachments: _attachments,
      );
      if (_createAlert) {
        if (_type == HealthEntryType.vaccine) {
          await _createAgendaAlert('Rappel vaccin : $title', _nextReminder);
        } else if (_type == HealthEntryType.visit && _followUp != null) {
          await _createAgendaAlert('Contrôle : $title', _followUp!);
        }
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showHealthToast(context, friendlyHealthError(e), icon: Symbols.error);
      }
    }
  }

  /// « Créer une alerte dans l'agenda » : un rappel du module 3, le jour du rappel à 9 h.
  Future<void> _createAgendaAlert(String alertTitle, DateTime due) async {
    try {
      await ReminderRepository().create(
        petName: _pet?.name ?? '',
        petBreed: _pet?.breed,
        title: alertTitle,
        description: _practitioner.text.trim().isEmpty ? null : _practitioner.text.trim(),
        detail: 'Carnet de santé',
        category: ReminderCategory.vet,
        dueAt: DateTime(due.year, due.month, due.day, 9),
      );
    } catch (_) {
      // Le soin est enregistré ; seule l'alerte a échoué.
      if (mounted) showHealthToast(context, "Soin enregistré, mais l'alerte n'a pas pu être créée dans l'agenda.", icon: Symbols.info);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HealthColors.surface,
      appBar: const HealthAppBar(title: 'Ajouter Un Soin Médical'),
      bottomNavigationBar: _Footer(saving: _saving, onSave: _save),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const _PrivacyRow(),
            const SizedBox(height: 8),
            StreamBuilder<HealthPet?>(
              stream: _petStream,
              builder: (context, snapshot) {
                _pet = snapshot.data;
                return _pet == null ? const SizedBox(height: 88) : _PetCard(pet: _pet!);
              },
            ),
            const SizedBox(height: 16),
            const Text('Nouveau soin médical', style: HealthText.headlineMd),
            const SizedBox(height: 4),
            const Text(
              'Consignez les détails de la consultation, vaccin ou soin administré.',
              style: HealthText.bodyMd,
            ),
            const SizedBox(height: 16),
            _section(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const HealthFieldLabel("Type d'acte médical", required: true),
                  const Text("Sélectionnez le type d'intervention effectuée", style: HealthText.bodySm),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 8,
                    children: [
                      for (final t in HealthEntryType.values)
                        _TypePill(
                          type: t,
                          selected: t == _type,
                          onTap: () => setState(() {
                            if (t != _type) _subject.clear();
                            _type = t;
                          }),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _typeSection(),
            const SizedBox(height: 16),
            _detailsSection(),
            const SizedBox(height: 16),
            _descriptionSection(),
            const SizedBox(height: 16),
            _attachmentsSection(),
          ],
        ),
      ),
    );
  }

  Widget _section({required Widget child}) => HealthCard(child: child);

  /// Bloc propre au type d'acte : vaccin, visite, examen, allergie ou note libre.
  Widget _typeSection() => switch (_type) {
        HealthEntryType.vaccine => _vaccineSection(true),
        HealthEntryType.visit => _subjectSection(
            icon: Symbols.stethoscope,
            title: 'Visite vétérinaire',
            subtitle: 'Le motif de la consultation et le prochain contrôle',
            label: 'Motif de la visite',
            hint: 'Ex: Contrôle annuel, boiterie...',
            error: 'Indiquez le motif de la visite.',
            suggestions: _visitReasons,
            extra: [const SizedBox(height: 16), _followUpCard()],
          ),
        HealthEntryType.exam => _subjectSection(
            icon: Symbols.radiology,
            title: "Détails de l'examen",
            subtitle: 'Le type d\'examen ; le résultat va dans les observations',
            label: "Type d'examen",
            hint: 'Ex: Prise de sang, Radiographie...',
            error: "Indiquez le type d'examen.",
            suggestions: _examTypes,
          ),
        HealthEntryType.allergy => _subjectSection(
            icon: Symbols.warning,
            title: 'Allergie ou sensibilité',
            subtitle: "Ce qui provoque la réaction et sa gravité",
            label: 'Allergène ou réaction',
            hint: 'Ex: Poulet, pollen, piqûres de puces...',
            error: "Indiquez l'allergène ou la réaction.",
            suggestions: _allergens,
            extra: [const SizedBox(height: 16), _severityPicker()],
          ),
        HealthEntryType.note => _subjectSection(
            icon: Symbols.edit_note,
            title: 'Note libre',
            subtitle: 'Un titre court pour retrouver la note dans le carnet',
            label: 'Titre de la note',
            hint: 'Ex: Changement de croquettes',
            error: 'Donnez un titre à la note.',
            suggestions: const [],
          ),
      };

  /// Carte avec un champ principal (qui devient le titre dans le carnet) et des suggestions.
  Widget _subjectSection({
    required IconData icon,
    required String title,
    required String subtitle,
    required String label,
    required String hint,
    required String error,
    required List<String> suggestions,
    List<Widget> extra = const [],
  }) {
    return _section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(color: HealthColors.primaryFixed, shape: BoxShape.circle),
                child: Icon(icon, size: 18, color: HealthColors.onPrimaryFixed),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: HealthText.headlineSm),
                    Text(subtitle, style: HealthText.bodySm),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          HealthFieldLabel(label, required: true),
          TextFormField(
            controller: _subject,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 120,
            buildCounter: _noCounter,
            decoration: healthInputDecoration(hint: hint, suffixIcon: icon),
            validator: (v) => (v ?? '').trim().isEmpty ? error : null,
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final value in suggestions) _SmallChip(label: value, onTap: () => _subject.text = value)],
            ),
          ],
          ...extra,
        ],
      ),
    );
  }

  /// Visite : « Planifier un prochain contrôle », avec une alerte facultative dans l'agenda.
  Widget _followUpCard() {
    final date = _followUp;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: HealthColors.surfaceLow, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Symbols.event_repeat, size: 18, color: HealthColors.primary),
              const SizedBox(width: 6),
              const Expanded(child: HealthFieldLabel('Planifier un prochain contrôle')),
              Switch(
                value: date != null,
                onChanged: (on) => setState(() => _followUp = on ? _defaultFollowUp(_careDate) : null),
                activeTrackColor: HealthColors.primaryContainer,
                activeThumbColor: Colors.white,
              ),
            ],
          ),
          if (date != null) ...[
            const SizedBox(height: 8),
            _DateField(
              text: formatSlashDate(date),
              icon: Symbols.calendar_month,
              iconColor: HealthColors.primary,
              fill: Colors.white,
              onTap: _pickFollowUp,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Symbols.notifications_active, size: 18, color: HealthColors.onSurfaceVariant),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Créer une alerte dans l'agenda",
                    style: TextStyle(fontSize: 14, color: HealthColors.onSurface),
                  ),
                ),
                Switch(
                  value: _createAlert,
                  onChanged: (v) => setState(() => _createAlert = v),
                  activeTrackColor: HealthColors.primaryContainer,
                  activeThumbColor: Colors.white,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Allergie : gravité de la réaction (enregistrée en tête des observations).
  Widget _severityPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HealthFieldLabel('Gravité de la réaction', required: true),
        Wrap(
          spacing: 8,
          children: [
            for (final level in _severities)
              ChoiceChip(
                label: Text(level),
                selected: _severity == level,
                onSelected: (_) => setState(() => _severity = level),
                selectedColor: HealthColors.primaryFixed,
              ),
          ],
        ),
      ],
    );
  }

  Widget _vaccineSection(bool active) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: HealthColors.cardShadow,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 6, color: HealthColors.primaryContainer),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(color: HealthColors.primaryFixed, shape: BoxShape.circle),
                          child: const Icon(Symbols.vaccines, size: 18, color: HealthColors.onPrimaryFixed),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Protocole Vaccinal', style: HealthText.headlineSm),
                              Text('Renseignez les données obligatoires du carnet', style: HealthText.bodySm),
                            ],
                          ),
                        ),
                        const HealthPill(
                          label: 'Important',
                          background: HealthColors.secondaryFixed,
                          foreground: HealthColors.onSecondaryFixed,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const HealthFieldLabel('Nom ou Spécialité du vaccin', required: true),
                    TextFormField(
                      controller: _vaccineName,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 120,
                      buildCounter: _noCounter,
                      decoration: healthInputDecoration(
                        hint: 'Ex: CHPPiL, Rage, Toux du chenil...',
                        suffixIcon: Symbols.medication,
                      ),
                      validator: (v) => active && (v ?? '').trim().isEmpty ? 'Indiquez le nom du vaccin.' : null,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final (label, value) in _vaccineSuggestions)
                          _SmallChip(label: label, onTap: () => _vaccineName.text = value),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const HealthFieldLabel('Numéro de lot & Série', optional: true),
                    TextFormField(
                      controller: _batchNumber,
                      maxLength: 60,
                      buildCounter: _noCounter,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                      decoration: healthInputDecoration(hint: 'Ex: #VX-99482', suffixIcon: Symbols.tag),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: HealthColors.surfaceLow, borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Symbols.event_repeat, size: 18, color: HealthColors.primary),
                              const SizedBox(width: 6),
                              const Expanded(child: HealthFieldLabel('Prochain rappel vaccinal', required: true)),
                              HealthPill(
                                label: formatTimeUntil(_nextReminder, now: _careDate),
                                background: HealthColors.primaryFixed,
                                foreground: HealthColors.onPrimaryFixed,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _DateField(
                            text: formatSlashDate(_nextReminder),
                            icon: Symbols.calendar_month,
                            iconColor: HealthColors.primary,
                            fill: Colors.white,
                            onTap: _pickReminderDate,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Symbols.notifications_active, size: 18, color: HealthColors.onSurfaceVariant),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  "Créer une alerte dans l'agenda",
                                  style: TextStyle(fontSize: 14, color: HealthColors.onSurface),
                                ),
                              ),
                              Switch(
                                value: _createAlert,
                                onChanged: (v) => setState(() => _createAlert = v),
                                activeTrackColor: HealthColors.primaryContainer,
                                activeThumbColor: Colors.white,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailsSection() {
    final practitioner = _practitioner.text.trim();
    final isUsual = practitioner.isNotEmpty && practitioner == _usualPractitioner;
    final needsPractitioner = _type != HealthEntryType.note;
    return _section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Détails de la consultation', style: HealthText.headlineSm),
          const SizedBox(height: 16),
          HealthFieldLabel(_type == HealthEntryType.vaccine ? "Date d'administration" : 'Date du soin', required: true),
          _DateField(text: formatCareDate(_careDate), icon: Symbols.today, onTap: _pickCareDate),
          const SizedBox(height: 16),
          HealthFieldLabel('Vétérinaire ou clinique', required: needsPractitioner, optional: !needsPractitioner),
          TextFormField(
            controller: _practitioner,
            textCapitalization: TextCapitalization.words,
            maxLength: 120,
            buildCounter: _noCounter,
            decoration: healthInputDecoration(
              hint: 'Rechercher une clinique ou un vétérinaire...',
              suffixIcon: Symbols.local_hospital,
            ),
            validator: (v) =>
                needsPractitioner && (v ?? '').trim().isEmpty ? 'Indiquez le vétérinaire ou la clinique.' : null,
          ),
          if (isUsual) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Symbols.verified, size: 14, color: HealthColors.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Praticien habituel certifié dans le dossier de ${_pet?.name ?? "votre animal"}',
                    style: HealthText.bodySm,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const HealthFieldLabel('Coût des soins', optional: true),
          TextFormField(
            controller: _cost,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            decoration: healthInputDecoration(hint: '0,00 €', suffixIcon: Symbols.payments),
            validator: (v) {
              final text = (v ?? '').replaceAll('€', '').replaceAll(' ', '').replaceAll(',', '.');
              if (text.isEmpty) return null;
              final value = double.tryParse(text);
              return value == null || value < 0 ? 'Montant invalide (ex : 65,00).' : null;
            },
          ),
        ],
      ),
    );
  }

  Widget _descriptionSection() {
    return _section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Description & Observations', style: HealthText.labelLg)),
              Text(
                '${_description.text.length}/1000',
                style: HealthText.labelSm.copyWith(fontFamily: 'monospace', color: HealthColors.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Examen général, tolérance du produit, recommandations du vétérinaire',
            style: HealthText.bodySm,
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: _description,
            minLines: 4,
            maxLines: 8,
            maxLength: 1000,
            buildCounter: _noCounter,
            textCapitalization: TextCapitalization.sentences,
            decoration: healthInputDecoration(
              hint:
                  'Remarques du vétérinaire, tolérance du vaccin, recommandations particulières, poids relevé...',
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Ajout rapide :', style: HealthText.labelSm),
              if (_latestWeight != null)
                _SmallChip(
                  label: '+ Poids ${formatKg(_latestWeight!)}kg',
                  square: true,
                  onTap: () {
                    _weightAdded = true;
                    _appendNote('Poids : ${formatKg(_latestWeight!)} kg.');
                  },
                ),
              _SmallChip(label: '+ Bon état général', square: true, onTap: () => _appendNote('Bon état général.')),
              _SmallChip(label: '+ À jeun', square: true, onTap: () => _appendNote('À jeun 12h.')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _attachmentsSection() {
    final count = _attachments.length;
    return _section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(child: Text('Pièces jointes & Ordonnance', style: HealthText.headlineSm)),
              if (count > 0)
                Text(
                  count == 1 ? '1 document prêt' : '$count documents prêts',
                  style: HealthText.labelSm.copyWith(color: HealthColors.primary),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Joignez la vignette vaccinale, un devis ou une facture vétérinaire',
            style: HealthText.bodySm,
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < count; i++) ...[
            _AttachmentTile(file: _attachments[i], onRemove: () => setState(() => _attachments.removeAt(i))),
            const SizedBox(height: 8),
          ],
          Material(
            color: HealthColors.surfaceHigh,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _addAttachment,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Symbols.add_a_photo, size: 20, color: HealthColors.primary),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        "Ajouter l'ordonnance ou la vignette (PDF, Photo)",
                        style: HealthText.labelLg,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget? _noCounter(BuildContext context, {required int currentLength, required bool isFocused, required int? maxLength}) =>
    null;

class _PrivacyRow extends StatelessWidget {
  const _PrivacyRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: HealthColors.surfaceHigh, borderRadius: BorderRadius.circular(999)),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Symbols.lock, size: 14, color: HealthColors.onSurfaceVariant),
              SizedBox(width: 4),
              Text('Données chiffrées & privées', style: TextStyle(fontSize: 11, color: HealthColors.onSurfaceVariant)),
            ],
          ),
        ),
        const Spacer(),
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(color: HealthColors.primary, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        const Text('Carnet synchronisé', style: TextStyle(fontSize: 11, color: HealthColors.onSurfaceVariant)),
      ],
    );
  }
}

/// Carte de l'animal en haut du formulaire.
class _PetCard extends StatelessWidget {
  const _PetCard({required this.pet});

  final HealthPet pet;

  @override
  Widget build(BuildContext context) {
    final ageAndSpecies = [
      if (pet.birthDate != null) formatPetAge(pet.birthDate!, short: true),
      pet.speciesText,
    ].join(' • ');
    return HealthCard(
      child: Row(
        children: [
          Stack(
            children: [
              HealthPetPhoto(name: pet.name, photo: pet.photo, size: 56),
              const Positioned(right: 0, bottom: 0, child: HealthPhotoBadge(icon: Symbols.pets, size: 16, color: HealthColors.primary)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(pet.name, style: HealthText.headlineSm, overflow: TextOverflow.ellipsis)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: HealthColors.surfaceLow, borderRadius: BorderRadius.circular(999)),
                      child: Text(ageAndSpecies, style: HealthText.labelSm.copyWith(color: HealthColors.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(pet.breed ?? pet.speciesText, style: HealthText.bodySm, overflow: TextOverflow.ellipsis),
                    ),
                    if (pet.chipNumber != null) ...[
                      const Text('  •  ', style: TextStyle(color: HealthColors.outlineVariant, fontSize: 12)),
                      Flexible(
                        child: Text(
                          'ICAD: ${pet.chipNumber}',
                          style: HealthText.labelSm.copyWith(fontFamily: 'monospace', color: HealthColors.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.type, required this.selected, required this.onTap});

  final HealthEntryType type;
  final bool selected;
  final VoidCallback onTap;

  static const _icons = {
    HealthEntryType.visit: Symbols.stethoscope,
    HealthEntryType.vaccine: Symbols.vaccines,
    HealthEntryType.exam: Symbols.radiology,
    HealthEntryType.allergy: Symbols.warning,
    HealthEntryType.note: Symbols.edit_note,
  };

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : HealthColors.onSurface;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? HealthColors.primaryContainer : HealthColors.surfaceHigh,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_icons[type], size: 16, color: fg),
                const SizedBox(width: 6),
                Text(type.label, style: HealthText.labelMd.copyWith(color: fg)),
                if (selected) ...[const SizedBox(width: 6), Icon(Symbols.check, size: 14, color: fg)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Petite puce grise : suggestions de vaccin et « Ajout rapide ».
class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.label, required this.onTap, this.square = false});

  final String label;
  final VoidCallback onTap;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(square ? 4 : 8);
    return Material(
      color: HealthColors.surfaceHigh,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: square ? 8 : 10, vertical: square ? 2 : 4),
          child: Text(
            label,
            style: HealthText.labelSm.copyWith(color: square ? HealthColors.onSurface : HealthColors.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

/// Champ date en lecture seule : un appui ouvre le calendrier.
class _DateField extends StatelessWidget {
  const _DateField({required this.text, required this.icon, required this.onTap, this.iconColor, this.fill});

  final String text;
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fill ?? HealthColors.surfaceLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: HealthColors.onSurface))),
              Icon(icon, size: 20, color: iconColor ?? HealthColors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.file, required this.onRemove});

  final PendingAttachment file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isImage = file.mimeType.startsWith('image/');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: HealthColors.surfaceLow, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: HealthColors.surfaceHigh, borderRadius: BorderRadius.circular(8)),
            child: Icon(isImage ? Symbols.document_scanner : Symbols.picture_as_pdf, size: 20, color: HealthColors.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.name, style: HealthText.labelMd, overflow: TextOverflow.ellipsis),
                Text(
                  '${isImage ? 'Image' : 'PDF'} • ${formatFileSize(file.bytes.length)}${isImage ? ' • Numérisé' : ''}',
                  style: HealthText.bodySm,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Retirer',
            onPressed: onRemove,
            icon: const Icon(Symbols.close, size: 18, color: HealthColors.outline),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.saving, required this.onSave});

  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: HealthColors.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: HealthColors.cardShadow,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: saving ? null : () => Navigator.of(context).maybePop(),
                style: TextButton.styleFrom(
                  backgroundColor: HealthColors.surfaceHigh,
                  foregroundColor: HealthColors.onSurface,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                child: const Text('Annuler'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: saving ? null : onSave,
                style: FilledButton.styleFrom(
                  backgroundColor: HealthColors.primaryContainer,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                icon: saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Symbols.check_circle, size: 20),
                label: const Text('Enregistrer le soin'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
