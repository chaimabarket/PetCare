import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/routes.dart';
import '../../../core/widgets/coming_soon_screen.dart';
import '../data/pet.dart';
import '../data/pet_media.dart';
import '../data/pet_repository.dart';
import 'pet_detail_screen.dart';
import 'pet_form_screen.dart';
import 'pet_format.dart';
import 'pet_style.dart';
import 'widgets/pet_photo.dart';

/// Onglet « Mes animaux » (maquettes « Mes animaux – liste » et « Mes animaux – aucun animal »).
class MyPetsScreen extends StatefulWidget {
  const MyPetsScreen({super.key});

  @override
  State<MyPetsScreen> createState() => _MyPetsScreenState();
}

class _MyPetsScreenState extends State<MyPetsScreen> {
  final _user = FirebaseAuth.instance.currentUser;
  late final _petsStream = _user == null ? null : PetRepository().watchMine(_user.uid);
  final _search = TextEditingController();

  bool _showArchived = false;
  bool _sortByName = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openForm() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PetFormScreen()));

  void _openComingSoon(String title) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ComingSoonScreen(title: title)),
      );

  List<Pet> _visible(List<Pet> pets) {
    final query = _search.text.trim().toLowerCase();
    final list = pets.where((p) => p.isArchived == _showArchived).where((p) {
      if (query.isEmpty) return true;
      return p.name.toLowerCase().contains(query) ||
          (p.breed ?? '').toLowerCase().contains(query) ||
          p.species.label.toLowerCase().contains(query) ||
          (p.chipNumber ?? '').contains(query);
    }).toList();
    if (_sortByName) {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else {
      // Une fiche tout juste créée n'a pas encore son horodatage serveur : elle passe en tête.
      final now = DateTime.now();
      list.sort((a, b) => (b.createdAt ?? now).compareTo(a.createdAt ?? now));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return const _VisitorState();

    return StreamBuilder<List<Pet>>(
      stream: _petsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _MessageState(
            icon: Icons.error_outline,
            text: 'Impossible de charger vos animaux. Vérifiez votre connexion.',
          );
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: PetColors.primary));

        final pets = snapshot.data!;
        if (pets.isEmpty) return _EmptyState(onAdd: _openForm, onComingSoon: _openComingSoon);

        final activeCount = pets.where((p) => !p.isArchived).length;
        final archivedCount = pets.length - activeCount;
        final visible = _visible(pets);

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _openForm,
            tooltip: 'Ajouter un nouvel animal',
            backgroundColor: PetColors.primaryContainer,
            foregroundColor: Colors.white,
            elevation: 6,
            shape: const StadiumBorder(),
            icon: const Icon(Icons.add, size: 22),
            label: Text('Ajouter un animal', style: PetText.labelLg.copyWith(color: Colors.white)),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: const BoxDecoration(
                      color: PetColors.primaryFixed,
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                      boxShadow: petCardShadow,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.pets, size: 15, color: PetColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          activeCount == 1 ? '1 animal enregistré' : '$activeCount animaux enregistrés',
                          style: PetText.labelSm.copyWith(color: PetColors.onPrimaryFixed),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _RoundIconButton(
                    icon: Icons.tune,
                    tooltip: 'Gérer les notifications de santé',
                    onTap: () => _openComingSoon('Rappels de santé'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                "Gérez la santé, l'alimentation et le suivi vétérinaire de vos fidèles compagnons au quotidien.",
                style: PetText.bodyMd,
              ),
              const SizedBox(height: 16),
              _SearchField(controller: _search),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      icon: Icons.check_circle_outline,
                      label: 'Actifs ($activeCount)',
                      selected: !_showArchived,
                      onTap: () => setState(() => _showArchived = false),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      icon: Icons.inventory_2_outlined,
                      label: 'Archivés ($archivedCount)',
                      selected: _showArchived,
                      onTap: () => setState(() => _showArchived = true),
                    ),
                    Container(
                      width: 1,
                      height: 20,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      color: PetColors.surfaceHigh,
                    ),
                    Material(
                      color: PetColors.surfaceLow,
                      shape: const StadiumBorder(),
                      child: InkWell(
                        customBorder: const StadiumBorder(),
                        onTap: () => setState(() => _sortByName = !_sortByName),
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.swap_vert, size: 16, color: PetColors.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(
                                _sortByName ? 'Nom (A-Z)' : 'Récents',
                                style: PetText.labelMd.copyWith(color: PetColors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (visible.isEmpty)
                _NoResult(
                  text: _search.text.trim().isNotEmpty
                      ? 'Aucun animal ne correspond à « ${_search.text.trim()} ».'
                      : _showArchived
                          ? 'Aucun animal archivé.'
                          : 'Aucun animal actif. Ajoutez un compagnon avec le bouton ci-dessous.',
                  actionLabel: _search.text.trim().isNotEmpty ? 'Réinitialiser la recherche' : null,
                  onAction: _search.clear,
                )
              else
                for (var i = 0; i < visible.length; i++) ...[
                  _PetCard(
                    key: ValueKey(visible[i].id),
                    pet: visible[i],
                    ringIndex: i,
                    onComingSoon: _openComingSoon,
                  ),
                  const SizedBox(height: 16),
                ],
              const SizedBox(height: 8),
              _FosterCard(onTap: () => _openComingSoon("Famille d'accueil")),
            ],
          ),
        );
      },
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: PetColors.surfaceContainer,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 32, height: 32, child: Icon(icon, size: 18, color: PetColors.onSurfaceVariant)),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: PetColors.surfaceLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: petCardShadow,
      ),
      child: TextField(
        controller: controller,
        style: PetText.bodyMd.copyWith(color: PetColors.onSurface),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          filled: false,
          isCollapsed: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          hintText: 'Rechercher par nom, race...',
          hintStyle: PetText.bodyMd.copyWith(color: PetColors.outline),
          prefixIcon: const Icon(Icons.search, size: 20, color: PetColors.onSurfaceVariant),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Effacer la recherche',
                  onPressed: controller.clear,
                  icon: const Icon(Icons.close, size: 18, color: PetColors.outline),
                ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : PetColors.onSurfaceVariant;
    return Material(
      color: selected ? PetColors.primaryContainer : PetColors.surfaceLowest,
      shape: const StadiumBorder(),
      elevation: 0.5,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: PetText.labelMd.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte d'un animal : avatar, identité, dernier poids et raccourcis Santé / Rendez-vous / Profil.
class _PetCard extends StatefulWidget {
  const _PetCard({super.key, required this.pet, required this.ringIndex, required this.onComingSoon});

  final Pet pet;
  final int ringIndex;
  final ValueChanged<String> onComingSoon;

  @override
  State<_PetCard> createState() => _PetCardState();
}

class _PetCardState extends State<_PetCard> {
  late final _lastWeight = PetRepository().watchWeights(widget.pet.id, limit: 1);

  static const _rings = [
    [PetColors.primaryContainer, PetColors.secondaryContainer],
    [PetColors.primaryContainer, PetColors.surfaceHigh],
    [PetColors.secondaryContainer, PetColors.surfaceHigh],
  ];

  void _openDetail() => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => PetDetailScreen(petId: widget.pet.id)),
      );

  @override
  Widget build(BuildContext context) {
    final pet = widget.pet;
    final ring = _rings[widget.ringIndex % _rings.length];
    final details = [
      formatAge(pet.birthDate),
      if (pet.hasChip)
        'Pucé (ICAD : ${truncateChip(pet.chipNumber!)})'
      else if (pet.sterilized)
        sterilizedLabel(pet),
    ].join(' • ');

    return Material(
      color: PetColors.surfaceLowest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 0.5,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: _openDetail,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PetAvatar(petId: pet.id, female: pet.isFemale, ring: ring),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(pet.name, style: PetText.headlineSm, overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 6),
                            if (pet.favorite)
                              const Icon(Icons.favorite, size: 18, color: PetColors.secondary)
                            else if (pet.hasChip)
                              const Icon(Icons.verified_outlined, size: 16, color: PetColors.primary),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(speciesAndBreed(pet), style: PetText.bodyMd),
                        const SizedBox(height: 2),
                        Text(details, style: PetText.bodySm.copyWith(color: PetColors.outline)),
                        StreamBuilder<List<WeightEntry>>(
                          stream: _lastWeight,
                          builder: (context, snapshot) {
                            final last = snapshot.data?.firstOrNull;
                            if (last == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: _WeightPill(entry: last),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: PetColors.surfaceLow.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _QuickButton(
                    icon: Icons.medical_services_outlined,
                    label: 'Santé',
                    color: PetColors.primaryContainer,
                    onTap: () => widget.onComingSoon('Carnet de santé'),
                  ),
                  const SizedBox(width: 8),
                  _QuickButton(
                    icon: Icons.calendar_today_outlined,
                    label: 'Rendez-vous',
                    color: PetColors.onSurfaceVariant,
                    onTap: () => widget.onComingSoon('Rendez-vous'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _openDetail,
                    style: TextButton.styleFrom(
                      foregroundColor: PetColors.primary,
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Profil', style: PetText.labelMd.copyWith(color: PetColors.primary)),
                        const Icon(Icons.chevron_right, size: 18),
                      ],
                    ),
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

class _PetAvatar extends StatelessWidget {
  const _PetAvatar({required this.petId, required this.female, required this.ring});

  final String petId;
  final bool female;
  final List<Color> ring;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 72,
            height: 72,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(begin: Alignment.bottomLeft, end: Alignment.topRight, colors: ring),
            ),
            child: ClipOval(child: PetCoverImage(petId: petId, iconSize: 28)),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: PetColors.surfaceLowest,
                shape: BoxShape.circle,
                boxShadow: petCardShadow,
              ),
              child: Icon(
                female ? Icons.female : Icons.male,
                size: 15,
                color: female ? PetColors.secondary : PetColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeightPill extends StatelessWidget {
  const _WeightPill({required this.entry});

  final WeightEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: PetColors.surfaceLow, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.scale_outlined, size: 16, color: PetColors.primaryContainer),
          const SizedBox(width: 6),
          Flexible(
            child: Text.rich(
              TextSpan(
                style: PetText.bodySm.copyWith(color: PetColors.onSurface),
                children: [
                  const TextSpan(text: 'Dernier poids : '),
                  TextSpan(
                    text: '${formatKg(entry.weightKg)} kg',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: '  (${formatSince(entry.measuredOn)})',
                    style: PetText.labelSm.copyWith(color: PetColors.outline),
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

class _QuickButton extends StatelessWidget {
  const _QuickButton({required this.icon, required this.label, required this.color, required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
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
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 6),
              Text(label, style: PetText.labelMd.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FosterCard extends StatelessWidget {
  const _FosterCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: PetColors.surfaceLow, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: PetColors.primaryFixed, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.volunteer_activism_outlined, size: 20, color: PetColors.primary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Famille d'accueil ou bénévole ?", style: PetText.labelLg),
                Text('Liez les fiches temporaires de votre association', style: PetText.bodySm),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: PetColors.surfaceLowest,
            shape: const CircleBorder(),
            elevation: 0.5,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: const SizedBox(
                width: 32,
                height: 32,
                child: Icon(Icons.add, size: 18, color: PetColors.primary, semanticLabel: 'Synchroniser une association'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoResult extends StatelessWidget {
  const _NoResult({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: PetColors.surfaceLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: petCardShadow,
      ),
      child: Column(
        children: [
          const Icon(Icons.pets, size: 32, color: PetColors.primaryFixedDim),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, style: PetText.bodyMd),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!, style: PetText.labelLg.copyWith(color: PetColors.primary)),
            ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: PetColors.primaryContainer),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: PetText.bodyMd),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class _VisitorState extends StatelessWidget {
  const _VisitorState();

  @override
  Widget build(BuildContext context) {
    return _MessageState(
      icon: Icons.pets,
      text: 'Connectez-vous pour créer le profil de vos animaux et suivre leur santé.',
      action: FilledButton(
        onPressed: () => Navigator.of(context).pushNamed(AppRoutes.login),
        child: const Text('Se connecter'),
      ),
    );
  }
}

/// État vide : aucun animal sur le compte.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd, required this.onComingSoon});

  final VoidCallback onAdd;
  final ValueChanged<String> onComingSoon;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mes compagnons', style: PetText.headlineLgMobile),
                  Text('Gérez la santé et le suivi de vos fidèles amis au quotidien.', style: PetText.bodyMd),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: PetColors.secondaryFixed,
                shape: BoxShape.circle,
                boxShadow: petCardShadow,
              ),
              child: const Icon(Icons.favorite, size: 20, color: PetColors.onSecondaryFixed),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: PetColors.surfaceLow, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const Icon(Icons.search, size: 20, color: PetColors.outline),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Rechercher par nom, race, puce...',
                  style: PetText.bodyMd.copyWith(color: PetColors.outline),
                ),
              ),
              const Icon(Icons.tune, size: 18, color: PetColors.outline),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            _CountChip(label: 'Actifs', selected: true),
            SizedBox(width: 8),
            _CountChip(label: 'Archivés', selected: false),
          ],
        ),
        const SizedBox(height: 24),
        _EmptyCard(onAdd: onAdd, onImport: () => onComingSoon('Importer une fiche')),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              const Expanded(child: Text('Ce qui vous attend avec PetCare', style: PetText.labelLg)),
              Text('3 outils clés', style: PetText.labelSm.copyWith(color: PetColors.primary)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const _BenefitTile(
          icon: Icons.menu_book_outlined,
          iconBackground: Color(0x1A0F766E),
          iconColor: PetColors.primaryContainer,
          title: 'Carnet de santé numérique',
          text: 'Poids, antécédents, stérilisation et ordonnances toujours accessibles.',
        ),
        const SizedBox(height: 8),
        const _BenefitTile(
          icon: Icons.notifications_active_outlined,
          iconBackground: PetColors.secondaryFixed,
          iconColor: PetColors.secondary,
          title: 'Rappels intelligents',
          text: 'Alertes automatiques pour vermifuges, vaccins et visites médicales.',
        ),
        const SizedBox(height: 8),
        const _BenefitTile(
          icon: Icons.diversity_1_outlined,
          iconBackground: PetColors.tertiaryFixed,
          iconColor: PetColors.tertiary,
          title: 'Réseau bienveillant',
          text: 'Garde entre passionnés vérifiés et conseils certifiés.',
        ),
        const SizedBox(height: 24),
        Material(
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [PetColors.surfaceHigh, PetColors.surfaceContainer, PetColors.surfaceLow],
              ),
            ),
            child: InkWell(
              onTap: () => onComingSoon('Guide de bienvenue'),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, size: 26, color: PetColors.primaryContainer),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Besoin d'aide pour démarrer ?", style: PetText.labelMd),
                          Text('Consultez notre guide de bienvenue', style: PetText.bodySm),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 20, color: PetColors.outline),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : PetColors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: selected ? PetColors.primary : PetColors.surfaceLow,
        borderRadius: BorderRadius.circular(999),
        boxShadow: selected ? petCardShadow : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: PetText.labelMd.copyWith(color: color)),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: selected ? Colors.white.withValues(alpha: 0.2) : PetColors.surfaceHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('0', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.onAdd, required this.onImport});

  final VoidCallback onAdd;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: PetColors.surfaceLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: petCardShadow,
      ),
      child: Stack(
        children: [
          const Positioned(top: -48, right: -48, child: _Glow(color: PetColors.secondaryFixed, opacity: 0.4)),
          const Positioned(bottom: -40, left: -40, child: _Glow(color: PetColors.primaryFixed, opacity: 0.3)),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                SizedBox(
                  width: 160,
                  height: 160,
                  child: Stack(
                    children: [
                      const Positioned.fill(child: CustomPaint(painter: _EmptyIllustrationPainter())),
                      Positioned(
                        right: 12,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: PetColors.surfaceLowest,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: const [
                              BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 4)),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(color: PetColors.secondary, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Nouveau départ',
                                style: PetText.labelSm.copyWith(color: PetColors.onSurface, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Vous n'avez pas encore ajouté d'animal",
                  textAlign: TextAlign.center,
                  style: PetText.headlineMd,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Créez le profil de votre protégé pour gérer son carnet de santé, planifier ses vaccins et '
                  'veiller sur son bien-être en toute quiétude.',
                  textAlign: TextAlign.center,
                  style: PetText.bodyMd,
                ),
                const SizedBox(height: 24),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: FilledButton.icon(
                    onPressed: onAdd,
                    style: FilledButton.styleFrom(
                      backgroundColor: PetColors.primaryContainer,
                      minimumSize: const Size.fromHeight(48),
                      elevation: 3,
                    ),
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    label: Text('Ajouter mon premier compagnon', style: PetText.labelLg.copyWith(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: onImport,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.verified_outlined, size: 16, color: PetColors.secondary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text.rich(
                          TextSpan(
                            style: PetText.labelMd.copyWith(color: PetColors.onSurfaceVariant),
                            children: const [
                              TextSpan(text: 'Vous venez d\'adopter sur PetCare ? '),
                              TextSpan(
                                text: 'Importer la fiche',
                                style: TextStyle(
                                  color: PetColors.primary,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.opacity});

  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 144,
      height: 144,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)]),
      ),
    );
  }
}

class _BenefitTile extends StatelessWidget {
  const _BenefitTile({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: PetColors.surfaceLow, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: iconBackground, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: PetText.labelLg),
                Text(text, style: PetText.bodySm, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Illustration de l'état vide (gamelle, laisse et patte), reprise du SVG de la maquette (160 × 160).
class _EmptyIllustrationPainter extends CustomPainter {
  const _EmptyIllustrationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 160, size.height / 160);
    Paint fill(Color c) => Paint()..color = c;

    canvas
      ..drawCircle(const Offset(80, 80), 68, fill(const Color(0xFFEFF4FF)))
      ..drawCircle(const Offset(80, 80), 54, fill(const Color(0xFFFFDBCF).withValues(alpha: 0.55)))
      ..drawOval(Rect.fromCenter(center: const Offset(62, 108), width: 68, height: 28), fill(const Color(0xFF0F766E)))
      ..drawOval(Rect.fromCenter(center: const Offset(62, 104), width: 56, height: 18), fill(const Color(0xFF80D5CB)))
      ..drawOval(Rect.fromCenter(center: const Offset(62, 103), width: 40, height: 11), fill(const Color(0xFF005C55)));

    final heart = Path()
      ..moveTo(62, 101.5)
      ..cubicTo(60, 99.5, 56.5, 101, 56.5, 103)
      ..cubicTo(56.5, 104.5, 62, 107.5, 62, 107.5)
      ..cubicTo(62, 107.5, 67.5, 104.5, 67.5, 103)
      ..cubicTo(67.5, 101, 64, 99.5, 62, 101.5)
      ..close();
    canvas.drawPath(heart, fill(Colors.white.withValues(alpha: 0.9)));

    final leash = Path()
      ..moveTo(106, 112)
      ..cubicTo(116, 110, 124, 100, 120, 86)
      ..cubicTo(116, 72, 100, 70, 94, 82)
      ..cubicTo(90, 90, 95, 98, 103, 98)
      ..cubicTo(110, 98, 114, 93, 112, 88);
    canvas.drawPath(
      leash,
      Paint()
        ..color = const Color(0xFF8C4E38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas
      ..save()
      ..translate(88, 78)
      ..rotate(-25 * 3.1415926535 / 180)
      ..drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 8, 13), const Radius.circular(4)),
        fill(const Color(0xFFFEAE92)),
      )
      ..restore();

    final paw = fill(const Color(0xFF0F766E));
    canvas
      ..save()
      ..translate(78, 52)
      ..rotate(8 * 3.1415926535 / 180)
      ..drawOval(Rect.fromCenter(center: Offset.zero, width: 14, height: 18), paw)
      ..restore()
      ..drawCircle(const Offset(67, 42), 3.2, paw)
      ..drawCircle(const Offset(75, 37), 3.2, paw)
      ..drawCircle(const Offset(85, 39), 3.2, paw)
      ..drawCircle(const Offset(92, 47), 3, paw);

    final star = Path()
      ..moveTo(112, 40)
      ..lineTo(113.8, 45.2)
      ..lineTo(119, 47)
      ..lineTo(113.8, 48.8)
      ..lineTo(112, 54)
      ..lineTo(110.2, 48.8)
      ..lineTo(105, 47)
      ..lineTo(110.2, 45.2)
      ..close();
    canvas
      ..drawPath(star, fill(const Color(0xFFFEAE92)))
      ..drawCircle(const Offset(44, 68), 2.5, fill(const Color(0xFF80D5CB)));
  }

  @override
  bool shouldRepaint(_EmptyIllustrationPainter oldDelegate) => false;
}
