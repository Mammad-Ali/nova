import '../../../../core/l10n/app_strings.dart';
import 'speedtest_servers.dart';

/// Speed test servers in Azerbaijan, run by the country's internet providers
/// for the Speedtest network — from Baku to Nakhchivan. Testing against one
/// measures the connection inside the country; against your own provider's,
/// inside its network.
///
/// From the Speedtest network's public server list (November 2026). Some
/// answer only their own provider's customers; the server picker times
/// them all and lists those that answer.
const kAzerbaijanServers = <SpeedTestServer>[
  SpeedTestServer.provider(id: 45546, sponsor: 'Aztelekom', city: 'Baku', host: 'speedtest.aztelekom.az:8080'),
  SpeedTestServer.provider(id: 68729, sponsor: 'ICTA', city: 'Baku', host: 'speedtest2.icta.az.prod.hosts.ooklaserver.net:8080'),
  SpeedTestServer.provider(id: 2268, sponsor: 'Nar', city: 'Baku', host: 'speedtest.azerfon.az:8080'),
  SpeedTestServer.provider(id: 15518, sponsor: 'AZnet Technologies', city: 'Baku', host: 'speedtest.az-net.az:8080'),
  SpeedTestServer.provider(id: 17428, sponsor: 'IZONE', city: 'Baku', host: 'speedtest.izone.az:8080'),
  SpeedTestServer.provider(id: 26391, sponsor: 'CityNet', city: 'Baku', host: 'speedtest.uninet.az:8080'),
  SpeedTestServer.provider(id: 43502, sponsor: 'SELNET', city: 'Baku', host: 'speedtest.selnet.az.prod.hosts.ooklaserver.net:8080'),
  SpeedTestServer.provider(id: 43969, sponsor: 'ULTEL', city: 'Baku', host: 'speedtest.ultel.net:8080'),
  SpeedTestServer.provider(id: 61038, sponsor: 'Azercell Telecom', city: 'Baku', host: 'speedtest02.azercell.com.prod.hosts.ooklaserver.net:8080'),
  SpeedTestServer.provider(id: 65372, sponsor: 'Metronet', city: 'Baku', host: 'speedtest.metronet.az.prod.hosts.ooklaserver.net:8080'),
  SpeedTestServer.provider(id: 70929, sponsor: 'Delta Telecom', city: 'Baku', host: 'spd2.datacenter.az.prod.hosts.ooklaserver.net:8080'),
  SpeedTestServer.provider(id: 70970, sponsor: 'Maxinet', city: 'Baku', host: 'speedtest.maxinet.az.prod.hosts.ooklaserver.net:8080'),
  SpeedTestServer.provider(id: 71862, sponsor: 'Seabak', city: 'Baku', host: 'speedtest2.cloud.az.prod.hosts.ooklaserver.net:8080'),
  SpeedTestServer.provider(id: 10897, sponsor: 'AzFiberNet', city: 'Baku', host: 'speedtestbaku1.azfiber.net.prod.hosts.ooklaserver.net:8080'),
  SpeedTestServer.provider(id: 41519, sponsor: 'Fibernet', city: 'Baku', host: 'speedtest.fiber.net.az.prod.hosts.ooklaserver.net:8080'),
  SpeedTestServer.provider(id: 68216, sponsor: 'Azeronline', city: 'Baku', host: 'speedtest.azeronline.com.prod.hosts.ooklaserver.net:8080'),
  SpeedTestServer.provider(id: 26918, sponsor: 'Connect', city: 'Baku', host: 'speedtest.connect.az:8080'),
  SpeedTestServer.provider(id: 71725, sponsor: 'NetPoint', city: 'Baku', host: 'speedtest.netpoint.az.prod.hosts.ooklaserver.net:8080'),
  SpeedTestServer.provider(id: 50470, sponsor: 'Flexnet', city: 'Baku', host: 'speedtest.flexnet.az.prod.hosts.ooklaserver.net:8080'),
  SpeedTestServer.provider(id: 49035, sponsor: 'ARTKOM', city: 'Baku', host: 'speedtest.artkom.az:8080'),
  SpeedTestServer.provider(id: 64252, sponsor: 'Voltnet', city: 'Baku', host: 'speedtest.voltnet.az.prod.hosts.ooklaserver.net:8080'),
  SpeedTestServer.provider(id: 15687, sponsor: 'SHAKH Telecom', city: 'Baku', host: 'speedtest.shakh.tv.prod.hosts.ooklaserver.net:8080'),
  SpeedTestServer.provider(id: 39069, sponsor: 'PASHA Technology', city: 'Baku', host: 'speedtest.pasha-technology.com.prod.hosts.ooklaserver.net:8080'),
  SpeedTestServer.provider(id: 15459, sponsor: 'AZEURONET', city: 'Baku', host: 'speedtest.azeuronet.az:8080'),
  SpeedTestServer.provider(id: 2221, sponsor: 'Bakcell', city: 'Baku', host: 'speedtest.bakcell.com:8080'),
  SpeedTestServer.provider(id: 72947, sponsor: 'BuludTelecom', city: 'Baku', host: 'speedtest.buludtelecom.com.prod.hosts.ooklaserver.net:8080'),
  SpeedTestServer.provider(id: 47848, sponsor: 'DigiNet', city: 'Baku', host: 'speedtest.diginet.az.prod.hosts.ooklaserver.net:8080'),
  SpeedTestServer.provider(id: 73921, sponsor: 'EuroNet', city: 'Baku', host: 'speedtest.euronet-telecom.az.prod.hosts.ooklaserver.net:8080'),
  SpeedTestServer.provider(id: 12417, sponsor: 'Teleport', city: 'Baku', host: 'speedtest.teleport.az.prod.hosts.ooklaserver.net:8080'),
  SpeedTestServer.provider(id: 15402, sponsor: 'Boss Group', city: 'Baku', host: 'speedtest.bossnet.az.prod.hosts.ooklaserver.net:8080'),
  SpeedTestServer.provider(id: 70615, sponsor: 'ADANET', city: 'Baku', host: 'speedtest.adanet.tv:8080'),
  SpeedTestServer.provider(id: 13292, sponsor: 'KATV 1', city: 'Baku', host: 'sp1.katv1.net:8080'),
  SpeedTestServer.provider(id: 70745, sponsor: 'GSP', city: 'Baku', host: 'speedtest.gsp.az.prod.hosts.ooklaserver.net:8080'),
  SpeedTestServer.provider(id: 75184, sponsor: 'AzTechNet', city: 'Baku', host: 'ookla.static01.aztechnet.az:8080'),
  SpeedTestServer.provider(id: 26286, sponsor: 'AzEuroTel', city: 'Baku', host: 'speedtest.aet.az:8080'),
  SpeedTestServer.provider(id: 41874, sponsor: 'Aztelekom', city: 'Xirdalan', host: 'speedtest3.aztelekom.az:8080'),
  SpeedTestServer.provider(id: 72023, sponsor: 'Azeronline', city: 'Sumgayit', host: 'speedtest2.azeronline.com.prod.hosts.ooklaserver.net:8080'),
  SpeedTestServer.provider(id: 3923, sponsor: 'Aztelekom', city: 'Shirvan', host: 'speedtest5.aztelekom.az:8080'),
  SpeedTestServer.provider(id: 72128, sponsor: 'Azeronline', city: 'Shirvan', host: 'speedtest4.azeronline.com.prod.hosts.ooklaserver.net:8080'),
  SpeedTestServer.provider(id: 3014, sponsor: 'Aztelekom', city: 'Shamakhi', host: 'speedtest7.aztelekom.az:8080'),
  SpeedTestServer.provider(id: 74248, sponsor: 'Azeronline', city: 'Salyan', host: 'speedtest7.azeronline.com.prod.hosts.ooklaserver.net:8080'),
  SpeedTestServer.provider(id: 74267, sponsor: 'Azeronline', city: 'Kurdamir', host: 'speedtest10.azeronline.com.prod.hosts.ooklaserver.net:8080'),
  SpeedTestServer.provider(id: 15343, sponsor: 'Aztelekom', city: 'Guba', host: 'speedtest4.aztelekom.az:8080'),
  SpeedTestServer.provider(id: 512, sponsor: 'Aztelekom', city: 'Masally', host: 'speedtest6.aztelekom.az:8080'),
  SpeedTestServer.provider(id: 74236, sponsor: 'Azeronline', city: 'Lankaran', host: 'speedtest6.azeronline.com.prod.hosts.ooklaserver.net:8080'),
  SpeedTestServer.provider(id: 74262, sponsor: 'Azeronline', city: 'Aghjabadi', host: 'speedtest8.azeronline.com.prod.hosts.ooklaserver.net:8080'),
  SpeedTestServer.provider(id: 71807, sponsor: 'Aztelekom', city: 'Yevlakh', host: 'speedtest2.aztelekom.az:8080'),
  SpeedTestServer.provider(id: 72078, sponsor: 'Azeronline', city: 'Yevlakh', host: 'speedtest3.azeronline.com.prod.hosts.ooklaserver.net:8080'),
  SpeedTestServer.provider(id: 74249, sponsor: 'Azeronline', city: 'Shaki', host: 'speedtest9.azeronline.com.prod.hosts.ooklaserver.net:8080'),
  SpeedTestServer.provider(id: 71529, sponsor: 'Fibernet', city: 'Shaki', host: 'speedtest55.fiber.net.az.prod.hosts.ooklaserver.net:8080'),
  SpeedTestServer.provider(id: 12248, sponsor: 'Aztelekom', city: 'Khankendi', host: 'speedtest8.aztelekom.az:8080'),
  SpeedTestServer.provider(id: 25576, sponsor: 'Aztelekom', city: 'Ganja', host: 'speedtest10.aztelekom.az:8080'),
  SpeedTestServer.provider(id: 25575, sponsor: 'Aztelekom', city: 'Zaqatala', host: 'speedtest9.aztelekom.az:8080'),
  SpeedTestServer.provider(id: 41182, sponsor: 'Fibernet', city: 'Zaqatala', host: 'speedtest62.fiber.net.az.prod.hosts.ooklaserver.net:8080'),
  SpeedTestServer.provider(id: 72922, sponsor: 'Azeronline', city: 'Shamkir', host: 'speedtest5.azeronline.com.prod.hosts.ooklaserver.net:8080'),
  SpeedTestServer.provider(id: 56585, sponsor: 'ArazNET', city: 'Nakhchivan', host: 'speedtest.araz-net.az:8080'),
];

/// Every server that can be picked, by its Speedtest id.
SpeedTestServer? providerServerById(int? id) =>
    id == null ? null : kAzerbaijanServers.where((s) => s.id == id).firstOrNull;

/// The cities' names in Azerbaijani and Russian; English, German and
/// Hungarian use the English names the list comes with.
const _cityNames = <String, (String az, String ru)>{
  'Aghjabadi': ('Ağcabədi', 'Агджабеди'),
  'Baku': ('Bakı', 'Баку'),
  'Ganja': ('Gəncə', 'Гянджа'),
  'Guba': ('Quba', 'Губа'),
  'Khankendi': ('Xankəndi', 'Ханкенди'),
  'Kurdamir': ('Kürdəmir', 'Кюрдамир'),
  'Lankaran': ('Lənkəran', 'Ленкорань'),
  'Masally': ('Masallı', 'Масаллы'),
  'Nakhchivan': ('Naxçıvan', 'Нахчыван'),
  'Salyan': ('Salyan', 'Сальяны'),
  'Shaki': ('Şəki', 'Шеки'),
  'Shamakhi': ('Şamaxı', 'Шамахы'),
  'Shamkir': ('Şəmkir', 'Шамкир'),
  'Shirvan': ('Şirvan', 'Ширван'),
  'Sumgayit': ('Sumqayıt', 'Сумгаит'),
  'Xirdalan': ('Xırdalan', 'Хырдалан'),
  'Yevlakh': ('Yevlax', 'Евлах'),
  'Zaqatala': ('Zaqatala', 'Закатала'),
};

String cityName(String city, AppLocale locale) => switch (locale) {
      AppLocale.az => _cityNames[city]?.$1 ?? city,
      AppLocale.ru => _cityNames[city]?.$2 ?? city,
      _ => city,
    };
