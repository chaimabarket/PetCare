import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../adoption/data/adoption_listing.dart';
import '../../data/assistant_service.dart';

/// « Rédiger avec l'IA » (maquette Stitch M7) : propose une description d'annonce à partir du
/// formulaire. Renvoie le texte choisi, ou `null` si l'utilisateur annule.
Future<String?> showListingWriterSheet(BuildContext context, ListingDraft draft) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (context) => _ListingWriterSheet(draft: draft),
  );
}

class _ListingWriterSheet extends StatefulWidget {
  const _ListingWriterSheet({required this.draft});

  final ListingDraft draft;

  @override
  State<_ListingWriterSheet> createState() => _ListingWriterSheetState();
}

class _ListingWriterSheetState extends State<_ListingWriterSheet> {
  final _service = AssistantService();
  String? _text;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) await _service.countMessage(uid);
      final text = await _service.writeListingDescription(widget.draft);
      if (mounted) setState(() => _text = text);
    } on AssistantException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('✨ Description proposée', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Container(
            constraints: const BoxConstraints(minHeight: 120),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: _loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text("L'IA rédige…", style: TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  )
                : Text(
                    _error ?? _text ?? '',
                    style: TextStyle(fontSize: 15, height: 1.5, color: _error != null ? AppColors.error : AppColors.textPrimary),
                  ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Relisez et modifiez le texte avant de publier.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading || _text == null ? null : () => Navigator.of(context).pop(_text),
            child: const Text('Utiliser ce texte'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _loading ? null : _generate,
            child: const Text('Régénérer'),
          ),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        ],
      ),
    );
  }
}
