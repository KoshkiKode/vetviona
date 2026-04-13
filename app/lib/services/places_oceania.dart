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

  // ── Additional Australia ───────────────────────────────────────────────────
  Place(continent:'Oceania', name:'Ballarat', modernCountry:'Australia', iso3:'AUS', state:'Victoria',
    historicalContext:'Victorian goldfields; Eureka Stockade 1854 workers\' rebellion; major genealogy records.',
    colonizer:'British Empire', nativeTribes:'Wathaurong'),
  Place(continent:'Oceania', name:'Bendigo', modernCountry:'Australia', iso3:'AUS', state:'Victoria',
    historicalContext:'Gold rush city; significant Chinese community records; Bendigo Bank origins.',
    colonizer:'British Empire', nativeTribes:'Dja Dja Wurrung'),
  Place(continent:'Oceania', name:'Geelong', modernCountry:'Australia', iso3:'AUS', state:'Victoria',
    historicalContext:'Victoria\'s second city; wool and automotive industry; Corio Bay port.',
    colonizer:'British Empire', nativeTribes:'Wathaurong'),
  Place(continent:'Oceania', name:'Newcastle', modernCountry:'Australia', iso3:'AUS', state:'New South Wales',
    historicalContext:'Second largest NSW city; Hunter Valley coal; first penal settlement in Australia.',
    colonizer:'British Empire', nativeTribes:'Awabakal'),
  Place(continent:'Oceania', name:'Wollongong', modernCountry:'Australia', iso3:'AUS', state:'New South Wales',
    historicalContext:'Steel city south of Sydney; Illawarra coast; major immigrant worker records.',
    colonizer:'British Empire', nativeTribes:'Dharawal'),
  Place(continent:'Oceania', name:'Launceston', modernCountry:'Australia', iso3:'AUS', state:'Tasmania',
    historicalContext:'Second Tasmanian city; Van Diemen\'s Land records; Cataract Gorge.',
    colonizer:'British Empire', nativeTribes:'Palawa (Tasmanian Aboriginal)'),
  Place(continent:'Oceania', name:'Cairns', modernCountry:'Australia', iso3:'AUS', state:'Queensland',
    historicalContext:'Tropical north Queensland gateway; Great Barrier Reef; sugar cane industry.',
    colonizer:'British Empire', nativeTribes:'Yirrganydji, Gimuy Walubara Yidinji'),
  Place(continent:'Oceania', name:'Townsville', modernCountry:'Australia', iso3:'AUS', state:'Queensland',
    historicalContext:'North Queensland port; WWII Allied base; largest tropical city in Australia.',
    colonizer:'British Empire', nativeTribes:'Bindal, Wulgurukaba'),
  Place(continent:'Oceania', name:'Toowoomba', modernCountry:'Australia', iso3:'AUS', state:'Queensland',
    historicalContext:'Garden City of Queensland; Darling Downs agricultural hub; German settler records.',
    colonizer:'British Empire', nativeTribes:'Giabal, Jarowair'),
  Place(continent:'Oceania', name:'Broken Hill', modernCountry:'Australia', iso3:'AUS', state:'New South Wales',
    historicalContext:'Silver-zinc-lead mining city; BHP Billiton origin; outback records.',
    colonizer:'British Empire', nativeTribes:'Wilyakali'),
  Place(continent:'Oceania', name:'Port Adelaide', modernCountry:'Australia', iso3:'AUS', state:'South Australia',
    historicalContext:'Main port of South Australia; convict hulk records; significant immigrant processing.',
    colonizer:'British Empire', nativeTribes:'Kaurna'),
  Place(continent:'Oceania', name:'Alice Springs', modernCountry:'Australia', iso3:'AUS', state:'Northern Territory',
    historicalContext:'Red Centre; Arrernte Aboriginal land; Overland Telegraph Station; outback settlement.',
    colonizer:'British Empire', nativeTribes:'Arrernte (Aranda)'),

  // ── Additional New Zealand ─────────────────────────────────────────────────
  Place(continent:'Oceania', name:'Dunedin', modernCountry:'New Zealand', iso3:'NZL', state:'Otago Region',
    historicalContext:'Scottish heritage city; Edinburgh of the South; Otago gold rush records.',
    colonizer:'British Empire', nativeTribes:'Māori (Ngāi Tahu)'),
  Place(continent:'Oceania', name:'Hamilton', modernCountry:'New Zealand', iso3:'NZL', state:'Waikato Region',
    historicalContext:'Waikato River city; Māori King Movement heartland; agricultural centre.',
    colonizer:'British Empire', nativeTribes:'Māori (Waikato)'),
  Place(continent:'Oceania', name:'Tauranga', modernCountry:'New Zealand', iso3:'NZL', state:'Bay of Plenty Region',
    historicalContext:'Fastest-growing NZ city; kiwifruit export; Gate Pā battle 1864.',
    colonizer:'British Empire', nativeTribes:'Māori (Ngāi Te Rangi, Ngāti Ranginui)'),
  Place(continent:'Oceania', name:'Nelson', modernCountry:'New Zealand', iso3:'NZL', state:'Nelson Region',
    historicalContext:'Sunniest city in NZ; Abel Tasman National Park nearby; early British settler records.',
    colonizer:'British Empire', nativeTribes:'Māori (Ngāti Toa, Te Āti Awa)'),
  Place(continent:'Oceania', name:'Napier', modernCountry:'New Zealand', iso3:'NZL', state:'Hawke\'s Bay Region',
    historicalContext:'Art Deco city rebuilt after 1931 earthquake; wine and fruit region.',
    colonizer:'British Empire', nativeTribes:'Māori (Ngāti Kahungunu)'),
  Place(continent:'Oceania', name:'Palmerston North', modernCountry:'New Zealand', iso3:'NZL', state:'Manawatū-Whanganui Region',
    historicalContext:'University city; Massey University; agricultural Manawatū plains.',
    colonizer:'British Empire', nativeTribes:'Māori (Rangitāne)'),
  Place(continent:'Oceania', name:'Rotorua', modernCountry:'New Zealand', iso3:'NZL', state:'Bay of Plenty Region',
    historicalContext:'Māori cultural heartland; geothermal activity; Te Arawa ancestral home.',
    colonizer:'British Empire', nativeTribes:'Māori (Te Arawa)'),

  // ── Additional Pacific Islands ─────────────────────────────────────────────
  Place(continent:'Oceania', name:'Noumea', modernCountry:'New Caledonia', iso3:'NCL', state:'South Province',
    historicalContext:'French colonial capital; nickel mining; convict transportation destination; Kanak independence movement.',
    colonizer:'French Empire', nativeTribes:'Kanak'),
  Place(continent:'Oceania', name:'Papeete', modernCountry:'French Polynesia', iso3:'PYF', state:'Windward Islands',
    historicalContext:'Capital of French Polynesia; Tahitian culture; Paul Gauguin lived in Tahiti.',
    colonizer:'French Empire', nativeTribes:'Maohi (Tahitian)'),
  Place(continent:'Oceania', name:'Hagåtña', modernCountry:'Guam', iso3:'GUM', state:'Guam',
    historicalContext:'Capital; Spanish 1668–1898; American territory after Spanish-American War.',
    colonizer:'Spanish Empire, United States', nativeTribes:'Chamorro', romanizedNative:'Agana'),

];
