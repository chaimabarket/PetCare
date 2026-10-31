import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/routes.dart';
import '../../../core/widgets/coming_soon_screen.dart';
import '../../../l10n/app_localizations.dart';
import '../data/pet.dart';
import '../data/pet_media.dart';
import '../data/pet_repository.dart';
import 'pet_form_screen.dart';
import 'pet_format.dart';
import 'pet_style.dart';
import 'widgets/archive_pet_dialog.dart';
import 'widgets/pet_photo.dart';
import 'widgets/weight_chart.dart';

/// Largeur à partir de laquelle la fiche passe en deux colonnes (web, tablette).
const _wideBreakpoint = 900.0;

/// Fiche d'un animal (maquette « Profil de Milo »).
class PetDetailScreen extends StatefulWidget {
  const PetDetailScreen({super.key, required this.petId});

  final String petId;

  @override
  State<PetDetailScreen> createState() => _PetDetailScreenState();
}

class _PetDetailScreenState extends State<PetDetailScreen> {
  final _repository = PetRepository();
  late final _petStream = _repository.watch(widget.petId);
  late final _photosStream = _repository.watchPhotos(widget.petId);
  late final _weightsStream = _repository.watchWeights(widget.petId);

  int _selectedPhoto = 0;
  List<PetPhoto> _photos = const [];
  List<WeightEntry> _weights = const [];

  AppLocalizations get _l => AppLocalizations.of(context);

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  void _edit(Pet pet) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PetFormScreen(pet: pet, photos: _photos, currentWeight: _weights.firstOrNull),
        ),
      );

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    final error = _l.petsOpError;
    try {
      await action();
      if (success != null && mounted) _snack(success);
    } on PetException {
      if (mounted) _snack(error);
    }
  }

  Future<void> _archive(Pet pet) async {
    final success = _l.petsArchivedDone(pet.name, pet.isFemale.toString());
    // Modules Rendez-vous, Perdus & trouvés et Adoption : passer ici leurs éléments bloquants
    // (`blockers`) puis retirer `checksPending`.
    final confirmed = await showArchivePetDialog(context, petName: pet.name, checksPending: true);
    if (!confirmed) return;
    await _run(() => _repository.archive(pet.id), success: success);
  }

  Future<void> _restore(Pet pet) => _run(
        () => _repository.restore(pet.id),
        success: _l.petsRestoredDone(pet.name, pet.isFemale.toString()),
      );

  Future<void> _addPhoto() async {
    if (_photos.length >= maxPetPhotos) return;
    final bytes = await pickPetPhoto(context);
    if (bytes == null) return;
    await _run(() => _repository.addPhoto(widget.petId, bytes, position: _photos.length));
  }

  Future<void> _photoOptions(PetPhoto photo) async {
    final l = _l;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: PetColors.surfaceLowest,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (photo.sortOrder != 0)
              ListTile(
                leading: const Icon(Icons.star_outline, color: PetColors.primary),
                title: Text(l.petsFormPhotoMakeMain, style: PetText.labelLg),
                onTap: () => Navigator.of(context).pop('cover'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: PetColors.error),
              title: Text(l.petsPhotoDelete, style: PetText.labelLg.copyWith(color: PetColors.error)),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'cover') {
      setState(() => _selectedPhoto = 0);
      await _run(() => _repository.setCover(widget.petId, _photos, photo.id));
    } else if (action == 'delete') {
      setState(() => _selectedPhoto = 0);
      await _run(() => _repository.deletePhoto(widget.petId, _photos, photo.id), success: l.petsPhotoDeleted);
    }
  }

  void _openViewer() {
    if (_photos.isEmpty) return;
    final l = _l;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              child: Center(child: Image.memory(_photos[_selectedPhoto.clamp(0, _photos.length - 1)].bytes)),
            ),
          ),
          Positioned(
            top: 40,
            right: 16,
            child: IconButton(
              tooltip: l.petsClose,
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editNotes(Pet pet) async {
    final success = _l.petsNotesSaved;
    final notes = await showDialog<String>(
      context: context,
      builder: (_) => _NotesDialog(initial: pet.notes ?? ''),
    );
    if (notes == null) return;
    await _run(() => _repository.setNotes(pet.id, notes), success: success);
  }

  /// Assistant IA (branche `chatbot`) : une fois fusionné, ouvrir ici `AppRoutes.assistant` avec cet animal.
  void _openAdvice() {
    final title = _l.petsAdvice;
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ComingSoonScreen(title: title)));
  }

  Future<void> _addWeight() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _AddWeightDialog(
        petId: widget.petId,
        repository: _repository,
        previous: _weights.firstOrNull,
      ),
    );
  }

  void _openWeightHistory(Pet pet) {
    if (_weights.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PetColors.surfaceLowest,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _WeightHistorySheet(petId: widget.petId, repository: _repository, readOnly: pet.isArchived),
    );
  }

  Future<void> _addContact(Pet pet) async {
    final success = _l.petsContactAdded;
    final contact = await showDialog<PetContact>(context: context, builder: (_) => const _ContactDialog());
    if (contact == null) return;
    await _run(() => _repository.setContacts(pet.id, [...pet.contacts, contact]), success: success);
  }

  Future<void> _removeContact(Pet pet, int index) async {
    final l = _l;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.petsContactRemoveTitle, style: PetText.headlineSm),
        content: Text(l.petsContactRemoveBody(pet.contacts[index].name), style: PetText.bodyMd),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.petsCancel)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.petsRemove, style: const TextStyle(color: PetColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final contacts = [...pet.contacts]..removeAt(index);
    await _run(() => _repository.setContacts(pet.id, contacts));
  }

  Future<void> _call(String phone) async {
    final error = _l.petsCallError;
    final launched = await launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(' ', '')));
    if (!launched && mounted) _snack(error);
  }

  Future<void> _share(Pet pet) async {
    final l = _l;
    // Partage volontaire et limité (FR-31) : ni puce, ni notes privées, ni données médicales.
    final summary = [
      pet.name,
      [
        petKindLabel(l, pet),
        if (pet.hasBreed && pet.species != PetSpecies.other) pet.breed!,
        sexLabel(l, pet.sex),
        formatAge(l, pet.birthDate),
      ].join(' • '),
      l.petsShareFooter,
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: summary));
    if (mounted) _snack(l.petsShareCopied(pet.name));
  }

  @override
  Widget build(BuildContext context) {
    final l = _l;
    return StreamBuilder<Pet?>(
      stream: _petStream,
      builder: (context, petSnapshot) {
        final pet = petSnapshot.data;
        return Scaffold(
          backgroundColor: PetColors.surface,
          appBar: _appBar(l, pet),
          body: petSnapshot.hasError
              ? _Message(text: l.petsNotFound)
              : pet == null
                  ? (petSnapshot.connectionState == ConnectionState.active
                      ? _Message(text: l.petsDeleted)
                      : const Center(child: CircularProgressIndicator(color: PetColors.primary)))
                  : StreamBuilder<List<PetPhoto>>(
                      stream: _photosStream,
                      builder: (context, photosSnapshot) {
                        _photos = photosSnapshot.data ?? const [];
                        return StreamBuilder<List<WeightEntry>>(
                          stream: _weightsStream,
                          builder: (context, weightsSnapshot) {
                            _weights = weightsSnapshot.data ?? const [];
                            return LayoutBuilder(
                              builder: (context, constraints) => constraints.maxWidth >= _wideBreakpoint
                                  ? _wideContent(l, pet)
                                  : _content(l, pet),
                            );
                          },
                        );
                      },
                    ),
        );
      },
    );
  }

  PreferredSizeWidget _appBar(AppLocalizations l, Pet? pet) {
    return AppBar(
      backgroundColor: PetColors.surface,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 64,
      titleSpacing: 0,
      leading: IconButton(
        tooltip: l.petsBackTooltip,
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back, color: PetColors.onSurface),
      ),
      title: Text(
        pet == null ? '' : l.petsDetailTitle(pet.name),
        style: PetText.headlineSm,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        if (pet != null) ...[
          IconButton(
            tooltip: pet.favorite ? l.petsFavoriteRemove : l.petsFavoriteAdd,
            onPressed: pet.isArchived ? null : () => _run(() => _repository.setFavorite(pet.id, !pet.favorite)),
            icon: Icon(pet.favorite ? Icons.favorite : Icons.favorite_border, color: PetColors.secondary),
          ),
          PopupMenuButton<String>(
            tooltip: l.petsMoreOptions,
            icon: const Icon(Icons.more_vert, color: PetColors.onSurfaceVariant),
            color: PetColors.surfaceLowest,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  _edit(pet);
                case 'archive':
                  _archive(pet);
                case 'restore':
                  _restore(pet);
              }
            },
            itemBuilder: (_) => [
              if (!pet.isArchived)
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(Icons.edit_outlined, size: 20, color: PetColors.primary),
                      const SizedBox(width: 8),
                      Text(l.petsMenuEdit, style: PetText.labelMd.copyWith(fontSize: 14)),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: pet.isArchived ? 'restore' : 'archive',
                child: Row(
                  children: [
                    Icon(
                      pet.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                      size: 20,
                      color: PetColors.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      pet.isArchived ? l.petsMenuRestore : l.petsMenuArchive,
                      style: PetText.labelMd.copyWith(fontSize: 14, color: PetColors.secondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 16),
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
    );
  }

  /// Sections de la colonne d'informations (identité, poids, raccourcis, contacts, actions).
  List<Widget> _sections(AppLocalizations l, Pet pet) => [
        _identityCard(l, pet),
        const SizedBox(height: 24),
        _weightCard(l, pet),
        const SizedBox(height: 24),
        _healthCard(l),
        const SizedBox(height: 16),
        _appointmentsCard(l, pet),
        const SizedBox(height: 24),
        _contactsCard(l, pet),
        const SizedBox(height: 32),
        _bottomActions(l, pet),
      ];

  /// Téléphone : photo pleine largeur puis les cartes les unes sous les autres.
  Widget _content(AppLocalizations l, Pet pet) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _gallery(l, pet),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _sections(l, pet)),
        ),
      ],
    );
  }

  /// Web et tablette : galerie à gauche, informations à droite (maquette web).
  Widget _wideContent(AppLocalizations l, Pet pet) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ColoredBox(color: PetColors.surfaceLowest, child: _gallery(l, pet, heroHeight: 420)),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 6,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _sections(l, pet)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gallery(AppLocalizations l, Pet pet, {double heroHeight = 320}) {
    final selected = _photos.isEmpty ? null : _photos[_selectedPhoto.clamp(0, _photos.length - 1)];
    final canAdd = !pet.isArchived && _photos.length < maxPetPhotos;
    final thumbsTop = heroHeight - 24;

    return SizedBox(
      height: thumbsTop + 64 + 8,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: heroHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PetImage(bytes: selected?.bytes, iconSize: 72),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0x99000000), Colors.transparent, Color(0x33000000)],
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (pet.isArchived)
                        _OverlayBadge(
                          icon: Icons.inventory_2_outlined,
                          label: l.petsArchivedBadge,
                          background: PetColors.surfaceLowest.withValues(alpha: 0.9),
                          color: PetColors.onSurfaceVariant,
                        )
                      else
                        // Module 2 (Santé) : affichera ici l'état de santé réel (« En pleine forme »…).
                        _OverlayBadge(
                          icon: Icons.schedule,
                          label: l.petsHealthStatusBadge,
                          background: PetColors.surfaceLowest.withValues(alpha: 0.9),
                          color: PetColors.primary,
                        ),
                      if (pet.hasChip)
                        _OverlayBadge(
                          icon: Icons.qr_code_2,
                          label: l.petsIcad(truncateChip(pet.chipNumber!, keep: 9)),
                          background: PetColors.inverseSurface.withValues(alpha: 0.8),
                          color: PetColors.inverseOnSurface,
                        ),
                    ],
                  ),
                ),
                if (_photos.isNotEmpty)
                  Positioned(
                    right: 16,
                    bottom: 16 + 24,
                    child: Tooltip(
                      message: l.petsFullscreen,
                      child: Material(
                        color: PetColors.surfaceLowest.withValues(alpha: 0.9),
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _openViewer,
                          child: const SizedBox(
                            width: 36,
                            height: 36,
                            child: Icon(Icons.fullscreen, size: 18, color: PetColors.onSurface),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            top: thumbsTop,
            left: 0,
            right: 0,
            height: 72,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (var i = 0; i < _photos.length; i++) ...[
                  _Thumbnail(
                    photo: _photos[i],
                    selected: i == _selectedPhoto.clamp(0, _photos.length - 1),
                    onTap: () => setState(() => _selectedPhoto = i),
                    onLongPress: pet.isArchived ? null : () => _photoOptions(_photos[i]),
                  ),
                  const SizedBox(width: 8),
                ],
                if (canAdd)
                  Align(
                    alignment: Alignment.topCenter,
                    child: Material(
                      color: PetColors.surfaceLow,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _addPhoto,
                        child: SizedBox(
                          width: 64,
                          height: 64,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_a_photo_outlined, size: 20, color: PetColors.primary),
                              const SizedBox(height: 2),
                              Text(l.petsAdd, style: PetText.labelSm.copyWith(fontSize: 10, color: PetColors.primary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _identityCard(AppLocalizations l, Pet pet) {
    final birth = pet.birthDate == null
        ? l.petsSpecBirthUnknown
        : '${formatLongDate(l, pet.birthDate!)}${pet.birthDateEstimated ? ' ${l.petsSpecEstimated}' : ''}';

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(pet.name, style: PetText.headlineMd, overflow: TextOverflow.ellipsis)),
                        if (pet.hasChip) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(color: PetColors.primary, shape: BoxShape.circle),
                            child: const Icon(Icons.verified_outlined, size: 13, color: Colors.white),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${pet.hasBreed ? pet.breed : speciesLabel(l, pet.species)} • ${sexLabel(l, pet.sex)} ',
                            style: PetText.bodyMd,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Icône plutôt que le caractère ♂/♀, rendu en emoji coloré sur le web.
                        Icon(pet.isFemale ? Icons.female : Icons.male, size: 16, color: PetColors.primary),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: PetColors.surfaceLow, borderRadius: BorderRadius.circular(999)),
                child: Text(formatAge(l, pet.birthDate), style: PetText.labelMd.copyWith(color: PetColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _SpecTile(icon: Icons.pets, label: l.petsFormSpecies, value: petKindLabel(l, pet))),
              const SizedBox(width: 12),
              Expanded(
                child: _SpecTile(
                  icon: Icons.content_cut,
                  label: l.petsSpecSterilization,
                  value: pet.sterilized ? l.petsSpecYes(sterilizedLabel(l, pet)) : l.petsNo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _SpecTile(icon: Icons.cake_outlined, label: l.petsSpecBirth, value: birth)),
              const SizedBox(width: 12),
              Expanded(
                child: _SpecTile(
                  icon: Icons.badge_outlined,
                  label: l.petsFormIdentification,
                  value: pet.hasChip ? truncateChip(pet.chipNumber!, keep: 11) : l.petsSpecNotProvided,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PetColors.surfaceLow.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notes, size: 18, color: PetColors.secondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l.petsNotesTitle,
                        style: PetText.labelMd.copyWith(color: PetColors.secondary, letterSpacing: 0.6),
                      ),
                    ),
                    if (!pet.isArchived)
                      IconButton(
                        tooltip: l.petsNotesEdit,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _editNotes(pet),
                        icon: const Icon(Icons.edit_outlined, size: 16, color: PetColors.onSurfaceVariant),
                      ),
                  ],
                ),
                Text(
                  pet.notes == null ? l.petsNotesEmpty : '« ${pet.notes} »',
                  style: PetText.bodySm.copyWith(color: PetColors.onSurface, fontStyle: FontStyle.italic, height: 1.625),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _weightCard(AppLocalizations l, Pet pet) {
    final last = _weights.firstOrNull;
    final previous = _weights.length > 1 ? _weights[1] : null;
    final chartEntries = _weights.take(6).toList().reversed.toList();

    Widget? trend;
    if (last != null && previous != null) {
      final diff = last.weightKg - previous.weightKg;
      final days = last.measuredOn.difference(previous.measuredOn).inDays;
      final month = formatShortMonth(l, previous.measuredOn);
      final period = days <= 31
          ? l.petsWeightThisMonth
          : l.petsWeightSince(l.localeName.startsWith('fr') ? month.toLowerCase() : month);
      final stable = diff.abs() < 0.005;
      final text = stable ? l.petsWeightStable(period) : '${diff > 0 ? '+' : '-'}${formatKg(l, diff.abs())} kg $period';
      trend = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: PetColors.emerald100, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              stable
                  ? Icons.trending_flat
                  : diff > 0
                      ? Icons.trending_up
                      : Icons.trending_down,
              size: 12,
              color: PetColors.emerald800,
            ),
            const SizedBox(width: 2),
            Text(text, style: PetText.labelSm.copyWith(color: PetColors.emerald800)),
          ],
        ),
      );
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _openWeightHistory(pet),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: PetColors.surfaceLow, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.scale_outlined, size: 20, color: PetColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.petsWeightTitle, style: PetText.headlineSm),
                      Text(
                        last == null ? l.petsWeightNone : l.petsWeightLastAgo(formatDaysAgo(l, last.measuredOn)),
                        style: PetText.bodySm,
                      ),
                    ],
                  ),
                ),
                if (last != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text.rich(
                        TextSpan(
                          text: formatKg(l, last.weightKg),
                          style: PetText.headlineMd.copyWith(letterSpacing: -0.4),
                          children: const [TextSpan(text: ' kg', style: PetText.bodyMd)],
                        ),
                      ),
                      ?trend,
                    ],
                  ),
              ],
            ),
          ),
          if (chartEntries.isNotEmpty) ...[
            const SizedBox(height: 16),
            WeightChart(entries: chartEntries),
          ],
          if (!pet.isArchived) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _addWeight,
              style: TextButton.styleFrom(
                backgroundColor: PetColors.surfaceLow,
                foregroundColor: PetColors.primary,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: Text(l.petsWeightAdd, style: PetText.labelMd.copyWith(color: PetColors.primary)),
            ),
          ],
        ],
      ),
    );
  }

  /// Carte « Carnet de santé » : ouvre le carnet de santé de l'animal (module 2).
  Widget _healthCard(AppLocalizations l) {
    return _shortcutCard(
      icon: Icons.monitor_heart_outlined,
      iconBackground: PetColors.primary.withValues(alpha: 0.1),
      iconColor: PetColors.primary,
      title: l.petsScreenHealthBook,
      subtitle: l.petsHealthSubtitle,
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.healthRecord, arguments: widget.petId),
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(12)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.notification_important_outlined, size: 20, color: Color(0xFFD97706)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            l.petsHealthAlertTitle,
                            style: PetText.labelMd.copyWith(color: const Color(0xFF451A03)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const _SoonChip(),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(l.petsHealthAlertBody, style: PetText.bodySm.copyWith(color: const Color(0xFF92400E))),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _SoonCounter(label: l.petsCounterSoon(l.petsCounterVaccines))),
            Expanded(child: _SoonCounter(label: l.petsCounterSoon(l.petsCounterTreatments))),
          ],
        ),
      ],
    );
  }

  /// Carte « Rendez-vous » : ouvre l'agenda filtré sur cet animal (module 3).
  Widget _appointmentsCard(AppLocalizations l, Pet pet) {
    return _shortcutCard(
      icon: Icons.calendar_month_outlined,
      iconBackground: PetColors.secondaryFixed,
      iconColor: PetColors.secondary,
      title: l.petsScreenAppointments,
      subtitle: l.petsAppointmentsSubtitle,
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.agenda, arguments: pet.name),
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: PetColors.surfaceLow, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: PetColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(l.petsAppointmentNext, style: PetText.labelMd.copyWith(color: PetColors.primary)),
                  ),
                  const _SoonChip(),
                ],
              ),
              const SizedBox(height: 6),
              Text(l.petsAppointmentBody, style: PetText.bodySm),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.petsAppointmentNew, style: PetText.labelMd.copyWith(color: PetColors.primary)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward, size: 16, color: PetColors.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _shortcutCard({
    required IconData icon,
    required Color iconBackground,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    List<Widget> children = const [],
  }) {
    return Material(
      color: PetColors.surfaceLowest,
      borderRadius: BorderRadius.circular(16),
      elevation: 0.5,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: iconBackground, borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, size: 22, color: iconColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: PetText.headlineSm),
                        Text(subtitle, style: PetText.bodySm),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 20, color: PetColors.onSurfaceVariant),
                ],
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _contactsCard(AppLocalizations l, Pet pet) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.contact_phone_outlined, size: 20, color: PetColors.secondary),
              const SizedBox(width: 8),
              Expanded(child: Text(l.petsContactsTitle, style: PetText.headlineSm)),
              if (!pet.isArchived && pet.contacts.length < 5)
                IconButton(
                  tooltip: l.petsContactAdd,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _addContact(pet),
                  icon: const Icon(Icons.add, size: 18, color: PetColors.onSurfaceVariant),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (pet.contacts.isEmpty) Text(l.petsContactsEmpty, style: PetText.bodySm),
          for (var i = 0; i < pet.contacts.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _ContactTile(
              contact: pet.contacts[i],
              onCall: () => _call(pet.contacts[i].phone),
              onLongPress: pet.isArchived ? null : () => _removeContact(pet, i),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bottomActions(AppLocalizations l, Pet pet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!pet.isArchived) ...[
          FilledButton.icon(
            onPressed: () => _edit(pet),
            style: FilledButton.styleFrom(backgroundColor: PetColors.primary, minimumSize: const Size.fromHeight(48)),
            icon: const Icon(Icons.edit_outlined, size: 20),
            label: Text(
              l.petsEditInfo(pet.name),
              overflow: TextOverflow.ellipsis,
              style: PetText.labelLg.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          _SecondaryAction(
            icon: Icons.tips_and_updates_outlined,
            label: l.petsAdvice,
            color: PetColors.primary,
            onTap: _openAdvice,
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: _SecondaryAction(
                icon: Icons.ios_share,
                iconColor: PetColors.onSurfaceVariant,
                label: l.petsShare,
                color: PetColors.onSurface,
                onTap: () => _share(pet),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: pet.isArchived
                  ? _SecondaryAction(
                      icon: Icons.unarchive_outlined,
                      label: l.petsRestoreName(pet.name),
                      color: PetColors.primary,
                      onTap: () => _restore(pet),
                    )
                  : _SecondaryAction(
                      icon: Icons.archive_outlined,
                      label: l.petsArchiveName(pet.name),
                      color: PetColors.secondary,
                      onTap: () => _archive(pet),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PetColors.surfaceLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: petCardShadow,
      ),
      child: child,
    );
  }
}

/// Pastille « Bientôt disponible » des blocs alimentés par d'autres modules.
class _SoonChip extends StatelessWidget {
  const _SoonChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: PetColors.surfaceLowest, borderRadius: BorderRadius.circular(999)),
      child: Text(
        AppLocalizations.of(context).comingSoon,
        style: PetText.labelSm.copyWith(color: PetColors.onSurfaceVariant),
      ),
    );
  }
}

class _SoonCounter extends StatelessWidget {
  const _SoonCounter({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(color: PetColors.outline, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: PetText.bodySm.copyWith(color: PetColors.onSurface))),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(text, textAlign: TextAlign.center, style: PetText.bodyMd),
      ),
    );
  }
}

class _OverlayBadge extends StatelessWidget {
  const _OverlayBadge({required this.icon, required this.label, required this.background, required this.color});

  final IconData icon;
  final String label;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999), boxShadow: petCardShadow),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: PetText.labelSm.copyWith(color: color, letterSpacing: 0.4)),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.photo, required this.selected, required this.onTap, this.onLongPress});

  final PetPhoto photo;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: AnimatedScale(
        scale: selected ? 1.05 : 1,
        duration: const Duration(milliseconds: 150),
        child: AnimatedOpacity(
          opacity: selected ? 1 : 0.8,
          duration: const Duration(milliseconds: 150),
          child: GestureDetector(
            onTap: onTap,
            onLongPress: onLongPress,
            onSecondaryTap: onLongPress,
            child: Container(
              width: 64,
              height: 64,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: selected ? PetColors.primary.withValues(alpha: 0.2) : const Color(0x0D000000),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PetImage(bytes: photo.bytes, iconSize: 20),
                  if (selected) ColoredBox(color: PetColors.primary.withValues(alpha: 0.2)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpecTile extends StatelessWidget {
  const _SpecTile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: PetColors.surfaceLow, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: PetColors.surfaceLowest,
              borderRadius: BorderRadius.circular(8),
              boxShadow: petCardShadow,
            ),
            child: Icon(icon, size: 18, color: PetColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: PetText.bodySm),
                Text(value, style: PetText.labelMd, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact, required this.onCall, this.onLongPress});

  final PetContact contact;
  final VoidCallback onCall;
  final VoidCallback? onLongPress;

  String get _initials {
    final parts = contact.name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.first.replaceAll('.', '').toLowerCase() == 'dr') return 'Dr';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final emergency = contact.emergency;
    final accent = emergency ? PetColors.error : PetColors.primary;
    final subtitle = [if (contact.detail.isNotEmpty) contact.detail, contact.phone].join(' • ');

    return Material(
      color: emergency ? PetColors.errorContainer.withValues(alpha: 0.4) : PetColors.surfaceLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onLongPress: onLongPress,
        onSecondaryTap: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: emergency ? PetColors.error : PetColors.surfaceLowest,
                  shape: BoxShape.circle,
                  boxShadow: petCardShadow,
                ),
                child: emergency
                    ? const Icon(Icons.emergency_outlined, size: 18, color: Colors.white)
                    : Text(
                        _initials,
                        style: PetText.labelLg.copyWith(color: PetColors.primary, fontWeight: FontWeight.w700),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: PetText.labelMd.copyWith(color: emergency ? PetColors.onErrorContainer : null),
                    ),
                    Text(subtitle, style: PetText.bodySm),
                  ],
                ),
              ),
              Material(
                color: accent,
                shape: const CircleBorder(),
                elevation: 0.5,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onCall,
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(Icons.call, size: 18, color: Colors.white, semanticLabel: l.petsCall(contact.name)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color? iconColor;
  final VoidCallback onTap;

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
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: iconColor ?? color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label, overflow: TextOverflow.ellipsis, style: PetText.labelMd.copyWith(color: color)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotesDialog extends StatefulWidget {
  const _NotesDialog({required this.initial});

  final String initial;

  @override
  State<_NotesDialog> createState() => _NotesDialogState();
}

class _NotesDialogState extends State<_NotesDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: PetColors.surfaceLowest,
      title: Text(l.petsFormNotes, style: PetText.headlineSm),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 3,
        maxLines: 6,
        maxLength: 500,
        style: PetText.bodyLg,
        decoration: InputDecoration(hintText: l.petsNotesHint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.petsCancel)),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          child: Text(l.petsSave),
        ),
      ],
    );
  }
}

class _AddWeightDialog extends StatefulWidget {
  const _AddWeightDialog({required this.petId, required this.repository, this.previous, this.entry});

  final String petId;
  final PetRepository repository;
  final WeightEntry? previous;

  /// Pesée à corriger ; `null` pour en ajouter une.
  final WeightEntry? entry;

  @override
  State<_AddWeightDialog> createState() => _AddWeightDialogState();
}

class _AddWeightDialogState extends State<_AddWeightDialog> {
  late final _weight = TextEditingController(text: widget.entry?.weightKg.toString());
  late final _note = TextEditingController(text: widget.entry?.note);
  late DateTime _date = widget.entry?.measuredOn ?? DateTime.now();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _weight.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 40),
      lastDate: now,
      helpText: AppLocalizations.of(context).petsWeightDateHelp,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final value = double.tryParse(_weight.text.trim().replaceAll(',', '.'));
    if (value == null || value <= 0 || value > 500) {
      setState(() => _error = l.petsFormWeightError);
      return;
    }
    if ((value * 100).roundToDouble() != value * 100) {
      setState(() => _error = l.petsFormWeightDecimals);
      return;
    }

    // Valeur inhabituelle (écart de plus de 30 % avec la dernière pesée) : on demande confirmation.
    final previous = widget.previous;
    if (previous != null && (value - previous.weightKg).abs() / previous.weightKg > 0.3) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.petsWeightUnusualTitle, style: PetText.headlineSm),
          content: Text(
            l.petsWeightUnusualBody(formatKg(l, previous.weightKg), formatKg(l, value)),
            style: PetText.bodyMd,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.petsFix)),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.petsConfirm)),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final entry = widget.entry;
      if (entry == null) {
        await widget.repository.addWeight(widget.petId, date: _date, weightKg: value, note: _note.text);
      } else {
        await widget.repository.updateWeight(widget.petId, entry.id, weightKg: value, note: _note.text);
      }
      if (mounted) Navigator.of(context).pop();
    } on DuplicateWeightException {
      setState(() {
        _saving = false;
        _error = l.petsWeightDuplicate(formatLongDate(l, _date));
      });
    } on PetException {
      setState(() {
        _saving = false;
        _error = l.petsWeightSaveError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: PetColors.surfaceLowest,
      title: Text(widget.entry == null ? l.petsWeightAdd : l.petsWeightEdit, style: PetText.headlineSm),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _weight,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            style: PetText.bodyLg,
            decoration: InputDecoration(
              labelText: l.petsWeightLabel,
              suffixText: 'kg',
              errorText: _error,
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            // Le jour identifie la pesée : une correction ne le change pas.
            onTap: widget.entry == null ? _pickDate : null,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: l.petsDate,
                suffixIcon: widget.entry == null ? const Icon(Icons.calendar_today_outlined, size: 20) : null,
              ),
              child: Text(formatLongDate(l, _date), style: PetText.bodyLg),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLength: 250,
            style: PetText.bodyMd.copyWith(color: PetColors.onSurface),
            decoration: InputDecoration(labelText: l.petsNoteOptional, counterText: ''),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: Text(l.petsCancel)),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          child: Text(l.petsSave),
        ),
      ],
    );
  }
}

class _WeightHistorySheet extends StatelessWidget {
  const _WeightHistorySheet({required this.petId, required this.repository, required this.readOnly});

  final String petId;
  final PetRepository repository;

  /// Animal archivé : l'historique reste consultable, mais plus modifiable.
  final bool readOnly;

  /// [neighbour] est la pesée voisine : elle sert à repérer une correction inhabituelle.
  Future<void> _edit(BuildContext context, WeightEntry entry, WeightEntry? neighbour) => showDialog<void>(
        context: context,
        builder: (_) => _AddWeightDialog(petId: petId, repository: repository, previous: neighbour, entry: entry),
      );

  Future<void> _delete(BuildContext context, WeightEntry entry) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.petsWeightDeleteTitle, style: PetText.headlineSm),
        content: Text(
          l.petsWeightDeleteBody(formatKg(l, entry.weightKg), formatLongDate(l, entry.measuredOn)),
          style: PetText.bodyMd,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.petsCancel)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.petsDelete, style: const TextStyle(color: PetColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await repository.deleteWeight(petId, entry.id);
    } on PetException {
      messenger.showSnackBar(SnackBar(content: Text(l.petsOpError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scrollController) => StreamBuilder<List<WeightEntry>>(
        stream: repository.watchWeights(petId),
        builder: (context, snapshot) {
          final entries = snapshot.data ?? const <WeightEntry>[];
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text(l.petsWeightHistory, style: PetText.headlineSm),
              const SizedBox(height: 8),
              for (final (i, entry) in entries.indexed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.scale_outlined, color: PetColors.primary),
                  title: Text('${formatKg(l, entry.weightKg)} kg', style: PetText.labelLg),
                  subtitle: Text(
                    [formatLongDate(l, entry.measuredOn), if (entry.note != null) entry.note!].join(' • '),
                    style: PetText.bodySm,
                  ),
                  trailing: readOnly
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: l.petsWeightEdit,
                              onPressed: () => _edit(
                                context,
                                entry,
                                i + 1 < entries.length ? entries[i + 1] : (i > 0 ? entries[i - 1] : null),
                              ),
                              icon: const Icon(Icons.edit_outlined, color: PetColors.primary),
                            ),
                            IconButton(
                              tooltip: l.petsWeightDeleteTooltip,
                              onPressed: () => _delete(context, entry),
                              icon: const Icon(Icons.delete_outline, color: PetColors.error),
                            ),
                          ],
                        ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ContactDialog extends StatefulWidget {
  const _ContactDialog();

  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _detail = TextEditingController();
  final _phone = TextEditingController();
  bool _emergency = false;

  @override
  void dispose() {
    _name.dispose();
    _detail.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      PetContact(name: _name.text.trim(), detail: _detail.text.trim(), phone: _phone.text.trim(), emergency: _emergency),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: PetColors.surfaceLowest,
      title: Text(l.petsContactNew, style: PetText.headlineSm),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: l.petsContactName, hintText: l.petsContactNameHint),
                validator: (v) => (v ?? '').trim().length < 2 ? l.petsContactNameError : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _detail,
                decoration: InputDecoration(labelText: l.petsContactPlace, hintText: l.petsContactPlaceHint),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
                decoration: InputDecoration(labelText: l.petsContactPhone, hintText: '+216 71 000 000'),
                validator: (v) {
                  final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                  return digits.length < 8 || digits.length > 15 ? l.petsContactPhoneError : null;
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _emergency,
                onChanged: (value) => setState(() => _emergency = value),
                activeTrackColor: PetColors.error,
                title: Text(l.petsContactEmergency, style: PetText.labelLg),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.petsCancel)),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          child: Text(l.petsAdd),
        ),
      ],
    );
  }
}
