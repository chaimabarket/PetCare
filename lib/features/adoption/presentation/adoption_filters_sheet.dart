import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/adoption_enums.dart';
import '../data/adoption_filters.dart';
import '../data/adoption_listing.dart';
import 'widgets/adoption_widgets.dart';

/// Feuille « Filtres d'adoption ». Renvoie les nouveaux filtres, ou `null` si fermée.
Future<AdoptionFilters?> showAdoptionFiltersSheet(
  BuildContext context, {
  required AdoptionFilters filters,
  required List<AdoptionListing> listings,
}) {
  return showModalBottomSheet<AdoptionFilters>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _FiltersSheet(initial: filters, listings: listings),
  );
}

class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({required this.initial, required this.listings});

  final AdoptionFilters initial;
  final List<AdoptionListing> listings;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late var _f = widget.initial;

  late final _cities = {for (final l in widget.listings) l.city.trim()}.where((c) => c.isNotEmpty).toList()..sort();

  Set<T> _toggle<T>(Set<T> set, T value) => set.contains(value) ? ({...set}..remove(value)) : {...set, value};

  @override
  Widget build(BuildContext context) {
    final count = _f.apply(widget.listings).length;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
            child: Row(
              children: [
                const Icon(Icons.tune, color: AdoptionColors.tealDeep),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text("Filtres d'adoption", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  tooltip: 'Fermer',
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(backgroundColor: AdoptionColors.blueSurface),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                _Section(
                  title: 'Espèce',
                  trailing: _f.species.isEmpty ? null : '${_f.species.length} sélectionnée${_f.species.length > 1 ? 's' : ''}',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterPill(
                        label: 'Tous',
                        selected: _f.species.isEmpty,
                        onTap: () => setState(() => _f = _f.copyWith(species: {})),
                      ),
                      for (final s in Species.values)
                        FilterPill(
                          label: s.label,
                          emoji: s.emoji,
                          selected: _f.species.contains(s),
                          onTap: () => setState(() => _f = _f.copyWith(species: _toggle(_f.species, s))),
                        ),
                    ],
                  ),
                ),
                _Section(
                  title: "Âge de l'animal",
                  child: _TwoColumns(
                    children: [
                      for (final a in AgeGroup.values)
                        _OptionTile(
                          title: a.label,
                          subtitle: a.hint,
                          selected: _f.ages.contains(a),
                          onTap: () => setState(() => _f = _f.copyWith(ages: _toggle(_f.ages, a))),
                        ),
                    ],
                  ),
                ),
                _Section(
                  title: 'Sexe',
                  child: SegmentedButton<Sex?>(
                    showSelectedIcon: false,
                    segments: [
                      const ButtonSegment(value: null, label: Text('Tous')),
                      for (final s in Sex.values) ButtonSegment(value: s, label: Text('${s.label} ${s.symbol}')),
                    ],
                    selected: {_f.sex},
                    onSelectionChanged: (v) => setState(() => _f = _f.copyWith(sex: () => v.first)),
                  ),
                ),
                _Section(
                  title: 'Gabarit / Taille',
                  child: Row(
                    children: [
                      for (final s in PetSize.values) ...[
                        if (s != PetSize.small) const SizedBox(width: 8),
                        Expanded(
                          child: _OptionTile(
                            title: s.label,
                            subtitle: s.hint,
                            centered: true,
                            selected: _f.sizes.contains(s),
                            onTap: () => setState(() => _f = _f.copyWith(sizes: _toggle(_f.sizes, s))),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _Section(
                  title: 'Localisation',
                  child: DropdownButtonFormField<String?>(
                    initialValue: _cities.contains(_f.city) ? _f.city : null,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.location_on_outlined)),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Toutes les villes')),
                      for (final c in _cities) DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) => setState(() => _f = _f.copyWith(city: () => v)),
                  ),
                ),
                _Section(
                  title: 'Personnalité & Compatibilités',
                  trailing: _f.badges.isEmpty ? null : '${_f.badges.length} critère${_f.badges.length > 1 ? 's' : ''}',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final b in PersonalityBadge.values)
                        BadgeChip(
                          badge: b,
                          selected: _f.badges.contains(b),
                          onTap: () => setState(() => _f = _f.copyWith(badges: _toggle(_f.badges, b))),
                        ),
                    ],
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _f.urgentOnly,
                  onChanged: (v) => setState(() => _f = _f.copyWith(urgentOnly: v)),
                  title: const Text('Adopte-moi uniquement', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Animaux en attente depuis plus de 30 jours ou avec des soins spécifiques'),
                ),
              ],
            ),
          ),
          BottomActions(
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _f = _f.cleared()),
                style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
                icon: const Icon(Icons.restart_alt),
                label: const Text('Réinitialiser'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _f),
                  child: Text('Voir $count animal${count > 1 ? 'aux' : ''}'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});

  final String title;
  final String? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
              if (trailing != null)
                Text(trailing!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.teal)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _TwoColumns extends StatelessWidget {
  const _TwoColumns({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: children[i]),
              const SizedBox(width: 8),
              Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox()),
            ],
          ),
        ],
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.centered = false,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final bool centered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.textPrimary;
    return Material(
      color: selected ? AdoptionColors.tealDeep : AdoptionColors.blueSurface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: fg)),
              Text(subtitle, style: TextStyle(fontSize: 13, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}
