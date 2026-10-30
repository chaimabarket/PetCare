import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../adoption/presentation/widgets/adoption_widgets.dart';
import '../../../appointments/data/reminder.dart';
import '../../../appointments/data/reminder_repository.dart';
import '../../data/answer_parser.dart';
import '../../data/assistant_pet.dart';

/// Catégorie du rappel devinée d'après son intitulé (modifiable dans la feuille).
ReminderCategory guessReminderCategory(String title) {
  final t = title.toLowerCase();
  if (t.contains('vaccin')) return ReminderCategory.vet;
  if (t.contains('vermifug') || t.contains('antiparasit') || t.contains('puce') || t.contains('tique')) {
    return ReminderCategory.treatment;
  }
  if (t.contains('contrôle') || t.contains('controle') || t.contains('bilan') || t.contains('visite')) {
    return ReminderCategory.checkup;
  }
  if (t.contains('toilett') || t.contains('bain') || t.contains('griffe') || t.contains('dent') || t.contains('brossage')) {
    return ReminderCategory.hygiene;
  }
  if (t.contains('médicament') || t.contains('medicament') || t.contains('comprimé')) return ReminderCategory.medication;
  return ReminderCategory.care;
}

/// Feuille « Créer un rappel » préremplie par l'assistant ; l'utilisateur confirme.
/// Renvoie `true` si le rappel a été créé dans le module Rendez-vous et rappels.
Future<bool> showReminderSheet(BuildContext context, {required ReminderSuggestion suggestion, required AssistantPet pet}) async {
  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (context) => _ReminderSheet(suggestion: suggestion, pet: pet),
  );
  return created ?? false;
}

class _ReminderSheet extends StatefulWidget {
  const _ReminderSheet({required this.suggestion, required this.pet});

  final ReminderSuggestion suggestion;
  final AssistantPet pet;

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  late final _title = TextEditingController(text: widget.suggestion.title);
  late DateTime _date = widget.suggestion.dueAt;
  late ReminderCategory _category = guessReminderCategory(widget.suggestion.title);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: today.add(const Duration(days: 731)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = "L'intitulé est obligatoire.");
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ReminderRepository().create(
        petName: widget.pet.name,
        petBreed: widget.pet.breed,
        title: _title.text,
        description: "Conseillé par l'assistant PetCare",
        category: _category,
        dueAt: DateTime(_date.year, _date.month, _date.day, 9),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('ReminderSheet: $e');
      if (mounted) {
        setState(() {
          _saving = false;
          _error = "Le rappel n'a pas pu être créé. Vérifiez votre connexion.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('⏰ Créer un rappel', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Pour ${widget.pet.name} · visible dans « Rappels de soins ».',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Intitulé'),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.event_outlined)),
              child: Text(formatShortDate(_date)),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ReminderCategory>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Catégorie'),
            items: [for (final c in ReminderCategory.values) DropdownMenuItem(value: c, child: Text(c.label))],
            onChanged: (c) => setState(() => _category = c ?? _category),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Créer le rappel'),
          ),
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }
}
