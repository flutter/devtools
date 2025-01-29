// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

/// The RESTful APIs used by the app.
library;

/// All servers with RestfulAPI implement this base.
abstract class RestfulAPI {
  RestfulAPI();

  String uri();

  String get activeFriendlyName;

  Object? findData(Object? data);

  String display(Object? data, int index);
}

/// StarWars information server.
class StarWars extends RestfulAPI {
  StarWars([String name = starWarsPeople]) {
    _defaultUri = _friendlyNames[name]!;
    _activeFriendlyName = name;
  }

  static const starWarsFilms = 'StarWars Films';
  static const starWarsPeople = 'StarWars People';
  static const starWarsPlanets = 'StarWars Planets';
  static const starWarsSpecies = 'StarWars Species';
  static const starWarsStarships = 'StarWars Starships';
  static const starWarsVehicles = 'StarWars Vehicles';

  static const _friendlyNames = {
    starWarsFilms: 'https://swapi.co/api/films',
    starWarsPeople: 'https://swapi.co/api/people',
    starWarsPlanets: 'https://swapi.co/api/planets',
    starWarsSpecies: 'https://swapi.co/api/species',
    starWarsStarships: 'https://swapi.co/api/starships',
    starWarsVehicles: 'https://swapi.co/api/vehicles',
  };

  late final String _activeFriendlyName;
  late final String _defaultUri;

  static List<String> get friendlyNames => _friendlyNames.keys.toList();

  @override
  String get activeFriendlyName => _activeFriendlyName;

  @override
  String uri() => _defaultUri;

  @override
  Object? findData(Object? data) => (data as Map)['results'];

  @override
  String display(Object? data, int index) {
    // data from film Restful URI has slightly different format
    // title instead of name.
    final isFilm = _defaultUri == _friendlyNames[starWarsFilms];
    return data == null
        ? ''
        : ((data as Map)[index] as Map)[isFilm ? 'title' : 'name'];
  }
}

/// CitiBike NYCA single public API that shows location, status and current
/// availability for all stations in the New York City bike sharing imitative.
class CitiBikesNYC extends RestfulAPI {
  static const citiBikesUri =
      'https://feeds.citibikenyc.com/stations/stations.json';

  static const friendlyName = 'NYC Bike Sharing';

  @override
  String uri() => citiBikesUri;

  @override
  String get activeFriendlyName => friendlyName;

  @override
  Object? findData(Object? data) => (data as Map)['stationBeanList'];

  @override
  String display(Object? data, int index) =>
      data == null ? '' : ((data as List)[index] as Map)['stationName'];
}

class CityInformation {
  CityInformation(this.name);

  String name;
  int size = -1;
  String state = '???';
}

/// OpenWeatherMap APIs
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
  static const friendlyName = 'Weather';

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

  CityInformation? firstCity;
  CityInformation? secondCity;

  String _cityIdsList({int initialStart = -1, int count = 20}) {
    final buff = StringBuffer();

    final start = initialStart == -1 ? randomSeed() : initialStart;
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
  String get activeFriendlyName => friendlyName;

  @override
  Object? findData(Object? data) => (data as Map)['list']; // weather group

  static String cityName(Object? data, int index) =>
      '${((data as List)[index] as Map)['name']}';

  static String temperature(Object? data, int index) =>
      '${(((data as List)[index] as Map)['main'] as Map)['temp']}';

  static String weather(Object? data, int index) =>
      '${((((data as Map)[index] as Map)['weather'] as List)[0] as Map)['main']}';

  @override
  String display(Object? data, int index) =>
      '${OpenWeatherMapAPI.cityName(data, index)} '
      '${OpenWeatherMapAPI.temperature(data, index)} '
      '${OpenWeatherMapAPI.weather(data, index)}';
}
