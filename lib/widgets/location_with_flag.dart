import 'package:flutter/material.dart';
import '../services/places_service.dart';
import 'country_filter_chips.dart';

/// Shows the country flag emoji for a city by geocoding the city name to a country code.
/// When [city] is null or empty, or geocoding fails, builds an empty widget so layout stays stable.
class LocationFlagIcon extends StatefulWidget {
  final String? city;
  final double fontSize;

  const LocationFlagIcon({
    super.key,
    this.city,
    this.fontSize = 18,
  });

  @override
  State<LocationFlagIcon> createState() => _LocationFlagIconState();
}

class _LocationFlagIconState extends State<LocationFlagIcon> {
  Future<String?>? _countryFuture;

  void _updateFuture() {
    if (widget.city != null && widget.city!.trim().isNotEmpty) {
      _countryFuture = PlacesService.geocodeToCountryCode(widget.city!.trim());
    } else {
      _countryFuture = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _updateFuture();
  }

  @override
  void didUpdateWidget(covariant LocationFlagIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.city != widget.city) _updateFuture();
  }

  @override
  Widget build(BuildContext context) {
    if (_countryFuture == null) return const SizedBox.shrink();
    return FutureBuilder<String?>(
      future: _countryFuture,
      builder: (context, snapshot) {
        final code = snapshot.data;
        if (code == null || code.length != 2) return const SizedBox.shrink();
        final flag = CountryFilterChips.flagEmoji(code);
        if (flag.isEmpty) return const SizedBox.shrink();
        return Text(
          flag,
          style: TextStyle(fontSize: widget.fontSize, height: 1.2),
        );
      },
    );
  }
}
