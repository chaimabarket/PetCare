import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../pet_style.dart';

/// Élément en cours qui empêche l'archivage (rendez-vous à venir, annonce ouverte… RG-06).
///
/// Les modules Rendez-vous, Perdus & trouvés et Adoption fourniront ces éléments ; tant qu'ils
/// n'existent pas, la liste est vide et l'archivage est directement possible.
class ArchiveBlocker {
  const ArchiveBlocker({
    required this.icon,
    required this.label,
    required this.actionLabel,
    required this.onAction,
    this.iconColor = PetColors.primary,
    this.actionColor = PetColors.primary,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String actionLabel;
  final Color actionColor;
  final VoidCallback onAction;
}

/// Boîte de dialogue « Archiver la fiche de … ? ». Renvoie `true` si l'utilisateur confirme.
///
/// [checksPending] affiche l'encadré « Bientôt disponible » tant que les modules qui fournissent
/// les éléments bloquants ne sont pas branchés.
Future<bool> showArchivePetDialog(
  BuildContext context, {
  required String petName,
  List<ArchiveBlocker> blockers = const [],
  bool checksPending = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => _ArchivePetDialog(petName: petName, blockers: blockers, checksPending: checksPending),
  );
  return confirmed ?? false;
}

class _ArchivePetDialog extends StatelessWidget {
  const _ArchivePetDialog({required this.petName, required this.blockers, required this.checksPending});

  final String petName;
  final List<ArchiveBlocker> blockers;
  final bool checksPending;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final blocked = blockers.isNotEmpty;

    return Dialog(
      backgroundColor: PetColors.surfaceLowest,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 448),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: PetColors.secondaryFixed,
                            shape: BoxShape.circle,
                            boxShadow: petCardShadow,
                          ),
                          child: const Icon(Icons.archive, size: 32, color: PetColors.onSecondaryContainer),
                        ),
                        const SizedBox(height: 16),
                        Text(l.petsArchiveTitle(petName), textAlign: TextAlign.center, style: PetText.headlineSm),
                        const SizedBox(height: 4),
                        Text(
                          l.petsArchiveBody(petName),
                          textAlign: TextAlign.center,
                          style: PetText.bodyMd.copyWith(height: 1.625),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: IconButton(
                      tooltip: l.petsArchiveCloseTooltip,
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close, size: 20, color: PetColors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              if (blocked)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: _BlockersCard(blockers: blockers),
                )
              else if (checksPending)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: _ChecksPendingCard(),
                ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 48,
                      child: blocked
                          ? Tooltip(
                              message: l.petsArchiveLockedTooltip,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: PetColors.surfaceContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.lock_outline, size: 18, color: PetColors.outline),
                                    const SizedBox(width: 4),
                                    Text(l.petsMenuArchive, style: PetText.labelLg.copyWith(color: PetColors.outline)),
                                  ],
                                ),
                              ),
                            )
                          : FilledButton.icon(
                              onPressed: () => Navigator.of(context).pop(true),
                              style: FilledButton.styleFrom(
                                backgroundColor: PetColors.secondary,
                                minimumSize: const Size.fromHeight(48),
                              ),
                              icon: const Icon(Icons.archive_outlined, size: 18),
                              label: Text(l.petsMenuArchive, style: PetText.labelLg.copyWith(color: Colors.white)),
                            ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          backgroundColor: PetColors.surfaceHigh,
                          foregroundColor: PetColors.onSurface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(l.petsCancel, style: PetText.labelLg),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChecksPendingCard extends StatelessWidget {
  const _ChecksPendingCard();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PetColors.secondaryFixed.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.schedule, size: 20, color: PetColors.secondary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.petsArchiveChecksTitle, style: PetText.labelLg.copyWith(color: PetColors.onSecondaryFixed)),
                const SizedBox(height: 2),
                Text(l.petsArchiveChecksBody, style: PetText.bodySm.copyWith(color: PetColors.secondary)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: PetColors.surfaceLowest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(l.comingSoon, style: PetText.labelSm.copyWith(color: PetColors.onSurface)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockersCard extends StatelessWidget {
  const _BlockersCard({required this.blockers});

  final List<ArchiveBlocker> blockers;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PetColors.secondaryFixed.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.warning_rounded, size: 20, color: PetColors.secondary),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.petsArchiveBlockersTitle(blockers.length),
                      style: PetText.labelLg.copyWith(color: PetColors.onSecondaryFixed),
                    ),
                    const SizedBox(height: 2),
                    Text(l.petsArchiveBlockersBody, style: PetText.bodySm.copyWith(color: PetColors.secondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final blocker in blockers) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: PetColors.surfaceLowest,
                borderRadius: BorderRadius.circular(8),
                boxShadow: petCardShadow,
              ),
              child: Row(
                children: [
                  Icon(blocker.icon, size: 18, color: blocker.iconColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(blocker.label, style: PetText.labelMd, overflow: TextOverflow.ellipsis),
                  ),
                  InkWell(
                    onTap: blocker.onAction,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(blocker.actionLabel, style: PetText.labelMd.copyWith(color: blocker.actionColor)),
                          const SizedBox(width: 2),
                          Icon(Icons.arrow_forward, size: 14, color: blocker.actionColor),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: PetColors.outline),
              const SizedBox(width: 4),
              Expanded(child: Text(l.petsArchiveBlockersFooter(blockers.length), style: PetText.labelSm)),
            ],
          ),
        ],
      ),
    );
  }
}
