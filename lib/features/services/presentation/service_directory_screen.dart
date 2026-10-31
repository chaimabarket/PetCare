import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/data/user_role.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/data/user_profile.dart';
import '../data/service_models.dart';
import '../data/service_repository.dart';
import 'provider_screens.dart';
import 'service_detail_screen.dart';

const _categories = <(String, IconData)>[
  ('Vétérinaires', Icons.medical_services_outlined),
  ('Toiletteurs', Icons.content_cut_rounded),
  ('Promeneurs', Icons.directions_walk_rounded),
  ('Pensions', Icons.hotel_outlined),
  ('Boutiques', Icons.storefront_outlined),
  ('Autres', Icons.more_horiz_rounded),
];

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final _repository = ServiceRepository();
  final _searchController = TextEditingController();
  String _category = 'Tous';
  String _city = '';
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PetCare Services',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Les professionnels près de vous',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (user != null)
              StreamBuilder<UserProfile?>(
                stream: ProfileRepository().watch(user.uid),
                builder: (context, snapshot) {
                  final role = snapshot.data?.role;
                  if (role != UserRole.provider && role != UserRole.admin) {
                    return const SizedBox.shrink();
                  }
                  return IconButton.filledTonal(
                    tooltip: role == UserRole.admin
                        ? 'Validation des prestataires'
                        : 'Espace prestataire',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => role == UserRole.admin
                            ? const ServicesAdminScreen()
                            : const ProviderWorkspaceScreen(),
                      ),
                    ),
                    icon: Icon(
                      role == UserRole.admin
                          ? Icons.fact_check_outlined
                          : Icons.store_mall_directory_outlined,
                    ),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _searchController,
          onChanged: (value) =>
              setState(() => _search = value.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Rechercher un service',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _search.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Effacer la recherche',
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _search = '');
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: _SectionTitle('Catégories')),
            TextButton(
              onPressed: () => setState(() => _category = 'Tous'),
              child: const Text('Toutes'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _categories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 9,
            mainAxisSpacing: 9,
            childAspectRatio: 1.16,
          ),
          itemBuilder: (context, index) {
            final category = _categories[index];
            return _CategoryTile(
              label: category.$1,
              icon: category.$2,
              selected: _category == category.$1,
              onTap: () => setState(() => _category = category.$1),
            );
          },
        ),
        const SizedBox(height: 14),
        TextField(
          onChanged: (value) =>
              setState(() => _city = value.trim().toLowerCase()),
          decoration: const InputDecoration(
            hintText: 'Ville',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
        ),
        const SizedBox(height: 22),
        const _SectionTitle('Professionnels à proximité'),
        const SizedBox(height: 10),
        StreamBuilder<List<ServiceProvider>>(
          stream: _repository.watchPublishedProviders(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _MessagePanel(
                icon: Icons.cloud_off_outlined,
                title: 'Services indisponibles',
                message: 'Vérifiez votre connexion puis réessayez.',
                actionLabel: 'Réessayer',
                onAction: () => setState(() {}),
              );
            }
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final providers = snapshot.data!.where((provider) {
              final matchesCategory =
                  _category == 'Tous' || provider.category == _category;
              final searchable =
                  '${provider.name} ${provider.category} ${provider.city}'
                      .toLowerCase();
              return matchesCategory &&
                  searchable.contains(_search) &&
                  provider.city.toLowerCase().contains(_city);
            }).toList()..sort((left, right) => left.name.compareTo(right.name));
            if (providers.isEmpty) {
              return _MessagePanel(
                icon: Icons.search_off_rounded,
                title: snapshot.data!.isEmpty
                    ? 'Aucun service pour le moment'
                    : 'Aucun résultat',
                message: snapshot.data!.isEmpty
                    ? 'Les professionnels vérifiés apparaîtront ici dès leur publication.'
                    : 'Essayez une autre catégorie ou une autre ville.',
                actionLabel: snapshot.data!.isEmpty
                    ? null
                    : 'Réinitialiser les filtres',
                onAction: snapshot.data!.isEmpty
                    ? null
                    : () {
                        _searchController.clear();
                        setState(() {
                          _search = '';
                          _city = '';
                          _category = 'Tous';
                        });
                      },
              );
            }
            return Column(
              children: [
                for (final provider in providers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ProviderCard(
                      provider: provider,
                      repository: _repository,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ServiceDetailScreen(
                            provider: provider,
                            repository: _repository,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.provider,
    required this.repository,
    required this.onTap,
  });

  final ServiceProvider provider;
  final ServiceRepository repository;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 150,
            width: double.infinity,
            child: _ProviderImage(provider: provider, height: 150),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        provider.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.verified_rounded,
                      size: 18,
                      color: AppColors.teal,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  provider.category,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 7),
                StreamBuilder<List<ProviderService>>(
                  stream: repository.watchServices(provider.ownerId),
                  builder: (context, snapshot) {
                    final prices =
                        snapshot.data
                            ?.map((service) => service.price)
                            .toList() ??
                        [];
                    if (prices.isEmpty) return const SizedBox.shrink();
                    prices.sort();
                    return Text(
                      'À partir de ${prices.first.toStringAsFixed(0)} DT',
                      style: const TextStyle(
                        color: AppColors.teal,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        provider.city,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    TextButton(onPressed: onTap, child: const Text('Voir')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.tealLight : AppColors.surface,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.teal : AppColors.border,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 23,
              color: selected ? AppColors.teal : AppColors.textSecondary,
            ),
            const SizedBox(height: 7),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.tealDark : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ProviderImage extends StatelessWidget {
  const _ProviderImage({required this.provider, required this.height});

  final ServiceProvider provider;
  final double height;

  @override
  Widget build(BuildContext context) {
    final imageUrl = provider.photoUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        height: height,
        color: AppColors.tealLight,
        child: Center(
          child: Icon(
            _categoryIcon(provider.category),
            size: 42,
            color: AppColors.teal,
          ),
        ),
      );
    }
    return Image.network(
      imageUrl,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        height: height,
        color: AppColors.tealLight,
        child: Center(
          child: Icon(
            _categoryIcon(provider.category),
            size: 42,
            color: AppColors.teal,
          ),
        ),
      ),
    );
  }
}

IconData _categoryIcon(String category) => switch (category) {
  'Vétérinaires' => Icons.medical_services_outlined,
  'Toiletteurs' => Icons.content_cut_rounded,
  'Promeneurs' => Icons.directions_walk_rounded,
  'Pensions' => Icons.hotel_outlined,
  'Boutiques' => Icons.storefront_outlined,
  _ => Icons.pets_outlined,
};

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
  );
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Icon(icon, size: 34, color: AppColors.teal),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 10),
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}
