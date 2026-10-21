import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/validators.dart';
import '../../auth/presentation/widgets/auth_feedback.dart';
import '../data/profile_repository.dart';
import '../data/user_profile.dart';

/// Modification des informations personnelles (nom, téléphone, ville).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.profile.fullName);
  late final _phoneController = TextEditingController(text: widget.profile.phone);
  late final _cityController = TextEditingController(text: widget.profile.city);
  final _repository = ProfileRepository();

  bool _saving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  static String? _validatePhone(String? value) {
    final phone = value?.replaceAll(RegExp(r'[\s.\-]'), '') ?? '';
    if (phone.isEmpty) return null; // facultatif
    if (!RegExp(r'^\+?\d{8,15}$').hasMatch(phone)) return "Le numéro de téléphone n'est pas valide.";
    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await _repository.update(
        uid: widget.profile.uid,
        fullName: _nameController.text,
        city: _cityController.text,
        phone: _phoneController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil mis à jour.')));
      Navigator.of(context).pop();
    } catch (_) {
      setState(() => _errorMessage = "Impossible d'enregistrer les modifications. Réessayez.");
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
        title: const Text(
          'Modifier le profil',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.3),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Color(0x0F0F172A), blurRadius: 3, offset: Offset(0, 1))],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Label('Nom complet', required: true),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    validator: (v) => AuthValidators.required(v, 'Saisissez votre nom complet.'),
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline, size: 20)),
                  ),
                  const SizedBox(height: 16),
                  const _Label('Adresse e-mail'),
                  TextFormField(
                    initialValue: widget.profile.email,
                    enabled: false,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.mail_outline, size: 20),
                      helperText: "L'adresse e-mail sert à vous connecter et ne peut pas être modifiée ici.",
                      helperMaxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _Label('Numéro de téléphone'),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    validator: _validatePhone,
                    decoration: const InputDecoration(
                      hintText: 'Ex : +216 20 123 456',
                      prefixIcon: Icon(Icons.smartphone, size: 20),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _Label('Ville de résidence', required: true),
                  TextFormField(
                    controller: _cityController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    validator: (v) => AuthValidators.required(v, 'Saisissez votre ville.'),
                    onFieldSubmitted: (_) => _save(),
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.location_on_outlined, size: 20)),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    ErrorBanner(_errorMessage!),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Enregistrer'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.required = false});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          text: text,
          children: [
            if (required) const TextSpan(text: ' *', style: TextStyle(color: AppColors.coralText)),
          ],
        ),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
