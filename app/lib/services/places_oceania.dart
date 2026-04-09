import '../models/place.dart';

/// Oceania: organised continent → country → state/region → county → city
const List<Place> placesOceania = [

  // ── Australia ─────────────────────────────────────────────────────────────
  Place(continent:'Oceania', name:'Canberra', modernCountry:'Australia', iso3:'AUS', state:'Australian Capital Territory',
    historicalContext:'Capital since 1927; purpose-built compromise between Sydney and Melbourne.',
    colonizer:'British Empire', nativeTribes:'Ngunnawal, Ngambri'),
  Place(continent:'Oceania', name:'Sydney', modernCountry:'Australia', iso3:'AUS', state:'New South Wales',
    county:'City of Sydney', historicalContext:'First British settlement (Botany Bay 1788); largest Australian city.',
    colonizer:'British Empire', nativeTribes:'Eora, Gadigal'),
  Place(continent:'Oceania', name:'Melbourne', modernCountry:'Australia', iso3:'AUS', state:'Victoria',
    county:'City of Melbourne', historicalContext:'Victorian gold rush 1851; former Commonwealth capital 1901–1927.',
    colonizer:'British Empire', nativeTribes:'Wurundjeri, Boon Wurrung'),
  Place(continent:'Oceania', name:'Brisbane', modernCountry:'Australia', iso3:'AUS', state:'Queensland',
    county:'City of Brisbane', historicalContext:'British penal colony (Moreton Bay 1824); capital of Queensland.',
    colonizer:'British Empire', nativeTribes:'Turrbal, Jagera'),
  Place(continent:'Oceania', name:'Perth', modernCountry:'Australia', iso3:'AUS', state:'Western Australia',
    county:'City of Perth', historicalContext:'Swan River Colony 1829; most isolated major city on Earth.',
    colonizer:'British Empire', nativeTribes:'Noongar (Whadjuk)'),
  Place(continent:'Oceania', name:'Adelaide', modernCountry:'Australia', iso3:'AUS', state:'South Australia',
    county:'City of Adelaide', historicalContext:'Free settler colony 1836 (no convicts); planned "city of churches".',
    colonizer:'British Empire', nativeTribes:'Kaurna'),
  Place(continent:'Oceania', name:'Darwin', modernCountry:'Australia', iso3:'AUS', state:'Northern Territory',
    historicalContext:'Capital of NT; bombed by Japan 1942; gateway to Top End and Arnhem Land.',
    colonizer:'British Empire', nativeTribes:'Larrakia'),
  Place(continent:'Oceania', name:'Hobart', modernCountry:'Australia', iso3:'AUS', state:'Tasmania',
    county:'City of Hobart', historicalContext:'Second oldest Australian city (1804); Van Diemen\'s Land convict colony.',
    colonizer:'British Empire', nativeTribes:'Palawa (Tasmanian Aboriginal)'),

  // ── New Zealand ───────────────────────────────────────────────────────────
  Place(continent:'Oceania', name:'Wellington', modernCountry:'New Zealand', iso3:'NZL', state:'Wellington Region',
    historicalContext:'Capital since 1865; Treaty of Waitangi (1840) marked formal British sovereignty.',
    colonizer:'British Empire', nativeTribes:'Māori (Te Āti Awa)'),
  Place(continent:'Oceania', name:'Auckland', modernCountry:'New Zealand', iso3:'NZL', state:'Auckland Region',
    historicalContext:'Largest city; volcanic isthmus; former capital until 1865.',
    colonizer:'British Empire', nativeTribes:'Māori (Ngāti Whātua)'),
  Place(continent:'Oceania', name:'Christchurch', modernCountry:'New Zealand', iso3:'NZL', state:'Canterbury Region',
    historicalContext:'South Island\'s largest city; English planned settlement 1848; 2011 earthquake.',
    colonizer:'British Empire', nativeTribes:'Māori (Ngāi Tahu)'),
  Place(continent:'Oceania', name:'Waitangi', modernCountry:'New Zealand', iso3:'NZL', state:'Northland Region',
    historicalContext:'Site of Treaty of Waitangi 1840 between Māori chiefs and British Crown.',
    colonizer:'British Empire', nativeTribes:'Māori (Ngāpuhi)'),

  // ── Fiji ──────────────────────────────────────────────────────────────────
  Place(continent:'Oceania', name:'Suva', modernCountry:'Fiji', iso3:'FJI', state:'Central Division',
    historicalContext:'Capital; British Crown Colony 1874; Indo-Fijian sugar worker descendants.',
    colonizer:'British Empire', nativeTribes:'iTaukei (Fijian)'),

  // ── Papua New Guinea ──────────────────────────────────────────────────────
  Place(continent:'Oceania', name:'Port Moresby', modernCountry:'Papua New Guinea', iso3:'PNG', state:'National Capital District',
    historicalContext:'Capital; British Papua then Australian Territory; independence 1975.',
    colonizer:'British Empire, Australian administration', nativeTribes:'Motu, Koiari'),

  // ── Solomon Islands ───────────────────────────────────────────────────────
  Place(continent:'Oceania', name:'Honiara', modernCountry:'Solomon Islands', iso3:'SLB', state:'Guadalcanal Province',
    historicalContext:'Capital; WWII Battle of Guadalcanal 1942–1943; British protectorate.',
    colonizer:'British Empire', nativeTribes:'Melanesian (Guale)'),

  // ── Vanuatu ───────────────────────────────────────────────────────────────
  Place(continent:'Oceania', name:'Port Vila', modernCountry:'Vanuatu', iso3:'VUT', state:'Shefa Province',
    historicalContext:'Capital; unique French-British Condominium (New Hebrides) until 1980.',
    colonizer:'French Empire, British Empire', nativeTribes:'Melanesian (Efate)'),

  // ── Samoa ─────────────────────────────────────────────────────────────────
  Place(continent:'Oceania', name:'Apia', modernCountry:'Samoa', iso3:'WSM', state:'Tuamasaga District',
    historicalContext:'Capital; German Samoa then New Zealand mandate; independence 1962.',
    colonizer:'German Empire, New Zealand administration', nativeTribes:'Samoan'),

  // ── Tonga ─────────────────────────────────────────────────────────────────
  Place(continent:'Oceania', name:"Nuku'alofa", modernCountry:'Tonga', iso3:'TON', state:"Tongatapu Island",
    historicalContext:'Capital; Polynesian kingdom; British protectorate 1900–1970; never fully colonised.',
    colonizer:'British Empire (protectorate)', nativeTribes:'Tongan'),

  // ── Kiribati ──────────────────────────────────────────────────────────────
  Place(continent:'Oceania', name:'South Tarawa', modernCountry:'Kiribati', iso3:'KIR', state:'Gilbert Islands',
    historicalContext:'Capital; WWII Battle of Tarawa; British Gilbert and Ellice Islands Colony.',
    colonizer:'British Empire', nativeTribes:'I-Kiribati'),

  // ── Micronesia ────────────────────────────────────────────────────────────
  Place(continent:'Oceania', name:'Palikir', modernCountry:'Federated States of Micronesia', iso3:'FSM', state:'Pohnpei State',
    historicalContext:'Capital; Spanish then German then Japanese then US Trust Territory.',
    colonizer:'Spanish Empire, German Empire, Japanese Empire, US administration', nativeTribes:'Pohnpeian'),

  // ── Marshall Islands ──────────────────────────────────────────────────────
  Place(continent:'Oceania', name:'Majuro', modernCountry:'Marshall Islands', iso3:'MHL', state:'Majuro Atoll',
    historicalContext:'Capital; German then Japanese then US nuclear test site region (Bikini Atoll nearby).',
    colonizer:'German Empire, Japanese Empire, US administration', nativeTribes:'Marshallese'),

  // ── Nauru ─────────────────────────────────────────────────────────────────
  Place(continent:'Oceania', name:'Yaren', modernCountry:'Nauru', iso3:'NRU', state:'Yaren District',
    historicalContext:'De facto capital; phosphate mining island; German then Australian then British mandate.',
    colonizer:'German Empire, Australian administration', nativeTribes:'Nauruan'),

  // ── Palau ─────────────────────────────────────────────────────────────────
  Place(continent:'Oceania', name:'Ngerulmud', modernCountry:'Palau', iso3:'PLW', state:'Melekeok State',
    historicalContext:'Capital; German, Japanese, US Trust Territory; independence in Compact of Free Association 1994.',
    colonizer:'Spanish Empire, German Empire, Japanese Empire, US administration', nativeTribes:'Palauan'),

  // ── Tuvalu ────────────────────────────────────────────────────────────────
  Place(continent:'Oceania', name:'Funafuti', modernCountry:'Tuvalu', iso3:'TUV', state:'Funafuti Atoll',
    historicalContext:'Capital atoll; British Elliott Islands; independence 1978; threatened by rising sea levels.',
    colonizer:'British Empire', nativeTribes:'Tuvaluan (Polynesian)'),
];
