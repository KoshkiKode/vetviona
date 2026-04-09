import '../models/place.dart';

/// Historical territories and empires.
/// Use validTo ISO-8601 date to filter by event date.
/// modernCountry = the historical state/empire name for search purposes.
const List<Place> placesHistorical = [

  // ══════════════════════════════════════════════════════════════════════════
  // OTTOMAN EMPIRE  (c. 1299 – 1922)
  // ══════════════════════════════════════════════════════════════════════════
  Place(continent:'Asia', name:'Constantinople', modernCountry:'Ottoman Empire', iso3:'OTT',
    state:'Rumelia Province', historicalContext:'Ottoman capital from 1453–1923; previously Byzantine capital.',
    nativeTribes:'Turks, Greeks, Armenians, Jews', romanizedNative:'Kostantiniyye / Κωνσταντινούπολη',
    validTo:'1923-10-29T00:00:00.000Z'),
  Place(continent:'Asia', name:'Bursa', modernCountry:'Ottoman Empire', iso3:'OTT',
    state:'Anatolia Province', historicalContext:'First Ottoman capital (1326–1365); Green Tomb of Orhan Gazi.',
    nativeTribes:'Turks, Greeks', validTo:'1922-11-01T00:00:00.000Z'),
  Place(continent:'Asia', name:'Edirne', modernCountry:'Ottoman Empire', iso3:'OTT',
    state:'Thrace Province', historicalContext:'Second Ottoman capital (1369–1453); Selimiye Mosque UNESCO site.',
    nativeTribes:'Turks, Greeks, Bulgarians', romanizedNative:'Adrianople', validTo:'1922-11-01T00:00:00.000Z'),
  Place(continent:'Asia', name:'Salonica', modernCountry:'Ottoman Empire', iso3:'OTT',
    state:'Rumelia Province', historicalContext:'Cosmopolitan Ottoman port; large Sephardic Jewish population post-1492.',
    nativeTribes:'Greeks, Jews, Turks', romanizedNative:'Selanik / Thessaloniki', validTo:'1912-11-08T00:00:00.000Z'),
  Place(continent:'Asia', name:'Baghdad', modernCountry:'Ottoman Empire', iso3:'OTT',
    state:'Baghdad Province', historicalContext:'Ottoman Baghdad; seat of Baghdad Vilayet from 1535.',
    nativeTribes:'Arabs, Kurds, Assyrians', validTo:'1920-08-10T00:00:00.000Z'),
  Place(continent:'Asia', name:'Damascus', modernCountry:'Ottoman Empire', iso3:'OTT',
    state:'Syria Province', historicalContext:'Umayyad Caliphate capital; Ottoman province seat.',
    nativeTribes:'Arabs, Druze, Kurds', romanizedNative:'Şam', validTo:'1920-07-24T00:00:00.000Z'),
  Place(continent:'Asia', name:'Beirut', modernCountry:'Ottoman Empire', iso3:'OTT',
    state:'Mount Lebanon Mutasarrifate', historicalContext:'Rising commercial Ottoman port in 19th century.',
    nativeTribes:'Arabs, Druze, Maronites', validTo:'1920-09-01T00:00:00.000Z'),
  Place(continent:'Africa', name:'Tripoli', modernCountry:'Ottoman Empire', iso3:'OTT',
    state:'Tripolitania Province', historicalContext:'Ottoman Tripolitania until Italian conquest 1911.',
    nativeTribes:'Berbers, Arabs', validTo:'1911-10-18T00:00:00.000Z'),

  // ══════════════════════════════════════════════════════════════════════════
  // BYZANTINE EMPIRE  (395 – 1453)
  // ══════════════════════════════════════════════════════════════════════════
  Place(continent:'Europe', name:'Constantinople', modernCountry:'Byzantine Empire', iso3:'BYZ',
    state:'Thrace', historicalContext:'Eastern Roman / Byzantine capital from 330 AD to fall to Ottomans 1453.',
    nativeTribes:'Greeks, Armenians', romanizedNative:'Κωνσταντινούπολη',
    validTo:'1453-05-29T00:00:00.000Z'),
  Place(continent:'Europe', name:'Thessalonica', modernCountry:'Byzantine Empire', iso3:'BYZ',
    state:'Macedonia', historicalContext:'Second city of Byzantium; birthplace of Sts Cyril and Methodius.',
    nativeTribes:'Greeks, Slavs', romanizedNative:'Θεσσαλονίκη', validTo:'1430-03-29T00:00:00.000Z'),
  Place(continent:'Asia', name:'Antioch', modernCountry:'Byzantine Empire', iso3:'BYZ',
    state:'Syria Prima', historicalContext:'Major Byzantine patriarchate; Crusader Principality 1098.',
    nativeTribes:'Greeks, Syrians', romanizedNative:'Ἀντιόχεια', validTo:'1268-05-18T00:00:00.000Z'),
  Place(continent:'Europe', name:'Nicaea', modernCountry:'Byzantine Empire', iso3:'BYZ',
    state:'Bithynia', historicalContext:'Council of Nicaea 325; Empire of Nicaea capital 1204–1261.',
    nativeTribes:'Greeks', romanizedNative:'Νίκαια', validTo:'1453-05-29T00:00:00.000Z'),

  // ══════════════════════════════════════════════════════════════════════════
  // ROMAN EMPIRE  (27 BC – 476 AD west; – 1453 east)
  // ══════════════════════════════════════════════════════════════════════════
  Place(continent:'Europe', name:'Rome', modernCountry:'Roman Empire', iso3:'ROM',
    state:'Latium', historicalContext:'Capital of the Republic then Empire; Seven Hills; Forum Romanum.',
    nativeTribes:'Latins, Sabines', romanizedNative:'Roma', validTo:'0476-09-04T00:00:00.000Z'),
  Place(continent:'Europe', name:'Carthage', modernCountry:'Roman Empire', iso3:'ROM',
    state:'Africa Proconsularis', historicalContext:'Rebuilt as Roman colony; Pliny the Elder stationed here.',
    nativeTribes:'Berbers', romanizedNative:'Carthago', validTo:'0698-01-01T00:00:00.000Z'),
  Place(continent:'Europe', name:'Alexandria', modernCountry:'Roman Empire', iso3:'ROM',
    state:'Egypt', historicalContext:'Roman Egypt provincial capital; Museum and Library.',
    nativeTribes:'Greeks, Egyptians, Jews', romanizedNative:'Alexandria', validTo:'0641-09-17T00:00:00.000Z'),
  Place(continent:'Europe', name:'London', modernCountry:'Roman Empire', iso3:'ROM',
    state:'Britannia', historicalContext:'Roman Londinium c. 47 AD; walled city on Thames.',
    nativeTribes:'Trinovantes, Catuvellauni', romanizedNative:'Londinium', validTo:'0410-01-01T00:00:00.000Z'),
  Place(continent:'Europe', name:'York', modernCountry:'Roman Empire', iso3:'ROM',
    state:'Britannia Secunda', historicalContext:'Roman Eboracum; Constantine the Great proclaimed emperor here 306.',
    nativeTribes:'Brigantes', romanizedNative:'Eboracum', validTo:'0410-01-01T00:00:00.000Z'),
  Place(continent:'Europe', name:'Cologne', modernCountry:'Roman Empire', iso3:'ROM',
    state:'Germania Inferior', historicalContext:'Roman Colonia Agrippina; birthplace of Empress Agrippina the Younger.',
    nativeTribes:'Ubii', romanizedNative:'Colonia Claudia Ara Agrippinensium', validTo:'0476-09-04T00:00:00.000Z'),
  Place(continent:'Asia', name:'Jerusalem', modernCountry:'Roman Empire', iso3:'ROM',
    state:'Judaea / Syria Palaestina', historicalContext:'Herod\'s Temple; destruction 70 AD; Aelia Capitolina.',
    nativeTribes:'Jews, Samaritans', romanizedNative:'Aelia Capitolina', validTo:'0636-11-01T00:00:00.000Z'),

  // ══════════════════════════════════════════════════════════════════════════
  // SOVIET UNION  (1922 – 1991)
  // ══════════════════════════════════════════════════════════════════════════
  Place(continent:'Europe', name:'Moscow', modernCountry:'Soviet Union', iso3:'SUN',
    state:'Moscow Oblast', historicalContext:'Soviet capital; Red Square, Kremlin; Cold War HQ.',
    nativeTribes:'Russians', romanizedNative:'Москва', validTo:'1991-12-25T00:00:00.000Z'),
  Place(continent:'Europe', name:'Leningrad', modernCountry:'Soviet Union', iso3:'SUN',
    state:'Leningrad Oblast', historicalContext:'Formerly and later Saint Petersburg; renamed for Lenin; WWII 872-day siege.',
    nativeTribes:'Russians', romanizedNative:'Ленинград', validTo:'1991-09-06T00:00:00.000Z'),
  Place(continent:'Asia', name:'Tashkent', modernCountry:'Soviet Union', iso3:'SUN',
    state:'Uzbek SSR', historicalContext:'Soviet Uzbekistan capital; 1966 earthquake.',
    nativeTribes:'Uzbek', romanizedNative:'Ташкент', validTo:'1991-12-25T00:00:00.000Z'),
  Place(continent:'Asia', name:'Alma-Ata', modernCountry:'Soviet Union', iso3:'SUN',
    state:'Kazakh SSR', historicalContext:'Soviet Kazakhstan capital; largest city in the SSR.',
    nativeTribes:'Kazakh, Russian', romanizedNative:'Алма-Ата', validTo:'1991-12-25T00:00:00.000Z'),
  Place(continent:'Europe', name:'Kiev', modernCountry:'Soviet Union', iso3:'SUN',
    state:'Ukrainian SSR', historicalContext:'Capital of Soviet Ukraine; motherland of Rus\' civilisation.',
    nativeTribes:'Ukrainians', romanizedNative:'Київ / Киев', validTo:'1991-12-25T00:00:00.000Z'),
  Place(continent:'Europe', name:'Minsk', modernCountry:'Soviet Union', iso3:'SUN',
    state:'Byelorussian SSR', historicalContext:'Soviet Belarussian capital; nearly destroyed in WWII.',
    nativeTribes:'Belarusians', romanizedNative:'Мінск', validTo:'1991-12-25T00:00:00.000Z'),
  Place(continent:'Asia', name:'Baku', modernCountry:'Soviet Union', iso3:'SUN',
    state:'Azerbaijani SSR', historicalContext:'Soviet Azerbaijani capital; Caspian oil.',
    nativeTribes:'Azerbaijanis', romanizedNative:'Баку', validTo:'1991-12-25T00:00:00.000Z'),
  Place(continent:'Asia', name:'Yerevan', modernCountry:'Soviet Union', iso3:'SUN',
    state:'Armenian SSR', historicalContext:'Soviet Armenian capital; survived genocide under prior Ottoman rule.',
    nativeTribes:'Armenians', romanizedNative:'Երևան', validTo:'1991-12-25T00:00:00.000Z'),
  Place(continent:'Asia', name:'Tbilisi', modernCountry:'Soviet Union', iso3:'SUN',
    state:'Georgian SSR', historicalContext:'Soviet Georgian capital; ancient Caucasus city.',
    nativeTribes:'Georgians', romanizedNative:'Тбилиси', validTo:'1991-12-25T00:00:00.000Z'),
  Place(continent:'Europe', name:'Tallinn', modernCountry:'Soviet Union', iso3:'SUN',
    state:'Estonian SSR', historicalContext:'Soviet Estonia capital; Hanseatic heritage city.',
    nativeTribes:'Estonians', romanizedNative:'Таллинн / Reval', validTo:'1991-09-06T00:00:00.000Z'),
  Place(continent:'Europe', name:'Riga', modernCountry:'Soviet Union', iso3:'SUN',
    state:'Latvian SSR', historicalContext:'Soviet Latvia capital; major Baltic Sea port.',
    nativeTribes:'Latvians', romanizedNative:'Рига', validTo:'1991-09-06T00:00:00.000Z'),
  Place(continent:'Europe', name:'Vilnius', modernCountry:'Soviet Union', iso3:'SUN',
    state:'Lithuanian SSR', historicalContext:'Soviet Lithuania capital; Grand Duchy of Lithuania historical seat.',
    nativeTribes:'Lithuanians', romanizedNative:'Вильнюс', validTo:'1991-09-06T00:00:00.000Z'),

  // ══════════════════════════════════════════════════════════════════════════
  // AUSTRIA-HUNGARY  (1867 – 1918)
  // ══════════════════════════════════════════════════════════════════════════
  Place(continent:'Europe', name:'Vienna', modernCountry:'Austria-Hungary', iso3:'AUH',
    state:'Lower Austria', historicalContext:'Habsburg Imperial capital; "City of Music"; Congress of Vienna 1815.',
    nativeTribes:'Germans, Czechs, Hungarians', romanizedNative:'Wien', validTo:'1918-11-12T00:00:00.000Z'),
  Place(continent:'Europe', name:'Budapest', modernCountry:'Austria-Hungary', iso3:'AUH',
    state:'Kingdom of Hungary', historicalContext:'Dual capital; Buda + Pest unified 1873; chain bridge landmark.',
    nativeTribes:'Hungarians (Magyars)', romanizedNative:'Budapest', validTo:'1918-11-16T00:00:00.000Z'),
  Place(continent:'Europe', name:'Prague', modernCountry:'Austria-Hungary', iso3:'AUH',
    state:'Kingdom of Bohemia', historicalContext:'Bohemian crown jewel; Kafka\'s city; Spring 1968.',
    nativeTribes:'Czechs, Germans, Jews', romanizedNative:'Praha / Prag', validTo:'1918-10-28T00:00:00.000Z'),
  Place(continent:'Europe', name:'Sarajevo', modernCountry:'Austria-Hungary', iso3:'AUH',
    state:'Bosnia-Herzegovina', historicalContext:'Assassination of Archduke Franz Ferdinand 1914; sparked WWI.',
    nativeTribes:'Bosnians, Serbs, Croats', romanizedNative:'Sarajevo', validTo:'1918-10-29T00:00:00.000Z'),
  Place(continent:'Europe', name:'Trieste', modernCountry:'Austria-Hungary', iso3:'AUH',
    state:'Austrian Littoral', historicalContext:'Main Habsburg port on Adriatic; cosmopolitan commercial city.',
    nativeTribes:'Italians, Slovenes, Greeks', romanizedNative:'Trieste / Trst', validTo:'1918-11-03T00:00:00.000Z'),
  Place(continent:'Europe', name:'Lwów', modernCountry:'Austria-Hungary', iso3:'AUH',
    state:'Kingdom of Galicia and Lodomeria', historicalContext:'Now Lviv, Ukraine; historic Polish-Ukrainian-Jewish city.',
    nativeTribes:'Poles, Ukrainians, Jews', romanizedNative:'Lemberg / Lviv / Львів', validTo:'1918-11-01T00:00:00.000Z'),

  // ══════════════════════════════════════════════════════════════════════════
  // YUGOSLAV FEDERATION  (1943 – 1992)
  // ══════════════════════════════════════════════════════════════════════════
  Place(continent:'Europe', name:'Belgrade', modernCountry:'Yugoslavia', iso3:'YUG',
    state:'SR Serbia', historicalContext:'Federal capital; Tito\'s non-aligned Yugoslavia; NATO bombing 1999.',
    nativeTribes:'Serbs, Croats, Slovenes', romanizedNative:'Beograd', validTo:'1992-04-28T00:00:00.000Z'),
  Place(continent:'Europe', name:'Zagreb', modernCountry:'Yugoslavia', iso3:'YUG',
    state:'SR Croatia', historicalContext:'Croatian capital; Austro-Hungarian then Yugoslav then independent 1991.',
    nativeTribes:'Croats', romanizedNative:'Zagreb', validTo:'1991-06-25T00:00:00.000Z'),
  Place(continent:'Europe', name:'Ljubljana', modernCountry:'Yugoslavia', iso3:'YUG',
    state:'SR Slovenia', historicalContext:'Slovenian capital; Austrian then Yugoslav then independent 1991.',
    nativeTribes:'Slovenes', romanizedNative:'Ljubljana / Laibach', validTo:'1991-06-25T00:00:00.000Z'),
  Place(continent:'Europe', name:'Sarajevo', modernCountry:'Yugoslavia', iso3:'YUG',
    state:'SR Bosnia-Herzegovina', historicalContext:'1984 Winter Olympics; besieged 1992–1995 in Bosnian War.',
    nativeTribes:'Bosnians, Serbs, Croats', romanizedNative:'Sarajevo', validTo:'1992-04-06T00:00:00.000Z'),

  // ══════════════════════════════════════════════════════════════════════════
  // BRITISH INDIAN EMPIRE / BRITISH RAJ  (1858 – 1947)
  // ══════════════════════════════════════════════════════════════════════════
  Place(continent:'Asia', name:'Calcutta', modernCountry:'British India', iso3:'BRI',
    state:'Bengal Presidency', historicalContext:'British Indian capital until 1911; East India Company headquarters.',
    nativeTribes:'Bengali', romanizedNative:'Kolkata', validTo:'1947-08-15T00:00:00.000Z'),
  Place(continent:'Asia', name:'Delhi', modernCountry:'British India', iso3:'BRI',
    state:'Delhi Territory', historicalContext:'New Delhi built as Indian capital from 1912; Mughal seat.',
    nativeTribes:'Punjabi, Hindi-speaking', romanizedNative:'Delhi', validTo:'1947-08-15T00:00:00.000Z'),
  Place(continent:'Asia', name:'Bombay', modernCountry:'British India', iso3:'BRI',
    state:'Bombay Presidency', historicalContext:'Principal western port; Portuguese gift to British Crown 1661.',
    nativeTribes:'Koli', romanizedNative:'Mumbai', validTo:'1947-08-15T00:00:00.000Z'),
  Place(continent:'Asia', name:'Madras', modernCountry:'British India', iso3:'BRI',
    state:'Madras Presidency', historicalContext:'First British fort in India (Fort St George 1644).',
    nativeTribes:'Tamil', romanizedNative:'Chennai', validTo:'1947-08-15T00:00:00.000Z'),
  Place(continent:'Asia', name:'Rangoon', modernCountry:'British India', iso3:'BRI',
    state:'Burma Province', historicalContext:'Capital of British Burma; annexed 1853.',
    nativeTribes:'Bamar', romanizedNative:'Yangon', validTo:'1948-01-04T00:00:00.000Z'),

  // ══════════════════════════════════════════════════════════════════════════
  // QING DYNASTY CHINA  (1644 – 1912)
  // ══════════════════════════════════════════════════════════════════════════
  Place(continent:'Asia', name:'Peking', modernCountry:'Qing Dynasty', iso3:'QNG',
    state:'Zhili Province', historicalContext:'Qing capital; Forbidden City; Summer Palace; Boxer Rebellion.',
    nativeTribes:'Han, Manchu', romanizedNative:'北京 (Běijīng)', validTo:'1912-02-12T00:00:00.000Z'),
  Place(continent:'Asia', name:'Nanking', modernCountry:'Qing Dynasty', iso3:'QNG',
    state:'Jiangnan Province', historicalContext:'Treaty of Nanking 1842 ended First Opium War; ceded Hong Kong.',
    nativeTribes:'Han', romanizedNative:'南京', validTo:'1912-02-12T00:00:00.000Z'),
  Place(continent:'Asia', name:'Canton', modernCountry:'Qing Dynasty', iso3:'QNG',
    state:'Guangdong Province', historicalContext:'Only port open to foreign trade pre-Opium Wars; Cohong system.',
    nativeTribes:'Cantonese', romanizedNative:'广州', validTo:'1912-02-12T00:00:00.000Z'),

  // ══════════════════════════════════════════════════════════════════════════
  // CZECHOSLOVAKIA  (1918 – 1993)
  // ══════════════════════════════════════════════════════════════════════════
  Place(continent:'Europe', name:'Prague', modernCountry:'Czechoslovakia', iso3:'CSK',
    state:'Bohemia', historicalContext:'Czechoslovak capital; Munich Agreement 1938; Prague Spring 1968; Velvet Revolution 1989.',
    nativeTribes:'Czechs, Slovaks, Germans', romanizedNative:'Praha', validTo:'1993-01-01T00:00:00.000Z'),
  Place(continent:'Europe', name:'Bratislava', modernCountry:'Czechoslovakia', iso3:'CSK',
    state:'Slovakia', historicalContext:'Slovak administrative capital within Czechoslovakia; medieval Pressburg.',
    nativeTribes:'Slovaks, Hungarians', romanizedNative:'Bratislava / Pozsony / Pressburg', validTo:'1993-01-01T00:00:00.000Z'),

  // ══════════════════════════════════════════════════════════════════════════
  // PRUSSIA / GERMAN EMPIRE  (1701 – 1918)
  // ══════════════════════════════════════════════════════════════════════════
  Place(continent:'Europe', name:'Berlin', modernCountry:'German Empire', iso3:'GER',
    state:'Kingdom of Prussia', historicalContext:'Prussian capital then German Imperial capital; Hohenzollern dynasty.',
    nativeTribes:'Germans', romanizedNative:'Berlin', validTo:'1918-11-09T00:00:00.000Z'),
  Place(continent:'Europe', name:'Königsberg', modernCountry:'German Empire', iso3:'GER',
    state:'Province of East Prussia', historicalContext:'Prussian coronation city; Immanuel Kant\'s birthplace; now Kaliningrad (Russia).',
    nativeTribes:'Germans, Poles, Lithuanians', romanizedNative:'Königsberg', validTo:'1945-04-09T00:00:00.000Z'),

  // ══════════════════════════════════════════════════════════════════════════
  // COLONIAL TERRITORIES (misc.)
  // ══════════════════════════════════════════════════════════════════════════
  Place(continent:'Americas', name:'New Amsterdam', modernCountry:'Dutch Colony', iso3:'NLD',
    state:'New Netherland', historicalContext:'Dutch West India Company trading post 1626; became British New York 1664.',
    nativeTribes:'Lenape', romanizedNative:'New Amsterdam', validTo:'1664-09-08T00:00:00.000Z'),
  Place(continent:'Asia', name:'Batavia', modernCountry:'Dutch East Indies', iso3:'DEI',
    state:'Java', historicalContext:'VOC headquarters in Asia 1619–1942; conquered by Japan; became Jakarta.',
    nativeTribes:'Betawi', romanizedNative:'Batavia', validTo:'1942-03-05T00:00:00.000Z'),
  Place(continent:'Asia', name:'Goa', modernCountry:'Portuguese India', iso3:'PGI',
    state:'Goa Province', historicalContext:'Portuguese East India capital 1510–1961; "Golden Goa" spice trade hub.',
    nativeTribes:'Konkani', romanizedNative:'Goa', validTo:'1961-12-19T00:00:00.000Z'),
  Place(continent:'Africa', name:'Cape Colony', modernCountry:'British Cape Colony', iso3:'CPC',
    state:'Cape of Good Hope', historicalContext:'Dutch VOC station 1652; British from 1806; Cape Town capital.',
    nativeTribes:'Khoikhoi, Xhosa', romanizedNative:'Kaapkolonie', validTo:'1910-05-31T00:00:00.000Z'),

  // ══════════════════════════════════════════════════════════════════════════
  // ANCIENT CIVILISATIONS
  // ══════════════════════════════════════════════════════════════════════════
  Place(continent:'Asia', name:'Nineveh', modernCountry:'Assyrian Empire', iso3:'ASY',
    state:'Assyria', historicalContext:'Neo-Assyrian Empire capital; Library of Ashurbanipal; fell 612 BC.',
    nativeTribes:'Assyrians', romanizedNative:'𒉌𒉡𒀀', validTo:'-0612-01-01T00:00:00.000Z'),
  Place(continent:'Asia', name:'Ur', modernCountry:'Sumerian City-State', iso3:'SUM',
    state:'Sumer', historicalContext:'One of earliest cities; ziggurat of Ur-Nammu; Abraham\'s traditional birthplace.',
    nativeTribes:'Sumerians', romanizedNative:'Urim', validTo:'-0500-01-01T00:00:00.000Z'),
  Place(continent:'Africa', name:'Memphis', modernCountry:'Ancient Egypt', iso3:'EGY_ANC',
    state:'Lower Egypt', historicalContext:'First capital of unified Egypt c. 3100 BC; near Great Pyramids.',
    nativeTribes:'Ancient Egyptians', romanizedNative:'Men-nefer', validTo:'-0641-01-01T00:00:00.000Z'),
  Place(continent:'Africa', name:'Thebes', modernCountry:'Ancient Egypt', iso3:'EGY_ANC',
    state:'Upper Egypt', historicalContext:'New Kingdom capital; Karnak and Luxor temples; Valley of the Kings.',
    nativeTribes:'Ancient Egyptians', romanizedNative:'Waset', validTo:'-0332-01-01T00:00:00.000Z'),
  Place(continent:'Europe', name:'Athens', modernCountry:'Ancient Greece', iso3:'GRC_ANC',
    state:'Attica', historicalContext:'Birthplace of democracy; Acropolis; Platonic philosophy.',
    nativeTribes:'Athenians', romanizedNative:'Ἀθῆναι', validTo:'-0146-01-01T00:00:00.000Z'),
  Place(continent:'Europe', name:'Sparta', modernCountry:'Ancient Greece', iso3:'GRC_ANC',
    state:'Laconia', historicalContext:'Militaristic city-state; rival of Athens; Battle of Thermopylae 480 BC.',
    nativeTribes:'Spartans (Dorians)', romanizedNative:'Σπάρτη', validTo:'-0146-01-01T00:00:00.000Z'),
];
