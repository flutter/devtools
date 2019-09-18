/// All Restful Servers are defined here.

import 'tabs/settings.dart';

/// All servers with RestfulAPI implement this base.
abstract class RestfulAPI {
  RestfulAPI(this.previous);

  RestfulAPI previous;
  RestfulAPI next;

  String uri();

  dynamic findData(dynamic data);

  String display(dynamic data, int index);
}

/// StarWars information server.
class StarWars extends RestfulAPI {
  StarWars([int index = 1]) : super(currentRestfulAPI) {
    switch (index) {
      case 0:
        _defaultUri = StarWars.filmsUri;
        break;
      case 1:
        _defaultUri = StarWars.peopleUri;
        break;
      case 2:
        _defaultUri = StarWars.planetsUri;
        break;
      case 3:
        _defaultUri = StarWars.speciesUri;
        break;
      case 4:
        _defaultUri = StarWars.starshipsUri;
        break;
      case 5:
        _defaultUri = StarWars.vehiclesUri;
        break;
      default:
        _defaultUri = StarWars.peopleUri;
    }
  }

  static const peopleUri = 'https://swapi.co/api/people';
  static const vehiclesUri = 'https://swapi.co/api/vehicles';
  static const starshipsUri = 'https://swapi.co/api/starships';
  static const planetsUri = 'https://swapi.co/api/planets';
  static const filmsUri = 'https://swapi.co/api/films';
  static const speciesUri = 'https://swapi.co/api/species';

  String _defaultUri;

  @override
  String uri() => _defaultUri;

  @override
  dynamic findData(dynamic data) => data['results'];

  @override
  String display(dynamic data, int index) {
    final isFilm = _defaultUri == StarWars.filmsUri;
    return data == null ? '' : data[index][isFilm ? 'title' : 'name'];
  }
}

/// CitiBike NYCA single public API that shows location, status and current
/// availability for all stations in the New York City bike sharing imitative.
class CitiBikesNYC extends RestfulAPI {
  CitiBikesNYC() : super(currentRestfulAPI);

  static const citiBikesUri =
      'https://feeds.citibikenyc.com/stations/stations.json';

  @override
  String uri() => citiBikesUri;

  @override
  dynamic findData(dynamic data) => data['stationBeanList'];

  @override
  String display(dynamic data, int index) =>
      data == null ? '' : data[index]['stationName'];
}

class CityInformation {
  CityInformation(this.name);

  String name;
  int size = -1;
  String state = '???';
}

/// openewathermap APIs
///
///   Docs on Restful APIs https://openweathermap.org/current#data
///
///   City IDs are found in these files: http://bulk.openweathermap.org/sample/
///
///   Find a particular city use grep e.g.,
///       > grep -A 10 -B 10 -i "Kansas City" city.list.json
///
///   APPID is  ca0dbbe6d72c4d9e8c829abb4a534c16     DevTools_memoryLeaks
///
///   Subscribe for free OpenWeatherMap then create an appid using:
///       https://home.openweathermap.org/api_keys
class OpenWeatherMapAPI extends RestfulAPI {
  OpenWeatherMapAPI() : super(currentRestfulAPI);

  static const _baseUrl = 'http://api.openweathermap.org/data/2.5/group?id=';
  static const _unitsOption = '&units=imperial';
  static const _appidOption = '&appid=ca0dbbe6d72c4d9e8c829abb4a534c16';

  static const _cityIds = {
    'Seattle': 5809844,
    'Atlanta': 4180439,
    'Portland': 4720131,
    'Chicago': 4887398,
    'Orlando': 4167147,
    'San Francisco': 5391959,
    'San Jose': 5392171,
    'Phoenix': 5131135,
    'Denver': 4853799,
    'St. Louis': 6157004,
    'Houston': 4430529,
    'Dallas': 5722064,
    'Mobile': 4076598,
    'Richmond': 5780388,
    'Hartford': 5255628,
    'Detroit': 4990729,
    'Minneapolis': 4275586,
    'Cleveland': 5248933,
    'Harrisburg': 5228340,
    'Bangor': 5244626,
    'Nashville': 4245376,
    'Boston': 4183849,
    'Las Vegas': 5475433,
    'Kansas City': 4273837,
  };

  CityInformation firstCity;
  CityInformation secondCity;

  String _cityIdsList({int initialStart = -1, int count = 20}) {
    final StringBuffer buff = StringBuffer();

    final int start = initialStart == -1 ? randomSeed() : initialStart;
    firstCity = CityInformation(_cityIds.keys.toList()[start]);

    secondCity = firstCity;

    final ids = _cityIds.values.toList();
    for (var index = start; index < count; index++) {
      if (index != start) buff.write(',');
      buff.write('${ids[index]}');
    }

    return buff.toString();
  }

  // Index starting from 0..3
  static int randomSeed() => DateTime.now().second % 4;

  String get uri20Cities =>
      '$_baseUrl${_cityIdsList()}$_unitsOption$_appidOption';

  @override
  String uri() => uri20Cities;

  @override
  dynamic findData(dynamic data) => data['list']; // weather group

  static String cityName(dynamic data, int index) => '${data[index]['name']}';

  static String temperature(dynamic data, int index) =>
      '${data[index]['main']['temp']}';

  static String weather(dynamic data, int index) =>
      '${data[index]['weather'][0]['main']}';

  @override
  String display(dynamic data, int index) =>
      '${OpenWeatherMapAPI.cityName(data, index)} '
      '${OpenWeatherMapAPI.temperature(data, index)} '
      '${OpenWeatherMapAPI.weather(data, index)}';
}
