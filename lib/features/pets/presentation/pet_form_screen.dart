import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../data/pet.dart';
import '../data/pet_media.dart';
import '../data/pet_repository.dart';
import 'pet_format.dart';
import 'pet_style.dart';
import 'widgets/pet_photo.dart';

/// Formulaire « Ajouter un animal » (maquette Stitch), aussi utilisé pour modifier une fiche.
class PetFormScreen extends StatefulWidget {
  const PetFormScreen({super.key, this.pet, this.photos = const [], this.currentWeight});

  /// Fiche à modifier ; `null` pour un nouvel animal.
  final Pet? pet;
  final List<PetPhoto> photos;
  final WeightEntry? currentWeight;

  @override
  State<PetFormScreen> createState() => _PetFormScreenState();
}

class _PetFormScreenState extends State<PetFormScreen> {
  static const _notesMax = 500;

  late final _name = TextEditingController(text: widget.pet?.name);
  late final _breed = TextEditingController(text: widget.pet?.breed);
  late final _weight = TextEditingController(
    text: widget.currentWeight == null ? '' : widget.currentWeight!.weightKg.toString(),
  );
  late final _chip = TextEditingController(text: widget.pet?.chipNumber);
  late final _notes = TextEditingController(text: widget.pet?.notes);

  late PetSpecies _species = widget.pet?.species ?? PetSpecies.dog;
  late PetSex _sex = widget.pet?.sex ?? PetSex.male;
  late bool _sterilized = widget.pet?.sterilized ?? false;
  late DateTime? _birthDate = widget.pet?.birthDate;
  late bool _birthEstimated = widget.pet?.birthDateEstimated ?? false;
  late final List<EditablePhoto> _photos = [
    for (final p in widget.photos) EditablePhoto(id: p.id, bytes: p.bytes),
  ];

  bool _submitted = false;
  bool _saving = false;

  bool get _editing => widget.pet != null;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _weight, _chip, _notes]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _breed, _weight, _chip, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _nameError(AppLocalizations l) {
    final length = _name.text.trim().length;
    if (length < 2) return l.petsFormNameError;
    if (length > 80) return l.petsFormNameTooLong;
    return null;
  }

  String? _birthError(AppLocalizations l) => _birthDate == null ? l.petsFormBirthError : null;

  /// Poids saisi en kg, `null` si le champ est vide.
  double? get _weightValue {
    final text = _weight.text.trim().replaceAll(',', '.');
    return text.isEmpty ? null : double.tryParse(text);
  }

  String? _weightError(AppLocalizations l) {
    if (_weight.text.trim().isEmpty) return null;
    final value = _weightValue;
    if (value == null || value <= 0 || value > 500) return l.petsFormWeightError;
    if ((value * 100).roundToDouble() != value * 100) return l.petsFormWeightDecimals;
    return null;
  }

  String? _chipError(AppLocalizations l) {
    final chip = _chip.text.trim();
    if (chip.isEmpty || RegExp(r'^\d{15}$').hasMatch(chip)) return null;
    return l.petsFormChipError;
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 1, now.month, now.day),
      firstDate: DateTime(now.year - 40),
      lastDate: now,
      helpText: AppLocalizations.of(context).petsFormBirthDate,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _addPhoto({int? replaceIndex}) async {
    if (replaceIndex == null && _photos.length >= maxPetPhotos) return;
    final bytes = await pickPetPhoto(context);
    if (bytes == null || !mounted) return;
    setState(() {
      if (replaceIndex != null) {
        _photos[replaceIndex] = EditablePhoto(bytes: bytes);
      } else {
        _photos.add(EditablePhoto(bytes: bytes));
      }
    });
  }

  void _makeCover(int index) => setState(() => _photos.insert(0, _photos.removeAt(index)));

  void _removePhoto(int index) => setState(() => _photos.removeAt(index));

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitted = true);
    if (_nameError(l) != null || _birthError(l) != null || _weightError(l) != null || _chipError(l) != null) {
      messenger.showSnackBar(SnackBar(content: Text(l.petsFormCheckFields)));
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final draft = PetDraft(
      name: _name.text,
      species: _species,
      sex: _sex,
      birthDate: _birthDate!,
      breed: _breed.text,
      birthDateEstimated: _birthEstimated,
      chipNumber: _chip.text,
      sterilized: _sterilized,
      notes: _notes.text,
    );
    final weight = _weightValue;
    // En modification, une nouvelle pesée n'est créée que si le poids a changé.
    final newWeight = weight != null && weight != widget.currentWeight?.weightKg ? weight : null;

    setState(() => _saving = true);
    try {
      final repository = PetRepository();
      if (_editing) {
        await repository.update(
          petId: widget.pet!.id,
          draft: draft,
          photos: _photos,
          previousPhotoIds: widget.photos.map((p) => p.id).toList(),
          weightKg: newWeight,
        );
      } else {
        await repository.create(
          ownerId: uid,
          draft: draft,
          photos: _photos.map((p) => p.bytes).toList(),
          weightKg: newWeight,
        );
      }
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.petsFormSaved(draft.name.trim()))));
      Navigator.of(context).pop();
    } on FirebaseException {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l.petsFormSaveError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: PetColors.surface,
      appBar: AppBar(
        backgroundColor: PetColors.surface,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 56,
        leadingWidth: 120,
        centerTitle: true,
        leading: TextButton.icon(
          onPressed: () => Navigator.of(context).maybePop(),
          style: TextButton.styleFrom(foregroundColor: PetColors.primary),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          label: Text(l.petsCancel, style: PetText.labelLg.copyWith(color: PetColors.primary)),
        ),
        title: Text(_editing ? l.petsFormTitleEdit : l.petsFormTitleAdd, style: PetText.headlineSm),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkResponse(
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.profile),
              child: const CircleAvatar(
                radius: 16,
                backgroundColor: PetColors.primary,
                child: Icon(Icons.person_outline, size: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  _intro(l),
                  const SizedBox(height: 16),
                  _photosSection(l),
                  const SizedBox(height: 24),
                  _identitySection(l),
                  const SizedBox(height: 24),
                  _healthSection(l),
                  const SizedBox(height: 24),
                  _notesSection(l),
                  const SizedBox(height: 24),
                  _heartBanner(l),
                ],
              ),
              Positioned(left: 16, right: 16, bottom: 12, child: SafeArea(top: false, child: _actionBar(l))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _intro(AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: PetColors.secondaryContainer,
            borderRadius: BorderRadius.circular(999),
            boxShadow: petCardShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pets, size: 14, color: PetColors.onSecondaryContainer),
              const SizedBox(width: 4),
              Text(l.petsFormBadge, style: PetText.labelSm.copyWith(color: PetColors.onSecondaryContainer)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _editing ? l.petsFormHeadingEdit(widget.pet!.name) : l.petsFormHeadingNew,
          style: PetText.headlineLgMobile.copyWith(letterSpacing: -0.5),
        ),
        const SizedBox(height: 2),
        Text(l.petsFormIntro, style: PetText.bodyMd),
      ],
    );
  }

  Widget _photosSection(AppLocalizations l) {
    final count = _photos.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(l.petsFormPhotosTitle, style: PetText.headlineSm)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: PetColors.surfaceHighest, borderRadius: BorderRadius.circular(999)),
              child: Text(
                l.petsFormPhotosCount(count, maxPetPhotos),
                style: PetText.labelMd.copyWith(color: PetColors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 4.0;
            final cell = (constraints.maxWidth - 3 * gap) / 4;
            final main = cell * 2 + gap;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: main, height: main, child: _mainPhotoSlot(l)),
                const SizedBox(width: gap),
                SizedBox(
                  width: main,
                  child: Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (var i = 1; i < maxPetPhotos; i++)
                        SizedBox(width: cell, height: cell, child: _photoSlot(l, i)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: PetColors.surfaceLow, borderRadius: BorderRadius.circular(12)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('💡', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 4),
              Expanded(child: Text(l.petsFormPhotoTip, style: PetText.bodySm)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mainPhotoSlot(AppLocalizations l) {
    if (_photos.isEmpty) return _AddPhotoSlot(onTap: _addPhoto, label: l.petsFormPhotoMainSlot, large: true);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          PetImage(bytes: _photos.first.bytes),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [PetColors.onSurface.withValues(alpha: 0.6), Colors.transparent],
                stops: const [0, 0.5],
              ),
            ),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: PetColors.primary.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, size: 12, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(l.petsFormPhotoMain, style: PetText.labelSm.copyWith(color: Colors.white)),
                ],
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: _MiniCircleButton(
              icon: Icons.edit_outlined,
              tooltip: l.petsFormPhotoReplace,
              onTap: () => _addPhoto(replaceIndex: 0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoSlot(AppLocalizations l, int index) {
    if (index >= _photos.length) return _AddPhotoSlot(onTap: _addPhoto, label: l.petsAdd);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          PetImage(bytes: _photos[index].bytes, iconSize: 20),
          Positioned.fill(
            child: Tooltip(
              message: l.petsFormPhotoMakeMain,
              child: Material(
                color: Colors.transparent,
                child: InkWell(onTap: () => _makeCover(index)),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: _MiniCircleButton(icon: Icons.close, tooltip: l.petsFormPhotoRemove, onTap: () => _removePhoto(index)),
          ),
        ],
      ),
    );
  }

  Widget _identitySection(AppLocalizations l) {
    return _SectionCard(
      icon: Icons.badge_outlined,
      title: l.petsFormIdentity,
      children: [
        _Field(
          label: l.petsFormName,
          required: true,
          controller: _name,
          hint: l.petsFormNameHint,
          error: _submitted ? _nameError(l) : null,
          textCapitalization: TextCapitalization.words,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Label(text: l.petsFormSpecies, required: true),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final species in PetSpecies.values)
                  _SpeciesChip(
                    emoji: species.emoji,
                    label: speciesLabel(l, species),
                    selected: _species == species,
                    onTap: () => setState(() => _species = species),
                  ),
              ],
            ),
          ],
        ),
        _Field(
          label: l.petsFormBreed,
          controller: _breed,
          hint: l.petsFormBreedHint,
          help: l.petsFormBreedHelp,
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Label(text: l.petsFormSex, required: true),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: PetColors.surfaceContainer, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  for (final sex in PetSex.values) ...[
                    if (sex != PetSex.values.first) const SizedBox(width: 4),
                    Expanded(
                      child: _SegmentButton(
                        icon: sex == PetSex.male ? Icons.male : Icons.female,
                        label: sexLabel(l, sex),
                        selected: _sex == sex,
                        onTap: () => setState(() => _sex = sex),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            Material(
              color: PetColors.surfaceLow,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _sterilized = !_sterilized),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.medical_services_outlined, size: 20, color: PetColors.primary),
                      const SizedBox(width: 4),
                      Expanded(child: Text(l.petsFormSterilized, style: PetText.labelLg)),
                      Switch(
                        value: _sterilized,
                        onChanged: (value) => setState(() => _sterilized = value),
                        activeTrackColor: PetColors.primary,
                        activeThumbColor: Colors.white,
                        inactiveTrackColor: PetColors.surfaceHighest,
                        inactiveThumbColor: Colors.white,
                        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _healthSection(AppLocalizations l) {
    final birthError = _submitted ? _birthError(l) : null;
    return _SectionCard(
      icon: Icons.monitor_heart_outlined,
      title: l.petsFormHealth,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Label(text: l.petsFormBirthDate, required: true),
            const SizedBox(height: 4),
            Material(
              color: birthError == null ? PetColors.surfaceContainer : PetColors.errorContainer,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _pickBirthDate,
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _birthDate == null ? l.petsFormDateHint : formatInputDate(_birthDate!),
                          style: PetText.bodyLg.copyWith(color: _birthDate == null ? PetColors.outline : null),
                        ),
                      ),
                      const Icon(Icons.calendar_today_outlined, size: 22, color: PetColors.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),
            if (birthError != null) _ErrorText(birthError),
            const SizedBox(height: 4),
            InkWell(
              onTap: () => setState(() => _birthEstimated = !_birthEstimated),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _birthEstimated,
                      onChanged: (value) => setState(() => _birthEstimated = value ?? false),
                      activeColor: PetColors.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(child: Text(l.petsFormBirthEstimated, style: PetText.bodySm)),
                ],
              ),
            ),
          ],
        ),
        _Field(
          label: l.petsFormWeight,
          controller: _weight,
          hint: l.petsFormWeightHint,
          help: l.petsFormWeightHelp,
          error: _submitted ? _weightError(l) : null,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          suffix: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: PetColors.surfaceHighest, borderRadius: BorderRadius.circular(4)),
            child: Text('kg', style: PetText.labelMd.copyWith(color: PetColors.primary)),
          ),
        ),
        _Field(
          label: l.petsFormIdentification,
          optionalLabel: l.petsFormOptional,
          controller: _chip,
          hint: l.petsFormChipHint,
          error: _submitted ? _chipError(l) : null,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(15)],
          monospace: true,
          suffix: const Icon(Icons.qr_code_scanner, size: 22, color: PetColors.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _notesSection(AppLocalizations l) {
    return _SectionCard(
      icon: Icons.edit_note,
      title: l.petsFormNotes,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Label(text: l.petsFormNotesLabel),
            const SizedBox(height: 4),
            TextField(
              controller: _notes,
              minLines: 3,
              maxLines: 6,
              style: PetText.bodyLg,
              inputFormatters: [LengthLimitingTextInputFormatter(_notesMax)],
              decoration: _decoration(hint: l.petsFormNotesHint, padding: const EdgeInsets.all(16)),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: Text(l.petsFormNotesPrivate, style: PetText.bodySm)),
                Text('${_notes.text.length} / $_notesMax', style: PetText.labelSm),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _heartBanner(AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PetColors.tertiaryFixed,
        borderRadius: BorderRadius.circular(12),
        boxShadow: petCardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: PetColors.secondaryContainer, shape: BoxShape.circle),
            child: const Icon(Icons.favorite_border, size: 20, color: PetColors.onSecondaryContainer),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.petsFormHeartTitle,
                  style: PetText.labelLg.copyWith(color: PetColors.onTertiaryFixed, fontWeight: FontWeight.w700),
                ),
                Text(
                  l.petsFormHeartBody,
                  style: PetText.bodySm.copyWith(color: PetColors.onTertiaryFixed.withValues(alpha: 0.9)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBar(AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: PetColors.surfaceLowest.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 25, offset: Offset(0, 10))],
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
            style: TextButton.styleFrom(
              backgroundColor: PetColors.surfaceLow,
              foregroundColor: PetColors.onSurface,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(l.petsCancel, style: PetText.labelLg),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: PetColors.primaryContainer,
                minimumSize: const Size.fromHeight(48),
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            l.petsFormSave,
                            overflow: TextOverflow.ellipsis,
                            style: PetText.labelLg.copyWith(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _decoration({
  required String hint,
  bool error = false,
  Widget? suffix,
  EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  bool monospace = false,
}) {
  const none = OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide.none);
  return InputDecoration(
    filled: true,
    fillColor: error ? PetColors.errorContainer : PetColors.surfaceContainer,
    hintText: hint,
    hintStyle: PetText.bodyLg.copyWith(color: PetColors.outline, fontFamily: monospace ? 'monospace' : null),
    hintMaxLines: 3,
    contentPadding: padding,
    counterText: '',
    suffixIcon: error
        ? const Icon(Icons.error, size: 22, color: PetColors.error)
        : suffix == null
            ? null
            : Padding(padding: const EdgeInsets.only(right: 8), child: Center(widthFactor: 1, child: suffix)),
    border: none,
    enabledBorder: none,
    focusedBorder: none,
    errorBorder: none,
    focusedErrorBorder: none,
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.icon, required this.title, required this.children});

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PetColors.surfaceLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: petCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: PetColors.primary),
              const SizedBox(width: 4),
              Text(title, style: PetText.headlineSm),
            ],
          ),
          for (final child in children) ...[const SizedBox(height: 16), child],
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text, this.required = false, this.optionalLabel});

  final String text;
  final bool required;
  final String? optionalLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              text: text,
              style: PetText.labelLg,
              children: [
                if (required)
                  const TextSpan(text: ' *', style: TextStyle(color: PetColors.error, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
        if (optionalLabel != null) Text(optionalLabel!, style: PetText.labelSm),
      ],
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(text, style: PetText.bodySm.copyWith(color: PetColors.error)),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.required = false,
    this.optionalLabel,
    this.help,
    this.error,
    this.suffix,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.monospace = false,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final bool required;
  final String? optionalLabel;
  final String? help;
  final String? error;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool monospace;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Label(text: label, required: required, optionalLabel: optionalLabel),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          textCapitalization: textCapitalization,
          style: PetText.bodyLg.copyWith(
            color: hasError ? PetColors.onErrorContainer : PetColors.onSurface,
            fontFamily: monospace ? 'monospace' : null,
          ),
          decoration: _decoration(hint: hint, error: hasError, suffix: suffix, monospace: monospace),
        ),
        if (hasError)
          _ErrorText(error!)
        else if (help != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(help!, style: PetText.bodySm),
          ),
      ],
    );
  }
}

class _SpeciesChip extends StatelessWidget {
  const _SpeciesChip({required this.emoji, required this.label, required this.selected, required this.onTap});

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? PetColors.primary : PetColors.surfaceContainer,
        shape: const StadiumBorder(),
        elevation: selected ? 0.5 : 0,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji),
                const SizedBox(width: 6),
                Text(label, style: PetText.labelMd.copyWith(color: selected ? Colors.white : PetColors.onSurface)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? PetColors.primary : PetColors.onSurfaceVariant;
    return Material(
      color: selected ? PetColors.surfaceLowest : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      elevation: selected ? 0.5 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 4),
              Text(label, style: PetText.labelLg.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddPhotoSlot extends StatelessWidget {
  const _AddPhotoSlot({required this.onTap, required this.label, this.large = false});

  final VoidCallback onTap;
  final String label;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PetColors.surfaceLowest,
      borderRadius: BorderRadius.circular(12),
      elevation: 0.5,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: large ? 44 : 32,
              height: large ? 44 : 32,
              decoration: const BoxDecoration(color: PetColors.primaryFixed, shape: BoxShape.circle),
              child: Icon(Icons.add, size: large ? 24 : 18, color: PetColors.onPrimaryFixed),
            ),
            const SizedBox(height: 4),
            Text(label, style: PetText.labelSm, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _MiniCircleButton extends StatelessWidget {
  const _MiniCircleButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: PetColors.surfaceLowest.withValues(alpha: 0.9),
        shape: const CircleBorder(),
        elevation: 0.5,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 28, height: 28, child: Icon(icon, size: 16, color: PetColors.onSurface)),
        ),
      ),
    );
  }
}
