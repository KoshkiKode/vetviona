import '../models/place.dart';

/// Asia: organised continent → country → state/region → county → city
const List<Place> placesAsia = [

  // ── Afghanistan ───────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Kabul', modernCountry:'Afghanistan', iso3:'AFG', state:'Kabul Province',
    historicalContext:'Capital; Durrani Empire then British-influenced buffer state; Soviet invasion 1979.',
    colonizer:'British Empire (influence)', nativeTribes:'Pashtun, Tajik, Hazara'),
  Place(continent:'Asia', name:'Kandahar', modernCountry:'Afghanistan', iso3:'AFG', state:'Kandahar Province',
    historicalContext:'Founded by Alexander the Great; first capital of the Durrani (Afghan) Empire 1747.',
    colonizer:'Various empires', nativeTribes:'Pashtun', romanizedNative:'Qandahār'),

  // ── Armenia ───────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Yerevan', modernCountry:'Armenia', iso3:'ARM', state:'Yerevan City',
    historicalContext:'One of world\'s oldest cities; ancient Erebuni fortress; Soviet Republic capital.',
    colonizer:'Ottoman Empire, Russian Empire', nativeTribes:'Armenians', romanizedNative:'Երևան'),

  // ── Azerbaijan ────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Baku', modernCountry:'Azerbaijan', iso3:'AZE', state:'Baku City',
    historicalContext:'Oil-boom city on Caspian; Soviet Republic; old walled city (İçərişəhər) UNESCO-listed.',
    colonizer:'Russian Empire, Persian influence', nativeTribes:'Azerbaijanis', romanizedNative:'Bakı'),

  // ── Bahrain ───────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Manama', modernCountry:'Bahrain', iso3:'BHR', state:'Capital Governorate',
    historicalContext:'Island capital; Portuguese then Persian then British protectorate; major Gulf trading port.',
    colonizer:'Portuguese Empire, Persian Empire, British Empire', nativeTribes:'Bahrani Arabs, Shia Baharnas'),

  // ── Bangladesh ────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Dhaka', modernCountry:'Bangladesh', iso3:'BGD', state:'Dhaka Division',
    historicalContext:'Capital; Mughal capital of Bengal; British India; East Pakistan until 1971.',
    colonizer:'Mughal Empire, British India', nativeTribes:'Bengali', romanizedNative:'ঢাকা'),
  Place(continent:'Asia', name:'Chittagong', modernCountry:'Bangladesh', iso3:'BGD', state:'Chittagong Division',
    historicalContext:'Major seaport; Portuguese traders 16th century; Arakan Kingdom influence.',
    colonizer:'Portuguese Empire, British India', nativeTribes:'Bengali, Hill Tribes'),

  // ── Bhutan ────────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Thimphu', modernCountry:'Bhutan', iso3:'BTN', state:'Thimphu District',
    historicalContext:'Capital since 1955; Himalayan Buddhist kingdom; never formally colonised.',
    nativeTribes:'Ngalop (Bhutanese), Sharchop'),

  // ── Brunei ────────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Bandar Seri Begawan', modernCountry:'Brunei', iso3:'BRN', state:'Brunei-Muara District',
    historicalContext:'Capital; Brunei Sultanate powerful in 15–17th century; British protectorate 1888.',
    colonizer:'British Empire', nativeTribes:'Malay, Kedayan', romanizedNative:'Bandar Sri Begawan'),

  // ── Cambodia ──────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Phnom Penh', modernCountry:'Cambodia', iso3:'KHM', state:'Phnom Penh Capital',
    historicalContext:'Capital; French Indochina; Khmer Rouge genocide 1975–1979.',
    colonizer:'French Empire', nativeTribes:'Khmer', romanizedNative:'ភ្នំពេញ'),
  Place(continent:'Asia', name:'Siem Reap', modernCountry:'Cambodia', iso3:'KHM', state:'Siem Reap Province',
    historicalContext:'Gateway to Angkor Wat complex; Khmer Empire capital region 9th–15th century.',
    colonizer:'French Empire', nativeTribes:'Khmer'),

  // ── China ─────────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Beijing', modernCountry:'China', iso3:'CHN', state:'Beijing Municipality',
    historicalContext:'Capital; Ming and Qing dynasty seat; Forbidden City; Mongol Khanbaliq.',
    nativeTribes:'Han', romanizedNative:'北京 (Běijīng)'),
  Place(continent:'Asia', name:'Shanghai', modernCountry:'China', iso3:'CHN', state:'Shanghai Municipality',
    historicalContext:'Major treaty port after Opium Wars; international concessions; financial hub.',
    colonizer:'British Empire (concession)', nativeTribes:'Wu Chinese (Shanghainese)', romanizedNative:'上海'),
  Place(continent:'Asia', name:'Guangzhou', modernCountry:'China', iso3:'CHN', state:'Guangdong',
    historicalContext:'Canton; first Chinese city open to foreign trade; Opium War starting point.',
    colonizer:'British Empire (trade concession)', nativeTribes:'Cantonese', romanizedNative:'广州 / Canton'),
  Place(continent:'Asia', name:'Xi\'an', modernCountry:'China', iso3:'CHN', state:'Shaanxi',
    historicalContext:'Ancient capital of 13 dynasties; eastern terminus of the Silk Road; Terracotta Army.',
    nativeTribes:'Han', romanizedNative:'西安 / Chang\'an'),
  Place(continent:'Asia', name:'Nanjing', modernCountry:'China', iso3:'CHN', state:'Jiangsu',
    historicalContext:'Capital of Ming dynasty and Republic of China; site of 1937 Nanjing Massacre.',
    nativeTribes:'Han', romanizedNative:'南京'),
  Place(continent:'Asia', name:'Chongqing', modernCountry:'China', iso3:'CHN', state:'Chongqing Municipality',
    historicalContext:'Wartime capital during WWII; massive inland megacity on Yangtze River.',
    nativeTribes:'Han, Tujia'),
  Place(continent:'Asia', name:'Lhasa', modernCountry:'China', iso3:'CHN', state:'Tibet Autonomous Region',
    historicalContext:'Historic capital of Tibet; seat of the Dalai Lama; annexed by China 1951.',
    nativeTribes:'Tibetan', romanizedNative:'ལྷ་ས།'),
  Place(continent:'Asia', name:'Ürümqi', modernCountry:'China', iso3:'CHN', state:'Xinjiang',
    historicalContext:'Capital of Xinjiang; Silk Road junction; historically part of various Turkic khanates.',
    nativeTribes:'Uyghur', romanizedNative:'乌鲁木齐'),

  // ── Cyprus ────────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Nicosia', modernCountry:'Cyprus', iso3:'CYP', state:'Nicosia District',
    historicalContext:'World\'s last divided capital; British Crown Colony until 1960; split after 1974.',
    colonizer:'Venetian Republic, Ottoman Empire, British Empire', nativeTribes:'Mycenaean Greeks', romanizedNative:'Λευκωσία / Lefkoşa'),

  // ── Georgia ───────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Tbilisi', modernCountry:'Georgia', iso3:'GEO', state:'Tbilisi City',
    historicalContext:'Capital; ancient crossroads city; Soviet Republic; Rose Revolution 2003.',
    colonizer:'Persian Empire, Russian Empire', nativeTribes:'Kartvelians (Georgians)', romanizedNative:'თბილისი'),

  // ── India ─────────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'New Delhi', modernCountry:'India', iso3:'IND', state:'Delhi',
    county:'Central Delhi', historicalContext:'Capital; designed by Lutyens; built by British replacing Calcutta as capital.',
    colonizer:'British East India Company, British India', nativeTribes:'Punjabi, Hindi-speaking'),
  Place(continent:'Asia', name:'Mumbai', modernCountry:'India', iso3:'IND', state:'Maharashtra',
    county:'Mumbai City District', historicalContext:'Commercial capital; Bombay under British; Portuguese then British trading post.',
    colonizer:'Portuguese Empire, British East India Company', nativeTribes:'Koli', romanizedNative:'मुंबई / Bombay'),
  Place(continent:'Asia', name:'Kolkata', modernCountry:'India', iso3:'IND', state:'West Bengal',
    county:'Kolkata District', historicalContext:'Former British Raj capital; founded by East India Company 1690; jute and trade hub.',
    colonizer:'British East India Company', nativeTribes:'Bengali', romanizedNative:'কলকাতা / Calcutta'),
  Place(continent:'Asia', name:'Chennai', modernCountry:'India', iso3:'IND', state:'Tamil Nadu',
    county:'Chennai District', historicalContext:'British Madras; first British settlement in India (Fort St George 1644).',
    colonizer:'British East India Company', nativeTribes:'Tamil', romanizedNative:'சென்னை / Madras'),
  Place(continent:'Asia', name:'Bengaluru', modernCountry:'India', iso3:'IND', state:'Karnataka',
    county:'Bangalore Urban District', historicalContext:'Mysore Kingdom then British India; modern IT capital of India.',
    colonizer:'Mysore Kingdom, British India', nativeTribes:'Kannada', romanizedNative:'ಬೆಂಗಳೂರು / Bangalore'),
  Place(continent:'Asia', name:'Hyderabad', modernCountry:'India', iso3:'IND', state:'Telangana',
    county:'Hyderabad District', historicalContext:'Nizam of Hyderabad principality; acceded to India 1948.',
    colonizer:'Mughal Empire, British India (indirect)', nativeTribes:'Telugu, Urdu-speaking'),
  Place(continent:'Asia', name:'Agra', modernCountry:'India', iso3:'IND', state:'Uttar Pradesh',
    historicalContext:'Mughal capital; location of Taj Mahal and Agra Fort; Akbar\'s seat.',
    colonizer:'Mughal Empire, British India', nativeTribes:'Braj Bhasha speakers'),
  Place(continent:'Asia', name:'Varanasi', modernCountry:'India', iso3:'IND', state:'Uttar Pradesh',
    historicalContext:'One of world\'s oldest continually inhabited cities; Hindu sacred site on Ganges.',
    nativeTribes:'Hindi/Bhojpuri speakers', romanizedNative:'वाराणसी / Benares'),
  Place(continent:'Asia', name:'Goa', modernCountry:'India', iso3:'IND', state:'Goa',
    historicalContext:'Portuguese colony until 1961 (longest European colony in Asia).',
    colonizer:'Portuguese Empire', nativeTribes:'Konkani', romanizedNative:'Goa / गोवा'),

  // ── Indonesia ─────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Jakarta', modernCountry:'Indonesia', iso3:'IDN', state:'Jakarta Special Capital Region',
    historicalContext:'Capital; Dutch Batavia; seat of VOC; independence 1945.',
    colonizer:'Dutch East India Company (VOC)', nativeTribes:'Betawi', romanizedNative:'Batavia / Jayakarta'),
  Place(continent:'Asia', name:'Surabaya', modernCountry:'Indonesia', iso3:'IDN', state:'East Java',
    historicalContext:'Second city; major port; Battle of Surabaya 1945 in revolution.',
    colonizer:'Dutch East Indies', nativeTribes:'Javanese, Madurese'),
  Place(continent:'Asia', name:'Bali', modernCountry:'Indonesia', iso3:'IDN', state:'Bali',
    historicalContext:'Hindu-Balinese culture; Dutch colonial control from 1908.',
    colonizer:'Dutch East Indies', nativeTribes:'Balinese'),

  // ── Iran ──────────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Tehran', modernCountry:'Iran', iso3:'IRN', state:'Tehran Province',
    historicalContext:'Capital since 1796; Qajar dynasty seat; CIA-backed 1953 coup.',
    nativeTribes:'Persian, Azeri', romanizedNative:'تهران'),
  Place(continent:'Asia', name:'Isfahan', modernCountry:'Iran', iso3:'IRN', state:'Isfahan Province',
    historicalContext:'Safavid Empire capital "half the world" (naqsh-e jahan); UNESCO sites.',
    colonizer:'Safavid Empire', nativeTribes:'Persian', romanizedNative:'اصفهان / Esfahan'),
  Place(continent:'Asia', name:'Persepolis', modernCountry:'Iran', iso3:'IRN', state:'Fars Province',
    historicalContext:'Achaemenid Persian Empire ceremonial capital; burned by Alexander the Great 330 BC.',
    nativeTribes:'Persians', romanizedNative:'پرسپولیس',
    validTo:'-0330-01-01T00:00:00.000Z'),
  Place(continent:'Asia', name:'Shiraz', modernCountry:'Iran', iso3:'IRN', state:'Fars Province',
    historicalContext:'Ancient cultural capital; poetry of Hafez and Saadi; near Persepolis ruins.',
    nativeTribes:'Persian', romanizedNative:'شیراز'),

  // ── Iraq ──────────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Baghdad', modernCountry:'Iraq', iso3:'IRQ', state:'Baghdad Governorate',
    historicalContext:'Abbasid Caliphate Round City capital 762 AD; sacked by Mongols 1258; British Mandate.',
    colonizer:'Ottoman Empire, British Empire', nativeTribes:'Arabs, Kurds', romanizedNative:'بغداد'),
  Place(continent:'Asia', name:'Mosul', modernCountry:'Iraq', iso3:'IRQ', state:'Nineveh Governorate',
    historicalContext:'Near ancient Nineveh (Assyrian capital); Ottoman province then British Mandate.',
    colonizer:'Ottoman Empire, British Empire', nativeTribes:'Arabs, Kurds, Assyrians', romanizedNative:'الموصل'),
  Place(continent:'Asia', name:'Babylon', modernCountry:'Iraq', iso3:'IRQ', state:'Babylon Governorate',
    historicalContext:'Ancient Babylonian Empire capital; Hammurabi\'s Code; Hanging Gardens; conquered by Persia 539 BC.',
    nativeTribes:'Babylonians', romanizedNative:'بابل',
    validTo:'-0539-01-01T00:00:00.000Z'),

  // ── Israel / Palestine ────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Jerusalem', modernCountry:'Israel', iso3:'ISR', state:'Jerusalem District',
    historicalContext:'Holy city for Judaism, Christianity, Islam; Roman, Byzantine, Crusader, Ottoman rule.',
    colonizer:'Roman Empire, Byzantine Empire, Arab Conquest, Crusaders, Ottoman Empire, British Empire',
    nativeTribes:'Canaanites, Israelites, Arabs', romanizedNative:'ירושלים / القدس'),
  Place(continent:'Asia', name:'Tel Aviv', modernCountry:'Israel', iso3:'ISR', state:'Tel Aviv District',
    historicalContext:'Founded 1909 as first Hebrew city; became major metropolis post-1948.',
    nativeTribes:'Jewish settlers on Ottoman land', romanizedNative:'תל אביב'),

  // ── Japan ─────────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Tokyo', modernCountry:'Japan', iso3:'JPN', state:'Tokyo Metropolis',
    historicalContext:'Capital; formerly Edo (Tokugawa Shogunate); renamed Tokyo 1868 at Meiji Restoration.',
    nativeTribes:'Yamato Japanese', romanizedNative:'東京 / Edo'),
  Place(continent:'Asia', name:'Kyoto', modernCountry:'Japan', iso3:'JPN', state:'Kyoto Prefecture',
    historicalContext:'Imperial capital 794–1869; 2,000 temples and shrines; UNESCO World Heritage sites.',
    nativeTribes:'Yamato Japanese', romanizedNative:'京都 / Heiankyō'),
  Place(continent:'Asia', name:'Osaka', modernCountry:'Japan', iso3:'JPN', state:'Osaka Prefecture',
    historicalContext:'Commercial capital "the nation\'s kitchen"; Toyotomi Hideyoshi\'s castle city.',
    nativeTribes:'Yamato Japanese', romanizedNative:'大阪'),
  Place(continent:'Asia', name:'Hiroshima', modernCountry:'Japan', iso3:'JPN', state:'Hiroshima Prefecture',
    historicalContext:'First city destroyed by nuclear weapon (1945 atomic bomb); Peace Memorial City.',
    nativeTribes:'Yamato Japanese', romanizedNative:'広島'),
  Place(continent:'Asia', name:'Nagasaki', modernCountry:'Japan', iso3:'JPN', state:'Nagasaki Prefecture',
    historicalContext:'Only open port to foreign trade in Edo period; second atomic bomb target 1945.',
    colonizer:'Portuguese Empire (trade)', nativeTribes:'Yamato Japanese', romanizedNative:'長崎'),
  Place(continent:'Asia', name:'Nara', modernCountry:'Japan', iso3:'JPN', state:'Nara Prefecture',
    historicalContext:'Japan\'s first permanent capital 710–784 AD; giant Buddha (Daibutsu) at Tōdai-ji.',
    nativeTribes:'Yamato Japanese', romanizedNative:'奈良'),

  // ── Jordan ────────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Amman', modernCountry:'Jordan', iso3:'JOR', state:'Amman Governorate',
    historicalContext:'Ancient Philadelphia (Roman Decapolis); Circassian settlement 1878; British Mandate.',
    colonizer:'Ottoman Empire, British Empire', nativeTribes:'Arabs, Circassians', romanizedNative:'عمّان'),
  Place(continent:'Asia', name:'Petra', modernCountry:'Jordan', iso3:'JOR', state:'Ma\'an Governorate',
    historicalContext:'Nabataean capital carved in rose-red sandstone; Roman province Arabia Petraea.',
    colonizer:'Roman Empire, Byzantine Empire', nativeTribes:'Nabataeans'),

  // ── Kazakhstan ────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Astana', modernCountry:'Kazakhstan', iso3:'KAZ', state:'Akmola Region',
    historicalContext:'Capital since 1997; formerly Akmolinsk, Tselinograd, Akmola; futuristic planned city.',
    colonizer:'Russian Empire, Soviet Union', nativeTribes:'Kazakh', romanizedNative:'Астана / Nur-Sultan'),
  Place(continent:'Asia', name:'Almaty', modernCountry:'Kazakhstan', iso3:'KAZ', state:'Almaty City',
    historicalContext:'Former capital; Russian fortress Verny; Soviet hub; commercial capital.',
    colonizer:'Russian Empire, Soviet Union', nativeTribes:'Kazakh', romanizedNative:'Алматы / Alma-Ata'),

  // ── Kuwait ────────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Kuwait City', modernCountry:'Kuwait', iso3:'KWT', state:'Al Asimah Governorate',
    historicalContext:'Capital; British protectorate 1899–1961; oil wealth from 1938.',
    colonizer:'British Empire', nativeTribes:'Kuwaiti Arabs', romanizedNative:'مدينة الكويت'),

  // ── Kyrgyzstan ────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Bishkek', modernCountry:'Kyrgyzstan', iso3:'KGZ', state:'Chuy Region',
    historicalContext:'Capital; Russian fort Pishpek; Soviet Frunze; independence 1991.',
    colonizer:'Russian Empire, Soviet Union', nativeTribes:'Kyrgyz', romanizedNative:'Бишкек / Frunze'),

  // ── Laos ──────────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Vientiane', modernCountry:'Laos', iso3:'LAO', state:'Vientiane Prefecture',
    historicalContext:'Capital; Lan Xang Kingdom; French Indochina.',
    colonizer:'French Empire', nativeTribes:'Lao Loum', romanizedNative:'ວຽງຈັນ'),

  // ── Lebanon ───────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Beirut', modernCountry:'Lebanon', iso3:'LBN', state:'Beirut Governorate',
    historicalContext:'Phoenician city; Ottoman then French Mandate; "Paris of the Middle East" before civil war.',
    colonizer:'Ottoman Empire, French Empire', nativeTribes:'Phoenicians, Arabs', romanizedNative:'بيروت'),

  // ── Malaysia ──────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Kuala Lumpur', modernCountry:'Malaysia', iso3:'MYS', state:'Federal Territory of Kuala Lumpur',
    historicalContext:'Capital; founded 1857 by Hakka tin miners; British Malaya crown colony.',
    colonizer:'British Empire', nativeTribes:'Orang Asli, Malay', romanizedNative:'كوالا لومڤور'),
  Place(continent:'Asia', name:'Malacca', modernCountry:'Malaysia', iso3:'MYS', state:'Melaka',
    historicalContext:'Historic port city; Malacca Sultanate; Portuguese then Dutch then British colony.',
    colonizer:'Portuguese Empire, Dutch Republic, British Empire', nativeTribes:'Malay, Orang Asli', romanizedNative:'Melaka'),
  Place(continent:'Asia', name:'Penang', modernCountry:'Malaysia', iso3:'MYS', state:'Penang',
    historicalContext:'First British trading post in Malay Peninsula 1786; multicultural colonial heritage.',
    colonizer:'British East India Company', nativeTribes:'Malay', romanizedNative:'Pulau Pinang'),

  // ── Maldives ──────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Malé', modernCountry:'Maldives', iso3:'MDV', state:'Malé Atoll',
    historicalContext:'Capital; island sultanate; Portuguese and Dutch presence; British protectorate.',
    colonizer:'Portuguese Empire, Dutch Republic, British Empire', nativeTribes:'Dhivehi (Maldivians)'),

  // ── Mongolia ──────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Ulaanbaatar', modernCountry:'Mongolia', iso3:'MNG', state:'Ulaanbaatar City',
    historicalContext:'Capital; nomadic Buddhist monastery city; Chinese Qing then Soviet satellite.',
    colonizer:'Chinese (Qing), Soviet Union', nativeTribes:'Mongolian', romanizedNative:'Улаанбаатар / Urga'),

  // ── Myanmar ───────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Naypyidaw', modernCountry:'Myanmar', iso3:'MMR', state:'Naypyidaw Union Territory',
    historicalContext:'Capital since 2006; purpose-built by military junta.',
    colonizer:'British India', nativeTribes:'Bamar (Burman)', romanizedNative:'နေပြည်တော်'),
  Place(continent:'Asia', name:'Yangon', modernCountry:'Myanmar', iso3:'MMR', state:'Yangon Region',
    historicalContext:'Former capital; British Burma capital (Rangoon); major port on Irrawaddy delta.',
    colonizer:'British India', nativeTribes:'Bamar', romanizedNative:'ရန်ကုန် / Rangoon'),
  Place(continent:'Asia', name:'Bagan', modernCountry:'Myanmar', iso3:'MMR', state:'Mandalay Region',
    historicalContext:'Ancient capital of Pagan Kingdom 9th–13th century; 10,000 Buddhist temples.',
    nativeTribes:'Burmese', romanizedNative:'ပုဂံ'),

  // ── Nepal ─────────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Kathmandu', modernCountry:'Nepal', iso3:'NPL', state:'Bagmati Province',
    historicalContext:'Capital; Kingdom of Nepal; Hindu-Buddhist heritage; never colonised.',
    nativeTribes:'Newar, Khas', romanizedNative:'काठमाडौं'),

  // ── North Korea ───────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Pyongyang', modernCountry:'North Korea', iso3:'PRK', state:'Pyongyang',
    historicalContext:'Capital; ancient Gojoseon site; Japanese annexation; divided Korea 1945.',
    colonizer:'Japanese Empire', nativeTribes:'Korean', romanizedNative:'평양'),

  // ── Oman ──────────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Muscat', modernCountry:'Oman', iso3:'OMN', state:'Muscat Governorate',
    historicalContext:'Capital; Portuguese fort colony 1507–1650; Omani empire at its peak reached Zanzibar.',
    colonizer:'Portuguese Empire', nativeTribes:'Omani Arabs', romanizedNative:'مسقط'),

  // ── Pakistan ──────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Islamabad', modernCountry:'Pakistan', iso3:'PAK', state:'Islamabad Capital Territory',
    historicalContext:'Capital since 1966; purpose-built to replace Rawalpindi/Karachi.',
    colonizer:'British India', nativeTribes:'Pothohari'),
  Place(continent:'Asia', name:'Karachi', modernCountry:'Pakistan', iso3:'PAK', state:'Sindh',
    county:'Karachi City', historicalContext:'Former capital and largest city; major port; British Indian railway hub.',
    colonizer:'British India', nativeTribes:'Baloch, Sindhi', romanizedNative:'کراچی'),
  Place(continent:'Asia', name:'Lahore', modernCountry:'Pakistan', iso3:'PAK', state:'Punjab',
    historicalContext:'Mughal Empire cultural capital; gateway of British India to Afghanistan.',
    colonizer:'Mughal Empire, British India', nativeTribes:'Punjabi', romanizedNative:'لاہور'),
  Place(continent:'Asia', name:'Mohenjo-daro', modernCountry:'Pakistan', iso3:'PAK', state:'Sindh',
    historicalContext:'Indus Valley Civilisation city c. 2500 BC; advanced urban planning.',
    nativeTribes:'Indus Valley peoples', romanizedNative:'موئن جو دڑو',
    validTo:'-1900-01-01T00:00:00.000Z'),

  // ── Philippines ───────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Manila', modernCountry:'Philippines', iso3:'PHL', state:'Metro Manila',
    historicalContext:'Capital; Spanish colonial seat 1571–1898; US territory until 1946.',
    colonizer:'Spanish Empire, American Empire', nativeTribes:'Tagalog', romanizedNative:'Maynila'),
  Place(continent:'Asia', name:'Cebu City', modernCountry:'Philippines', iso3:'PHL', state:'Cebu Province',
    historicalContext:'Oldest Spanish settlement in Philippines (1565); Magellan\'s Cross site.',
    colonizer:'Spanish Empire', nativeTribes:'Cebuano'),

  // ── Qatar ─────────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Doha', modernCountry:'Qatar', iso3:'QAT', state:'Ad-Dawhah Municipality',
    historicalContext:'Capital; British protectorate 1916; oil wealth post-1940; 2022 FIFA World Cup host.',
    colonizer:'Ottoman Empire, British Empire', nativeTribes:'Qatari Arabs', romanizedNative:'الدوحة'),

  // ── Russia (Asian) ────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Novosibirsk', modernCountry:'Russia', iso3:'RUS', state:'Novosibirsk Oblast',
    historicalContext:'Largest city in Siberia; Trans-Siberian Railway junction; Soviet industrial city.',
    colonizer:'Russian Empire, Soviet Union', nativeTribes:'Indigenous Siberians'),
  Place(continent:'Asia', name:'Vladivostok', modernCountry:'Russia', iso3:'RUS', state:'Primorsky Krai',
    historicalContext:'Russian Pacific fleet base; eastern terminus of Trans-Siberian Railway; formerly Chinese territory.',
    colonizer:'Russian Empire (seized from Qing China)', nativeTribes:'Udege, Nanai'),
  Place(continent:'Asia', name:'Samarkand', modernCountry:'Uzbekistan', iso3:'UZB', state:'Samarkand Region',
    historicalContext:'Timur (Tamerlane)\'s capital; Silk Road hub; one of oldest inhabited cities in Central Asia.',
    colonizer:'Timurid Empire, Russian Empire, Soviet Union', nativeTribes:'Sogdians, Uzbek', romanizedNative:'Самарқанд'),

  // ── Saudi Arabia ──────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Riyadh', modernCountry:'Saudi Arabia', iso3:'SAU', state:'Riyadh Region',
    historicalContext:'Capital; al-Diriyah Emirate founding city; Al Saud dynasty seat.',
    nativeTribes:'Najdi Arabs', romanizedNative:'الرياض'),
  Place(continent:'Asia', name:'Mecca', modernCountry:'Saudi Arabia', iso3:'SAU', state:'Mecca Region',
    historicalContext:'Holiest city in Islam; birthplace of Muhammad; annual Hajj pilgrimage.',
    colonizer:'Ottoman Empire', nativeTribes:'Quraysh Arabs', romanizedNative:'مكة المكرمة'),
  Place(continent:'Asia', name:'Medina', modernCountry:'Saudi Arabia', iso3:'SAU', state:'Medina Region',
    historicalContext:'Second holiest city in Islam; Prophet Muhammad\'s mosque and burial place.',
    colonizer:'Ottoman Empire', nativeTribes:'Arabs', romanizedNative:'المدينة المنورة'),
  Place(continent:'Asia', name:'Jeddah', modernCountry:'Saudi Arabia', iso3:'SAU', state:'Mecca Region',
    historicalContext:'Main port on Red Sea; gateway for Hajj pilgrims; UNESCO Historic District.',
    colonizer:'Ottoman Empire', nativeTribes:'Hejazi Arabs', romanizedNative:'جدة'),

  // ── Singapore ─────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Singapore', modernCountry:'Singapore', iso3:'SGP', state:'Central Region',
    historicalContext:'British trading post founded by Raffles 1819; fell to Japan 1942; independence 1965.',
    colonizer:'British Empire, Japanese Empire', nativeTribes:'Malay (Orang Laut)', romanizedNative:'Singapura / 新加坡'),

  // ── South Korea ───────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Seoul', modernCountry:'South Korea', iso3:'KOR', state:'Seoul Special City',
    historicalContext:'Capital; Joseon dynasty Hanyang; Japanese colonial capital Keijō; divided Korea.',
    colonizer:'Japanese Empire', nativeTribes:'Korean', romanizedNative:'서울 / 漢陽'),
  Place(continent:'Asia', name:'Gyeongju', modernCountry:'South Korea', iso3:'KOR', state:'North Gyeongsang Province',
    historicalContext:'Capital of Silla Kingdom (57 BC – 935 AD); "museum without walls".',
    nativeTribes:'Korean', romanizedNative:'경주'),

  // ── Sri Lanka ────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Sri Jayawardenepura Kotte', modernCountry:'Sri Lanka', iso3:'LKA', state:'Western Province',
    historicalContext:'Legislative capital; Portuguese, Dutch then British Ceylon colony.',
    colonizer:'Portuguese Empire, Dutch Republic, British Empire', nativeTribes:'Sinhalese'),
  Place(continent:'Asia', name:'Colombo', modernCountry:'Sri Lanka', iso3:'LKA', state:'Western Province',
    historicalContext:'Commercial capital; Portuguese Colombo; Dutch and British port city.',
    colonizer:'Portuguese Empire, Dutch Republic, British Empire', nativeTribes:'Sinhalese, Tamil'),

  // ── Syria ─────────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Damascus', modernCountry:'Syria', iso3:'SYR', state:'Damascus Governorate',
    historicalContext:'One of world\'s oldest continuously inhabited cities; Umayyad Caliphate capital.',
    colonizer:'Roman Empire, Arab Conquest, Ottoman Empire, French Empire', nativeTribes:'Aramaeans', romanizedNative:'دمشق'),
  Place(continent:'Asia', name:'Aleppo', modernCountry:'Syria', iso3:'SYR', state:'Aleppo Governorate',
    historicalContext:'Ancient Silk Road city; UNESCO heritage; heavily damaged in Syrian Civil War.',
    colonizer:'Seleucid Empire, Roman Empire, Ottoman Empire, French Empire', nativeTribes:'Aramaeans', romanizedNative:'حلب'),

  // ── Taiwan ────────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Taipei', modernCountry:'Taiwan', iso3:'TWN', state:'Taipei City',
    historicalContext:'Capital; Dutch and Spanish settlement 17th century; Japanese colony 1895–1945.',
    colonizer:'Dutch Republic, Spanish Empire, Japanese Empire', nativeTribes:'Austronesian (Formosan tribes)', romanizedNative:'臺北'),

  // ── Tajikistan ────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Dushanbe', modernCountry:'Tajikistan', iso3:'TJK', state:'Dushanbe City',
    historicalContext:'Capital; Russian Empire then Soviet Tajik SSR.',
    colonizer:'Russian Empire, Soviet Union', nativeTribes:'Tajik', romanizedNative:'Душанбе'),

  // ── Thailand ──────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Bangkok', modernCountry:'Thailand', iso3:'THA', state:'Bangkok Metropolis',
    historicalContext:'Capital; Rattanakosin Kingdom; never colonised; Treaty of Bowring opened trade to Britain.',
    nativeTribes:'Thai', romanizedNative:'กรุงเทพมหานคร / Krung Thep'),
  Place(continent:'Asia', name:'Ayutthaya', modernCountry:'Thailand', iso3:'THA', state:'Phra Nakhon Si Ayutthaya Province',
    historicalContext:'Ayutthaya Kingdom capital 1350–1767; destroyed by Burmese; UNESCO site.',
    nativeTribes:'Thai', romanizedNative:'พระนครศรีอยุธยา'),

  // ── Timor-Leste ───────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Dili', modernCountry:'Timor-Leste', iso3:'TLS', state:'Dili District',
    historicalContext:'Capital; Portuguese Timor then Indonesian occupation 1975–1999; independence 2002.',
    colonizer:'Portuguese Empire, Indonesian occupation', nativeTribes:'Tetum, Mambai'),

  // ── Turkey ────────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Ankara', modernCountry:'Turkey', iso3:'TUR', state:'Ankara Province',
    historicalContext:'Capital since 1923; Atatürk chose over Istanbul for new secular republic.',
    colonizer:'Ottoman Empire', nativeTribes:'Phrygians, Galatians', romanizedNative:'Ankara / Angora'),
  Place(continent:'Asia', name:'Istanbul', modernCountry:'Turkey', iso3:'TUR', state:'Istanbul Province',
    historicalContext:'Byzantium → Constantinople (Roman/Byzantine) → Istanbul (Ottoman); straddles two continents.',
    colonizer:'Roman Empire (as capital)', nativeTribes:'Thracians', romanizedNative:'İstanbul / Κωνσταντινούπολη'),
  Place(continent:'Asia', name:'Ephesus', modernCountry:'Turkey', iso3:'TUR', state:'İzmir Province',
    historicalContext:'Ancient Greek Ionian city; Temple of Artemis (one of Seven Wonders); Roman provincial capital.',
    colonizer:'Greek colonists, Roman Empire', nativeTribes:'Luwians', romanizedNative:'Ἔφεσος',
    validTo:'0500-01-01T00:00:00.000Z'),

  // ── Turkmenistan ──────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Ashgabat', modernCountry:'Turkmenistan', iso3:'TKM', state:'Ashgabat City',
    historicalContext:'Capital; Russian Empire then Soviet Turkmen SSR; largely destroyed by 1948 earthquake.',
    colonizer:'Russian Empire, Soviet Union', nativeTribes:'Turkmen', romanizedNative:'Aşgabat'),

  // ── United Arab Emirates ──────────────────────────────────────────────────
  Place(continent:'Asia', name:'Abu Dhabi', modernCountry:'United Arab Emirates', iso3:'ARE', state:'Abu Dhabi Emirate',
    historicalContext:'Capital; Bani Yas tribe homeland; British Trucial States protectorate until 1971.',
    colonizer:'British Empire', nativeTribes:'Bani Yas Arabs', romanizedNative:'أبوظبي'),
  Place(continent:'Asia', name:'Dubai', modernCountry:'United Arab Emirates', iso3:'ARE', state:'Dubai Emirate',
    historicalContext:'Pearl fishing village; British protectorate; rapid oil-era transformation.',
    colonizer:'British Empire', nativeTribes:'Bani Yas Arabs, Banu Tamim', romanizedNative:'دبي'),

  // ── Uzbekistan ────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Tashkent', modernCountry:'Uzbekistan', iso3:'UZB', state:'Tashkent City',
    historicalContext:'Capital; Silk Road city; Russian Empire conquest 1865; Soviet Uzbek SSR.',
    colonizer:'Russian Empire, Soviet Union', nativeTribes:'Uzbek', romanizedNative:'Toshkent'),
  Place(continent:'Asia', name:'Bukhara', modernCountry:'Uzbekistan', iso3:'UZB', state:'Bukhara Region',
    historicalContext:'Samanid Empire capital; great centre of Islamic learning; Silk Road trade.',
    colonizer:'Timurid Empire, Russian Empire', nativeTribes:'Sogdians, Uzbek', romanizedNative:'Buxoro'),

  // ── Vietnam ───────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:'Hanoi', modernCountry:'Vietnam', iso3:'VNM', state:'Hanoi Capital',
    historicalContext:'Capital; ancient Thăng Long; French Indochina administrative capital.',
    colonizer:'Chinese dynasties, French Empire', nativeTribes:'Kinh (Viet)', romanizedNative:'Hà Nội'),
  Place(continent:'Asia', name:'Ho Chi Minh City', modernCountry:'Vietnam', iso3:'VNM', state:'Ho Chi Minh City',
    historicalContext:'Khmer Prey Nokor then French Saigon; South Vietnam capital during Vietnam War.',
    colonizer:'French Empire, American influence', nativeTribes:'Khmer, Kinh', romanizedNative:'Thành phố Hồ Chí Minh / Sài Gòn'),
  Place(continent:'Asia', name:'Hội An', modernCountry:'Vietnam', iso3:'VNM', state:'Quảng Nam Province',
    historicalContext:'Ancient Cham trading port; Japanese and Chinese merchant quarters; UNESCO.',
    colonizer:'Cham Kingdom, French Empire', nativeTribes:'Cham, Kinh', romanizedNative:'Hội An'),

  // ── Yemen ─────────────────────────────────────────────────────────────────
  Place(continent:'Asia', name:"Sana'a", modernCountry:'Yemen', iso3:'YEM', state:"Sana'a Governorate",
    historicalContext:'Capital; Old City UNESCO site; Ottoman then British-influenced (Aden).',
    colonizer:'Ottoman Empire, British Empire (Aden)', nativeTribes:'Arabs, Sheba descendants', romanizedNative:'صنعاء'),
];
