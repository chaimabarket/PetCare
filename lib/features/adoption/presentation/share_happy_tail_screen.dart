import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/widgets/auth_feedback.dart';
import '../../profile/data/profile_repository.dart';
import '../data/adoption_listing.dart';
import '../data/happy_tail.dart';
import '../data/happy_tail_repository.dart';
import '../data/photo_picker.dart';
import 'widgets/adoption_widgets.dart';
import 'widgets/happy_tail_card.dart';

/// « Partager notre histoire » : l'adoptant publie son Happy Tail (maquette du même nom).
class ShareHappyTailScreen extends StatefulWidget {
  const ShareHappyTailScreen({super.key, required this.listing});

  /// Annonce adoptée par l'utilisateur connecté.
  final AdoptionListing listing;

  @override
  State<ShareHappyTailScreen> createState() => _ShareHappyTailScreenState();
}

class _ShareHappyTailScreenState extends State<ShareHappyTailScreen> {
  static const storyMax = 1000;
  static const _ideas = ['🌙 La première nuit', '🛋️ Son endroit préféré', '✨ Le déclic de confiance'];

  final _repository = HappyTailRepository();
  final _title = TextEditingController();
  final _story = TextEditingController();
  Uint8List? _after;
  String _authorName = '';
  var _existing = false;
  var _publicConsent = false;
  var _saving = false;
  var _loading = true;
  String? _error;

  AdoptionListing get _listing => widget.listing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final profile = await ProfileRepository().watch(uid).first;
    HappyTail? tail;
    try {
      tail = await _repository.watch(_listing.id).first;
    } catch (_) {
      tail = null;
    }
    if (!mounted) return;
    setState(() {
      _authorName = profile?.fullName ?? '';
      if (tail != null) {
        _existing = true;
        _publicConsent = true;
        _title.text = tail.title;
        _story.text = tail.story;
        _after = tail.after;
      }
      _loading = false;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _story.dispose();
    super.dispose();
  }

  Future<void> _pickAfter() async {
    try {
      final photo = await PhotoPicker().pickOne();
      if (photo != null && mounted) setState(() => _after = photo);
    } on PhotoTooLargeException catch (e) {
      if (mounted) showAdoptionMessage(context, e.message);
    }
  }

  void _addIdea(String idea) {
    final text = _story.text.trim();
    final label = idea.substring(idea.indexOf(' ') + 1);
    _story.text = text.isEmpty ? '$label : ' : '$text\n\n$label : ';
    _story.selection = TextSelection.collapsed(offset: _story.text.length);
    setState(() {});
  }

  Future<void> _publish() async {
    final error = switch ((_title.text.trim(), _story.text.trim(), _after, _publicConsent)) {
      (final t, _, _, _) when t.isEmpty => 'Donnez un titre à votre histoire.',
      (_, final s, _, _) when s.length < 30 => 'Racontez votre histoire en quelques phrases (30 caractères minimum).',
      (_, _, null, _) => 'Ajoutez une photo « Après » dans son nouveau foyer.',
      (_, _, _, false) => 'Confirmez que votre histoire peut être affichée publiquement.',
      _ => null,
    };
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final profile = await ProfileRepository().watch(uid).first;
      if (profile == null) throw StateError('profil absent');
      await _repository.save(
        listing: _listing,
        author: profile,
        title: _title.text,
        story: _story.text,
        after: _after!,
        exists: _existing,
      );
      if (!mounted) return;
      showAdoptionMessage(context, 'Votre histoire est en ligne 💛');
      Navigator.of(context).pushReplacementNamed(AppRoutes.happyTails);
    } catch (e) {
      debugPrint('ShareHappyTailScreen: $e');
      if (mounted) setState(() => _error = 'La publication a échoué. Vérifiez votre connexion et la taille de la photo.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: const Text('Partager notre histoire', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                AdoptionCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: PetPhoto(
                          bytes: _listing.cover,
                          species: _listing.species,
                          emojiSize: 26,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(_listing.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: StatusPill(
                                    label: 'Adopté le ${formatShortDate(_listing.adoptedAt)}',
                                    tone: PillTone.adopted,
                                    icon: Icons.favorite_border,
                                  ),
                                ),
                              ],
                            ),
                            Text(_listing.publisherName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TipBanner(
                  icon: Icons.auto_awesome_outlined,
                  title: "Votre histoire donne de l'espoir",
                  text: "Racontez l'évolution de ${_listing.name} pour inspirer de futures familles.",
                ),
                const SizedBox(height: 20),
                const BarTitle('Photos Avant / Après'),
                Row(
                  children: [
                    Expanded(
                      child: _PhotoSlot(
                        label: 'Photo de l\'annonce',
                        hint: 'Reprise automatiquement',
                        child: PetPhoto(bytes: _listing.cover, species: _listing.species, borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PhotoSlot(
                        label: 'Dans son foyer',
                        hint: _after == null ? 'Ajouter une photo' : 'Changer la photo',
                        onTap: _pickAfter,
                        child: _after == null
                            ? Container(
                                decoration: BoxDecoration(
                                  color: AdoptionColors.blueSurface,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.add_a_photo_outlined, size: 32, color: AdoptionColors.tealDeep),
                              )
                            : PetPhoto(bytes: _after, species: _listing.species, borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                AdoptionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const CardHeader(icon: Icons.history_edu_outlined, title: "Votre récit d'adoption"),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _title,
                        maxLength: 90,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(labelText: "Titre de l'histoire", hintText: 'De timide craintive à reine des siestes'),
                      ),
                      TextField(
                        controller: _story,
                        minLines: 5,
                        maxLines: 10,
                        maxLength: storyMax,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(labelText: 'Racontez son évolution', alignLabelWithHint: true),
                      ),
                      const Text('Idées à partager :', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [for (final idea in _ideas) ActionChip(label: Text(idea), onPressed: () => _addIdea(idea))],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Icon(Icons.visibility_outlined, color: AdoptionColors.tealDeep),
                    SizedBox(width: 6),
                    Text('Aperçu en direct', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 10),
                HappyTailCard(
                  authorName: _authorName,
                  animalName: _listing.name,
                  species: _listing.species,
                  breed: _listing.breed,
                  publisherName: _listing.publisherName,
                  title: _title.text.trim(),
                  story: _story.text.trim(),
                  likeCount: 0,
                  liked: false,
                  before: _listing.cover,
                  after: _after,
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: _publicConsent,
                  onChanged: (v) => setState(() => _publicConsent = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Publier sur la page Happy Tails', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Votre histoire et vos photos seront visibles par tous les membres de PetCare Community.'),
                ),
                if (_error != null) ...[const SizedBox(height: 8), ErrorBanner(_error!)],
              ],
            ),
      bottomNavigationBar: _loading
          ? null
          : BottomActions(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.coral, foregroundColor: AdoptionColors.brown),
                    onPressed: _saving ? null : _publish,
                    icon: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.favorite_border),
                    label: Text(_existing ? "Mettre à jour l'histoire" : 'Publier notre histoire'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({required this.label, required this.hint, required this.child, this.onTap});

  final String label;
  final String hint;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(aspectRatio: 1, child: child),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Text(hint, style: TextStyle(fontSize: 12, color: onTap == null ? AppColors.textSecondary : AppColors.teal)),
        ],
      ),
    );
  }
}
