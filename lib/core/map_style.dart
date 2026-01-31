/// Shared Google Maps style - clean, minimal light palette.
/// Used by itinerary map and visited countries map.
const String googleMapsStyleJson = '''
[
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#e8f4f8"}]},
  {"featureType":"landscape","elementType":"geometry","stylers":[{"color":"#f8f9fa"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#e9ecef"},{"weight":1}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#f1f3f5"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#dee2e6"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.park","stylers":[{"visibility":"simplified"},{"color":"#e8f5e9"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative","elementType":"geometry.stroke","stylers":[{"color":"#e9ecef"}]},
  {"featureType":"administrative","elementType":"labels.text.fill","stylers":[{"color":"#6c757d"}]},
  {"featureType":"administrative","elementType":"labels.text.stroke","stylers":[{"color":"#ffffff"}]}
]
''';
