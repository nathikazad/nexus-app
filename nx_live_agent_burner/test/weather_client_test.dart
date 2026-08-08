import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nx_live_agent_burner/weather_client.dart';

void main() {
  test('geocodes a city and maps current weather', () async {
    final client = WeatherClient(
      client: MockClient((request) async {
        if (request.url.host == 'geocoding-api.open-meteo.com') {
          return http.Response(
            '{"results":[{"name":"Kochi","admin1":"Kerala",'
            '"country":"India","latitude":9.94,"longitude":76.26}]}',
            200,
          );
        }
        return http.Response(
          '{"current":{"time":"2026-08-08T12:00",'
          '"temperature_2m":29.4,"apparent_temperature":34.1,'
          '"weather_code":61,"wind_speed_10m":12.5}}',
          200,
        );
      }),
    );

    final weather = await client.current('Kochi');

    expect(weather.place, 'Kochi, Kerala, India');
    expect(weather.temperatureCelsius, 29.4);
    expect(weather.description, 'rain');
    expect(weather.toJson()['source'], 'Open-Meteo');
    client.dispose();
  });

  test('maps representative WMO weather codes', () {
    expect(weatherDescription(0), 'clear sky');
    expect(weatherDescription(80), 'rain showers');
    expect(weatherDescription(95), 'thunderstorm');
  });
}
