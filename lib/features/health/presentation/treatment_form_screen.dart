import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/health_format.dart';
import '../data/health_repository.dart';
import '../data/treatment.dart';
import 'widgets/health_ui.dart';

/// « Nouveau traitement » (bouton de la maquette « Traitements »).
///
/// Pas de maquette dédiée : l'écran reprend les composants de « Ajouter un soin médical »
/// (cartes, champs, puces, pied de page). Renvoie `true` quand le traitement est enregistré.
class TreatmentFormScreen extends StatefulWidget {
  const TreatmentFormScreen({super.key, required this.petId});

  final String petId;

  @override
  State<TreatmentFormScreen> createState() => _TreatmentFormScreenState();
}

class _TreatmentFormScreenState extends State<TreatmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _subtitle = TextEditingController();
  final _practitioner = TextEditingController();
  final _posology = TextEditingController();
  final _scheduleNote = TextEditingController();

  var _category = treatmentCategories.first;
  var _form = TreatmentForm.tablet;
  var _start = dayOf(DateTime.now());
  late var _end = _start.add(const Duration(days: 6));
  final _doseTimes = <TimeOfDay>[const TimeOfDay(hour: 8, minute: 0), const TimeOfDay(hour: 20, minute: 0)];
  DateTime? _renewal;
  var _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _subtitle, _practitioner, _posology, _scheduleNote]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime initial, DateTime first, String help) => showDatePicker(
        context: context,
        initialDate: initial.isBefore(first) ? first : initial,
        firstDate: first,
        lastDate: DateTime(DateTime.now().year + 3, 12, 31),
        helpText: help,
      );

  Future<void> _addTime() async {
    final picked = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 12, minute: 0));
    if (picked == null) return;
    setState(() {
      if (!_doseTimes.contains(picked)) _doseTimes.add(picked);
      _doseTimes.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    });
  }

  String _hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await HealthRepository().addTreatment(
        petId: widget.petId,
        category: _category,
        name: _name.text,
        subtitle: _subtitle.text,
        form: _form,
        practitioner: _practitioner.text,
        posology: _posology.text,
        startDate: _start,
        endDate: _end,
        doseTimes: _doseTimes.map(_hhmm).toList(),
        renewalAt: _renewal,
        scheduleNote: _scheduleNote.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showHealthToast(context, friendlyHealthError(e), icon: Symbols.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HealthColors.surface,
      appBar: const HealthAppBar(title: 'Nouveau traitement'),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
                  style: TextButton.styleFrom(
                    backgroundColor: HealthColors.surfaceHigh,
                    foregroundColor: HealthColors.onSurface,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: HealthColors.primaryContainer,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Symbols.check_circle, size: 20),
                  label: const Text('Enregistrer le traitement'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            HealthCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const HealthFieldLabel('Catégorie', required: true),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in treatmentCategories)
                        ChoiceChip(
                          label: Text(c),
                          selected: c == _category,
                          onSelected: (_) => setState(() => _category = c),
                          selectedColor: HealthColors.primaryContainer,
                          labelStyle: HealthText.labelMd.copyWith(color: c == _category ? Colors.white : HealthColors.onSurface),
                          showCheckmark: false,
                          side: BorderSide.none,
                          backgroundColor: HealthColors.surfaceHigh,
                          shape: const StadiumBorder(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const HealthFieldLabel('Nom du médicament', required: true),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: healthInputDecoration(hint: 'Ex : Synulox 250 mg', suffixIcon: Symbols.medication),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Indiquez le nom du médicament.' : null,
                  ),
                  const SizedBox(height: 16),
                  const HealthFieldLabel('Principe actif ou forme', optional: true),
                  TextFormField(
                    controller: _subtitle,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: healthInputDecoration(hint: 'Ex : Amoxicilline + Acide Clavulanique'),
                  ),
                  const SizedBox(height: 16),
                  const HealthFieldLabel('Forme'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final f in TreatmentForm.values)
                        ChoiceChip(
                          label: Text(f.label),
                          selected: f == _form,
                          onSelected: (_) => setState(() => _form = f),
                          selectedColor: HealthColors.primaryContainer,
                          labelStyle: HealthText.labelMd.copyWith(color: f == _form ? Colors.white : HealthColors.onSurface),
                          showCheckmark: false,
                          side: BorderSide.none,
                          backgroundColor: HealthColors.surfaceHigh,
                          shape: const StadiumBorder(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const HealthFieldLabel('Vétérinaire prescripteur', optional: true),
                  TextFormField(
                    controller: _practitioner,
                    textCapitalization: TextCapitalization.words,
                    decoration: healthInputDecoration(
                      hint: 'Vide si vous administrez vous-même le soin',
                      suffixIcon: Symbols.stethoscope,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            HealthCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const HealthFieldLabel('Posologie prescrite', required: true),
                  const Text('Recopiez la posologie telle que prescrite par le vétérinaire.', style: HealthText.bodySm),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _posology,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: healthInputDecoration(hint: 'Ex : 1 comprimé matin et soir au milieu du repas pendant 10 jours.'),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Recopiez la posologie prescrite.' : null,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _DateTile(
                          label: 'Début',
                          value: formatHealthDate(_start),
                          onTap: () async {
                            final d = await _pickDate(_start, DateTime(2000), 'Début du traitement');
                            if (d != null) setState(() => _start = d);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _DateTile(
                          label: 'Fin',
                          value: formatHealthDate(_end),
                          onTap: () async {
                            final d = await _pickDate(_end, _start, 'Fin du traitement');
                            if (d != null) setState(() => _end = d);
                          },
                        ),
                      ),
                    ],
                  ),
                  if (_end.isBefore(_start))
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'La date de fin doit être après la date de début.',
                        style: TextStyle(fontSize: 12, color: HealthColors.error),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const HealthFieldLabel('Heures de prise'),
                  const Text('Pour afficher la « Prochaine prise » et noter chaque prise.', style: HealthText.bodySm),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in _doseTimes)
                        InputChip(
                          label: Text(_hhmm(t)),
                          onDeleted: () => setState(() => _doseTimes.remove(t)),
                          backgroundColor: HealthColors.surfaceLow,
                          side: BorderSide.none,
                          shape: const StadiumBorder(),
                        ),
                      ActionChip(
                        avatar: const Icon(Symbols.add, size: 16, color: HealthColors.primary),
                        label: const Text('Ajouter une heure'),
                        onPressed: _addTime,
                        backgroundColor: HealthColors.surfaceHigh,
                        side: BorderSide.none,
                        shape: const StadiumBorder(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            HealthCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const HealthFieldLabel('Prochain renouvellement', optional: true),
                  _DateTile(
                    label: 'Date approximative',
                    value: _renewal == null ? 'Aucun' : formatHealthDate(_renewal!),
                    onTap: () async {
                      final d = await _pickDate(
                        _renewal ?? _end.add(const Duration(days: 180)),
                        _end.add(const Duration(days: 1)),
                        'Prochain renouvellement',
                      );
                      if (d != null) setState(() => _renewal = d);
                    },
                    onClear: _renewal == null ? null : () => setState(() => _renewal = null),
                  ),
                  const SizedBox(height: 16),
                  const HealthFieldLabel('Note de protocole', optional: true),
                  TextFormField(
                    controller: _scheduleNote,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: healthInputDecoration(hint: 'Ex : Protocole préventif semestriel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.label, required this.value, required this.onTap, this.onClear});

  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HealthColors.surfaceLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: HealthText.labelSm.copyWith(color: HealthColors.outline)),
                    Text(value, style: const TextStyle(fontSize: 14, color: HealthColors.onSurface)),
                  ],
                ),
              ),
              if (onClear != null)
                IconButton(onPressed: onClear, icon: const Icon(Symbols.close, size: 18), tooltip: 'Effacer')
              else
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Symbols.calendar_month, size: 20, color: HealthColors.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
