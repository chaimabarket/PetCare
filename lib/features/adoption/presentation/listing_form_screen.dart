import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/widgets/auth_feedback.dart';
import '../../profile/data/profile_repository.dart';
import '../data/adoption_enums.dart';
import '../data/adoption_listing.dart';
import '../data/adoption_repository.dart';
import '../data/photo_picker.dart';
import 'widgets/adoption_widgets.dart';

/// Publier ou modifier une annonce (maquette « Publier une annonce d'adoption »).
///
/// Module 1 : quand la collection des animaux existera, proposer « Choisir un animal » en tête
/// du formulaire pour préremplir le nom, l'espèce, la race, le sexe, la date de naissance et les photos.
class ListingFormScreen extends StatefulWidget {
  const ListingFormScreen({super.key, this.listing});

  /// Annonce à modifier ; `null` pour une nouvelle annonce.
  final AdoptionListing? listing;

  @override
  State<ListingFormScreen> createState() => _ListingFormScreenState();
}

class _ListingFormScreenState extends State<ListingFormScreen> {
  static const maxBadges = 5;
  static const storyMax = 1000;

  final _formKey = GlobalKey<FormState>();
  final _repository = AdoptionRepository();
  final _picker = PhotoPicker();
  late final ListingDraft _draft = widget.listing == null ? ListingDraft() : ListingDraft.fromListing(widget.listing!, []);

  late final _name = TextEditingController(text: _draft.name);
  late final _breed = TextEditingController(text: _draft.breed);
  late final _city = TextEditingController(text: _draft.city);
  late final _title = TextEditingController(text: _draft.title);
  late final _story = TextEditingController(text: _draft.story);
  late final _needs = TextEditingController(text: _draft.needs);
  late final _conditions = TextEditingController(text: _draft.conditions);

  var _loadingPhotos = false;
  var _saving = false;
  String? _error;

  bool get _editing => widget.listing != null;

  @override
  void initState() {
    super.initState();
    if (_editing) {
      _loadPhotos();
    } else {
      _prefillCity();
    }
  }

  Future<void> _loadPhotos() async {
    setState(() => _loadingPhotos = true);
    try {
      final photos = await _repository.fetchPhotos(widget.listing!.id);
      if (mounted) setState(() => _draft.photos = photos);
    } finally {
      if (mounted) setState(() => _loadingPhotos = false);
    }
  }

  Future<void> _prefillCity() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final profile = await ProfileRepository().watch(uid).first;
    if (mounted && profile != null && _city.text.isEmpty) _city.text = profile.city;
  }

  @override
  void dispose() {
    for (final c in [_name, _breed, _city, _title, _story, _needs, _conditions]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _addPhotos() async {
    final photos = await _picker.pickMany(limit: AdoptionRepository.maxPhotos - _draft.photos.length);
    if (photos.isNotEmpty && mounted) setState(() => _draft.photos = [..._draft.photos, ...photos]);
  }

  void _makeCover(int index) {
    setState(() {
      final photos = [..._draft.photos];
      final photo = photos.removeAt(index);
      _draft.photos = [photo, ...photos];
    });
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _draft.birthDate,
      firstDate: DateTime(now.year - 30),
      lastDate: now,
      helpText: 'Date de naissance (approximative)',
    );
    if (picked != null) setState(() => _draft.birthDate = picked);
  }

  Future<void> _save({required bool publish}) async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) {
      setState(() => _error = 'Vérifiez les champs en rouge.');
      return;
    }
    if (publish && _draft.photos.isEmpty) {
      setState(() => _error = 'Ajoutez au moins une photo pour publier l\'annonce.');
      return;
    }
    _draft
      ..name = _name.text
      ..breed = _breed.text
      ..city = _city.text
      ..title = _title.text
      ..story = _story.text
      ..needs = _needs.text
      ..conditions = _conditions.text;

    final uid = FirebaseAuth.instance.currentUser!.uid;
    setState(() => _saving = true);
    try {
      final profile = await ProfileRepository().watch(uid).first;
      if (profile == null) throw const AdoptionException('Profil introuvable.');
      await _repository.saveListing(
        id: widget.listing?.id,
        draft: _draft,
        publisher: profile,
        publish: publish,
        currentStatus: widget.listing?.status,
      );
      if (!mounted) return;
      showAdoptionMessage(context, publish ? 'Annonce publiée 🐾' : 'Brouillon enregistré.');
      Navigator.of(context).pop();
    } on AdoptionException catch (e) {
      setState(() => _error = e.message);
    } catch (e, stackTrace) {
      debugPrint('ListingFormScreen: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _error = kDebugMode
          ? "L'enregistrement a échoué.\nDétail : $e"
          : "Impossible d'enregistrer l'annonce. Réessayez.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _archive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Archiver l'annonce ?"),
        content: const Text(
          "L'annonce ne sera plus visible. Les candidatures en attente seront refusées et les candidats informés.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Archiver')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _repository.archive(widget.listing!);
      if (!mounted) return;
      showAdoptionMessage(context, 'Annonce archivée.');
      Navigator.of(context).pop();
    } on AdoptionException catch (e) {
      if (mounted) showAdoptionMessage(context, e.message);
    }
  }

  String? _required(String? v, String message) => (v == null || v.trim().isEmpty) ? message : null;

  @override
  Widget build(BuildContext context) {
    final status = widget.listing?.status;
    final locked = status == ListingStatus.adopted;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Text(_editing ? "Modifier l'annonce" : 'Publier une annonce',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          if (_editing && status != ListingStatus.archived && status != ListingStatus.adopted)
            IconButton(tooltip: 'Archiver', onPressed: _archive, icon: const Icon(Icons.archive_outlined)),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            if (locked)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: TipBanner(
                  icon: Icons.celebration_outlined,
                  tone: TipTone.coral,
                  text: 'Cet animal a été adopté : seules les corrections de texte sont possibles.',
                ),
              ),
            _PhotosSection(
              photos: _draft.photos,
              loading: _loadingPhotos,
              onAdd: _addPhotos,
              onRemove: (i) => setState(() => _draft.photos = [..._draft.photos]..removeAt(i)),
              onMakeCover: _makeCover,
            ),
            const SizedBox(height: 16),
            _Card(
              icon: Icons.pets,
              title: "L'animal",
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nom *'),
                  validator: (v) => _required(v, "Indiquez le nom de l'animal."),
                ),
                const SizedBox(height: 12),
                const Text('Espèce', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in Species.values)
                      FilterPill(
                        label: s.label,
                        emoji: s.emoji,
                        selected: _draft.species == s,
                        onTap: () => setState(() => _draft.species = s),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _breed,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Race (facultatif)', hintText: 'Ex. Européen, croisé…'),
                ),
                const SizedBox(height: 12),
                SegmentedButton<Sex>(
                  showSelectedIcon: false,
                  segments: [for (final s in Sex.values) ButtonSegment(value: s, label: Text('${s.label} ${s.symbol}'))],
                  selected: {_draft.sex},
                  onSelectionChanged: (v) => setState(() => _draft.sex = v.first),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickBirthDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date de naissance (approximative)',
                      prefixIcon: Icon(Icons.cake_outlined),
                    ),
                    child: Text(formatShortDate(_draft.birthDate)),
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<PetSize>(
                  showSelectedIcon: false,
                  segments: [for (final s in PetSize.values) ButtonSegment(value: s, label: Text(s.label))],
                  selected: {_draft.size},
                  onSelectionChanged: (v) => setState(() => _draft.size = v.first),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _city,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: "Ville d'accueil *", prefixIcon: Icon(Icons.location_on_outlined)),
                  validator: (v) => _required(v, 'Indiquez la ville.'),
                ),
              ],
            ),
            _Card(
              icon: Icons.short_text,
              title: 'Informations principales',
              children: [
                TextFormField(
                  controller: _title,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: "Titre de l'annonce *", hintText: 'Douce Nala recherche une famille'),
                  validator: (v) => _required(v, 'Ajoutez un titre accrocheur.'),
                ),
                TextFormField(
                  controller: _story,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: storyMax,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Son histoire & tempérament *', alignLabelWithHint: true),
                  validator: (v) => (v == null || v.trim().length < 20) ? 'Racontez son histoire en quelques phrases.' : null,
                ),
              ],
            ),
            _Card(
              icon: Icons.psychology_alt_outlined,
              title: 'Traits de personnalité',
              trailing: StatusPill(label: '${_draft.badges.length}/$maxBadges', tone: PillTone.teal, dot: false),
              children: [
                const Text('Sélectionnez jusqu\'à 5 badges qui le ou la décrivent le mieux.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final b in PersonalityBadge.values)
                      BadgeChip(
                        badge: b,
                        selected: _draft.badges.contains(b),
                        onTap: () => setState(() {
                          if (_draft.badges.contains(b)) {
                            _draft.badges.remove(b);
                          } else if (_draft.badges.length < maxBadges) {
                            _draft.badges.add(b);
                          } else {
                            showAdoptionMessage(context, '5 badges maximum.');
                          }
                        }),
                      ),
                  ],
                ),
              ],
            ),
            _Card(
              icon: Icons.home_outlined,
              title: 'Compatibilités du foyer',
              children: [
                const Text('Ces réponses servent au score de compatibilité des candidatures.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                _Toggle(
                  label: 'OK enfants',
                  value: _draft.goodWithKids,
                  onChanged: (v) => setState(() => _draft.goodWithKids = v),
                ),
                _Toggle(
                  label: 'OK chats',
                  value: _draft.goodWithCats,
                  onChanged: (v) => setState(() => _draft.goodWithCats = v),
                ),
                _Toggle(
                  label: 'OK chiens',
                  value: _draft.goodWithDogs,
                  onChanged: (v) => setState(() => _draft.goodWithDogs = v),
                ),
                _Toggle(
                  label: "Besoin d'un jardin / extérieur",
                  value: _draft.needsGarden,
                  onChanged: (v) => setState(() => _draft.needsGarden = v),
                ),
              ],
            ),
            _Card(
              icon: Icons.bolt_outlined,
              title: 'Rythme de vie & autonomie',
              children: [
                const Text("Niveau d'énergie", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<EnergyLevel>(
                  showSelectedIcon: false,
                  segments: [for (final e in EnergyLevel.values) ButtonSegment(value: e, label: Text(e.label))],
                  selected: {_draft.energy},
                  onSelectionChanged: (v) => setState(() => _draft.energy = v.first),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Peut rester seul(e)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    StatusPill(label: '${_draft.okAloneHours} h / jour', tone: PillTone.teal, dot: false),
                  ],
                ),
                Slider(
                  value: _draft.okAloneHours.toDouble(),
                  max: 10,
                  divisions: 10,
                  label: '${_draft.okAloneHours} h',
                  onChanged: (v) => setState(() => _draft.okAloneHours = v.round()),
                ),
              ],
            ),
            _Card(
              icon: Icons.fact_check_outlined,
              title: 'Besoins & conditions',
              children: [
                TextFormField(
                  controller: _needs,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Besoins particuliers (facultatif)', alignLabelWithHint: true),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _conditions,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: "Conditions d'adoption *",
                    hintText: 'Frais, stérilisation, visite préalable…',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => _required(v, "Précisez les conditions d'adoption."),
                ),
              ],
            ),
            const TipBanner(
              tone: TipTone.coral,
              icon: Icons.shield_outlined,
              title: 'Charte de bienveillance',
              text: 'Les informations doivent être sincères et respecter le bien-être de l\'animal. '
                  'Le carnet de santé reste privé.',
            ),
            if (_error != null) ...[const SizedBox(height: 16), ErrorBanner(_error!)],
          ],
        ),
      ),
      bottomNavigationBar: BottomActions(
        children: [
          if (status == null || status == ListingStatus.draft) ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
              onPressed: _saving ? null : () => _save(publish: false),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Brouillon'),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: FilledButton.icon(
              onPressed: _saving ? null : () => _save(publish: true),
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.pets),
              label: Text(status == null || status == ListingStatus.draft || status == ListingStatus.archived
                  ? "Publier l'annonce"
                  : 'Enregistrer'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.icon, required this.title, required this.children, this.trailing});

  final IconData icon;
  final String title;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AdoptionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CardHeader(icon: icon, title: title, trailing: trailing),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _PhotosSection extends StatelessWidget {
  const _PhotosSection({
    required this.photos,
    required this.loading,
    required this.onAdd,
    required this.onRemove,
    required this.onMakeCover,
  });

  final List<Uint8List> photos;
  final bool loading;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onMakeCover;

  @override
  Widget build(BuildContext context) {
    final canAdd = photos.length < AdoptionRepository.maxPhotos;
    return AdoptionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeader(
            icon: Icons.photo_library_outlined,
            title: "Photos de l'annonce",
            subtitle: 'La première photo sert de couverture.',
            trailing: StatusPill(
              label: '${photos.length}/${AdoptionRepository.maxPhotos}',
              tone: photos.isEmpty ? PillTone.adopted : PillTone.teal,
              dot: false,
            ),
          ),
          const SizedBox(height: 14),
          if (loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (var i = 0; i < photos.length; i++)
                  _PhotoTile(
                    bytes: photos[i],
                    cover: i == 0,
                    onRemove: () => onRemove(i),
                    onMakeCover: i == 0 ? null : () => onMakeCover(i),
                  ),
                if (canAdd)
                  Material(
                    color: AdoptionColors.blueSurface,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: onAdd,
                      borderRadius: BorderRadius.circular(12),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, color: AdoptionColors.tealDeep),
                          SizedBox(height: 4),
                          Text('Ajouter', style: TextStyle(fontSize: 12, color: AdoptionColors.tealDeep)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          const Text('Format JPG ou PNG. Les photos sont réduites automatiquement.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.bytes, required this.cover, required this.onRemove, this.onMakeCover});

  final Uint8List bytes;
  final bool cover;
  final VoidCallback onRemove;
  final VoidCallback? onMakeCover;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GestureDetector(
            onTap: onMakeCover,
            child: Image.memory(bytes, fit: BoxFit.cover),
          ),
        ),
        if (cover)
          const Positioned(
            left: 4,
            top: 4,
            child: StatusPill(label: 'Couverture', tone: PillTone.adopted, icon: Icons.star),
          ),
        Positioned(
          right: 2,
          top: 2,
          child: IconButton.filled(
            tooltip: 'Retirer la photo',
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(backgroundColor: Colors.black54),
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 16),
          ),
        ),
      ],
    );
  }
}
