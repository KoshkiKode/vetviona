import '../models/place.dart';

/// Americas: organised continent → country → state/region → county → city
const List<Place> placesAmericas = [

  // ══════════════════════════════════════════════════════════════════════════
  // NORTH AMERICA
  // ══════════════════════════════════════════════════════════════════════════

  // ── Canada ────────────────────────────────────────────────────────────────
  Place(continent:'Americas', name:'Ottawa', modernCountry:'Canada', iso3:'CAN', state:'Ontario',
    county:'Ottawa-Carleton', historicalContext:'Capital since 1857; chosen by Queen Victoria as neutral between Toronto and Montreal.',
    colonizer:'British Empire', nativeTribes:'Algonquin'),
  Place(continent:'Americas', name:'Toronto', modernCountry:'Canada', iso3:'CAN', state:'Ontario',
    county:'Municipality of Metropolitan Toronto', historicalContext:'Largest city; Fort York 1793; "Hogtown" commercial capital.',
    colonizer:'French Empire, British Empire', nativeTribes:'Mississaugas, Haudenosaunee', romanizedNative:'Tkaronto'),
  Place(continent:'Americas', name:'Montreal', modernCountry:'Canada', iso3:'CAN', state:'Quebec',
    county:'Communauté Métropolitaine de Montréal', historicalContext:'French colony Ville-Marie 1642; major St Lawrence River port.',
    colonizer:'French Empire, British Empire', nativeTribes:'Mohawk, Huron-Wendat', romanizedNative:'Montréal'),
  Place(continent:'Americas', name:'Vancouver', modernCountry:'Canada', iso3:'CAN', state:'British Columbia',
    county:'Metro Vancouver', historicalContext:'British Columbia gold rush city; Trans-Canada Pacific terminus.',
    colonizer:'British Empire', nativeTribes:'Musqueam, Squamish, Tsleil-Waututh'),
  Place(continent:'Americas', name:'Quebec City', modernCountry:'Canada', iso3:'CAN', state:'Quebec',
    county:'Communauté Métropolitaine de Québec', historicalContext:'First European settlement in Canada (1608, Samuel de Champlain); walled city.',
    colonizer:'French Empire', nativeTribes:'Wendat, Algonquin'),
  Place(continent:'Americas', name:'Halifax', modernCountry:'Canada', iso3:'CAN', state:'Nova Scotia',
    county:'Halifax Regional Municipality', historicalContext:'British naval base 1749; gateway for European immigrants.',
    colonizer:'British Empire', nativeTribes:"Mi'kmaq"),
  Place(continent:'Americas', name:'Winnipeg', modernCountry:'Canada', iso3:'CAN', state:'Manitoba',
    historicalContext:'Red River settlement; Métis homeland; major grain distribution hub.',
    colonizer:'British Empire, Hudson\'s Bay Company', nativeTribes:'Métis, Assiniboine, Ojibwe'),
  Place(continent:'Americas', name:'Calgary', modernCountry:'Canada', iso3:'CAN', state:'Alberta',
    historicalContext:'NWMP fort 1875; cattle ranching then oil sands economy.',
    colonizer:'British Empire', nativeTribes:'Blackfoot Confederacy'),
  Place(continent:'Americas', name:'Edmonton', modernCountry:'Canada', iso3:'CAN', state:'Alberta',
    historicalContext:'Provincial capital; Hudson\'s Bay Company Fort Edmonton; gateway to northern Canada.',
    colonizer:'British Empire, Hudson\'s Bay Company', nativeTribes:'Cree, Métis'),

  // ── United States ─────────────────────────────────────────────────────────
  Place(continent:'Americas', name:'Washington D.C.', modernCountry:'United States', iso3:'USA',
    state:'District of Columbia', historicalContext:'Federal capital since 1800; designed by L\'Enfant; named for George Washington.',
    colonizer:'British Empire (prior)', nativeTribes:'Nacotchtank (Anacostan)'),
  Place(continent:'Americas', name:'New York City', modernCountry:'United States', iso3:'USA', state:'New York',
    county:'New York County (Manhattan)', historicalContext:'Dutch New Amsterdam 1626; largest US city; Ellis Island immigration.',
    colonizer:'Dutch Republic, British Empire', nativeTribes:'Lenape', romanizedNative:'New Amsterdam'),
  Place(continent:'Americas', name:'Los Angeles', modernCountry:'United States', iso3:'USA', state:'California',
    county:'Los Angeles County', historicalContext:'Spanish colonial pueblo 1781; Mexican territory; boomed post-railroad 1876.',
    colonizer:'Spanish Empire, Mexican Republic', nativeTribes:'Tongva (Gabrielino)'),
  Place(continent:'Americas', name:'Chicago', modernCountry:'United States', iso3:'USA', state:'Illinois',
    county:'Cook County', historicalContext:'Fort Dearborn 1803; Great Chicago Fire 1871; stockyards and jazz capital.',
    colonizer:'French Empire, British Empire', nativeTribes:'Potawatomi, Miami'),
  Place(continent:'Americas', name:'Philadelphia', modernCountry:'United States', iso3:'USA', state:'Pennsylvania',
    county:'Philadelphia County', historicalContext:'Founded by Quakers 1682; US capital 1776–1800; Liberty Bell.',
    colonizer:'British Empire', nativeTribes:'Lenape (Delaware)'),
  Place(continent:'Americas', name:'Boston', modernCountry:'United States', iso3:'USA', state:'Massachusetts',
    county:'Suffolk County', historicalContext:'Puritan settlement 1630; Boston Tea Party; seat of American Revolution.',
    colonizer:'British Empire', nativeTribes:'Massachusetts, Wampanoag'),
  Place(continent:'Americas', name:'New Orleans', modernCountry:'United States', iso3:'USA', state:'Louisiana',
    county:'Orleans Parish', historicalContext:'French La Nouvelle-Orléans 1718; Spanish then US after Louisiana Purchase 1803.',
    colonizer:'French Empire, Spanish Empire', nativeTribes:'Chitimacha, Natchez'),
  Place(continent:'Americas', name:'San Francisco', modernCountry:'United States', iso3:'USA', state:'California',
    county:'San Francisco County', historicalContext:'Spanish Mission Dolores 1776; Gold Rush 1849; major Pacific port.',
    colonizer:'Spanish Empire, Mexican Republic', nativeTribes:'Ohlone (Ramaytush)'),
  Place(continent:'Americas', name:'Santa Fe', modernCountry:'United States', iso3:'USA', state:'New Mexico',
    county:'Santa Fe County', historicalContext:'Oldest US state capital; Spanish colonial (1610); Pueblo revolt 1680.',
    colonizer:'Spanish Empire, Mexican Republic', nativeTribes:'Tewa Pueblo (Ohkay Owingeh)'),
  Place(continent:'Americas', name:'Charleston', modernCountry:'United States', iso3:'USA', state:'South Carolina',
    county:'Charleston County', historicalContext:'British colonial hub; major slave-trade port; Civil War Fort Sumter.',
    colonizer:'British Empire', nativeTribes:'Kiawah, Cherokee'),
  Place(continent:'Americas', name:'Detroit', modernCountry:'United States', iso3:'USA', state:'Michigan',
    county:'Wayne County', historicalContext:'French Fort Pontchartrain 1701; auto-industry capital; Underground Railroad hub.',
    colonizer:'French Empire, British Empire', nativeTribes:'Odawa, Potawatomi, Ojibwe'),
  Place(continent:'Americas', name:'St. Louis', modernCountry:'United States', iso3:'USA', state:'Missouri',
    county:'Independent City', historicalContext:'French trading post 1764; "Gateway to the West"; Lewis and Clark departure point.',
    colonizer:'French Empire, Spanish Empire', nativeTribes:'Osage, Mississippian Cahokia'),
  Place(continent:'Americas', name:'Seattle', modernCountry:'United States', iso3:'USA', state:'Washington',
    county:'King County', historicalContext:'Named for Chief Seattle (Suquamish); Klondike gold rush supply hub; tech capital.',
    colonizer:'British Empire, American settlement', nativeTribes:'Duwamish, Suquamish'),
  Place(continent:'Americas', name:'Miami', modernCountry:'United States', iso3:'USA', state:'Florida',
    county:'Miami-Dade County', historicalContext:'Spanish Florida; US territory 1821; Cuban diaspora capital post-1959.',
    colonizer:'Spanish Empire', nativeTribes:'Tequesta, Calusa'),
  Place(continent:'Americas', name:'Houston', modernCountry:'United States', iso3:'USA', state:'Texas',
    county:'Harris County', historicalContext:'Republic of Texas capital briefly; oil and gas hub; NASA Johnson Space Center.',
    colonizer:'Spanish Empire, Mexican Republic, Republic of Texas', nativeTribes:'Akokisa, Karankawa'),
  Place(continent:'Americas', name:'Honolulu', modernCountry:'United States', iso3:'USA', state:'Hawaii',
    county:'Honolulu County', historicalContext:'Kingdom of Hawaii capital; US annexation 1898; Pearl Harbor attack 1941.',
    colonizer:'British Empire (early contact), US annexation', nativeTribes:'Native Hawaiian (Kanaka Maoli)'),
  Place(continent:'Americas', name:'Juneau', modernCountry:'United States', iso3:'USA', state:'Alaska',
    county:'City and Borough of Juneau', historicalContext:'Alaska capital; gold rush town; Russian Alaska sold to US 1867.',
    colonizer:'Russian Empire, United States', nativeTribes:'Tlingit, Athabascan'),
  Place(continent:'Americas', name:'Salt Lake City', modernCountry:'United States', iso3:'USA', state:'Utah',
    county:'Salt Lake County', historicalContext:'Mormon pioneer settlement 1847; Brigham Young brought LDS Church here.',
    colonizer:'Mexican Republic, United States', nativeTribes:'Shoshone, Ute, Paiute'),
  Place(continent:'Americas', name:'Denver', modernCountry:'United States', iso3:'USA', state:'Colorado',
    county:'Denver County', historicalContext:'Pike\'s Peak gold rush 1858; "Mile High City"; railroad junction.',
    colonizer:'Spanish Empire, Mexican Republic', nativeTribes:'Arapaho, Cheyenne'),

  // ── Mexico ────────────────────────────────────────────────────────────────
  Place(continent:'Americas', name:'Mexico City', modernCountry:'Mexico', iso3:'MEX', state:'Mexico City',
    historicalContext:'Aztec Tenochtitlan capital; Spanish built atop it 1521; largest Spanish colonial city.',
    colonizer:'Spanish Empire', nativeTribes:'Mexica (Aztec)', romanizedNative:'Ciudad de México / Tenochtitlan'),
  Place(continent:'Americas', name:'Guadalajara', modernCountry:'Mexico', iso3:'MEX', state:'Jalisco',
    historicalContext:'Second city; colonial silver route; mariachi and tequila cultural origin.',
    colonizer:'Spanish Empire', nativeTribes:'Coca, Tecuexe'),
  Place(continent:'Americas', name:'Monterrey', modernCountry:'Mexico', iso3:'MEX', state:'Nuevo León',
    historicalContext:'Industrial capital of Mexico; near US border; Valle de Monterrey.',
    colonizer:'Spanish Empire', nativeTribes:'Coahuiltecan'),
  Place(continent:'Americas', name:'Oaxaca', modernCountry:'Mexico', iso3:'MEX', state:'Oaxaca',
    historicalContext:'Zapotec and Mixtec heritage; Monte Albán ancient capital nearby; colonial baroque city.',
    colonizer:'Spanish Empire', nativeTribes:'Zapotec, Mixtec'),
  Place(continent:'Americas', name:'Teotihuacan', modernCountry:'Mexico', iso3:'MEX', state:'Estado de México',
    historicalContext:'Pre-Columbian city; Pyramid of the Sun; dominated Mesoamerica c. 100–550 AD.',
    nativeTribes:'Teotihuacanos', validTo:'0550-01-01T00:00:00.000Z'),

  // ── Guatemala ─────────────────────────────────────────────────────────────
  Place(continent:'Americas', name:'Guatemala City', modernCountry:'Guatemala', iso3:'GTM', state:'Guatemala Department',
    historicalContext:'Capital; Spanish colonial; Maya K\'iche\' heritage; independence 1821.',
    colonizer:'Spanish Empire', nativeTribes:"Maya K'iche'"),
  Place(continent:'Americas', name:'Tikal', modernCountry:'Guatemala', iso3:'GTM', state:'Petén Department',
    historicalContext:'Largest ancient Maya city; peak c. 200–900 AD; UNESCO World Heritage.',
    nativeTribes:'Maya (Itzá)', validTo:'0900-01-01T00:00:00.000Z'),

  // ── Belize ────────────────────────────────────────────────────────────────
  Place(continent:'Americas', name:'Belmopan', modernCountry:'Belize', iso3:'BLZ', state:'Cayo District',
    historicalContext:'Capital since 1970 (built after Hurricane Hattie 1961); inland designed capital.',
    colonizer:'British Empire', nativeTribes:'Maya, Garifuna'),

  // ── El Salvador ───────────────────────────────────────────────────────────
  Place(continent:'Americas', name:'San Salvador', modernCountry:'El Salvador', iso3:'SLV', state:'San Salvador Department',
    historicalContext:'Capital; Spanish colonial; Central American independence 1821.',
    colonizer:'Spanish Empire', nativeTribes:'Pipil'),

  // ── Honduras ──────────────────────────────────────────────────────────────
  Place(continent:'Americas', name:'Tegucigalpa', modernCountry:'Honduras', iso3:'HND', state:'Francisco Morazán Department',
    historicalContext:'Capital; silver mining city; Spanish colonial.',
    colonizer:'Spanish Empire', nativeTribes:'Lenca'),

  // ── Nicaragua ─────────────────────────────────────────────────────────────
  Place(continent:'Americas', name:'Managua', modernCountry:'Nicaragua', iso3:'NIC', state:'Managua Department',
    historicalContext:'Capital since 1852; Spanish colonial; US Marines occupation 1912–1933.',
    colonizer:'Spanish Empire', nativeTribes:'Nicarao'),

  // ── Costa Rica ────────────────────────────────────────────────────────────
  Place(continent:'Americas', name:'San José', modernCountry:'Costa Rica', iso3:'CRI', state:'San José Province',
    historicalContext:'Capital; Spanish colonial; coffee republic; stable democracy.',
    colonizer:'Spanish Empire', nativeTribes:'Huetar'),

  // ── Panama ────────────────────────────────────────────────────────────────
  Place(continent:'Americas', name:'Panama City', modernCountry:'Panama', iso3:'PAN', state:'Panama Province',
    historicalContext:'Oldest continuously inhabited European city on Pacific coast (1519); Panama Canal hub.',
    colonizer:'Spanish Empire', nativeTribes:'Cueva, Kuna'),

  // ── Cuba ──────────────────────────────────────────────────────────────────
  Place(continent:'Americas', name:'Havana', modernCountry:'Cuba', iso3:'CUB', state:'La Habana Province',
    historicalContext:'Spanish colonial capital; 1959 Revolution; Soviet Cold War proxy.',
    colonizer:'Spanish Empire', nativeTribes:'Taíno', romanizedNative:'La Habana'),
  Place(continent:'Americas', name:'Santiago de Cuba', modernCountry:'Cuba', iso3:'CUB', state:'Santiago de Cuba Province',
    historicalContext:'First colonial capital; African cultural hub; slave trade history.',
    colonizer:'Spanish Empire', nativeTribes:'Taíno'),

  // ── Dominican Republic ────────────────────────────────────────────────────
  Place(continent:'Americas', name:'Santo Domingo', modernCountry:'Dominican Republic', iso3:'DOM', state:'Distrito Nacional',
    historicalContext:'Oldest continuously inhabited European city in Americas (1496); first Spanish colonial capital.',
    colonizer:'Spanish Empire', nativeTribes:'Taíno', romanizedNative:'La Nueva Isabella'),

  // ── Haiti ─────────────────────────────────────────────────────────────────
  Place(continent:'Americas', name:'Port-au-Prince', modernCountry:'Haiti', iso3:'HTI', state:'Ouest Department',
    historicalContext:'Capital; French Saint-Domingue slave colony; Haitian Revolution 1791–1804 (first Black republic).',
    colonizer:'French Empire', nativeTribes:'Taíno', romanizedNative:'Port-au-Prince'),

  // ── Jamaica ───────────────────────────────────────────────────────────────
  Place(continent:'Americas', name:'Kingston', modernCountry:'Jamaica', iso3:'JAM', state:'Kingston Parish',
    historicalContext:'Capital; British plantation colony; sugar and slave trade; Port Royal pirate hub nearby.',
    colonizer:'Spanish Empire, British Empire', nativeTribes:'Taíno'),

  // ── Trinidad and Tobago ────────────────────────────────────────────────────
  Place(continent:'Americas', name:'Port of Spain', modernCountry:'Trinidad and Tobago', iso3:'TTO', state:'Port of Spain',
    historicalContext:'Capital; Spanish then British colony; East Indian indenture workers post-slavery.',
    colonizer:'Spanish Empire, British Empire', nativeTribes:'Arawak, Carib'),

  // ── Barbados ──────────────────────────────────────────────────────────────
  Place(continent:'Americas', name:'Bridgetown', modernCountry:'Barbados', iso3:'BRB', state:'Saint Michael Parish',
    historicalContext:'Capital; British sugar colony; first English colony to cultivate sugar with enslaved Africans.',
    colonizer:'British Empire', nativeTribes:'Arawak, Kalinago'),

  // ══════════════════════════════════════════════════════════════════════════
  // SOUTH AMERICA
  // ══════════════════════════════════════════════════════════════════════════

  // ── Argentina ─────────────────────────────────────────────────────────────
  Place(continent:'Americas', name:'Buenos Aires', modernCountry:'Argentina', iso3:'ARG', state:'Autonomous City of Buenos Aires',
    historicalContext:'Capital; Spanish colonial Viceroyalty of the Río de la Plata; European immigrant hub.',
    colonizer:'Spanish Empire', nativeTribes:'Querandí', romanizedNative:'Ciudad de la Santísima Trinidad y Puerto de Santa María del Buen Ayre'),
  Place(continent:'Americas', name:'Córdoba', modernCountry:'Argentina', iso3:'ARG', state:'Córdoba Province',
    historicalContext:'Second city; Jesuit missions heritage; university city (1621, second oldest in Americas).',
    colonizer:'Spanish Empire', nativeTribes:'Comechingones, Sanavirón'),
  Place(continent:'Americas', name:'Mendoza', modernCountry:'Argentina', iso3:'ARG', state:'Mendoza Province',
    historicalContext:'Andean wine region; San Martín crossed Andes to liberate Chile and Peru from here.',
    colonizer:'Spanish Empire', nativeTribes:'Huarpe'),

  // ── Bolivia ───────────────────────────────────────────────────────────────
  Place(continent:'Americas', name:'Sucre', modernCountry:'Bolivia', iso3:'BOL', state:'Chuquisaca Department',
    historicalContext:'Constitutional capital; Spanish colonial silver city; Declaration of Independence signed 1825.',
    colonizer:'Spanish Empire', nativeTribes:'Charcas'),
  Place(continent:'Americas', name:'La Paz', modernCountry:'Bolivia', iso3:'BOL', state:'La Paz Department',
    historicalContext:'Seat of government; world\'s highest capital city; Aymara cultural centre.',
    colonizer:'Spanish Empire', nativeTribes:'Aymara'),
  Place(continent:'Americas', name:'Potosí', modernCountry:'Bolivia', iso3:'BOL', state:'Potosí Department',
    historicalContext:'Spanish colonial silver mine; Cerro Rico funded the entire Spanish Empire; UNESCO.',
    colonizer:'Spanish Empire', nativeTribes:'Quechua, Aymara'),

  // ── Brazil ────────────────────────────────────────────────────────────────
  Place(continent:'Americas', name:'Brasília', modernCountry:'Brazil', iso3:'BRA', state:'Federal District',
    historicalContext:'Modernist capital built 1956–1960; designed by Niemeyer and Costa; moved from Rio de Janeiro.',
    colonizer:'Portuguese Empire', nativeTribes:'Various Cerrado peoples'),
  Place(continent:'Americas', name:'São Paulo', modernCountry:'Brazil', iso3:'BRA', state:'São Paulo',
    county:'São Paulo Municipality', historicalContext:'Jesuit mission 1554; largest Brazilian city; industrial and financial hub.',
    colonizer:'Portuguese Empire', nativeTribes:'Guaianá, Tupiniquim', romanizedNative:'São Paulo de Piratininga'),
  Place(continent:'Americas', name:'Rio de Janeiro', modernCountry:'Brazil', iso3:'BRA', state:'Rio de Janeiro',
    county:'Rio de Janeiro Municipality', historicalContext:'Portuguese colonial capital; Brazilian Empire capital; Carnival and Samba.',
    colonizer:'Portuguese Empire', nativeTribes:'Tamoio, Tupinambá', romanizedNative:'São Sebastião do Rio de Janeiro'),
  Place(continent:'Americas', name:'Salvador', modernCountry:'Brazil', iso3:'BRA', state:'Bahia',
    historicalContext:'First capital of colonial Brazil; largest African diaspora city outside Africa.',
    colonizer:'Portuguese Empire', nativeTribes:'Tupinambá', romanizedNative:'São Salvador da Bahia de Todos os Santos'),
  Place(continent:'Americas', name:'Manaus', modernCountry:'Brazil', iso3:'BRA', state:'Amazonas',
    historicalContext:'Amazon river hub; rubber boom late 19th century; Ópera do Amazonas.',
    colonizer:'Portuguese Empire', nativeTribes:'Manaó'),
  Place(continent:'Americas', name:'Recife', modernCountry:'Brazil', iso3:'BRA', state:'Pernambuco',
    historicalContext:'Dutch Brazil capital (Mauritsstad 1630–1654) then Portuguese; "Venice of Brazil".',
    colonizer:'Portuguese Empire, Dutch Republic', nativeTribes:'Caetés'),

  // ── Chile ─────────────────────────────────────────────────────────────────
  Place(continent:'Americas', name:'Santiago', modernCountry:'Chile', iso3:'CHL', state:'Santiago Metropolitan Region',
    county:'Santiago Province', historicalContext:'Capital; founded by Pedro de Valdivia 1541; Inca borderland.',
    colonizer:'Spanish Empire', nativeTribes:'Mapuche, Picunche'),
  Place(continent:'Americas', name:'Valparaíso', modernCountry:'Chile', iso3:'CHL', state:'Valparaíso Region',
    historicalContext:'Chief Pacific port; Cape Horn trade route hub before Panama Canal; UNESCO.',
    colonizer:'Spanish Empire', nativeTribes:'Chango'),

  // ── Colombia ──────────────────────────────────────────────────────────────
  Place(continent:'Americas', name:'Bogotá', modernCountry:'Colombia', iso3:'COL', state:'Bogotá Capital District',
    historicalContext:'Capital; Spanish colonial Nuevo Reino de Granada; Muisca civilisation.',
    colonizer:'Spanish Empire', nativeTribes:'Muisca (Chibcha)', romanizedNative:'Santa Fe de Bogotá'),
  Place(continent:'Americas', name:'Cartagena', modernCountry:'Colombia', iso3:'COL', state:'Bolívar Department',
    historicalContext:'Fortified port; largest slave-trade port in Spanish Americas; UNESCO.',
    colonizer:'Spanish Empire', nativeTribes:'Calamarí (Zenú)'),
  Place(continent:'Americas', name:'Medellín', modernCountry:'Colombia', iso3:'COL', state:'Antioquia Department',
    historicalContext:'Coffee region; 1980s drug cartel hub; remarkable urban transformation.',
    colonizer:'Spanish Empire', nativeTribes:'Nutabe, Tahamí'),

  // ── Ecuador ───────────────────────────────────────────────────────────────
  Place(continent:'Americas', name:'Quito', modernCountry:'Ecuador', iso3:'ECU', state:'Pichincha Province',
    historicalContext:'Capital; Incan city; Spanish colonial; highest official capital in world.',
    colonizer:'Inca Empire, Spanish Empire', nativeTribes:'Quitu-Cara, Quechua'),
  Place(continent:'Americas', name:'Guayaquil', modernCountry:'Ecuador', iso3:'ECU', state:'Guayas Province',
    historicalContext:'Largest city and main port; Spanish colonial; banana and cacao export hub.',
    colonizer:'Spanish Empire', nativeTribes:'Huancavilca'),

  // ── Guyana ────────────────────────────────────────────────────────────────
  Place(continent:'Americas', name:'Georgetown', modernCountry:'Guyana', iso3:'GUY', state:'Demerara-Mahaica Region',
    historicalContext:'Capital; Dutch then British Demerara colony; sugar plantations and indentured labour.',
    colonizer:'Dutch Republic, British Empire', nativeTribes:'Arawak, Carib'),

  // ── Paraguay ──────────────────────────────────────────────────────────────
  Place(continent:'Americas', name:'Asunción', modernCountry:'Paraguay', iso3:'PRY', state:'Asunción Capital District',
    historicalContext:'Capital; founded 1537; Guaraní cultural stronghold; catastrophic War of Triple Alliance 1864.',
    colonizer:'Spanish Empire', nativeTribes:'Guaraní'),

  // ── Peru ──────────────────────────────────────────────────────────────────
  Place(continent:'Americas', name:'Lima', modernCountry:'Peru', iso3:'PER', state:'Lima Region',
    county:'Lima Province', historicalContext:'Capital; City of Kings (Ciudad de los Reyes); seat of Viceroyalty of Peru.',
    colonizer:'Spanish Empire', nativeTribes:'Ichma, Lima culture'),
  Place(continent:'Americas', name:'Cusco', modernCountry:'Peru', iso3:'PER', state:'Cusco Region',
    historicalContext:'Inca Empire capital; sacred navel of the world; Pizarro conquered 1533.',
    colonizer:'Spanish Empire', nativeTribes:'Inca (Quechua)', romanizedNative:'Qusqu'),
  Place(continent:'Americas', name:'Machu Picchu', modernCountry:'Peru', iso3:'PER', state:'Cusco Region',
    historicalContext:'Inca citadel c.1450; abandoned after Spanish conquest; rediscovered by Bingham 1911.',
    nativeTribes:'Inca (Quechua)'),

  // ── Suriname ──────────────────────────────────────────────────────────────
  Place(continent:'Americas', name:'Paramaribo', modernCountry:'Suriname', iso3:'SUR', state:'Paramaribo District',
    historicalContext:'Capital; Dutch colony; British for a time; UNESCO historic inner city.',
    colonizer:'Dutch Republic, British Empire', nativeTribes:'Arawak, Carib'),

  // ── Uruguay ───────────────────────────────────────────────────────────────
  Place(continent:'Americas', name:'Montevideo', modernCountry:'Uruguay', iso3:'URY', state:'Montevideo Department',
    historicalContext:'Capital; Spanish then Portuguese contested; independence 1828; "Switzerland of South America".',
    colonizer:'Spanish Empire, Portuguese Empire', nativeTribes:'Charrúa'),

  // ── Venezuela ─────────────────────────────────────────────────────────────
  Place(continent:'Americas', name:'Caracas', modernCountry:'Venezuela', iso3:'VEN', state:'Capital District',
    historicalContext:'Capital; Simón Bolívar\'s birthplace; Spanish colonial; oil economy 20th century.',
    colonizer:'Spanish Empire', nativeTribes:'Caracas (Teques)'),
];
