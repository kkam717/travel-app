import 'countries.dart';

/// Place type for search/explore (cities + natural places).
const List<String> placeTypes = ['city', 'volcano', 'desert', 'mountain'];

/// Notable place for discovery: name, type, country code.
class NotablePlace {
  final String name;
  final String type; // 'volcano' | 'desert' | 'mountain'
  final String countryCode;

  const NotablePlace({required this.name, required this.type, required this.countryCode});

  String get countryName => countries[countryCode] ?? countryCode;
}

/// Curated notable places (volcanoes, deserts, mountains) for explore/search.
const List<NotablePlace> notablePlaces = [
  NotablePlace(name: 'Volcán Acatenango', type: 'volcano', countryCode: 'GT'),
  NotablePlace(name: 'Volcán de Fuego', type: 'volcano', countryCode: 'GT'),
  NotablePlace(name: 'Salar de Uyuni (Salvador Dalí Desert)', type: 'desert', countryCode: 'BO'),
  NotablePlace(name: 'Salvador Dalí Desert', type: 'desert', countryCode: 'BO'),
  NotablePlace(name: 'Atacama Desert', type: 'desert', countryCode: 'CL'),
  NotablePlace(name: 'Sahara Desert', type: 'desert', countryCode: 'MA'),
  NotablePlace(name: 'Mount Fuji', type: 'mountain', countryCode: 'JP'),
  NotablePlace(name: 'Matterhorn', type: 'mountain', countryCode: 'CH'),
  NotablePlace(name: 'Table Mountain', type: 'mountain', countryCode: 'ZA'),
  NotablePlace(name: 'Mount Kilimanjaro', type: 'mountain', countryCode: 'TZ'),
  NotablePlace(name: 'Mount Etna', type: 'volcano', countryCode: 'IT'),
  NotablePlace(name: 'Santorini', type: 'volcano', countryCode: 'GR'),
];

List<NotablePlace> notablePlacesByType(String type) {
  return notablePlaces.where((p) => p.type == type).toList();
}
