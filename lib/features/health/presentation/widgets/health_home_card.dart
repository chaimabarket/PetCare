import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/health_format.dart';
import '../../data/health_pet.dart';
import '../../data/health_repository.dart';
import 'health_ui.dart';

/// Carte de l'Accueil (module 2) : prochains rappels vaccinaux et prises de traitement,
/// puis un accès au carnet de santé de chaque animal et aux fiches santé.
class HealthHomeCard extends StatefulWidget {
  const HealthHomeCard({super.key, required this.onOpenTab});

  /// Ouvre un onglet de la structure principale quand un écran du module en renvoie un.
  final ValueChanged<int> onOpenTab;

  @override
  State<HealthHomeCard> createState() => _HealthHomeCardState();
}

class _HealthHomeCardState extends State<HealthHomeCard> {
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  final _repository = HealthRepository();
  late final _pets = _uid == null ? null : _repository.watchMyPets(_uid);
  late final _upcoming = _uid == null ? null : _repository.watchUpcoming(_uid);

  Future<void> _open(String route, {Object? arguments}) async {
    final tab = await Navigator.of(context).pushNamed<Object?>(route, arguments: arguments);
    if (tab is int) widget.onOpenTab(tab);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0F0F172A), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: HealthColors.surfaceLow, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Symbols.health_and_safety, size: 22, color: AppColors.teal),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Vaccins & traitements',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, letterSpacing: -0.3),
                ),
              ),
              TextButton.icon(
                onPressed: () => _open(AppRoutes.healthSheets),
                iconAlignment: IconAlignment.end,
                style: TextButton.styleFrom(
                  foregroundColor: HealthColors.primary,
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                icon: const Icon(Icons.chevron_right, size: 18),
                label: const Text('Fiches santé'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<HealthPet>>(
            stream: _pets,
            builder: (context, petsSnap) => StreamBuilder<List<HealthUpcomingItem>>(
              stream: _upcoming,
              builder: (context, upcomingSnap) {
                final pets = petsSnap.data ?? const <HealthPet>[];
                final upcoming = (upcomingSnap.data ?? const <HealthUpcomingItem>[]).take(3).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (upcoming.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: HealthColors.surfaceLow, borderRadius: BorderRadius.circular(12)),
                        child: Text(
                          pets.isEmpty
                              ? 'Ajoutez un animal dans « Mes animaux » pour tenir son carnet de santé.'
                              : 'Aucun vaccin ni traitement à venir. Les prochains rappels apparaîtront ici.',
                          style: const TextStyle(fontSize: 14, height: 1.4, color: HealthColors.onSurfaceVariant),
                        ),
                      )
                    else
                      for (final item in upcoming)
                        _UpcomingRow(
                          item: item,
                          onTap: () => _open(AppRoutes.healthRecord, arguments: item.pet.id),
                        ),
                    if (pets.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final pet in pets)
                            ActionChip(
                              avatar: const Icon(Symbols.medical_information, size: 18, color: HealthColors.primary),
                              label: Text('Carnet de ${pet.name}'),
                              labelStyle: HealthText.labelMd.copyWith(color: HealthColors.primary),
                              backgroundColor: HealthColors.surfaceLow,
                              side: BorderSide.none,
                              shape: const StadiumBorder(),
                              onPressed: () => _open(AppRoutes.healthRecord, arguments: pet.id),
                            ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.item, required this.onTap});

  final HealthUpcomingItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final late = item.isVaccine && dayOf(item.dueAt).isBefore(dayOf(DateTime.now()));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.isVaccine ? HealthColors.blue50 : HealthColors.secondaryFixed,
                shape: BoxShape.circle,
              ),
              child: Icon(
                item.isVaccine ? Symbols.syringe : Symbols.pill,
                size: 20,
                color: item.isVaccine ? HealthColors.blue700 : HealthColors.secondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: HealthText.labelLg, overflow: TextOverflow.ellipsis),
                  Text(
                    item.isVaccine
                        ? '${item.pet.name} • ${formatHealthDate(item.dueAt)}'
                        : '${item.pet.name} • Prochaine prise',
                    style: HealthText.bodySm,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            HealthPill(
              label: item.isVaccine ? formatTimeUntil(item.dueAt) : formatDoseMoment(item.dueAt),
              background: late ? HealthColors.amber50 : HealthColors.secondaryFixed,
              foreground: late ? HealthColors.amber800 : HealthColors.onSecondaryFixed,
            ),
          ],
        ),
      ),
    );
  }
}
