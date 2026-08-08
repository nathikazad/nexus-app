import 'dart:convert';

import 'package:http/http.dart' as http;

class CurrentWeather {
  const CurrentWeather({
    required this.place,
    required this.latitude,
    required this.longitude,
    required this.temperatureCelsius,
    required this.apparentTemperatureCelsius,
    required this.windSpeedKph,
    required this.weatherCode,
    required this.observedAt,
  });

  final String place;
  final double latitude;
  final double longitude;
  final double temperatureCelsius;
  final double apparentTemperatureCelsius;
  final double windSpeedKph;
  final int weatherCode;
  final String observedAt;

  String get description => weatherDescription(weatherCode);

  Map<String, Object?> toJson() => {
    'place': place,
    'latitude': latitude,
    'longitude': longitude,
    'temperature_celsius': temperatureCelsius,
    'apparent_temperature_celsius': apparentTemperatureCelsius,
    'wind_speed_kph': windSpeedKph,
    'conditions': description,
    'weather_code': weatherCode,
    'observed_at': observedAt,
    'source': 'Open-Meteo',
  };
}

class WeatherClient {
  WeatherClient({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  Future<CurrentWeather> current(String location) async {
    if (location.isEmpty) throw ArgumentError('A location is required.');
    final geocodingUri = Uri.https(
      'geocoding-api.open-meteo.com',
      '/v1/search',
      {'name': location, 'count': '1', 'language': 'en', 'format': 'json'},
    );
    final geocoding = await _getJson(geocodingUri);
    final results = geocoding['results'];
    if (results is! List || results.isEmpty || results.first is! Map) {
      throw StateError('No weather location found for “$location”.');
    }
    final place = Map<String, dynamic>.from(results.first as Map);
    final latitude = _double(place['latitude']);
    final longitude = _double(place['longitude']);
    final forecastUri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '$latitude',
      'longitude': '$longitude',
      'current':
          'temperature_2m,apparent_temperature,weather_code,wind_speed_10m',
      'timezone': 'auto',
    });
    final forecast = await _getJson(forecastUri);
    final rawCurrent = forecast['current'];
    if (rawCurrent is! Map) {
      throw StateError('The weather service returned no current conditions.');
    }
    final current = Map<String, dynamic>.from(rawCurrent);
    final name = place['name']?.toString() ?? location;
    final area = place['admin1']?.toString();
    final country = place['country']?.toString();
    final labels = [
      name,
      if (area != null && area.isNotEmpty && area != name) area,
      if (country != null && country.isNotEmpty) country,
    ];
    return CurrentWeather(
      place: labels.join(', '),
      latitude: latitude,
      longitude: longitude,
      temperatureCelsius: _double(current['temperature_2m']),
      apparentTemperatureCelsius: _double(current['apparent_temperature']),
      windSpeedKph: _double(current['wind_speed_10m']),
      weatherCode: _integer(current['weather_code']),
      observedAt: current['time']?.toString() ?? '',
    );
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Weather service HTTP ${response.statusCode}.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw StateError('Invalid weather response.');
    return Map<String, dynamic>.from(decoded);
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}

double _double(Object? value) {
  if (value is num) return value.toDouble();
  return double.parse(value.toString());
}

int _integer(Object? value) {
  if (value is num) return value.toInt();
  return int.parse(value.toString());
}

String weatherDescription(int code) => switch (code) {
  0 => 'clear sky',
  1 => 'mainly clear',
  2 => 'partly cloudy',
  3 => 'overcast',
  45 || 48 => 'fog',
  51 || 53 || 55 => 'drizzle',
  56 || 57 => 'freezing drizzle',
  61 || 63 || 65 => 'rain',
  66 || 67 => 'freezing rain',
  71 || 73 || 75 || 77 => 'snow',
  80 || 81 || 82 => 'rain showers',
  85 || 86 => 'snow showers',
  95 => 'thunderstorm',
  96 || 99 => 'thunderstorm with hail',
  _ => 'unknown conditions',
};
