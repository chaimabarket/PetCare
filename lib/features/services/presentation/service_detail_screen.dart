import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../data/service_models.dart';
import '../data/service_repository.dart';

class ServiceDetailScreen extends StatelessWidget {
  const ServiceDetailScreen({
    super.key,
    required this.provider,
    required this.repository,
  });

  final ServiceProvider provider;
  final ServiceRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil prestataire')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 220,
              child: provider.photoUrl == null || provider.photoUrl!.isEmpty
                  ? Container(
                      color: AppColors.tealLight,
                      child: const Icon(
                        Icons.storefront_outlined,
                        size: 58,
                        color: AppColors.teal,
                      ),
                    )
                  : Image.network(
                      provider.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppColors.tealLight,
                        child: const Icon(
                          Icons.storefront_outlined,
                          size: 58,
                          color: AppColors.teal,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  provider.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.verified_rounded, color: AppColors.teal),
              const SizedBox(width: 4),
              const Text(
                'Vérifié',
                style: TextStyle(
                  color: AppColors.teal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '${provider.category} · ${provider.city}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (provider.description.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(provider.description, style: const TextStyle(height: 1.5)),
          ],
          const SizedBox(height: 22),
          const Text(
            'Prestations',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<ProviderService>>(
            stream: repository.watchServices(provider.ownerId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const _ServiceNotice(
                  'Impossible de charger les prestations.',
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.data!.isEmpty) {
                return const _ServiceNotice(
                  'Aucune prestation disponible actuellement.',
                );
              }
              return Column(
                children: [
                  for (final service in snapshot.data!)
                    _ServiceTile(
                      service: service,
                      onBook: () {
                        if (FirebaseAuth.instance.currentUser == null) {
                          Navigator.of(context).pushNamed(AppRoutes.login);
                          return;
                        }
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => BookingRequestScreen(
                              provider: provider,
                              service: service,
                              repository: repository,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
          if (provider.address != null && provider.address!.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Text(
              'Adresse',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, color: AppColors.teal),
                const SizedBox(width: 8),
                Expanded(child: Text(provider.address!)),
              ],
            ),
          ],
          if (provider.phone.isNotEmpty || provider.email.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Text(
              'Contact',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            if (provider.phone.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone_outlined),
                title: Text(provider.phone),
              ),
            if (provider.email.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.email_outlined),
                title: Text(provider.email),
              ),
          ],
        ],
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service, required this.onBook});

  final ProviderService service;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0F0F172A),
          blurRadius: 3,
          offset: Offset(0, 1),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                service.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${service.price.toStringAsFixed(0)} DT',
              style: const TextStyle(
                color: AppColors.teal,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          '${service.durationMinutes} min · prix indicatif',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        if (service.description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            service.description,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onBook,
          icon: const Icon(Icons.calendar_month_outlined),
          label: const Text('Réserver'),
        ),
      ],
    ),
  );
}

class _ServiceNotice extends StatelessWidget {
  const _ServiceNotice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      message,
      style: const TextStyle(color: AppColors.textSecondary),
    ),
  );
}

class BookingRequestScreen extends StatefulWidget {
  const BookingRequestScreen({
    super.key,
    required this.provider,
    required this.service,
    required this.repository,
  });

  final ServiceProvider provider;
  final ProviderService service;
  final ServiceRepository repository;

  @override
  State<BookingRequestScreen> createState() => _BookingRequestScreenState();
}

class _BookingRequestScreenState extends State<BookingRequestScreen> {
  static const _times = ['09:00', '10:30', '12:00', '14:00', '15:30', '17:00'];
  static const _weekdays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
  static const _months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

  final _animalController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  String? _time;
  bool _saving = false;
  bool _sent = false;

  @override
  void dispose() {
    _animalController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) return _BookingSuccessScreen(providerName: widget.provider.name);
    return Scaffold(
      appBar: AppBar(title: const Text('Réserver une prestation')),
      body: StreamBuilder<List<ServiceBooking>>(
        stream: widget.repository.watchProviderBookings(
          widget.provider.ownerId,
        ),
        builder: (context, snapshot) {
          final bookings = snapshot.data ?? const <ServiceBooking>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
            children: [
              _BookingServiceSummary(
                provider: widget.provider,
                service: widget.service,
              ),
              const SizedBox(height: 22),
              const _BookingSectionLabel('Pour quel animal ?'),
              const SizedBox(height: 8),
              TextField(
                controller: _animalController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: "Nom de l'animal",
                  prefixIcon: Icon(Icons.pets_outlined),
                ),
              ),
              const SizedBox(height: 22),
              const _BookingSectionLabel('Choisir une date'),
              const SizedBox(height: 10),
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 7,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final date = DateUtils.dateOnly(DateTime.now())
                        .add(Duration(days: index));
                    final selected = DateUtils.isSameDay(date, _date);
                    return ChoiceChip(
                      label: SizedBox(
                        width: 44,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _weekdays[date.weekday - 1],
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              '${date.day}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      selected: selected,
                      onSelected: (_) => setState(() {
                        _date = date;
                        _time = null;
                      }),
                      selectedColor: AppColors.teal,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : AppColors.textPrimary,
                      ),
                      showCheckmark: false,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_date.day} ${_months[_date.month - 1]} ${_date.year}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              const _BookingSectionLabel('Créneaux disponibles'),
              const SizedBox(height: 10),
              StreamBuilder<Map<int, Map<String, dynamic>>>(
                stream: widget.repository.watchAvailability(
                  widget.provider.ownerId,
                ),
                builder: (context, availabilitySnapshot) {
                  final dayAvailability =
                      availabilitySnapshot.data?[_date.weekday];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (availabilitySnapshot.hasData &&
                          dayAvailability?['enabled'] != true)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Text(
                            'Aucun horaire défini pour cette journée.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      Wrap(
                        spacing: 9,
                        runSpacing: 9,
                        children: [
                          for (final time in _times)
                            _TimeChip(
                              time: time,
                              selected: _time == time,
                              unavailable:
                                  bookings.any(
                                    (booking) =>
                                        booking.dateTime.year == _date.year &&
                                        booking.dateTime.month == _date.month &&
                                        booking.dateTime.day == _date.day &&
                                        booking.dateTime.hour ==
                                            int.parse(time.substring(0, 2)) &&
                                        booking.dateTime.minute ==
                                            int.parse(time.substring(3)) &&
                                        (booking.status == 'pending' ||
                                            booking.status == 'confirmed'),
                                  ) ||
                                  !_availabilityAllowsTime(
                                    time,
                                    dayAvailability,
                                  ) ||
                                  _slotIsPast(time),
                              onSelected: () => setState(() => _time = time),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              const _BookingSectionLabel('Notes (facultatif)'),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                minLines: 3,
                maxLines: 5,
                maxLength: 400,
                decoration: const InputDecoration(
                  hintText: 'Une information utile pour le prestataire…',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saving || _time == null ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: const Text('Demander la réservation'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Le prix sera confirmé directement avec le prestataire.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _slotIsPast(String time) {
    final hour = int.parse(time.substring(0, 2));
    final minute = int.parse(time.substring(3));
    return DateTime(
      _date.year,
      _date.month,
      _date.day,
      hour,
      minute,
    ).isBefore(DateTime.now());
  }

  bool _availabilityAllowsTime(
    String time,
    Map<String, dynamic>? availability,
  ) {
    if (availability?['enabled'] != true) return false;
    final slotStart =
        int.parse(time.substring(0, 2)) * 60 + int.parse(time.substring(3));
    final slotEnd = slotStart + widget.service.durationMinutes;
    final rawRanges = availability?['ranges'];
    final ranges = rawRanges is List ? rawRanges : [availability];
    return ranges.whereType<Map>().any((range) {
      final start = range['start'];
      final end = range['end'];
      if (start is! String || end is! String) return false;
      final startParts = start.split(':');
      final endParts = end.split(':');
      if (startParts.length != 2 || endParts.length != 2) return false;
      final startMinutes =
          int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
      return slotStart >= startMinutes && slotEnd <= endMinutes;
    });
  }

  Future<void> _submit() async {
    if (_animalController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Indiquez le nom de l'animal.")),
      );
      return;
    }
    final time = _time!;
    final dateTime = DateTime(
      _date.year,
      _date.month,
      _date.day,
      int.parse(time.substring(0, 2)),
      int.parse(time.substring(3)),
    );
    setState(() => _saving = true);
    try {
      await widget.repository.createBooking(
        provider: widget.provider,
        service: widget.service,
        animalName: _animalController.text,
        dateTime: dateTime,
        notes: _notesController.text,
      );
      if (mounted) setState(() => _sent = true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Réservation impossible : $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _BookingServiceSummary extends StatelessWidget {
  const _BookingServiceSummary({required this.provider, required this.service});

  final ServiceProvider provider;
  final ProviderService service;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const CircleAvatar(
          backgroundColor: AppColors.tealLight,
          child: Icon(Icons.spa_outlined, color: AppColors.teal),
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
                '${provider.name} · ${service.durationMinutes} min',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Text(
          '${service.price.toStringAsFixed(0)} DT',
          style: const TextStyle(
            color: AppColors.teal,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _BookingSectionLabel extends StatelessWidget {
  const _BookingSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) =>
      Text(label, style: const TextStyle(fontWeight: FontWeight.w700));
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.time,
    required this.selected,
    required this.unavailable,
    required this.onSelected,
  });

  final String time;
  final bool selected;
  final bool unavailable;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(time),
    selected: selected,
    onSelected: unavailable ? null : (_) => onSelected(),
    selectedColor: AppColors.teal,
    disabledColor: const Color(0xFFE5E7EB),
    labelStyle: TextStyle(
      color: unavailable
          ? AppColors.textSecondary
          : selected
          ? Colors.white
          : AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    showCheckmark: false,
  );
}

class _BookingSuccessScreen extends StatelessWidget {
  const _BookingSuccessScreen({required this.providerName});

  final String providerName;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Demande envoyée')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: AppColors.tealLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 48,
                color: AppColors.teal,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Demande envoyée',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Votre demande est visible dans votre agenda. $providerName vous répondra bientôt.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Terminé'),
            ),
          ],
        ),
      ),
    ),
  );
}
