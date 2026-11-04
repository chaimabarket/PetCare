import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../pets/data/pet.dart';
import '../../pets/data/pet_media.dart';
import '../../pets/data/pet_repository.dart';
import '../../pets/presentation/pet_form_screen.dart';
import '../../pets/presentation/pet_format.dart' as pet_format;
import '../data/health_repository.dart';
import '../data/health_summary.dart';
import 'widgets/health_today_card.dart';
import 'widgets/health_ui.dart';

/// Onglet « Santé » : le tableau du jour ([HealthTodayCard]), puis une carte par animal, ceux qui demandent
/// une action en premier.
///
/// Tout vient d'un seul appel (`GET /api/health/summary`), relu toutes les 60 s et aussitôt après
/// une modification : le carnet lui-même s'ouvre au toucher d'une carte.
class HealthTabScreen extends StatefulWidget {
  const HealthTabScreen({super.key, required this.onOpenTab});

  /// Affiche un onglet de la structure principale quand un écran ouvert d'ici en renvoie un.
  final ValueChanged<int> onOpenTab;

  @override
  State<HealthTabScreen> createState() => _HealthTabScreenState();
}

class _HealthTabScreenState extends State<HealthTabScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  final _repository = HealthRepository();
  late Stream<HealthSummary>? _summary = _uid == null ? null : _repository.watchSummary(_uid);

  void _retry() => setState(() => _summary = _repository.watchSummary(_uid!));

  Future<void> _openRecord(String petId) async {
    final tab = await Navigator.of(context).pushNamed<Object?>(AppRoutes.healthRecord, arguments: petId);
    if (tab is int) widget.onOpenTab(tab);
  }

  void _addPet() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PetFormScreen()));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_summary == null) return _VisitorView(l: l);

    return ColoredBox(
      color: HealthColors.surface,
      child: StreamBuilder<HealthSummary>(
        stream: _summary,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorView(message: friendlyHealthError(snapshot.error!), onRetry: _retry);
          }
          final summary = snapshot.data;
          if (summary == null) return const Center(child: CircularProgressIndicator());

          final now = DateTime.now();
          final active = summary.activeSorted(now);
          final archived = summary.archived;
          if (active.isEmpty && archived.isEmpty) return _EmptyView(onAddPet: _addPet);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (active.isNotEmpty) ...[
                HealthTodayCard(summary: summary, now: now, onOpenRecord: _openRecord),
                const SizedBox(height: 24),
                Text(l.healthTabMyPets, style: HealthText.headlineSm),
                const SizedBox(height: 12),
                for (final pet in active) ...[
                  _PetHealthCard(pet: pet, now: now, onTap: () => _openRecord(pet.id)),
                  const SizedBox(height: 12),
                ],
              ] else
                _EmptyView(onAddPet: _addPet, embedded: true),
              if (archived.isNotEmpty) ...[
                const SizedBox(height: 8),
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    leading: const Icon(Symbols.inventory_2, color: HealthColors.onSurfaceVariant),
                    title: Text(l.healthTabArchived(archived.length), style: HealthText.labelLg),
                    subtitle: Text(l.healthTabReadOnly, style: HealthText.bodySm),
                    children: [
                      for (final pet in archived) ...[
                        _PetHealthCard(pet: pet, now: now, onTap: () => _openRecord(pet.id)),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Carte d'un animal : photo, nom, espèce, prochain vaccin, traitements, dernière visite et allergies.
class _PetHealthCard extends StatefulWidget {
  const _PetHealthCard({required this.pet, required this.now, required this.onTap});

  final PetHealthSummary pet;
  final DateTime now;
  final VoidCallback onTap;

  @override
  State<_PetHealthCard> createState() => _PetHealthCardState();
}

class _PetHealthCardState extends State<_PetHealthCard> {
  // La photo n'est pas dans la synthèse (trop lourde) : chaque carte la lit, rafraîchie toutes les 5 min.
  late final _cover = PetRepository().watchCover(widget.pet.id);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pet = widget.pet;
    final now = widget.now;
    final date = DateFormat.yMMMd(l.localeName);
    final species = pet_format.speciesLabel(l, PetSpecies.fromCode(pet.species));
    final running = pet.runningTreatments(now);
    final doses = pet.todayDoses(now);
    final vaccine = pet.nextVaccine;

    final (vaccineLabel, vaccineBg, vaccineFg, vaccineIcon) = switch (pet.vaccineStatus(now)) {
      VaccineStatus.overdue => (l.healthTabVaccineOverdue, HealthColors.errorContainer, HealthColors.error, Symbols.warning),
      VaccineStatus.soon => (l.healthTabVaccineSoon, HealthColors.amber100, HealthColors.amber800, Symbols.schedule),
      VaccineStatus.upToDate => (l.healthTabVaccineUpToDate, HealthColors.emerald50, HealthColors.emerald700, Symbols.verified),
      VaccineStatus.none => (l.healthTabVaccineNone, HealthColors.surfaceHigh, HealthColors.onSurfaceVariant, Symbols.vaccines),
    };

    return Opacity(
      opacity: pet.archived ? 0.7 : 1,
      child: HealthCard(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StreamBuilder<PetPhoto?>(
                  stream: _cover,
                  builder: (context, snap) =>
                      HealthPetPhoto(name: pet.name, photo: snap.data?.bytes, size: 56),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pet.name, style: HealthText.headlineSm, overflow: TextOverflow.ellipsis),
                      Text(
                        pet.breed == null || pet.breed!.trim().isEmpty ? species : '$species • ${pet.breed}',
                        style: HealthText.bodySm,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Symbols.chevron_right, color: HealthColors.outline),
              ],
            ),
            const SizedBox(height: 12),
            HealthPill(label: vaccineLabel, icon: vaccineIcon, background: vaccineBg, foreground: vaccineFg),
            if (vaccine != null) ...[
              const SizedBox(height: 4),
              Text(
                l.healthTabVaccineDue(vaccine.title, date.format(vaccine.dueAt)),
                style: HealthText.bodySm.copyWith(
                  color: pet.vaccineStatus(now) == VaccineStatus.overdue ? HealthColors.error : null,
                  fontWeight: pet.vaccineStatus(now) == VaccineStatus.overdue ? FontWeight.w600 : null,
                ),
              ),
            ],
            const SizedBox(height: 8),
            _InfoLine(icon: Symbols.medication, text: l.healthTabTreatments(running.length)),
            if (doses.isNotEmpty)
              _InfoLine(
                icon: Symbols.alarm,
                text: l.healthTabDosesToday(doses.where((d) => d.done).length, doses.length),
                highlight: doses.any((d) => !d.done),
              ),
            if (pet.lastVisitDate != null || pet.allergies.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (pet.lastVisitDate != null)
                    HealthPill(
                      label: l.healthTabLastVisit(date.format(pet.lastVisitDate!)),
                      icon: Symbols.stethoscope,
                      background: HealthColors.surfaceLow,
                      foreground: HealthColors.primary,
                    ),
                  for (final allergy in pet.allergies)
                    HealthPill(
                      label: l.healthTabAllergy(allergy),
                      icon: Symbols.warning,
                      background: HealthColors.amber50,
                      foreground: HealthColors.amber800,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text, this.highlight = false});

  final IconData icon;
  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? HealthColors.secondary : HealthColors.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: HealthText.bodySm.copyWith(color: color, fontWeight: highlight ? FontWeight.w600 : null),
            ),
          ),
        ],
      ),
    );
  }
}

/// Visiteur non connecté : le carnet est privé, invitation à se connecter.
class _VisitorView extends StatelessWidget {
  const _VisitorView({required this.l});

  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        HealthEmptyState(icon: Symbols.lock, title: l.healthTabVisitorTitle, message: l.healthTabVisitorBody),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.login),
          child: Text(l.healthTabSignIn),
        ),
      ],
    );
  }
}

/// Aucun animal : le carnet vit sous la fiche d'un animal, on propose d'en ajouter un.
class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onAddPet, this.embedded = false});

  final VoidCallback onAddPet;

  /// Dans la liste (il n'y a que des animaux archivés) plutôt qu'en plein écran.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HealthEmptyState(icon: Symbols.pets, title: l.healthTabEmptyTitle, message: l.healthTabEmptyBody),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onAddPet,
          icon: const Icon(Symbols.add),
          label: Text(l.healthTabAddPet),
        ),
      ],
    );
    return embedded ? content : ListView(padding: const EdgeInsets.all(16), children: [content]);
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        HealthEmptyState(icon: Symbols.cloud_off, title: l.healthTabLoadError, message: message),
        const SizedBox(height: 16),
        OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Symbols.refresh), label: Text(l.healthTabRetry)),
      ],
    );
  }
}
