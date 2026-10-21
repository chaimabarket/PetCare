import 'package:flutter/material.dart';

import '../../../core/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../data/auth_service.dart';
import '../data/user_role.dart';
import 'validators.dart';
import 'widgets/auth_feedback.dart';

/// Écran d'inscription (maquette Stitch « Rejoignez la communauté »).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _cityController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = AuthService();

  UserRole _role = UserRole.owner;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _acceptedTerms = false;
  bool _showTermsError = false;
  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Met à jour la jauge de robustesse et l'état « Non conforme » pendant la saisie.
    _passwordController.addListener(_refresh);
    _confirmController.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _passwordsMismatch =>
      _confirmController.text.isNotEmpty && _confirmController.text != _passwordController.text;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final formValid = _formKey.currentState!.validate();
    setState(() => _showTermsError = !_acceptedTerms);
    if (!formValid || !_acceptedTerms) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await _authService.register(
        fullName: _nameController.text,
        email: _emailController.text,
        city: _cityController.text,
        password: _passwordController.text,
        role: _role,
      );
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 448),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _HeroCard(),
                  const SizedBox(height: 24),
                  const _StepHeader(number: 1, title: 'Choisissez votre profil', trailing: 'Étape 1 sur 2'),
                  const SizedBox(height: 8),
                  _RoleSelector(
                    selected: _role,
                    onChanged: (role) => setState(() => _role = role),
                  ),
                  const SizedBox(height: 24),
                  _buildFormCard(),
                  const SizedBox(height: 20),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    final strength = AuthValidators.passwordStrength(_passwordController.text);

    return _Card(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _StepHeader(number: 2, title: 'Vos coordonnées', trailing: 'Champs requis *'),
            const SizedBox(height: 16),
            const _FieldLabel('Nom complet'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              validator: (v) => AuthValidators.required(v, 'Saisissez votre nom complet.'),
              decoration: const InputDecoration(
                hintText: 'Ex : Clara Dupont',
                prefixIcon: Icon(Icons.person_outline, size: 20),
              ),
            ),
            const SizedBox(height: 16),
            const _FieldLabel('Adresse e-mail'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: AuthValidators.email,
              decoration: const InputDecoration(
                hintText: 'votre.email@exemple.fr',
                prefixIcon: Icon(Icons.mail_outline, size: 20),
              ),
            ),
            const SizedBox(height: 16),
            const _FieldLabel('Ville de résidence'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _cityController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.addressCity],
              validator: (v) => AuthValidators.required(v, 'Saisissez votre ville.'),
              decoration: const InputDecoration(
                hintText: 'Ex : Bordeaux (33)',
                prefixIcon: Icon(Icons.location_on_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 16),
            const _FieldLabel(
              'Mot de passe',
              trailing: Text(
                '${AuthValidators.minPasswordLength} car. minimum',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.teal),
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              validator: AuthValidators.newPassword,
              decoration: InputDecoration(
                hintText: '••••••••••••',
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                suffixIcon: _VisibilityToggle(
                  obscured: _obscurePassword,
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            if (_passwordController.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              _StrengthMeter(strength: strength),
            ],
            const SizedBox(height: 16),
            _FieldLabel(
              'Confirmer le mot de passe',
              color: _passwordsMismatch ? AppColors.error : null,
              trailing: _passwordsMismatch
                  ? const Text(
                      'Non conforme',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.error),
                    )
                  : null,
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _confirmController,
              obscureText: _obscureConfirm,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              validator: (v) {
                if (v == null || v.isEmpty) return 'Confirmez votre mot de passe.';
                if (v != _passwordController.text) return 'Les mots de passe ne correspondent pas.';
                return null;
              },
              decoration: InputDecoration(
                hintText: '••••••••••••',
                prefixIcon: Icon(
                  Icons.lock_reset,
                  size: 20,
                  color: _passwordsMismatch ? AppColors.error : null,
                ),
                suffixIcon: _VisibilityToggle(
                  obscured: _obscureConfirm,
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                fillColor: _passwordsMismatch ? AppColors.error.withValues(alpha: 0.06) : null,
                enabledBorder: _passwordsMismatch
                    ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
                      )
                    : null,
              ),
            ),
            if (_passwordsMismatch) ...[
              const SizedBox(height: 6),
              const InlineError('Les mots de passe ne correspondent pas.'),
            ],
            const SizedBox(height: 12),
            _TermsCheckbox(
              value: _acceptedTerms,
              showError: _showTermsError,
              onChanged: (value) => setState(() {
                _acceptedTerms = value;
                if (value) _showTermsError = false;
              }),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              ErrorBanner(_errorMessage!),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Créer mon compte'),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Déjà membre ?',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.teal,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Se connecter',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user_outlined, size: 16, color: AppColors.teal),
            SizedBox(width: 4),
            Text('Données protégées', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: CircleAvatar(radius: 2, backgroundColor: AppColors.border),
            ),
            Icon(Icons.favorite_border, size: 16, color: AppColors.coralText),
            SizedBox(width: 4),
            Text('100% Bienveillant', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0A0F172A), blurRadius: 3, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x080F172A), blurRadius: 2, offset: Offset(0, 1), spreadRadius: -1),
        ],
      ),
      child: child,
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              Image.asset(
                'assets/images/hero_friends.jpg',
                height: 176,
                width: double.infinity,
                fit: BoxFit.cover,
                semanticLabel: 'Illustration chien et chat assis ensemble',
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [AppColors.surface, Color(0x33FFFFFF), Color(0x00FFFFFF)],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.pets, size: 16, color: AppColors.teal),
                      SizedBox(width: 4),
                      Text(
                        'BIENVENUE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.teal,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rejoignez la communauté',
                  style: TextStyle(fontSize: 26, height: 34 / 26, fontWeight: FontWeight.w700, letterSpacing: -0.4),
                ),
                SizedBox(height: 4),
                Text(
                  'Créez votre compte pour adopter, proposer vos services ou soutenir nos refuges partenaires.',
                  style: TextStyle(fontSize: 14, height: 1.6, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.number, required this.title, required this.trailing});

  final int number;
  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
          child: Text(
            '$number',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        Text(trailing, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({required this.selected, required this.onChanged});

  final UserRole selected;
  final ValueChanged<UserRole> onChanged;

  static const _options = [
    (
      role: UserRole.owner,
      icon: Icons.favorite,
      title: 'Propriétaire & Adoptant',
      description: "J'adopte ou je prends soin de mes animaux au quotidien.",
      popular: true,
    ),
    (
      role: UserRole.provider,
      icon: Icons.medical_services_outlined,
      title: 'Prestataire de soins',
      description: 'Vétérinaire, pet-sitter certifié, toiletteur ou éducateur.',
      popular: false,
    ),
    (
      role: UserRole.shelter,
      icon: Icons.home_work_outlined,
      title: 'Refuge ou Association',
      description: "Organisme d'accueil, protection animale & adoption.",
      popular: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Type de compte',
      child: Column(
        children: [
          for (final option in _options) ...[
            _RoleCard(
              icon: option.icon,
              title: option.title,
              description: option.description,
              popular: option.popular,
              selected: option.role == selected,
              onTap: () => onChanged(option.role),
            ),
            if (option != _options.last) const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.popular,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool popular;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.teal.withValues(alpha: 0.35) : AppColors.divider,
              ),
            ),
            child: Opacity(
              opacity: selected ? 1 : 0.85,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.teal.withValues(alpha: 0.1) : const Color(0xFFDEE9FC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      size: 22,
                      color: selected ? AppColors.teal : const Color(0xFF3E4947),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            if (popular)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEAE92),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Populaire',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF793F2A),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: const TextStyle(fontSize: 12, height: 1.35, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AppColors.teal : const Color(0xFFD9E3F6),
                    ),
                    child: selected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.trailing, this.color});

  final String text;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final labelColor = color ?? AppColors.textPrimary;
    return Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              text: text,
              children: [
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: color ?? AppColors.coralText),
                ),
              ],
            ),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _VisibilityToggle extends StatelessWidget {
  const _VisibilityToggle({required this.obscured, required this.onPressed});

  final bool obscured;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: obscured ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
      icon: Icon(obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
      onPressed: onPressed,
    );
  }
}

class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter({required this.strength});

  /// De 0 à 4, voir [AuthValidators.passwordStrength].
  final int strength;

  static const _labels = ['Très faible', 'Faible', 'Moyen', 'Solide', 'Très solide'];

  Color get _color => switch (strength) {
        0 || 1 => AppColors.error,
        2 => const Color(0xFFD97706),
        _ => AppColors.teal,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 4,
                decoration: BoxDecoration(
                  color: i < strength ? _color : const Color(0xFFD9E3F6),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            _labels[strength],
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _color),
          ),
        ],
      ),
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({required this.value, required this.showError, required this.onChanged});

  final bool value;
  final bool showError;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: value,
                    onChanged: (v) => onChanged(v ?? false),
                    activeColor: AppColors.teal,
                    side: BorderSide(
                      color: showError ? AppColors.error : const Color(0xFFD1D5DB),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: "J'accepte les ",
                      children: [
                        TextSpan(
                          text: "Conditions Générales d'Utilisation",
                          style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w500),
                        ),
                        TextSpan(text: ' et la '),
                        TextSpan(
                          text: 'Charte de Bien-être Animal',
                          style: TextStyle(color: AppColors.coralText, fontWeight: FontWeight.w500),
                        ),
                        TextSpan(text: '.'),
                      ],
                    ),
                    style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showError) ...[
          const SizedBox(height: 4),
          const InlineError('Vous devez accepter les conditions pour créer un compte.'),
        ],
      ],
    );
  }
}
