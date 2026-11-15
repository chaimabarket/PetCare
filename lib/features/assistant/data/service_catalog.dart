import '../../services/data/service_models.dart';
import '../../services/data/service_repository.dart';
import 'assistant_actions.dart';

/// Prestation publiée, son prestataire et ses disponibilités, tels que l'assistant les connaît.
class CatalogService {
  const CatalogService({required this.provider, required this.service, required this.availability});

  final ServiceProvider provider;
  final ProviderService service;

  /// Disponibilités par jour de la semaine (1 = lundi), comme `ServiceRepository.watchAvailability`.
  final Map<int, Map<String, dynamic>> availability;

  String get id => service.id;
}

/// Nombre maximal de prestations envoyées au modèle.
const kServiceContextMax = 40;

const _serviceKeywords = [
  'réserv', 'reserv', 'vétérin', 'veterin', 'véto', 'veto', 'vet ', 'clinique', 'toilett', 'groom', 'salon',
  'pension', 'garde', 'promen', 'dressage', 'éducat', 'prestataire', 'prestation', 'service', 'rendez-vous',
  'rdv', 'book', 'appointment',
];

/// Vrai si la conversation parle d'un service ou d'une réservation : on joint alors les PRESTATIONS.
bool isServiceQuestion(String text) {
  final lower = ' ${text.toLowerCase()} ';
  return _serviceKeywords.any(lower.contains);
}

const _dayNames = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];

String _clean(String value) => value.replaceAll(RegExp(r'[\s|]+'), ' ').trim();

/// Plages d'un jour : `ranges`, ou l'ancien format `start` / `end` directement dans le jour.
List<String> _ranges(Map<String, dynamic>? day) {
  if (day == null || day['enabled'] != true) return const [];
  final raw = day['ranges'];
  final list = raw is List ? raw : [day];
  return [
    for (final r in list.whereType<Map>())
      if (r['start'] is String && r['end'] is String) '${r['start']}-${r['end']}',
  ];
}

bool _isOpen(Map<int, Map<String, dynamic>> week, int weekday) => _ranges(week[weekday]).isNotEmpty;

/// « lun 09:00-12:00 ; mar … ; fermé dim » : les jours fermés sont écrits pour que le modèle ne les propose pas.
String _hoursLine(Map<int, Map<String, dynamic>> week) {
  final open = [
    for (var d = 1; d <= 7; d++)
      if (_isOpen(week, d)) '${_dayNames[d - 1].substring(0, 3)} ${_ranges(week[d]).join(' ')}',
  ];
  if (open.isEmpty) return 'aucun horaire';
  final closed = [
    for (var d = 1; d <= 7; d++)
      if (!_isOpen(week, d)) _dayNames[d - 1].substring(0, 3),
  ];
  return [...open, if (closed.isNotEmpty) 'fermé ${closed.join(', ')}'].join(' ; ');
}

String _amount(double price) =>
    price == price.roundToDouble() ? '${price.toInt()}' : price.toString().replaceAll('.', ',');

/// Bloc « PRESTATIONS » : une ligne par prestation publiée, sans coordonnées personnelles.
String buildServiceContext(List<CatalogService> catalog) {
  final list = catalog.take(kServiceContextMax).toList();
  if (list.isEmpty) return 'PRESTATIONS (services PetCare réservables) : aucune pour le moment.';
  final lines = [
    for (final s in list)
      [
        '- id=${s.id}',
        _clean(s.service.name),
        '${_clean(s.provider.name)} (${_clean(s.provider.category)}, ${_clean(s.provider.city)})',
        '${s.service.durationMinutes} min',
        '${_amount(s.service.price)} DT',
        'horaires : ${_hoursLine(s.availability)}',
      ].join(' | '),
  ];
  return 'PRESTATIONS (services PetCare réservables ; heures de début possibles : ${kBookingTimes.join(', ')}, '
      'dans les horaires du prestataire) :\n${lines.join('\n')}';
}

CatalogService? findService(AssistantAction a, List<CatalogService> catalog) =>
    catalog.where((s) => s.id == a.text('service_id')).firstOrNull;

/// Recopie la prestation choisie dans l'action (prestataire, prix…) ; inchangée si l'identifiant est inconnu.
AssistantAction withServiceDetails(AssistantAction a, List<CatalogService> catalog) {
  if (a.type != AssistantActionType.serviceBooking) return a;
  final s = findService(a, catalog);
  if (s == null) return a;
  final address = s.provider.address?.trim() ?? '';
  final city = s.provider.city.trim();
  return a.withArgs({
    'prestataire': s.provider.name,
    'prestation': s.service.name,
    'duree': s.service.durationMinutes,
    'prix': s.service.price,
    'adresse': address.toLowerCase().contains(city.toLowerCase())
        ? address
        : [address, city].where((v) => v.isNotEmpty).join(', '),
  });
}

/// Vérifie le créneau comme le formulaire de réservation : heure proposée, jour ouvert, plage, pas dans le passé.
/// `null` = créneau possible ; sinon une phrase qui propose les créneaux du jour.
String? bookingProblem(AssistantAction a, CatalogService s, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final start = a.startsAt;
  final day = a.date('date');
  if (start == null || day == null) return "L'heure de la réservation n'est pas valide. À quelle heure souhaitez-vous venir ?";
  final provider = s.provider.name;
  final label = '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}';
  if (!_isOpen(s.availability, day.weekday)) {
    final openDays = [
      for (var d = 1; d <= 7; d++)
        if (_isOpen(s.availability, d)) _dayNames[d - 1],
    ];
    return '$provider est fermé le ${_dayNames[day.weekday - 1]}'
        '${openDays.isEmpty ? '' : ' (ouvert : ${openDays.join(', ')})'}. Quel autre jour vous convient ?';
  }
  bool possible(String time) {
    final t = DateTime(day.year, day.month, day.day, int.parse(time.substring(0, 2)), int.parse(time.substring(3)));
    return availabilityAllows(s.availability[day.weekday], time, s.service.durationMinutes) && t.isAfter(current);
  }

  final time = '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
  if (kBookingTimes.contains(time) && possible(time)) return null;
  final free = kBookingTimes.where(possible).toList();
  if (free.isEmpty) return '$provider n\'a plus de créneau possible le $label pour cette prestation. Voulez-vous un autre jour ?';
  return '$time n\'est pas proposé chez $provider le $label. Créneaux possibles ce jour-là : ${free.join(', ')}. '
      'Lequel souhaitez-vous ?';
}

List<CatalogService>? _cache;
DateTime? _cachedAt;

/// Prestations publiées de l'annuaire (mêmes lectures que l'écran Services), gardées 2 minutes :
/// une conversation sur une réservation compte souvent plusieurs messages.
Future<List<CatalogService>> loadServiceCatalog([ServiceRepository? repository]) async {
  final cachedAt = _cachedAt;
  if (_cache != null && cachedAt != null && DateTime.now().difference(cachedAt) < const Duration(minutes: 2)) {
    return _cache!;
  }
  final repo = repository ?? ServiceRepository();
  final providers = (await repo.watchPublishedProviders().first).take(20).toList();
  final perProvider = await Future.wait([
    for (final p in providers)
      () async {
        try {
          final results = await Future.wait<Object>([
            repo.watchServices(p.ownerId).first,
            repo.watchAvailability(p.ownerId).first,
          ]);
          final services = results[0] as List<ProviderService>;
          final week = results[1] as Map<int, Map<String, dynamic>>;
          return [
            for (final s in services)
              if (s.status == 'published') CatalogService(provider: p, service: s, availability: week),
          ];
        } catch (_) {
          return const <CatalogService>[];
        }
      }(),
  ]);
  final list = perProvider.expand((l) => l).take(kServiceContextMax).toList();
  _cache = list;
  _cachedAt = DateTime.now();
  return list;
}
