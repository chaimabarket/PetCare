import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/adoption_enums.dart';
import '../../data/compatibility.dart';

/// Couleurs propres au module, tirées de maquettes/petcare_community/DESIGN.md.
abstract final class AdoptionColors {
  static const brown = Color(0xFF8C4E38);
  static const peach = Color(0xFFFFDBCF);
  static const peachLight = Color(0xFFFFF0EB);
  static const blueSurface = Color(0xFFEFF4FF);
  static const mint = Color(0xFF9CF2E8);
  static const tealDeep = Color(0xFF005C55);
  static const textMuted = Color(0xFF3E4947);

  static const successBg = Color(0xFFD1FAE5);
  static const successText = Color(0xFF059669);
  static const warningBg = Color(0xFFFEF3C7);
  static const warningText = Color(0xFFD97706);
  static const inactiveBg = Color(0xFFF3F4F6);
}

/// Carte blanche standard (16 px, ombre légère).
class AdoptionCard extends StatelessWidget {
  const AdoptionCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0F0F172A), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: child,
    );
  }
}

enum PillTone { success, warning, adopted, inactive, teal, error }

/// Pastille de statut arrondie.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.tone, this.dot = true, this.icon});

  factory StatusPill.listing(ListingStatus status) => StatusPill(
        label: status.label,
        tone: switch (status) {
          ListingStatus.available => PillTone.success,
          ListingStatus.reserved => PillTone.warning,
          ListingStatus.adopted => PillTone.adopted,
          ListingStatus.draft || ListingStatus.archived => PillTone.inactive,
        },
      );

  factory StatusPill.application(ApplicationStatus status) => StatusPill(
        label: status.label,
        tone: switch (status) {
          ApplicationStatus.pending => PillTone.teal,
          ApplicationStatus.reviewing => PillTone.warning,
          ApplicationStatus.accepted => PillTone.success,
          ApplicationStatus.adopted => PillTone.adopted,
          ApplicationStatus.refused || ApplicationStatus.withdrawn => PillTone.inactive,
        },
      );

  final String label;
  final PillTone tone;
  final bool dot;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      PillTone.success => (AdoptionColors.successBg, AdoptionColors.successText),
      PillTone.warning => (AdoptionColors.warningBg, AdoptionColors.warningText),
      PillTone.adopted => (AdoptionColors.peachLight, AppColors.coralText),
      PillTone.inactive => (AdoptionColors.inactiveBg, AppColors.textSecondary),
      PillTone.teal => (AdoptionColors.mint, AdoptionColors.tealDeep),
      PillTone.error => (const Color(0xFFFFDAD6), AppColors.error),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ] else if (dot) ...[
            CircleAvatar(radius: 3, backgroundColor: fg),
            const SizedBox(width: 6),
          ],
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}

/// Badge de personnalité (emoji + libellé). Sélectionnable dans les formulaires et filtres.
class BadgeChip extends StatelessWidget {
  const BadgeChip({super.key, required this.badge, this.selected = false, this.onTap, this.compact = false});

  final PersonalityBadge badge;
  final bool selected;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final interactive = onTap != null;
    return Material(
      color: selected ? AdoptionColors.tealDeep : AdoptionColors.blueSurface,
      borderRadius: BorderRadius.circular(compact ? 8 : 999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 8 : 999),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: compact ? 4 : 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(badge.emoji, style: TextStyle(fontSize: compact ? 11 : 13)),
              const SizedBox(width: 4),
              Text(
                badge.label,
                style: TextStyle(
                  fontSize: compact ? 11 : 13,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
              if (selected && interactive) ...[
                const SizedBox(width: 4),
                const Icon(Icons.check, size: 14, color: Colors.white),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Photo d'animal ; sans photo, un fond doux avec l'emoji de l'espèce.
class PetPhoto extends StatelessWidget {
  const PetPhoto({super.key, required this.bytes, required this.species, this.borderRadius, this.emojiSize = 40});

  final Uint8List? bytes;
  final Species species;
  final BorderRadius? borderRadius;
  final double emojiSize;

  @override
  Widget build(BuildContext context) {
    final image = bytes == null
        ? Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AdoptionColors.peachLight, AdoptionColors.blueSurface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            alignment: Alignment.center,
            child: Text(species.emoji, style: TextStyle(fontSize: emojiSize)),
          )
        : Image.memory(bytes!, fit: BoxFit.cover, gaplessPlayback: true);
    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }
}

/// Titre de section avec petite barre teal (maquettes du formulaire).
class BarTitle extends StatelessWidget {
  const BarTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(color: AdoptionColors.tealDeep, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
          ?trailing,
        ],
      ),
    );
  }
}

/// En-tête de carte : icône dans un carré + titre.
class CardHeader extends StatelessWidget {
  const CardHeader({super.key, required this.icon, required this.title, this.trailing, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: AdoptionColors.blueSurface, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 22, color: AppColors.teal),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.2)),
              if (subtitle != null)
                Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

enum TipTone { coral, blue, green }

/// Encadré « Bon à savoir » / note d'information.
class TipBanner extends StatelessWidget {
  const TipBanner({super.key, required this.text, this.title, this.icon = Icons.lightbulb_outline, this.tone = TipTone.blue});

  final String text;
  final String? title;
  final IconData icon;
  final TipTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      TipTone.coral => (AdoptionColors.peachLight, AdoptionColors.brown),
      TipTone.blue => (AdoptionColors.blueSurface, AdoptionColors.tealDeep),
      TipTone.green => (const Color(0xFFE6F7F4), AdoptionColors.tealDeep),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (title != null)
                    TextSpan(text: '$title : ', style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: text),
                ],
              ),
              style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grande carte à choix unique (Appartement / Maison, Oui / Non…).
class SelectableCard extends StatelessWidget {
  const SelectableCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AdoptionColors.tealDeep : AppColors.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (icon != null)
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: selected ? AdoptionColors.mint : AdoptionColors.blueSurface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, size: 20, color: AdoptionColors.tealDeep),
                      ),
                    const Spacer(),
                    selected
                        ? const Icon(Icons.check_circle, color: AdoptionColors.tealDeep, size: 22)
                        : const Icon(Icons.circle, color: AdoptionColors.blueSurface, size: 22),
                  ],
                ),
                const SizedBox(height: 12),
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                if (subtitle != null)
                  Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ligne avec compteur − valeur + (Adultes, Enfants, Chats…).
class CounterRow extends StatelessWidget {
  const CounterRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.emoji,
    this.min = 0,
    this.max = 10,
  });

  final String title;
  final String? subtitle;
  final String? emoji;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AdoptionColors.blueSurface, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          if (emoji != null) ...[
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.surface,
              child: Text(emoji!, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                if (subtitle != null)
                  Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(999)),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Moins',
                  onPressed: value > min ? () => onChanged(value - 1) : null,
                  icon: const Icon(Icons.remove, size: 18),
                ),
                SizedBox(
                  width: 24,
                  child: Text('$value',
                      textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  tooltip: 'Plus',
                  onPressed: value < max ? () => onChanged(value + 1) : null,
                  style: IconButton.styleFrom(
                    backgroundColor: AdoptionColors.tealDeep,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.border,
                  ),
                  icon: const Icon(Icons.add, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Puce de filtre (Tous, Chats, Chiens…).
class FilterPill extends StatelessWidget {
  const FilterPill({super.key, required this.label, required this.selected, required this.onTap, this.emoji});

  final String label;
  final String? emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AdoptionColors.tealDeep : AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? AdoptionColors.tealDeep : AppColors.border),
          ),
          child: Text(
            emoji == null ? label : '$emoji  $label',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Jauge circulaire du score de compatibilité.
class ScoreGauge extends StatelessWidget {
  const ScoreGauge({super.key, required this.score, this.size = 56, this.showLevel = true});

  final int score;
  final double size;
  final bool showLevel;

  static Color colorOf(int score) => switch (CompatibilityLevel.of(score)) {
        CompatibilityLevel.high => AppColors.teal,
        CompatibilityLevel.medium => const Color(0xFFF59E0B),
        CompatibilityLevel.low => const Color(0xFF9CA3AF),
      };

  @override
  Widget build(BuildContext context) {
    final color = colorOf(score);
    return Semantics(
      label: 'Compatibilité $score %',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: size / 12,
                  backgroundColor: AppColors.divider,
                  color: color,
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Text(
                    '$score%',
                    style: TextStyle(fontSize: size * 0.26, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          if (showLevel) ...[
            const SizedBox(height: 4),
            Text(
              CompatibilityLevel.of(score).label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ],
      ),
    );
  }
}

/// Frise Envoyée → En étude → Acceptée → Adoptée (ou arrêtée à « Refusée »).
class ApplicationTimeline extends StatelessWidget {
  const ApplicationTimeline({super.key, required this.status});

  final ApplicationStatus status;

  @override
  Widget build(BuildContext context) {
    final stopped = status == ApplicationStatus.refused || status == ApplicationStatus.withdrawn;
    final reached = switch (status) {
      ApplicationStatus.pending => 0,
      ApplicationStatus.reviewing => 1,
      ApplicationStatus.accepted => 2,
      ApplicationStatus.adopted => 3,
      ApplicationStatus.refused || ApplicationStatus.withdrawn => 2,
    };
    final labels = [
      'Envoyée',
      'En étude',
      stopped ? (status == ApplicationStatus.refused ? 'Refusée' : 'Retirée') : 'Acceptée',
      'Adoptée',
    ];

    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: i == 0 ? const SizedBox() : _line(i <= reached, stopped)),
                    _dot(i, reached, stopped),
                    Expanded(child: i == labels.length - 1 ? const SizedBox() : _line(i < reached, stopped)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: i == reached ? FontWeight.w700 : FontWeight.w500,
                    color: stopped && i == 3
                        ? AppColors.border
                        : (i == 3 && status == ApplicationStatus.adopted ? AdoptionColors.brown : AppColors.textPrimary),
                    decoration: stopped && i == 3 ? TextDecoration.lineThrough : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _line(bool done, bool stopped) => Container(
        height: 3,
        color: done ? (stopped ? const Color(0xFF6B7280) : AdoptionColors.tealDeep) : AppColors.border,
      );

  Widget _dot(int i, int reached, bool stopped) {
    if (stopped && i == reached) {
      return const CircleAvatar(
          radius: 13, backgroundColor: AppColors.textPrimary, child: Icon(Icons.close, size: 15, color: Colors.white));
    }
    if (i == 3 && status == ApplicationStatus.adopted) {
      return const CircleAvatar(
          radius: 13, backgroundColor: AdoptionColors.brown, child: Icon(Icons.pets, size: 14, color: Colors.white));
    }
    if (i < reached || (i == reached && status == ApplicationStatus.accepted)) {
      return CircleAvatar(
        radius: 13,
        backgroundColor: stopped ? const Color(0xFF6B7280) : AdoptionColors.tealDeep,
        child: const Icon(Icons.check, size: 15, color: Colors.white),
      );
    }
    if (i == reached) {
      return const CircleAvatar(
        radius: 13,
        backgroundColor: AppColors.coral,
        child: Icon(Icons.more_horiz, size: 15, color: AdoptionColors.brown),
      );
    }
    return const CircleAvatar(radius: 13, backgroundColor: AdoptionColors.blueSurface);
  }
}

/// État vide ou erreur, centré.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.text, this.action});

  final IconData icon;
  final String title;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AdoptionColors.peachLight,
            child: Icon(icon, size: 34, color: AdoptionColors.brown),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.textSecondary)),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

/// Barre d'actions fixée en bas de l'écran.
class BottomActions extends StatelessWidget {
  const BottomActions({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(top: false, child: Row(children: children)),
    );
  }
}

/// Style du bouton « émotion » (brun des maquettes) : candidater, publier, confirmer.
ButtonStyle warmButtonStyle() => FilledButton.styleFrom(
      backgroundColor: AdoptionColors.brown,
      foregroundColor: Colors.white,
    );

/// Bouton secondaire bleu clair des maquettes (« Précédent », « Refuser »).
ButtonStyle softButtonStyle() => FilledButton.styleFrom(
      backgroundColor: AdoptionColors.blueSurface,
      foregroundColor: AppColors.textPrimary,
    );

void showAdoptionMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Les visiteurs peuvent consulter ; une action demande un compte.
Future<void> askToSignIn(BuildContext context, String reason) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Compte requis'),
      content: Text(reason),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Plus tard')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Se connecter')),
      ],
    ),
  );
  if (go == true && context.mounted) Navigator.of(context).pushNamed(AppRoutes.login);
}

/// Date courte « 14 févr. 2026 ».
String formatShortDate(DateTime? date) {
  if (date == null) return '—';
  const months = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
