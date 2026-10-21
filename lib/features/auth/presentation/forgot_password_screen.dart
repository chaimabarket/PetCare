import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/auth_service.dart';
import 'validators.dart';
import 'widgets/auth_feedback.dart';

/// Écran « Mot de passe oublié » (maquette Stitch du même nom).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  /// E-mail déjà saisi sur l'écran de connexion, pour éviter de le retaper.
  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const _resendDelay = 45;

  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(text: widget.initialEmail);
  final _authService = AuthService();

  bool _loading = false;
  String? _errorMessage;
  String? _sentTo;
  int _secondsBeforeResend = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final email = _emailController.text.trim();
      await _authService.sendPasswordReset(email);
      if (!mounted) return;
      setState(() => _sentTo = email);
      _startResendCountdown();
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startResendCountdown() {
    _timer?.cancel();
    setState(() => _secondsBeforeResend = _resendDelay);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _secondsBeforeResend--);
      if (_secondsBeforeResend <= 0) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Mot de passe oublié',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.3),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 448),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _TrustRow(),
                  const SizedBox(height: 24),
                  const _HeroCard(),
                  const SizedBox(height: 24),
                  _buildFormCard(),
                  if (_sentTo != null) ...[
                    const SizedBox(height: 24),
                    _SuccessCard(
                      email: _sentTo!,
                      secondsBeforeResend: _secondsBeforeResend,
                      onResend: _loading ? null : _send,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.teal,
                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Retour à la connexion'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _PledgeCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    final sent = _sentTo != null;

    return _Card(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Text.rich(
                  TextSpan(
                    text: 'Adresse e-mail',
                    children: [
                      TextSpan(
                        text: ' *',
                        style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Spacer(),
                Text(
                  'Liée à vos compagnons',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.send,
              autofillHints: const [AutofillHints.email],
              validator: AuthValidators.email,
              onFieldSubmitted: (_) => _send(),
              decoration: const InputDecoration(
                hintText: 'votre.email@exemple.fr',
                prefixIcon: Icon(Icons.mail_outline, size: 20),
              ),
            ),
            const SizedBox(height: 6),
            const Row(
              children: [
                Icon(Icons.lock_reset, size: 14, color: AppColors.textSecondary),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Format confidentiel et protégé par chiffrement SSL',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              ErrorBanner(_errorMessage!),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading || sent ? null : _send,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF005C55),
                disabledBackgroundColor: sent ? const Color(0xFF005C55) : null,
                disabledForegroundColor: sent ? Colors.white : null,
              ),
              child: _loading
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 8),
                        Text('Transmission en cours...'),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            sent ? 'Lien envoyé avec succès' : 'Envoyer le lien de réinitialisation',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(sent ? Icons.check : Icons.send_outlined, size: 20),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = EdgeInsets.zero, this.raised = false});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool raised;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          raised
              ? BoxShadow(
                  color: AppColors.teal.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              : const BoxShadow(color: Color(0x0F0F172A), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: child,
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFDBCF),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pets, size: 16, color: Color(0xFF380D01)),
              SizedBox(width: 4),
              Text(
                'ESPACE SÉCURISÉ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: Color(0xFF380D01),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        const Icon(Icons.verified_user_outlined, size: 16, color: AppColors.teal),
        const SizedBox(width: 4),
        const Text('Protection PetCare', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
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
                semanticLabel: "Illustration chaleureuse d'un chien et d'un chat complices assis ensemble",
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.center,
                      colors: [Color(0xCCFFFFFF), Color(0x00FFFFFF)],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.favorite_border, size: 14, color: Color(0xFF8C4E38)),
                      SizedBox(width: 4),
                      Text(
                        'Communauté solidaire',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF8C4E38)),
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
              children: [
                Text(
                  'Mot de passe oublié ?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, height: 34 / 26, fontWeight: FontWeight.w700, letterSpacing: -0.4),
                ),
                SizedBox(height: 4),
                Text(
                  "Ne vous inquiétez pas ! Saisissez l'adresse e-mail associée à votre compte PetCare Community "
                  'pour recevoir un lien sécurisé de réinitialisation.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF3E4947)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessCard extends StatelessWidget {
  const _SuccessCard({required this.email, required this.secondsBeforeResend, required this.onResend});

  final String email;
  final int secondsBeforeResend;
  final VoidCallback? onResend;

  @override
  Widget build(BuildContext context) {
    final canResend = secondsBeforeResend <= 0 && onResend != null;

    return _Card(
      raised: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(color: Color(0xFF9CF2E8), shape: BoxShape.circle),
                child: const Icon(Icons.mark_email_read_outlined, size: 26, color: Color(0xFF00201D)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF80D5CB).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 13, color: Color(0xFF005C55)),
                          SizedBox(width: 4),
                          Text(
                            'E-mail expédié',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF005C55)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Un e-mail vous a été envoyé !',
                      style: TextStyle(fontSize: 18, height: 24 / 18, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text.rich(
                  TextSpan(
                    text: 'Si cette adresse est enregistrée dans notre communauté, un lien de réinitialisation valable ',
                    children: [
                      TextSpan(text: '1 heure', style: TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(text: " vient d'être transmis à :"),
                    ],
                  ),
                  style: TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF3E4947)),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.alternate_email, size: 16, color: Color(0xFF005C55)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        email,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF005C55)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Color(0xFF7F4025)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Vérifiez vos spams si besoin',
                  style: TextStyle(fontSize: 12, color: Color(0xFF3E4947)),
                ),
              ),
              TextButton.icon(
                onPressed: canResend ? onResend : null,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF005C55),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                icon: const Icon(Icons.update, size: 16),
                label: Text(
                  canResend ? "Renvoyer l'e-mail" : "Renvoyer (dans ${secondsBeforeResend}s)",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PledgeCard extends StatelessWidget {
  const _PledgeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFDBCF).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.surface,
            child: Icon(Icons.volunteer_activism_outlined, size: 18, color: Color(0xFF8C4E38)),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Vos compagnons comptent sur vous. Nos équipes de bénévoles et de vétérinaires partenaires '
              'veillent sur la communauté 7j/7.',
              style: TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF793F2A)),
            ),
          ),
        ],
      ),
    );
  }
}
