import '../models/place.dart';

/// Oceania: all level-1 administrative subdivisions (states, provinces, regions, etc.).
const List<Place> placesSubdivisionsOceania = [
  // ── Australia ───────────────────────────────────────────────────
  Place(continent:'Oceania', name:'Australian Capital Territory', modernCountry:'Australia', iso3:'AUS', state:'Australian Capital Territory', historicalContext:'State or territory of Australia.'),
  Place(continent:'Oceania', name:'New South Wales', modernCountry:'Australia', iso3:'AUS', state:'New South Wales', historicalContext:'State or territory of Australia.'),
  Place(continent:'Oceania', name:'Northern Territory', modernCountry:'Australia', iso3:'AUS', state:'Northern Territory', historicalContext:'State or territory of Australia.'),
  Place(continent:'Oceania', name:'Queensland', modernCountry:'Australia', iso3:'AUS', state:'Queensland', historicalContext:'State or territory of Australia.'),
  Place(continent:'Oceania', name:'South Australia', modernCountry:'Australia', iso3:'AUS', state:'South Australia', historicalContext:'State or territory of Australia.'),
  Place(continent:'Oceania', name:'Tasmania', modernCountry:'Australia', iso3:'AUS', state:'Tasmania', historicalContext:'State or territory of Australia.'),
  Place(continent:'Oceania', name:'Victoria', modernCountry:'Australia', iso3:'AUS', state:'Victoria', historicalContext:'State or territory of Australia.'),
  Place(continent:'Oceania', name:'Western Australia', modernCountry:'Australia', iso3:'AUS', state:'Western Australia', historicalContext:'State or territory of Australia.'),

  // ── Fiji ────────────────────────────────────────────────────────
  Place(continent:'Oceania', name:'Central', modernCountry:'Fiji', iso3:'FJI', state:'Central', historicalContext:'Division of Fiji.'),
  Place(continent:'Oceania', name:'Eastern', modernCountry:'Fiji', iso3:'FJI', state:'Eastern', historicalContext:'Division of Fiji.'),
  Place(continent:'Oceania', name:'Northern', modernCountry:'Fiji', iso3:'FJI', state:'Northern', historicalContext:'Division of Fiji.'),
  Place(continent:'Oceania', name:'Rotuma', modernCountry:'Fiji', iso3:'FJI', state:'Rotuma', historicalContext:'Dependency of Fiji.'),
  Place(continent:'Oceania', name:'Western', modernCountry:'Fiji', iso3:'FJI', state:'Western', historicalContext:'Division of Fiji.'),

  // ── Kiribati ────────────────────────────────────────────────────
  Place(continent:'Oceania', name:'Gilbert Islands', modernCountry:'Kiribati', iso3:'KIR', state:'Gilbert Islands', historicalContext:'Group of islands (20 inhabited islands) of Kiribati.'),
  Place(continent:'Oceania', name:'Line Islands', modernCountry:'Kiribati', iso3:'KIR', state:'Line Islands', historicalContext:'Group of islands (20 inhabited islands) of Kiribati.'),
  Place(continent:'Oceania', name:'Phoenix Islands', modernCountry:'Kiribati', iso3:'KIR', state:'Phoenix Islands', historicalContext:'Group of islands (20 inhabited islands) of Kiribati.'),

  // ── Marshall Islands ────────────────────────────────────────────
  Place(continent:'Oceania', name:'Ralik chain', modernCountry:'Marshall Islands', iso3:'MHL', state:'Ralik chain', historicalContext:'Chain (of islands) of Marshall Islands.'),
  Place(continent:'Oceania', name:'Ratak chain', modernCountry:'Marshall Islands', iso3:'MHL', state:'Ratak chain', historicalContext:'Chain (of islands) of Marshall Islands.'),

  // ── Micronesia, Federated States of ─────────────────────────────
  Place(continent:'Oceania', name:'Chuuk', modernCountry:'Micronesia, Federated States of', iso3:'FSM', state:'Chuuk', historicalContext:'State of Micronesia, Federated States of.'),
  Place(continent:'Oceania', name:'Kosrae', modernCountry:'Micronesia, Federated States of', iso3:'FSM', state:'Kosrae', historicalContext:'State of Micronesia, Federated States of.'),
  Place(continent:'Oceania', name:'Pohnpei', modernCountry:'Micronesia, Federated States of', iso3:'FSM', state:'Pohnpei', historicalContext:'State of Micronesia, Federated States of.'),
  Place(continent:'Oceania', name:'Yap', modernCountry:'Micronesia, Federated States of', iso3:'FSM', state:'Yap', historicalContext:'State of Micronesia, Federated States of.'),

  // ── Nauru ───────────────────────────────────────────────────────
  Place(continent:'Oceania', name:'Aiwo', modernCountry:'Nauru', iso3:'NRU', state:'Aiwo', historicalContext:'District of Nauru.'),
  Place(continent:'Oceania', name:'Anabar', modernCountry:'Nauru', iso3:'NRU', state:'Anabar', historicalContext:'District of Nauru.'),
  Place(continent:'Oceania', name:'Anetan', modernCountry:'Nauru', iso3:'NRU', state:'Anetan', historicalContext:'District of Nauru.'),
  Place(continent:'Oceania', name:'Anibare', modernCountry:'Nauru', iso3:'NRU', state:'Anibare', historicalContext:'District of Nauru.'),
  Place(continent:'Oceania', name:'Baitsi', modernCountry:'Nauru', iso3:'NRU', state:'Baitsi', historicalContext:'District of Nauru.'),
  Place(continent:'Oceania', name:'Boe', modernCountry:'Nauru', iso3:'NRU', state:'Boe', historicalContext:'District of Nauru.'),
  Place(continent:'Oceania', name:'Buada', modernCountry:'Nauru', iso3:'NRU', state:'Buada', historicalContext:'District of Nauru.'),
  Place(continent:'Oceania', name:'Denigomodu', modernCountry:'Nauru', iso3:'NRU', state:'Denigomodu', historicalContext:'District of Nauru.'),
  Place(continent:'Oceania', name:'Ewa', modernCountry:'Nauru', iso3:'NRU', state:'Ewa', historicalContext:'District of Nauru.'),
  Place(continent:'Oceania', name:'Ijuw', modernCountry:'Nauru', iso3:'NRU', state:'Ijuw', historicalContext:'District of Nauru.'),
  Place(continent:'Oceania', name:'Meneng', modernCountry:'Nauru', iso3:'NRU', state:'Meneng', historicalContext:'District of Nauru.'),
  Place(continent:'Oceania', name:'Nibok', modernCountry:'Nauru', iso3:'NRU', state:'Nibok', historicalContext:'District of Nauru.'),
  Place(continent:'Oceania', name:'Uaboe', modernCountry:'Nauru', iso3:'NRU', state:'Uaboe', historicalContext:'District of Nauru.'),
  Place(continent:'Oceania', name:'Yaren', modernCountry:'Nauru', iso3:'NRU', state:'Yaren', historicalContext:'District of Nauru.'),

  // ── New Zealand ─────────────────────────────────────────────────
  Place(continent:'Oceania', name:'Auckland', modernCountry:'New Zealand', iso3:'NZL', state:'Auckland', historicalContext:'Region of New Zealand.'),
  Place(continent:'Oceania', name:'Bay of Plenty', modernCountry:'New Zealand', iso3:'NZL', state:'Bay of Plenty', historicalContext:'Region of New Zealand.'),
  Place(continent:'Oceania', name:'Canterbury', modernCountry:'New Zealand', iso3:'NZL', state:'Canterbury', historicalContext:'Region of New Zealand.'),
  Place(continent:'Oceania', name:'Chatham Islands Territory', modernCountry:'New Zealand', iso3:'NZL', state:'Chatham Islands Territory', historicalContext:'Special island authority of New Zealand.'),
  Place(continent:'Oceania', name:'Gisborne', modernCountry:'New Zealand', iso3:'NZL', state:'Gisborne', historicalContext:'Region of New Zealand.'),
  Place(continent:'Oceania', name:'Greater Wellington', modernCountry:'New Zealand', iso3:'NZL', state:'Greater Wellington', historicalContext:'Region of New Zealand.'),
  Place(continent:'Oceania', name:'Hawke\'s Bay', modernCountry:'New Zealand', iso3:'NZL', state:'Hawke\'s Bay', historicalContext:'Region of New Zealand.'),
  Place(continent:'Oceania', name:'Manawatū-Whanganui', modernCountry:'New Zealand', iso3:'NZL', state:'Manawatū-Whanganui', historicalContext:'Region of New Zealand.'),
  Place(continent:'Oceania', name:'Marlborough', modernCountry:'New Zealand', iso3:'NZL', state:'Marlborough', historicalContext:'Region of New Zealand.'),
  Place(continent:'Oceania', name:'Nelson', modernCountry:'New Zealand', iso3:'NZL', state:'Nelson', historicalContext:'Region of New Zealand.'),
  Place(continent:'Oceania', name:'Northland', modernCountry:'New Zealand', iso3:'NZL', state:'Northland', historicalContext:'Region of New Zealand.'),
  Place(continent:'Oceania', name:'Otago', modernCountry:'New Zealand', iso3:'NZL', state:'Otago', historicalContext:'Region of New Zealand.'),
  Place(continent:'Oceania', name:'Southland', modernCountry:'New Zealand', iso3:'NZL', state:'Southland', historicalContext:'Region of New Zealand.'),
  Place(continent:'Oceania', name:'Taranaki', modernCountry:'New Zealand', iso3:'NZL', state:'Taranaki', historicalContext:'Region of New Zealand.'),
  Place(continent:'Oceania', name:'Tasman', modernCountry:'New Zealand', iso3:'NZL', state:'Tasman', historicalContext:'Region of New Zealand.'),
  Place(continent:'Oceania', name:'Waikato', modernCountry:'New Zealand', iso3:'NZL', state:'Waikato', historicalContext:'Region of New Zealand.'),
  Place(continent:'Oceania', name:'West Coast', modernCountry:'New Zealand', iso3:'NZL', state:'West Coast', historicalContext:'Region of New Zealand.'),

  // ── Palau ───────────────────────────────────────────────────────
  Place(continent:'Oceania', name:'Aimeliik', modernCountry:'Palau', iso3:'PLW', state:'Aimeliik', historicalContext:'State of Palau.'),
  Place(continent:'Oceania', name:'Airai', modernCountry:'Palau', iso3:'PLW', state:'Airai', historicalContext:'State of Palau.'),
  Place(continent:'Oceania', name:'Angaur', modernCountry:'Palau', iso3:'PLW', state:'Angaur', historicalContext:'State of Palau.'),
  Place(continent:'Oceania', name:'Hatohobei', modernCountry:'Palau', iso3:'PLW', state:'Hatohobei', historicalContext:'State of Palau.'),
  Place(continent:'Oceania', name:'Kayangel', modernCountry:'Palau', iso3:'PLW', state:'Kayangel', historicalContext:'State of Palau.'),
  Place(continent:'Oceania', name:'Koror', modernCountry:'Palau', iso3:'PLW', state:'Koror', historicalContext:'State of Palau.'),
  Place(continent:'Oceania', name:'Melekeok', modernCountry:'Palau', iso3:'PLW', state:'Melekeok', historicalContext:'State of Palau.'),
  Place(continent:'Oceania', name:'Ngaraard', modernCountry:'Palau', iso3:'PLW', state:'Ngaraard', historicalContext:'State of Palau.'),
  Place(continent:'Oceania', name:'Ngarchelong', modernCountry:'Palau', iso3:'PLW', state:'Ngarchelong', historicalContext:'State of Palau.'),
  Place(continent:'Oceania', name:'Ngardmau', modernCountry:'Palau', iso3:'PLW', state:'Ngardmau', historicalContext:'State of Palau.'),
  Place(continent:'Oceania', name:'Ngatpang', modernCountry:'Palau', iso3:'PLW', state:'Ngatpang', historicalContext:'State of Palau.'),
  Place(continent:'Oceania', name:'Ngchesar', modernCountry:'Palau', iso3:'PLW', state:'Ngchesar', historicalContext:'State of Palau.'),
  Place(continent:'Oceania', name:'Ngeremlengui', modernCountry:'Palau', iso3:'PLW', state:'Ngeremlengui', historicalContext:'State of Palau.'),
  Place(continent:'Oceania', name:'Ngiwal', modernCountry:'Palau', iso3:'PLW', state:'Ngiwal', historicalContext:'State of Palau.'),
  Place(continent:'Oceania', name:'Peleliu', modernCountry:'Palau', iso3:'PLW', state:'Peleliu', historicalContext:'State of Palau.'),
  Place(continent:'Oceania', name:'Sonsorol', modernCountry:'Palau', iso3:'PLW', state:'Sonsorol', historicalContext:'State of Palau.'),

  // ── Papua New Guinea ────────────────────────────────────────────
  Place(continent:'Oceania', name:'Bougainville', modernCountry:'Papua New Guinea', iso3:'PNG', state:'Bougainville', historicalContext:'Autonomous region of Papua New Guinea.'),
  Place(continent:'Oceania', name:'Central', modernCountry:'Papua New Guinea', iso3:'PNG', state:'Central', historicalContext:'Province of Papua New Guinea.'),
  Place(continent:'Oceania', name:'Chimbu', modernCountry:'Papua New Guinea', iso3:'PNG', state:'Chimbu', historicalContext:'Province of Papua New Guinea.'),
  Place(continent:'Oceania', name:'East New Britain', modernCountry:'Papua New Guinea', iso3:'PNG', state:'East New Britain', historicalContext:'Province of Papua New Guinea.'),
  Place(continent:'Oceania', name:'East Sepik', modernCountry:'Papua New Guinea', iso3:'PNG', state:'East Sepik', historicalContext:'Province of Papua New Guinea.'),
  Place(continent:'Oceania', name:'Eastern Highlands', modernCountry:'Papua New Guinea', iso3:'PNG', state:'Eastern Highlands', historicalContext:'Province of Papua New Guinea.'),
  Place(continent:'Oceania', name:'Enga', modernCountry:'Papua New Guinea', iso3:'PNG', state:'Enga', historicalContext:'Province of Papua New Guinea.'),
  Place(continent:'Oceania', name:'Gulf', modernCountry:'Papua New Guinea', iso3:'PNG', state:'Gulf', historicalContext:'Province of Papua New Guinea.'),
  Place(continent:'Oceania', name:'Hela', modernCountry:'Papua New Guinea', iso3:'PNG', state:'Hela', historicalContext:'Province of Papua New Guinea.'),
  Place(continent:'Oceania', name:'Jiwaka', modernCountry:'Papua New Guinea', iso3:'PNG', state:'Jiwaka', historicalContext:'Province of Papua New Guinea.'),
  Place(continent:'Oceania', name:'Madang', modernCountry:'Papua New Guinea', iso3:'PNG', state:'Madang', historicalContext:'Province of Papua New Guinea.'),
  Place(continent:'Oceania', name:'Manus', modernCountry:'Papua New Guinea', iso3:'PNG', state:'Manus', historicalContext:'Province of Papua New Guinea.'),
  Place(continent:'Oceania', name:'Milne Bay', modernCountry:'Papua New Guinea', iso3:'PNG', state:'Milne Bay', historicalContext:'Province of Papua New Guinea.'),
  Place(continent:'Oceania', name:'Morobe', modernCountry:'Papua New Guinea', iso3:'PNG', state:'Morobe', historicalContext:'Province of Papua New Guinea.'),
  Place(continent:'Oceania', name:'National Capital District (Port Moresby)', modernCountry:'Papua New Guinea', iso3:'PNG', state:'National Capital District (Port Moresby)', historicalContext:'District of Papua New Guinea.'),
  Place(continent:'Oceania', name:'New Ireland', modernCountry:'Papua New Guinea', iso3:'PNG', state:'New Ireland', historicalContext:'Province of Papua New Guinea.'),
  Place(continent:'Oceania', name:'Northern', modernCountry:'Papua New Guinea', iso3:'PNG', state:'Northern', historicalContext:'Province of Papua New Guinea.'),
  Place(continent:'Oceania', name:'Southern Highlands', modernCountry:'Papua New Guinea', iso3:'PNG', state:'Southern Highlands', historicalContext:'Province of Papua New Guinea.'),
  Place(continent:'Oceania', name:'West New Britain', modernCountry:'Papua New Guinea', iso3:'PNG', state:'West New Britain', historicalContext:'Province of Papua New Guinea.'),
  Place(continent:'Oceania', name:'West Sepik', modernCountry:'Papua New Guinea', iso3:'PNG', state:'West Sepik', historicalContext:'Province of Papua New Guinea.'),
  Place(continent:'Oceania', name:'Western', modernCountry:'Papua New Guinea', iso3:'PNG', state:'Western', historicalContext:'Province of Papua New Guinea.'),
  Place(continent:'Oceania', name:'Western Highlands', modernCountry:'Papua New Guinea', iso3:'PNG', state:'Western Highlands', historicalContext:'Province of Papua New Guinea.'),

  // ── Samoa ───────────────────────────────────────────────────────
  Place(continent:'Oceania', name:'A\'ana', modernCountry:'Samoa', iso3:'WSM', state:'A\'ana', historicalContext:'District of Samoa.'),
  Place(continent:'Oceania', name:'Aiga-i-le-Tai', modernCountry:'Samoa', iso3:'WSM', state:'Aiga-i-le-Tai', historicalContext:'District of Samoa.'),
  Place(continent:'Oceania', name:'Atua', modernCountry:'Samoa', iso3:'WSM', state:'Atua', historicalContext:'District of Samoa.'),
  Place(continent:'Oceania', name:'Fa\'asaleleaga', modernCountry:'Samoa', iso3:'WSM', state:'Fa\'asaleleaga', historicalContext:'District of Samoa.'),
  Place(continent:'Oceania', name:'Gaga\'emauga', modernCountry:'Samoa', iso3:'WSM', state:'Gaga\'emauga', historicalContext:'District of Samoa.'),
  Place(continent:'Oceania', name:'Gagaifomauga', modernCountry:'Samoa', iso3:'WSM', state:'Gagaifomauga', historicalContext:'District of Samoa.'),
  Place(continent:'Oceania', name:'Palauli', modernCountry:'Samoa', iso3:'WSM', state:'Palauli', historicalContext:'District of Samoa.'),
  Place(continent:'Oceania', name:'Satupa\'itea', modernCountry:'Samoa', iso3:'WSM', state:'Satupa\'itea', historicalContext:'District of Samoa.'),
  Place(continent:'Oceania', name:'Tuamasaga', modernCountry:'Samoa', iso3:'WSM', state:'Tuamasaga', historicalContext:'District of Samoa.'),
  Place(continent:'Oceania', name:'Va\'a-o-Fonoti', modernCountry:'Samoa', iso3:'WSM', state:'Va\'a-o-Fonoti', historicalContext:'District of Samoa.'),
  Place(continent:'Oceania', name:'Vaisigano', modernCountry:'Samoa', iso3:'WSM', state:'Vaisigano', historicalContext:'District of Samoa.'),

  // ── Solomon Islands ─────────────────────────────────────────────
  Place(continent:'Oceania', name:'Capital Territory (Honiara)', modernCountry:'Solomon Islands', iso3:'SLB', state:'Capital Territory (Honiara)', historicalContext:'Capital territory of Solomon Islands.'),
  Place(continent:'Oceania', name:'Central', modernCountry:'Solomon Islands', iso3:'SLB', state:'Central', historicalContext:'Province of Solomon Islands.'),
  Place(continent:'Oceania', name:'Choiseul', modernCountry:'Solomon Islands', iso3:'SLB', state:'Choiseul', historicalContext:'Province of Solomon Islands.'),
  Place(continent:'Oceania', name:'Guadalcanal', modernCountry:'Solomon Islands', iso3:'SLB', state:'Guadalcanal', historicalContext:'Province of Solomon Islands.'),
  Place(continent:'Oceania', name:'Isabel', modernCountry:'Solomon Islands', iso3:'SLB', state:'Isabel', historicalContext:'Province of Solomon Islands.'),
  Place(continent:'Oceania', name:'Makira-Ulawa', modernCountry:'Solomon Islands', iso3:'SLB', state:'Makira-Ulawa', historicalContext:'Province of Solomon Islands.'),
  Place(continent:'Oceania', name:'Malaita', modernCountry:'Solomon Islands', iso3:'SLB', state:'Malaita', historicalContext:'Province of Solomon Islands.'),
  Place(continent:'Oceania', name:'Rennell and Bellona', modernCountry:'Solomon Islands', iso3:'SLB', state:'Rennell and Bellona', historicalContext:'Province of Solomon Islands.'),
  Place(continent:'Oceania', name:'Temotu', modernCountry:'Solomon Islands', iso3:'SLB', state:'Temotu', historicalContext:'Province of Solomon Islands.'),
  Place(continent:'Oceania', name:'Western', modernCountry:'Solomon Islands', iso3:'SLB', state:'Western', historicalContext:'Province of Solomon Islands.'),

  // ── Tonga ───────────────────────────────────────────────────────
  Place(continent:'Oceania', name:'\'Eua', modernCountry:'Tonga', iso3:'TON', state:'\'Eua', historicalContext:'Division of Tonga.'),
  Place(continent:'Oceania', name:'Ha\'apai', modernCountry:'Tonga', iso3:'TON', state:'Ha\'apai', historicalContext:'Division of Tonga.'),
  Place(continent:'Oceania', name:'Niuas', modernCountry:'Tonga', iso3:'TON', state:'Niuas', historicalContext:'Division of Tonga.'),
  Place(continent:'Oceania', name:'Tongatapu', modernCountry:'Tonga', iso3:'TON', state:'Tongatapu', historicalContext:'Division of Tonga.'),
  Place(continent:'Oceania', name:'Vava\'u', modernCountry:'Tonga', iso3:'TON', state:'Vava\'u', historicalContext:'Division of Tonga.'),

  // ── Tuvalu ──────────────────────────────────────────────────────
  Place(continent:'Oceania', name:'Funafuti', modernCountry:'Tuvalu', iso3:'TUV', state:'Funafuti', historicalContext:'Town council of Tuvalu.'),
  Place(continent:'Oceania', name:'Nanumaga', modernCountry:'Tuvalu', iso3:'TUV', state:'Nanumaga', historicalContext:'Island council of Tuvalu.'),
  Place(continent:'Oceania', name:'Nanumea', modernCountry:'Tuvalu', iso3:'TUV', state:'Nanumea', historicalContext:'Island council of Tuvalu.'),
  Place(continent:'Oceania', name:'Niutao', modernCountry:'Tuvalu', iso3:'TUV', state:'Niutao', historicalContext:'Island council of Tuvalu.'),
  Place(continent:'Oceania', name:'Nui', modernCountry:'Tuvalu', iso3:'TUV', state:'Nui', historicalContext:'Island council of Tuvalu.'),
  Place(continent:'Oceania', name:'Nukufetau', modernCountry:'Tuvalu', iso3:'TUV', state:'Nukufetau', historicalContext:'Island council of Tuvalu.'),
  Place(continent:'Oceania', name:'Nukulaelae', modernCountry:'Tuvalu', iso3:'TUV', state:'Nukulaelae', historicalContext:'Island council of Tuvalu.'),
  Place(continent:'Oceania', name:'Vaitupu', modernCountry:'Tuvalu', iso3:'TUV', state:'Vaitupu', historicalContext:'Island council of Tuvalu.'),

  // ── United States Minor Outlying Islands ────────────────────────
  Place(continent:'Oceania', name:'Baker Island', modernCountry:'United States Minor Outlying Islands', iso3:'UMI', state:'Baker Island', historicalContext:'Islands, groups of islands of United States Minor Outlying Islands.'),
  Place(continent:'Oceania', name:'Howland Island', modernCountry:'United States Minor Outlying Islands', iso3:'UMI', state:'Howland Island', historicalContext:'Islands, groups of islands of United States Minor Outlying Islands.'),
  Place(continent:'Oceania', name:'Jarvis Island', modernCountry:'United States Minor Outlying Islands', iso3:'UMI', state:'Jarvis Island', historicalContext:'Islands, groups of islands of United States Minor Outlying Islands.'),
  Place(continent:'Oceania', name:'Johnston Atoll', modernCountry:'United States Minor Outlying Islands', iso3:'UMI', state:'Johnston Atoll', historicalContext:'Islands, groups of islands of United States Minor Outlying Islands.'),
  Place(continent:'Oceania', name:'Kingman Reef', modernCountry:'United States Minor Outlying Islands', iso3:'UMI', state:'Kingman Reef', historicalContext:'Islands, groups of islands of United States Minor Outlying Islands.'),
  Place(continent:'Oceania', name:'Midway Islands', modernCountry:'United States Minor Outlying Islands', iso3:'UMI', state:'Midway Islands', historicalContext:'Islands, groups of islands of United States Minor Outlying Islands.'),
  Place(continent:'Oceania', name:'Navassa Island', modernCountry:'United States Minor Outlying Islands', iso3:'UMI', state:'Navassa Island', historicalContext:'Islands, groups of islands of United States Minor Outlying Islands.'),
  Place(continent:'Oceania', name:'Palmyra Atoll', modernCountry:'United States Minor Outlying Islands', iso3:'UMI', state:'Palmyra Atoll', historicalContext:'Islands, groups of islands of United States Minor Outlying Islands.'),
  Place(continent:'Oceania', name:'Wake Island', modernCountry:'United States Minor Outlying Islands', iso3:'UMI', state:'Wake Island', historicalContext:'Islands, groups of islands of United States Minor Outlying Islands.'),

  // ── Vanuatu ─────────────────────────────────────────────────────
  Place(continent:'Oceania', name:'Malampa', modernCountry:'Vanuatu', iso3:'VUT', state:'Malampa', historicalContext:'Province of Vanuatu.'),
  Place(continent:'Oceania', name:'Pénama', modernCountry:'Vanuatu', iso3:'VUT', state:'Pénama', historicalContext:'Province of Vanuatu.'),
  Place(continent:'Oceania', name:'Sanma', modernCountry:'Vanuatu', iso3:'VUT', state:'Sanma', historicalContext:'Province of Vanuatu.'),
  Place(continent:'Oceania', name:'Shéfa', modernCountry:'Vanuatu', iso3:'VUT', state:'Shéfa', historicalContext:'Province of Vanuatu.'),
  Place(continent:'Oceania', name:'Taféa', modernCountry:'Vanuatu', iso3:'VUT', state:'Taféa', historicalContext:'Province of Vanuatu.'),
  Place(continent:'Oceania', name:'Torba', modernCountry:'Vanuatu', iso3:'VUT', state:'Torba', historicalContext:'Province of Vanuatu.'),

  // ── Wallis and Futuna ───────────────────────────────────────────
  Place(continent:'Oceania', name:'Alo', modernCountry:'Wallis and Futuna', iso3:'WLF', state:'Alo', historicalContext:'Administrative precinct of Wallis and Futuna.'),
  Place(continent:'Oceania', name:'Sigave', modernCountry:'Wallis and Futuna', iso3:'WLF', state:'Sigave', historicalContext:'Administrative precinct of Wallis and Futuna.'),
  Place(continent:'Oceania', name:'Uvea', modernCountry:'Wallis and Futuna', iso3:'WLF', state:'Uvea', historicalContext:'Administrative precinct of Wallis and Futuna.'),
];
