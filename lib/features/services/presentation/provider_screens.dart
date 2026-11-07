import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/service_models.dart';
import '../data/service_repository.dart';

/// Catégories proposées dans les formulaires : celles de la base, lues par l'annuaire.
List<String> get _providerCategories => ServiceCategory.knownNames;
const _dayNames = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];

class ProviderWorkspaceScreen extends StatelessWidget {
  const ProviderWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Connectez-vous pour accéder à cet espace.')),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Espace prestataire'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.store_outlined), text: 'Profil'),
              Tab(icon: Icon(Icons.pets_outlined), text: 'Prestations'),
              Tab(
                icon: Icon(Icons.calendar_month_outlined),
                text: 'Disponibilités',
              ),
              Tab(icon: Icon(Icons.event_note_outlined), text: 'Réservations'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ProviderProfileTab(user: user),
            _ProviderServicesTab(providerId: user.uid),
            _AvailabilityTab(providerId: user.uid),
            _ProviderBookingsTab(providerId: user.uid),
          ],
        ),
      ),
    );
  }
}

class _ProviderProfileTab extends StatefulWidget {
  const _ProviderProfileTab({required this.user});

  final User user;

  @override
  State<_ProviderProfileTab> createState() => _ProviderProfileTabState();
}

class _ProviderProfileTabState extends State<_ProviderProfileTab> {
  final _repository = ServiceRepository();
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.displayName ?? '');
  final _city = TextEditingController();
  final _description = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _photoUrl = TextEditingController();
  String _category = _providerCategories.first;
  bool _saving = false;
  bool _loaded = false;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _description.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _photoUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<ServiceProvider?>(
    stream: _repository.watchProvider(widget.user.uid),
    builder: (context, snapshot) {
      final provider = snapshot.data;
      if (provider != null && !_loaded) {
        _name.text = provider.name;
        _city.text = provider.city;
        _description.text = provider.description;
        _phone.text = provider.phone;
        _email.text = provider.email;
        _address.text = provider.address ?? '';
        _photoUrl.text = provider.photoUrl ?? '';
        _category = _providerCategories.contains(provider.category)
            ? provider.category
            : 'Autres';
        _loaded = true;
      }
      if (snapshot.hasError) {
        return const _WorkspaceMessage('Impossible de charger votre profil.');
      }
      return ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _ProviderStatusBanner(status: provider?.status ?? 'draft'),
          const SizedBox(height: 18),
          const Text(
            'Profil professionnel',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nom professionnel',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Nom requis'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  items: [
                    for (final value in _providerCategories)
                      DropdownMenuItem(value: value, child: Text(value)),
                  ],
                  onChanged: (value) =>
                      setState(() => _category = value ?? _category),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _city,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Ville'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Ville requise'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 500,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Téléphone'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-mail professionnel',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _address,
                  decoration: const InputDecoration(labelText: 'Adresse'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _photoUrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'URL de la photo',
                    prefixIcon: Icon(Icons.image_outlined),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _saving ? null : () => _save(provider),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Enregistrer le profil'),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );

  Future<void> _save(ServiceProvider? current) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _repository.saveProvider(
        ServiceProvider(
          id: widget.user.uid,
          ownerId: widget.user.uid,
          name: _name.text,
          category: _category,
          city: _city.text,
          description: _description.text,
          phone: _phone.text,
          email: _email.text,
          status: current?.status == 'rejected'
              ? 'pending'
              : current?.status ?? 'pending',
          photoUrl: _photoUrl.text.trim().isEmpty
              ? null
              : _photoUrl.text.trim(),
          address: _address.text,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Profil enregistré. Il sera visible après validation.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enregistrement impossible : $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ProviderStatusBanner extends StatelessWidget {
  const _ProviderStatusBanner({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final published = status == 'published';
    final rejected = status == 'rejected';
    final color = published
        ? const Color(0xFF15803D)
        : rejected
        ? AppColors.error
        : const Color(0xFFB45309);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: published
            ? const Color(0xFFDCFCE7)
            : rejected
            ? const Color(0xFFFEE2E2)
            : const Color(0xFFFFF3D6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            published
                ? Icons.check_circle_outline
                : rejected
                ? Icons.cancel_outlined
                : Icons.hourglass_top_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              published
                  ? 'Profil publié'
                  : rejected
                  ? 'Profil refusé · vous pouvez le modifier puis le renvoyer'
                  : 'En attente de validation',
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderServicesTab extends StatelessWidget {
  const _ProviderServicesTab({required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context) {
    final repository = ServiceRepository();
    return StreamBuilder<List<ProviderService>>(
      stream: repository.watchServices(providerId, includeArchived: true),
      builder: (context, snapshot) {
        final services = snapshot.data ?? const <ProviderService>[];
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Mes prestations',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton.filled(
                  tooltip: 'Nouvelle prestation',
                  onPressed: () =>
                      _showServiceEditor(context, repository, providerId),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (snapshot.hasError)
              const _WorkspaceMessage('Impossible de charger les prestations.')
            else if (!snapshot.hasData)
              const Center(child: CircularProgressIndicator())
            else if (services.isEmpty)
              const _WorkspaceMessage('Ajoutez votre première prestation.')
            else
              for (final service in services)
                _ServiceManagementCard(
                  service: service,
                  onEdit: () => _showServiceEditor(
                    context,
                    repository,
                    providerId,
                    service,
                  ),
                  onArchive: service.status == 'archived'
                      ? null
                      : () => repository.saveService(
                          ProviderService(
                            id: service.id,
                            providerId: providerId,
                            name: service.name,
                            category: service.category,
                            durationMinutes: service.durationMinutes,
                            price: service.price,
                            status: 'archived',
                            description: service.description,
                          ),
                        ),
                ),
          ],
        );
      },
    );
  }
}

class _ServiceManagementCard extends StatelessWidget {
  const _ServiceManagementCard({
    required this.service,
    required this.onEdit,
    required this.onArchive,
  });

  final ProviderService service;
  final VoidCallback onEdit;
  final VoidCallback? onArchive;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const CircleAvatar(
          backgroundColor: AppColors.tealLight,
          child: Icon(Icons.pets, color: AppColors.teal),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                service.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '${service.durationMinutes} min · ${service.price.toStringAsFixed(0)} DT',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              if (service.status == 'archived')
                const Text(
                  'Archivée',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Modifier',
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
        ),
        if (onArchive != null)
          IconButton(
            tooltip: 'Archiver',
            onPressed: onArchive,
            icon: const Icon(Icons.archive_outlined),
          ),
      ],
    ),
  );
}

Future<void> _showServiceEditor(
  BuildContext context,
  ServiceRepository repository,
  String providerId, [
  ProviderService? service,
]) async {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController(text: service?.name ?? '');
  final description = TextEditingController(text: service?.description ?? '');
  final duration = TextEditingController(
    text: '${service?.durationMinutes ?? 45}',
  );
  final price = TextEditingController(
    text: service?.price.toStringAsFixed(0) ?? '',
  );
  var category = service?.category ?? _providerCategories.first;

  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(
          service == null ? 'Nouvelle prestation' : 'Modifier la prestation',
        ),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nom'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Nom requis'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Catégorie'),
                    items: [
                      // Une catégorie supprimée depuis reste choisie pour les prestations qui l'utilisent.
                      for (final value in {..._providerCategories, category})
                        DropdownMenuItem(value: value, child: Text(value)),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => category = value ?? category),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: duration,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Durée (minutes)',
                    ),
                    validator: (value) => int.tryParse(value ?? '') == null
                        ? 'Durée invalide'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Prix indicatif (DT)',
                    ),
                    validator: (value) => double.tryParse(value ?? '') == null
                        ? 'Prix invalide'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: description,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await repository.saveService(
                ProviderService(
                  id: service?.id ?? '',
                  providerId: providerId,
                  name: name.text,
                  category: category,
                  durationMinutes: int.parse(duration.text),
                  price: double.parse(price.text.replaceAll(',', '.')),
                  status: service?.status ?? 'published',
                  description: description.text,
                ),
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  description.dispose();
  duration.dispose();
  price.dispose();
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Prestation enregistrée.')));
  }
}

class _AvailabilityTab extends StatelessWidget {
  const _AvailabilityTab({required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context) {
    final repository = ServiceRepository();
    return StreamBuilder<Map<int, Map<String, dynamic>>>(
      stream: repository.watchAvailability(providerId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _WorkspaceMessage(
            'Impossible de charger vos disponibilités.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final availability = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              'Disponibilités',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Définissez vos jours et horaires de réservation.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            for (var day = 1; day <= 7; day++)
              _AvailabilityDayCard(
                day: day,
                data: availability[day],
                onSave: (value) => repository.saveAvailability(day, value),
              ),
          ],
        );
      },
    );
  }
}

class _AvailabilityDayCard extends StatefulWidget {
  const _AvailabilityDayCard({
    required this.day,
    required this.data,
    required this.onSave,
  });

  final int day;
  final Map<String, dynamic>? data;
  final Future<void> Function(Map<String, dynamic>) onSave;

  @override
  State<_AvailabilityDayCard> createState() => _AvailabilityDayCardState();
}

class _AvailabilityDayCardState extends State<_AvailabilityDayCard> {
  late bool _enabled;
  late List<Map<String, String>> _ranges;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _readData();
  }

  @override
  void didUpdateWidget(covariant _AvailabilityDayCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) _readData();
  }

  void _readData() {
    final data = widget.data ?? const <String, dynamic>{};
    _enabled = data['enabled'] as bool? ?? false;
    final ranges = data['ranges'];
    _ranges = ranges is List
        ? ranges.map((range) => Map<String, String>.from(range as Map)).toList()
        : [
            {
              'start': data['start'] as String? ?? '09:00',
              'end': data['end'] as String? ?? '17:00',
            },
          ];
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSave({
        'enabled': _enabled,
        'ranges': _ranges,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enregistrement impossible : $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            _dayNames[widget.day - 1],
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          value: _enabled,
          activeThumbColor: AppColors.teal,
          onChanged: (value) => setState(() => _enabled = value),
        ),
        if (_enabled) ...[
          for (var index = 0; index < _ranges.length; index++)
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _chooseTime(index, 'start'),
                  icon: const Icon(Icons.schedule_outlined),
                  label: Text(_ranges[index]['start']!),
                ),
                const Text(
                  'à',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                TextButton(
                  onPressed: () => _chooseTime(index, 'end'),
                  child: Text(_ranges[index]['end']!),
                ),
                const Spacer(),
                if (_ranges.length > 1)
                  IconButton(
                    tooltip: 'Supprimer cette plage',
                    onPressed: () => setState(() => _ranges.removeAt(index)),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
              ],
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(
                () => _ranges.add({'start': '14:00', 'end': '17:00'}),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une plage'),
            ),
          ),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: const Text('Enregistrer'),
          ),
        ),
      ],
    ),
  );

  Future<void> _chooseTime(int rangeIndex, String key) async {
    final oldParts = _ranges[rangeIndex][key]!.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(oldParts[0]),
        minute: int.parse(oldParts[1]),
      ),
    );
    if (picked == null) return;
    setState(() {
      _ranges[rangeIndex][key] =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    });
  }
}

class _ProviderBookingsTab extends StatelessWidget {
  const _ProviderBookingsTab({required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context) {
    final repository = ServiceRepository();
    return StreamBuilder<List<ServiceBooking>>(
      stream: repository.watchProviderBookings(providerId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _WorkspaceMessage(
            'Impossible de charger les réservations.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final bookings = snapshot.data!;
        if (bookings.isEmpty) {
          return const _WorkspaceMessage(
            'Vos demandes de réservation apparaîtront ici.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              'Réservations reçues · ${bookings.where((booking) => booking.status == 'pending').length} en attente',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            for (final booking in bookings)
              _BookingManagementCard(
                booking: booking,
                onStatus: (status) async {
                  try {
                    await repository.setBookingStatus(booking.id, status);
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Mise à jour impossible : $error'),
                        ),
                      );
                    }
                  }
                },
              ),
          ],
        );
      },
    );
  }
}

class _BookingManagementCard extends StatelessWidget {
  const _BookingManagementCard({required this.booking, required this.onStatus});

  final ServiceBooking booking;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    final pending = booking.status == 'pending';
    final statusColor = switch (booking.status) {
      'confirmed' => const Color(0xFF15803D),
      'declined' || 'cancelled' => AppColors.textSecondary,
      _ => const Color(0xFFB45309),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.tealLight,
                child: Icon(Icons.person_outline, color: AppColors.teal),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.clientName.isEmpty
                          ? 'Client'
                          : booking.clientName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      booking.animalName,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _bookingStatus(booking.status),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 22),
          Text(
            booking.serviceName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '${booking.dateTime.day.toString().padLeft(2, '0')}/${booking.dateTime.month.toString().padLeft(2, '0')}/${booking.dateTime.year} · ${booking.dateTime.hour.toString().padLeft(2, '0')}:${booking.dateTime.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (booking.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(booking.notes),
          ],
          if (pending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onStatus('declined'),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Refuser'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => onStatus('confirmed'),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Confirmer'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _bookingStatus(String status) => switch (status) {
  'confirmed' => 'Confirmée',
  'declined' => 'Refusée',
  'cancelled' => 'Annulée',
  _ => 'En attente',
};

class _WorkspaceMessage extends StatelessWidget {
  const _WorkspaceMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    ),
  );
}

class ServicesAdminScreen extends StatelessWidget {
  const ServicesAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = ServiceRepository();
    return Scaffold(
      appBar: AppBar(title: const Text('Validation des prestataires')),
      body: StreamBuilder<List<ServiceProvider>>(
        stream: repository.watchPendingProviders(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _WorkspaceMessage(
              'Impossible de charger les demandes.',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final providers = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.pending_actions_outlined,
                      color: AppColors.teal,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Prestataires à valider',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          Text(
                            '${providers.length}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Demandes en attente',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              if (providers.isEmpty)
                const _WorkspaceMessage(
                  'Aucun prestataire en attente de validation.',
                )
              else
                for (final provider in providers)
                  _AdminProviderCard(
                    provider: provider,
                    onStatus: (status) async {
                      try {
                        await repository.setProviderStatus(provider.id, status);
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Mise à jour impossible : $error'),
                            ),
                          );
                        }
                      }
                    },
                  ),
              const SizedBox(height: 22),
              _AdminCategoriesCard(repository: repository),
            ],
          );
        },
      ),
    );
  }
}

/// Catégories de l'annuaire : l'administrateur en ajoute ou en supprime.
class _AdminCategoriesCard extends StatefulWidget {
  const _AdminCategoriesCard({required this.repository});

  final ServiceRepository repository;

  @override
  State<_AdminCategoriesCard> createState() => _AdminCategoriesCardState();
}

class _AdminCategoriesCardState extends State<_AdminCategoriesCard> {
  static const _icons = [
    'veterinaire', 'toilettage', 'promenade', 'pension', 'boutique', 'education', 'pharmacie', 'transport', 'autre',
  ];

  late final _stream = widget.repository.watchCategories();
  final _name = TextEditingController();
  String _icon = 'autre';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action impossible : $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le nom doit contenir au moins 2 caractères.')),
      );
      return;
    }
    await _run(() async {
      await widget.repository.addCategory(name, _icon);
      _name.clear();
    });
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Catégories de l'annuaire", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text(
          'Les professionnels sont classés dans ces catégories.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<ServiceCategory>>(
          stream: _stream,
          initialData: ServiceCategory.defaults,
          builder: (context, snapshot) {
            final categories = snapshot.data ?? ServiceCategory.defaults;
            return Column(
              children: [
                for (final category in categories)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(category.iconData, color: AppColors.teal),
                    title: Text(category.name),
                    // Les catégories par défaut ne sont pas encore dans la base : rien à supprimer.
                    trailing: identical(categories, ServiceCategory.defaults)
                        ? null
                        : IconButton(
                            tooltip: 'Supprimer',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: _busy ? null : () => _run(() => widget.repository.deleteCategory(category.id)),
                          ),
                  ),
              ],
            );
          },
        ),
        const Divider(),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _name,
                maxLength: 40,
                decoration: const InputDecoration(labelText: 'Nouvelle catégorie', counterText: ''),
              ),
            ),
            const SizedBox(width: 10),
            DropdownButton<String>(
              value: _icon,
              onChanged: (value) => setState(() => _icon = value ?? 'autre'),
              items: [
                for (final key in _icons)
                  DropdownMenuItem(value: key, child: Icon(serviceCategoryIcon(key), color: AppColors.teal)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _busy ? null : _add,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter'),
          ),
        ),
      ],
    ),
  );
}

class _AdminProviderCard extends StatelessWidget {
  const _AdminProviderCard({required this.provider, required this.onStatus});

  final ServiceProvider provider;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          provider.name,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        const SizedBox(height: 4),
        Text(
          '${provider.category} · ${provider.city}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        if (provider.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            provider.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (provider.email.isNotEmpty || provider.phone.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            [
              provider.email,
              provider.phone,
            ].where((value) => value.isNotEmpty).join(' · '),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => onStatus('rejected'),
                icon: const Icon(Icons.close_rounded),
                label: const Text('Refuser'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => onStatus('published'),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Valider'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
