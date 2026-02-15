/// Lightweight model for a profile recommendation card.
///
/// Derived from [ItineraryStop] data where `rating == 5`.
///
/// TODO(DB): When an `is_recommended` column or a dedicated `recommendations`
/// table is added, fetch directly from the DB instead of computing client-side
/// from itinerary stops. Also add an `inspired_count` column backed by
/// aggregated interactions (saves + clones + add-to-trip).
class Recommendation {
  final String stopId;
  final String name;

  /// Raw category from [ItineraryStop.category].
  final String? category;

  /// City derived from the parent itinerary's destination.
  final String? city;

  /// ISO 3166-1 alpha-2 country code derived from the parent itinerary.
  final String? countryCode;

  final double? lat;
  final double? lng;

  /// Always 5.0 for now (only 5-star stops qualify).
  final double rating;

  /// Placeholder – TODO(tracking): implement inspired count via interaction
  /// tracking (saved-place + cloned-itinerary + add-to-trip attributable to
  /// viewing from this profile).
  final int inspiredCount;

  /// TODO(images): add place thumbnail URLs once a places/images table exists.
  final String? imageUrl;

  /// The itinerary this stop belongs to.
  final String itineraryId;

  const Recommendation({
    required this.stopId,
    required this.name,
    this.category,
    this.city,
    this.countryCode,
    this.lat,
    this.lng,
    this.rating = 5.0,
    this.inspiredCount = 0,
    this.imageUrl,
    required this.itineraryId,
  });

  /// Human-readable display category: Eat, Drink, Stay, or Guide.
  String get displayCategory {
    if (category == null) return 'Guide';
    final lower = category!.toLowerCase().trim();
    if (lower == 'eat' ||
        lower == 'restaurant' ||
        lower == 'food' ||
        lower == 'cafe' ||
        lower == 'bakery' ||
        lower == 'brunch' ||
        lower == 'dining') return 'Eat';
    if (lower == 'drink' ||
        lower == 'bar' ||
        lower == 'pub' ||
        lower == 'wine' ||
        lower == 'cocktail' ||
        lower == 'coffee' ||
        lower == 'lounge') return 'Drink';
    if (lower == 'stay' ||
        lower == 'hotel' ||
        lower == 'hostel' ||
        lower == 'accommodation' ||
        lower == 'lodge' ||
        lower == 'resort' ||
        lower == 'airbnb' ||
        lower == 'sleep') return 'Stay';
    return 'Guide';
  }
}
