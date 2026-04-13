import '../models/place.dart';

/// Africa: organised continent → country → state/region → county → city
const List<Place> placesAfrica = [

  // ── Algeria ──────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Algiers', modernCountry:'Algeria', iso3:'DZA', state:'Algiers Province',
    historicalContext:'Capital; Ottoman regency 1516–1830; French colonial capital until 1962.',
    colonizer:'Ottoman Empire, French Empire', nativeTribes:'Berbers (Amazigh)', romanizedNative:'Al-Jazāʾir'),
  Place(continent:'Africa', name:'Oran', modernCountry:'Algeria', iso3:'DZA', state:'Oran Province',
    historicalContext:'Major port; Spanish-held 1509–1708 and 1732–1791; large pied-noir community.',
    colonizer:'Spanish Crown, Ottoman Empire, French Empire', nativeTribes:'Berbers'),

  // ── Angola ───────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Luanda', modernCountry:'Angola', iso3:'AGO', state:'Luanda Province',
    historicalContext:'Capital; major Portuguese slave-trade port from 1575; independence 1975.',
    colonizer:'Portuguese Empire', nativeTribes:'Mbundu', romanizedNative:'São Paulo de Loanda'),

  // ── Benin ─────────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Porto-Novo', modernCountry:'Benin', iso3:'BEN', state:'Ouémé Department',
    historicalContext:'Official capital; Portuguese slave-trade port; Kingdom of Dahomey region.',
    colonizer:'Portuguese Empire, French Empire', nativeTribes:'Fon, Yoruba'),
  Place(continent:'Africa', name:'Cotonou', modernCountry:'Benin', iso3:'BEN', state:'Littoral Department',
    historicalContext:'Largest city and economic capital; major port on Bight of Benin.',
    colonizer:'French Empire', nativeTribes:'Fon, Mina'),

  // ── Botswana ──────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Gaborone', modernCountry:'Botswana', iso3:'BWA', state:'South-East District',
    historicalContext:'Capital since independence 1966; formerly Bechuanaland Protectorate under Britain.',
    colonizer:'British Empire', nativeTribes:'Tswana'),

  // ── Burkina Faso ─────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Ouagadougou', modernCountry:'Burkina Faso', iso3:'BFA', state:'Centre Region',
    historicalContext:'Capital; Mossi Kingdom seat; French Upper Volta until independence 1960.',
    colonizer:'French Empire', nativeTribes:'Mossi', romanizedNative:'Wogodogo'),

  // ── Burundi ───────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Gitega', modernCountry:'Burundi', iso3:'BDI', state:'Gitega Province',
    historicalContext:'Current capital (since 2019); former royal capital of the Kingdom of Burundi.',
    colonizer:'German East Africa, Belgian Congo', nativeTribes:'Hutu, Tutsi, Twa'),
  Place(continent:'Africa', name:'Bujumbura', modernCountry:'Burundi', iso3:'BDI', state:'Bujumbura Mairie',
    historicalContext:'Former capital and largest city; German colonial outpost on Lake Tanganyika.',
    colonizer:'German East Africa, Belgian administration', nativeTribes:'Hutu, Tutsi'),

  // ── Cabo Verde ───────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Praia', modernCountry:'Cabo Verde', iso3:'CPV', state:'Santiago Island',
    historicalContext:'Capital; Portuguese settlement from 1462; major Atlantic slave-trade junction.',
    colonizer:'Portuguese Empire', nativeTribes:'No indigenous population (uninhabited at settlement)'),

  // ── Cameroon ─────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Yaoundé', modernCountry:'Cameroon', iso3:'CMR', state:'Centre Region',
    historicalContext:'Capital; German Kamerun colony then French/British mandate.',
    colonizer:'German Empire, French Empire', nativeTribes:'Ewondo, Beti'),
  Place(continent:'Africa', name:'Douala', modernCountry:'Cameroon', iso3:'CMR', state:'Littoral Region',
    historicalContext:'Largest city and economic capital; major port under German and French rule.',
    colonizer:'German Empire, French Empire', nativeTribes:'Duala'),

  // ── Central African Republic ─────────────────────────────────────────────
  Place(continent:'Africa', name:'Bangui', modernCountry:'Central African Republic', iso3:'CAF', state:'Ombella-M\'Poko Prefecture',
    historicalContext:'Capital on Ubangi River; French Ubangi-Shari territory until independence 1960.',
    colonizer:'French Empire', nativeTribes:'Banda, Gbaya, Mandjia'),

  // ── Chad ──────────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:"N'Djamena", modernCountry:'Chad', iso3:'TCD', state:'N\'Djamena Region',
    historicalContext:'Capital; French Fort-Lamy until independence 1960.',
    colonizer:'French Empire', nativeTribes:'Sara, Arabs', romanizedNative:'Fort-Lamy'),

  // ── Comoros ───────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Moroni', modernCountry:'Comoros', iso3:'COM', state:'Grande Comore',
    historicalContext:'Capital; Arab sultanates then French protectorate until independence 1975.',
    colonizer:'Arab sultanates, French Empire', nativeTribes:'Comorians (Bantu-Arab)'),

  // ── Democratic Republic of the Congo ─────────────────────────────────────
  Place(continent:'Africa', name:'Kinshasa', modernCountry:'DR Congo', iso3:'COD', state:'Kinshasa Province',
    historicalContext:'Capital; Belgian Congo\'s Léopoldville; site of brutal colonial rubber trade abuses.',
    colonizer:'Belgian Congo (Leopold II)', nativeTribes:'Teke, Humbu', romanizedNative:'Léopoldville'),
  Place(continent:'Africa', name:'Lubumbashi', modernCountry:'DR Congo', iso3:'COD', state:'Haut-Katanga Province',
    historicalContext:'Mining city; copper belt capital; formerly Élisabethville under Belgian rule.',
    colonizer:'Belgian Congo', nativeTribes:'Luba', romanizedNative:'Élisabethville'),

  // ── Republic of the Congo ────────────────────────────────────────────────
  Place(continent:'Africa', name:'Brazzaville', modernCountry:'Republic of the Congo', iso3:'COG', state:'Brazzaville Department',
    historicalContext:'Capital; French Congo territory; across the river from Kinshasa.',
    colonizer:'French Empire', nativeTribes:'Kongo, Teke', romanizedNative:'Brazzaville'),

  // ── Côte d\'Ivoire ───────────────────────────────────────────────────────
  Place(continent:'Africa', name:"Yamoussoukro", modernCountry:"Côte d'Ivoire", iso3:'CIV', state:'Yamoussoukro Autonomous District',
    historicalContext:"Official capital; birthplace of Félix Houphouët-Boigny; French Ivory Coast colony.",
    colonizer:'French Empire', nativeTribes:"Baoulé"),
  Place(continent:'Africa', name:'Abidjan', modernCountry:"Côte d'Ivoire", iso3:'CIV', state:'Lagunes District',
    historicalContext:'Economic capital and largest city; major West African port.',
    colonizer:'French Empire', nativeTribes:'Dida, Adjoukrou'),

  // ── Djibouti ──────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Djibouti', modernCountry:'Djibouti', iso3:'DJI', state:'Djibouti Region',
    historicalContext:'Strategic Red Sea port; French Somaliland then Territory of Afars and Issas.',
    colonizer:'French Empire', nativeTribes:'Afar, Somali Issa'),

  // ── Egypt ─────────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Cairo', modernCountry:'Egypt', iso3:'EGY', state:'Cairo Governorate',
    historicalContext:'Near ancient Memphis; Fatimid capital 969 AD; Ottoman then British occupation.',
    colonizer:'Ottoman Empire, British Empire', nativeTribes:'Ancient Egyptians', romanizedNative:'Al-Qāhira'),
  Place(continent:'Africa', name:'Alexandria', modernCountry:'Egypt', iso3:'EGY', state:'Alexandria Governorate',
    historicalContext:'Founded by Alexander the Great 331 BC; site of ancient Library; major Greek diaspora.',
    colonizer:'Macedonian, Roman Empire, Ottoman Empire', nativeTribes:'Ancient Egyptians', romanizedNative:'Al-Iskandariyya'),
  Place(continent:'Africa', name:'Luxor', modernCountry:'Egypt', iso3:'EGY', state:'Luxor Governorate',
    historicalContext:'Ancient Thebes; capital of Egypt during the New Kingdom; major temple complexes.',
    colonizer:'Roman Empire, Arab Conquest', nativeTribes:'Ancient Egyptians', romanizedNative:'Waset / Thebes'),

  // ── Equatorial Guinea ────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Malabo', modernCountry:'Equatorial Guinea', iso3:'GNQ', state:'Bioko Norte Province',
    historicalContext:'Capital on Bioko Island; Spanish colony until independence 1968.',
    colonizer:'Spanish Empire', nativeTribes:'Bubi', romanizedNative:'Santa Isabel'),

  // ── Eritrea ───────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Asmara', modernCountry:'Eritrea', iso3:'ERI', state:'Maekel Region',
    historicalContext:'Capital; Italian colonial showpiece city; under Ethiopia until independence 1993.',
    colonizer:'Italian Empire, British administration, Ethiopia', nativeTribes:'Tigrinya', romanizedNative:'Asmera'),

  // ── Eswatini ─────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Mbabane', modernCountry:'Eswatini', iso3:'SWZ', state:'Hhohho Region',
    historicalContext:'Administrative capital; British Swaziland protectorate until 1968.',
    colonizer:'British Empire', nativeTribes:'Swazi'),

  // ── Ethiopia ──────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Addis Ababa', modernCountry:'Ethiopia', iso3:'ETH', state:'Addis Ababa City Administration',
    historicalContext:'Founded 1886 by Emperor Menelik II; African Union headquarters; never colonised.',
    nativeTribes:'Oromo, Amhara', romanizedNative:'Addis Abeba'),

  // ── Gabon ─────────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Libreville', modernCountry:'Gabon', iso3:'GAB', state:'Estuaire Province',
    historicalContext:'Capital; French Gabon colony; named for freed slaves settled there.',
    colonizer:'French Empire', nativeTribes:'Mpongwe, Fang'),

  // ── Gambia ────────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Banjul', modernCountry:'Gambia', iso3:'GMB', state:'Banjul Local Government Area',
    historicalContext:'Capital; British Bathurst; smallest African capital.',
    colonizer:'British Empire', nativeTribes:'Mandinka, Wolof', romanizedNative:'Bathurst'),

  // ── Ghana ─────────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Accra', modernCountry:'Ghana', iso3:'GHA', state:'Greater Accra Region',
    historicalContext:'Capital; British Gold Coast colony; Kwame Nkrumah declared independence here 1957.',
    colonizer:'Danish Empire, British Empire', nativeTribes:'Ga', romanizedNative:'Accra'),
  Place(continent:'Africa', name:'Kumasi', modernCountry:'Ghana', iso3:'GHA', state:'Ashanti Region',
    historicalContext:'Capital of the Ashanti Empire; major gold and slave trade centre historically.',
    nativeTribes:'Ashanti (Akan)'),

  // ── Guinea ────────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Conakry', modernCountry:'Guinea', iso3:'GIN', state:'Conakry Region',
    historicalContext:'Capital; French Guinea colony until independence 1958.',
    colonizer:'French Empire', nativeTribes:'Fula, Mandinka, Susu'),

  // ── Guinea-Bissau ─────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Bissau', modernCountry:'Guinea-Bissau', iso3:'GNB', state:'Bissau Autonomous Sector',
    historicalContext:'Capital; Portuguese slave-trade fort; independence 1974.',
    colonizer:'Portuguese Empire', nativeTribes:'Balanta, Fula, Mandinka'),

  // ── Kenya ─────────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Nairobi', modernCountry:'Kenya', iso3:'KEN', state:'Nairobi County',
    historicalContext:'Capital; founded 1899 as British East Africa railway depot.',
    colonizer:'British Empire', nativeTribes:'Maasai, Kikuyu'),
  Place(continent:'Africa', name:'Mombasa', modernCountry:'Kenya', iso3:'KEN', state:'Mombasa County',
    historicalContext:'Ancient Swahili port; Arab and Portuguese then British control.',
    colonizer:'Arab sultans, Portuguese Empire, British Empire', nativeTribes:'Mijikenda, Swahili'),

  // ── Lesotho ───────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Maseru', modernCountry:'Lesotho', iso3:'LSO', state:'Maseru District',
    historicalContext:'Capital; Basutoland British protectorate until independence 1966.',
    colonizer:'British Empire', nativeTribes:'Basotho (Sotho)'),

  // ── Liberia ───────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Monrovia', modernCountry:'Liberia', iso3:'LBR', state:'Montserrado County',
    historicalContext:'Founded 1822 for freed American slaves; named for US President Monroe.',
    colonizer:'American Colonization Society', nativeTribes:'Kpelle, Bassa, Grebo'),

  // ── Libya ─────────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Tripoli', modernCountry:'Libya', iso3:'LBY', state:'Tripoli District',
    historicalContext:'Capital; Phoenician then Roman then Ottoman port; Italian colony 1911–1943.',
    colonizer:'Ottoman Empire, Italian Empire', nativeTribes:'Berbers, Arabs', romanizedNative:'Oea / Tarabulus'),

  // ── Madagascar ────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Antananarivo', modernCountry:'Madagascar', iso3:'MDG', state:'Analamanga Region',
    historicalContext:'Capital of Merina Kingdom; French colony until independence 1960.',
    colonizer:'French Empire', nativeTribes:'Merina (Austronesian-African)', romanizedNative:'Tananarive'),

  // ── Malawi ────────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Lilongwe', modernCountry:'Malawi', iso3:'MWI', state:'Lilongwe District',
    historicalContext:'Capital since 1975; British Nyasaland protectorate until 1964.',
    colonizer:'British Empire', nativeTribes:'Chewa, Tumbuka'),

  // ── Mali ──────────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Bamako', modernCountry:'Mali', iso3:'MLI', state:'Bamako Capital District',
    historicalContext:'Capital; French Soudan colony; Mali Empire historical region.',
    colonizer:'French Empire', nativeTribes:'Bambara, Fula', romanizedNative:'Bamako'),
  Place(continent:'Africa', name:'Timbuktu', modernCountry:'Mali', iso3:'MLI', state:'Timbuktu Region',
    historicalContext:'Medieval centre of Islamic scholarship and trans-Saharan gold trade.',
    colonizer:'Songhai Empire, Moroccan Saadian dynasty, French Empire', nativeTribes:'Tuareg, Songhai', romanizedNative:'Tombouctou'),

  // ── Mauritania ────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Nouakchott', modernCountry:'Mauritania', iso3:'MRT', state:'Nouakchott-Ouest Region',
    historicalContext:'Capital; built after independence 1960; French West Africa territory.',
    colonizer:'French Empire', nativeTribes:'Moors (Berber-Arab), Black Africans'),

  // ── Mauritius ─────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Port Louis', modernCountry:'Mauritius', iso3:'MUS', state:'Port Louis District',
    historicalContext:'Capital; Dutch then French (Île de France) then British colony; sugar trade hub.',
    colonizer:'Dutch, French Empire, British Empire', nativeTribes:'No indigenous population'),

  // ── Morocco ───────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Rabat', modernCountry:'Morocco', iso3:'MAR', state:'Rabat-Salé-Kénitra Region',
    historicalContext:'Capital under French Protectorate (1912–1956).',
    colonizer:'Arab Conquest, French Empire', nativeTribes:'Berbers (Amazigh)', romanizedNative:'Ribat al-Fath'),
  Place(continent:'Africa', name:'Casablanca', modernCountry:'Morocco', iso3:'MAR', state:'Casablanca-Settat Region',
    historicalContext:'Largest city; major commercial port; Casa Blanca means "White House".',
    colonizer:'Portuguese Empire, French Empire', nativeTribes:'Berbers', romanizedNative:'Anfa'),
  Place(continent:'Africa', name:'Fez', modernCountry:'Morocco', iso3:'MAR', state:'Fès-Meknès Region',
    historicalContext:'Medieval capital; world\'s oldest university (University of Al Qarawiyyin, 859 AD).',
    colonizer:'Arab Conquest, French Protectorate', nativeTribes:'Berbers', romanizedNative:'Fès'),

  // ── Mozambique ────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Maputo', modernCountry:'Mozambique', iso3:'MOZ', state:'Maputo City Province',
    historicalContext:'Capital; Portuguese Lourenço Marques; independence 1975.',
    colonizer:'Portuguese Empire', nativeTribes:'Tsonga', romanizedNative:'Lourenço Marques'),

  // ── Namibia ───────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Windhoek', modernCountry:'Namibia', iso3:'NAM', state:'Khomas Region',
    historicalContext:'Capital; German South West Africa; South African administration until 1990.',
    colonizer:'German Empire, South Africa', nativeTribes:'Herero, Nama, San', romanizedNative:'Windhuk'),

  // ── Niger ─────────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Niamey', modernCountry:'Niger', iso3:'NER', state:'Niamey Urban Community',
    historicalContext:'Capital; French Niger colony; dryland Sahel region.',
    colonizer:'French Empire', nativeTribes:'Hausa, Zarma-Songhai, Tuareg'),

  // ── Nigeria ───────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Abuja', modernCountry:'Nigeria', iso3:'NGA', state:'Federal Capital Territory',
    historicalContext:'Capital since 1991; purpose-built to replace Lagos as neutral federal capital.',
    nativeTribes:'Gbagyi'),
  Place(continent:'Africa', name:'Lagos', modernCountry:'Nigeria', iso3:'NGA', state:'Lagos State',
    historicalContext:'Former capital; major West African port; Yoruba cultural centre; slave-trade history.',
    colonizer:'Portuguese Empire, British Empire', nativeTribes:'Awori Yoruba', romanizedNative:'Eko'),
  Place(continent:'Africa', name:'Kano', modernCountry:'Nigeria', iso3:'NGA', state:'Kano State',
    historicalContext:'Ancient Hausa emirate; trans-Saharan trade city; major textile production.',
    colonizer:'Fulani Empire, British Empire', nativeTribes:'Hausa-Fulani'),
  Place(continent:'Africa', name:'Ibadan', modernCountry:'Nigeria', iso3:'NGA', state:'Oyo State',
    historicalContext:'Largest city by area in sub-Saharan Africa; former Yoruba war camp turned city.',
    colonizer:'British Empire', nativeTribes:'Yoruba'),

  // ── Rwanda ────────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Kigali', modernCountry:'Rwanda', iso3:'RWA', state:'Kigali City',
    historicalContext:'Capital; German then Belgian Rwanda-Urundi territory; 1994 genocide site.',
    colonizer:'German East Africa, Belgian administration', nativeTribes:'Hutu, Tutsi, Twa'),

  // ── São Tomé and Príncipe ────────────────────────────────────────────────
  Place(continent:'Africa', name:'São Tomé', modernCountry:'São Tomé and Príncipe', iso3:'STP', state:'Água Grande District',
    historicalContext:'Capital; Portuguese colony from 1470; key Atlantic slave-trade island.',
    colonizer:'Portuguese Empire', nativeTribes:'No indigenous population'),

  // ── Senegal ───────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Dakar', modernCountry:'Senegal', iso3:'SEN', state:'Dakar Region',
    historicalContext:'Capital; French West Africa administrative capital; Gorée Island slave trade.',
    colonizer:'French Empire', nativeTribes:'Wolof, Lebou'),
  Place(continent:'Africa', name:'Saint-Louis', modernCountry:'Senegal', iso3:'SEN', state:'Saint-Louis Region',
    historicalContext:'First French settlement in sub-Saharan Africa (1659); former colonial capital.',
    colonizer:'French Empire', nativeTribes:'Wolof, Moorish'),

  // ── Seychelles ────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Victoria', modernCountry:'Seychelles', iso3:'SYC', state:'English River',
    historicalContext:'Capital; French then British colony; smallest African capital.',
    colonizer:'French Empire, British Empire', nativeTribes:'No indigenous population'),

  // ── Sierra Leone ──────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Freetown', modernCountry:'Sierra Leone', iso3:'SLE', state:'Western Area',
    historicalContext:'Founded 1787 for freed slaves from Britain and Nova Scotia.',
    colonizer:'British Empire', nativeTribes:'Temne, Mende'),

  // ── Somalia ───────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Mogadishu', modernCountry:'Somalia', iso3:'SOM', state:'Banadir Region',
    historicalContext:'Ancient Arab trading port; Italian Somaliland then British territory.',
    colonizer:'Arab sultanates, Italian Empire, British Empire', nativeTribes:'Somali', romanizedNative:'Muqdisho'),

  // ── South Africa ──────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Pretoria', modernCountry:'South Africa', iso3:'ZAF', state:'Gauteng',
    historicalContext:'Administrative capital; Boer Transvaal Republic capital; apartheid-era government seat.',
    colonizer:'British Empire (annexed Transvaal)', nativeTribes:'Ndebele, Tswana'),
  Place(continent:'Africa', name:'Cape Town', modernCountry:'South Africa', iso3:'ZAF', state:'Western Cape',
    historicalContext:'Legislative capital; Dutch VOC refreshment station 1652; Cape Colony under Britain.',
    colonizer:'Dutch East India Company (VOC), British Empire', nativeTribes:'Khoikhoi (Hottentot), San'),
  Place(continent:'Africa', name:'Johannesburg', modernCountry:'South Africa', iso3:'ZAF', state:'Gauteng',
    historicalContext:'Founded during 1886 gold rush; shaped by apartheid; largest South African city.',
    colonizer:'Boer Republic, British Empire', nativeTribes:'Sotho-Tswana', romanizedNative:'eGoli'),
  Place(continent:'Africa', name:'Durban', modernCountry:'South Africa', iso3:'ZAF', state:'KwaZulu-Natal',
    historicalContext:'British Natal colony; major Indian immigrant population from 1860.',
    colonizer:'British Empire', nativeTribes:'Zulu'),

  // ── South Sudan ───────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Juba', modernCountry:'South Sudan', iso3:'SSD', state:'Central Equatoria State',
    historicalContext:'Capital; youngest nation (2011); formerly Anglo-Egyptian Sudan.',
    colonizer:'Anglo-Egyptian Condominium', nativeTribes:'Bari'),

  // ── Sudan ─────────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Khartoum', modernCountry:'Sudan', iso3:'SDN', state:'Khartoum State',
    historicalContext:'Capital; confluence of Blue and White Nile; Anglo-Egyptian rule until 1956.',
    colonizer:'Ottoman Empire, British Empire', nativeTribes:'Sudanese Arabs, Nubians'),

  // ── Tanzania ──────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Dodoma', modernCountry:'Tanzania', iso3:'TZA', state:'Dodoma Region',
    historicalContext:'Capital since 1996; inland government seat replacing Dar es Salaam.',
    colonizer:'German East Africa, British administration', nativeTribes:'Gogo'),
  Place(continent:'Africa', name:'Dar es Salaam', modernCountry:'Tanzania', iso3:'TZA', state:'Dar es Salaam Region',
    historicalContext:'Former capital and largest city; Swahili trading port; German colonial headquarters.',
    colonizer:'Arab Sultanate of Zanzibar, German East Africa, British administration', nativeTribes:'Zaramo'),
  Place(continent:'Africa', name:'Zanzibar', modernCountry:'Tanzania', iso3:'TZA', state:'Zanzibar',
    historicalContext:'Omani Arab sultanate; major Indian Ocean slave-trade hub; British protectorate 1890.',
    colonizer:'Omani Sultanate, British Empire', nativeTribes:'Swahili, Shirazi'),

  // ── Togo ──────────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Lomé', modernCountry:'Togo', iso3:'TGO', state:'Maritime Region',
    historicalContext:'Capital; German Togoland then French/British mandate.',
    colonizer:'German Empire, French Empire', nativeTribes:'Ewe'),

  // ── Tunisia ───────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Tunis', modernCountry:'Tunisia', iso3:'TUN', state:'Tunis Governorate',
    historicalContext:'Near ancient Carthage; Ottoman regency then French Protectorate 1881–1956.',
    colonizer:'Ottoman Empire, French Empire', nativeTribes:'Berbers', romanizedNative:'Tunis'),
  Place(continent:'Africa', name:'Carthage', modernCountry:'Tunisia', iso3:'TUN', state:'Tunis Governorate',
    historicalContext:'Ancient Phoenician city-state; Rome\'s great rival, destroyed 146 BC.',
    colonizer:'Roman Empire', nativeTribes:'Berbers', romanizedNative:'Qart-ḥadašt',
    validTo:'-0146-01-01T00:00:00.000Z'),

  // ── Uganda ────────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Kampala', modernCountry:'Uganda', iso3:'UGA', state:'Central Region',
    historicalContext:'Capital; Buganda Kingdom seat; British East Africa Protectorate until 1962.',
    colonizer:'British Empire', nativeTribes:'Buganda (Baganda)'),

  // ── Zambia ────────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Lusaka', modernCountry:'Zambia', iso3:'ZMB', state:'Lusaka Province',
    historicalContext:'Capital; British Northern Rhodesia territory until independence 1964.',
    colonizer:'British Empire', nativeTribes:'Bemba, Tonga, Lozi'),

  // ── Zimbabwe ─────────────────────────────────────────────────────────────
  Place(continent:'Africa', name:'Harare', modernCountry:'Zimbabwe', iso3:'ZWE', state:'Harare Province',
    historicalContext:'Capital; British Rhodesia (Salisbury) until independence 1980.',
    colonizer:'British Empire (British South Africa Company)', nativeTribes:'Shona', romanizedNative:'Salisbury'),
  Place(continent:'Africa', name:'Bulawayo', modernCountry:'Zimbabwe', iso3:'ZWE', state:'Bulawayo Province',
    historicalContext:'Second city; Ndebele Kingdom capital before British colonisation.',
    colonizer:'British South Africa Company', nativeTribes:'Ndebele (Matabele)'),

  // ── Additional North Africa ───────────────────────────────────────────────
  Place(continent:'Africa', name:'Aswan', modernCountry:'Egypt', iso3:'EGY', state:'Aswan Governorate',
    historicalContext:'Gateway to Nubia; High Dam on Nile; ancient Elephantine island; Nubian culture.',
    colonizer:'Roman Empire, Arab, Ottoman Empire', nativeTribes:'Nubians, Ancient Egyptians', romanizedNative:'Swenet'),
  Place(continent:'Africa', name:'Marrakesh', modernCountry:'Morocco', iso3:'MAR', state:'Marrakesh-Safi Region',
    historicalContext:'Southern Moroccan imperial city; Berber Almoravid dynasty; Jemaa el-Fnaa square.',
    colonizer:'French Empire', nativeTribes:'Berbers (Amazigh)', romanizedNative:'Murrākuš'),
  Place(continent:'Africa', name:'Fes', modernCountry:'Morocco', iso3:'MAR', state:'Fès-Meknès Region',
    historicalContext:'Oldest imperial city; Fes el-Bali is world\'s largest car-free urban area; oldest university (859).',
    colonizer:'French Empire', nativeTribes:'Berbers (Amazigh)', romanizedNative:'Fās'),
  Place(continent:'Africa', name:'Constantine', modernCountry:'Algeria', iso3:'DZA', state:'Constantine Province',
    historicalContext:'Named after Emperor Constantine; rock-plateau city; ancient Cirta capital of Numidia.',
    colonizer:'Roman Empire, Arab, Ottoman Empire, French Empire', nativeTribes:'Berbers (Amazigh)', romanizedNative:'Cirta'),

  // ── Additional West Africa ────────────────────────────────────────────────
  Place(continent:'Africa', name:'Cape Coast', modernCountry:'Ghana', iso3:'GHA', state:'Central Region',
    historicalContext:'Slave castle; major transatlantic slave trade embarkation point; British colonial capital.',
    colonizer:'British Empire, Danish, Dutch', nativeTribes:'Fante'),
  Place(continent:'Africa', name:'Enugu', modernCountry:'Nigeria', iso3:'NGA', state:'Enugu State',
    historicalContext:'Igbo cultural capital; coal mining city; Biafra Republic capital 1967–1970.',
    colonizer:'British Empire', nativeTribes:'Igbo'),
  Place(continent:'Africa', name:'Yamoussoukro', modernCountry:'Ivory Coast', iso3:'CIV', state:'Lacs District',
    historicalContext:'Official capital; Basilica of Our Lady of Peace (largest Christian church in world).',
    colonizer:'French Empire', nativeTribes:'Baoulé'),
  Place(continent:'Africa', name:'N\'Djamena', modernCountry:'Chad', iso3:'TCD', state:'N\'Djamena Region',
    historicalContext:'Capital; French colonial Fort-Lamy; Chad Basin trade centre.',
    colonizer:'French Empire', nativeTribes:'Sara, Arab'),
  // ── Additional East Africa ────────────────────────────────────────────────
  Place(continent:'Africa', name:'Gondar', modernCountry:'Ethiopia', iso3:'ETH', state:'Amhara Region',
    historicalContext:'Ethiopian imperial capital 17th–19th century; Fasil Ghebbi castle complex; Falasha Jews.',
    nativeTribes:'Amhara, Beta Israel (Ethiopian Jews)'),
  Place(continent:'Africa', name:'Axum', modernCountry:'Ethiopia', iso3:'ETH', state:'Tigray Region',
    historicalContext:'Ancient Aksumite Empire capital; Ark of the Covenant tradition; obelisks.',
    nativeTribes:'Tigrinya', romanizedNative:'Aksum'),
  Place(continent:'Africa', name:'Djibouti City', modernCountry:'Djibouti', iso3:'DJI', state:'Djibouti Region',
    historicalContext:'Strategic Horn of Africa port; French Territory of Afars and Issas until 1977.',
    colonizer:'French Empire', nativeTribes:'Afar, Somali'),
  // ── Additional Southern Africa ────────────────────────────────────────────
  Place(continent:'Africa', name:'Port Elizabeth', modernCountry:'South Africa', iso3:'ZAF', state:'Eastern Cape',
    historicalContext:'British settler 1820; automotive industry; Xhosa cultural records.',
    colonizer:'British Empire', nativeTribes:'Xhosa'),
  Place(continent:'Africa', name:'Bloemfontein', modernCountry:'South Africa', iso3:'ZAF', state:'Free State',
    historicalContext:'Judicial capital; Orange Free State Boer Republic; Anglo-Boer War records.',
    colonizer:'British Empire', nativeTribes:'Sotho, Tswana'),
  Place(continent:'Africa', name:'Kimberley', modernCountry:'South Africa', iso3:'ZAF', state:'Northern Cape',
    historicalContext:'Diamond-rush city; Big Hole; Cecil Rhodes\' De Beers origin; Siege of Kimberley.',
    colonizer:'British Empire', nativeTribes:'Griqua, Tswana'),
];
