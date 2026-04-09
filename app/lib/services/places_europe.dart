import '../models/place.dart';

/// Europe: organised continent → country → state/region → county → city
const List<Place> placesEurope = [

  // ── Albania ──────────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Tirana', modernCountry:'Albania', iso3:'ALB', state:'Tirana County',
    historicalContext:'Capital of Albania; grew under Ottoman rule, became capital in 1920.',
    colonizer:'Ottoman Empire', nativeTribes:'Illyrians', romanizedNative:'Tiranë'),

  // ── Andorra ──────────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Andorra la Vella', modernCountry:'Andorra', iso3:'AND', state:'Andorra la Vella Parish',
    historicalContext:'Capital of the Andorran co-principality, established in 1278.',
    nativeTribes:'Andorrans (Catalan-speaking)'),

  // ── Austria ──────────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Vienna', modernCountry:'Austria', iso3:'AUT', state:'Vienna',
    historicalContext:'Capital of the Habsburg and Austro-Hungarian Empire; major genealogy records hub.',
    colonizer:'Roman Empire, Habsburg Dynasty', nativeTribes:'Celtic Boii', romanizedNative:'Vindobona'),
  Place(continent:'Europe', name:'Graz', modernCountry:'Austria', iso3:'AUT', state:'Styria',
    historicalContext:'Second largest Austrian city; Styria region records date to medieval period.',
    colonizer:'Habsburg Dynasty', nativeTribes:'Celtic Celts', romanizedNative:'Gratz'),
  Place(continent:'Europe', name:'Salzburg', modernCountry:'Austria', iso3:'AUT', state:'Salzburg',
    historicalContext:'Birthplace of Mozart; formerly an independent prince-archbishopric.',
    colonizer:'Holy Roman Empire', romanizedNative:'Juvavum'),
  Place(continent:'Europe', name:'Innsbruck', modernCountry:'Austria', iso3:'AUT', state:'Tyrol',
    historicalContext:'Habsburg seat; Tyrol was passed between Austria and Bavaria through centuries.',
    colonizer:'Habsburg Dynasty'),

  // ── Belarus ──────────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Minsk', modernCountry:'Belarus', iso3:'BLR', state:'Minsk Region',
    historicalContext:'Capital of Belarus; occupied by Poland-Lithuania, Russia, and Soviet Union.',
    colonizer:'Polish-Lithuanian Commonwealth, Russian Empire', nativeTribes:'Eastern Slavs', romanizedNative:'Mensk'),
  Place(continent:'Europe', name:'Brest', modernCountry:'Belarus', iso3:'BLR', state:'Brest Region',
    historicalContext:'Border city; Treaty of Brest-Litovsk signed here 1918.',
    colonizer:'Polish-Lithuanian Commonwealth, Russian Empire', romanizedNative:'Brest-Litovsk'),
  Place(continent:'Europe', name:'Grodno', modernCountry:'Belarus', iso3:'BLR', state:'Grodno Region',
    historicalContext:'Historic Jewish community; passed between Poland and Russia many times.',
    colonizer:'Polish-Lithuanian Commonwealth, Russian Empire', romanizedNative:'Hrodna'),

  // ── Belgium ──────────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Brussels', modernCountry:'Belgium', iso3:'BEL', state:'Brussels Capital Region',
    historicalContext:'Capital of Belgium and the EU; formerly part of Spanish and Austrian Netherlands.',
    colonizer:'Spanish Netherlands, Austrian Netherlands', nativeTribes:'Celtic Belgae', romanizedNative:'Bruxellae'),
  Place(continent:'Europe', name:'Antwerp', modernCountry:'Belgium', iso3:'BEL', state:'Antwerp Province',
    historicalContext:'Major port; commercial hub of the Habsburg Netherlands in the 16th century.',
    colonizer:'Spanish Netherlands', nativeTribes:'Celtic Belgae', romanizedNative:'Antverpiae'),
  Place(continent:'Europe', name:'Ghent', modernCountry:'Belgium', iso3:'BEL', state:'East Flanders',
    historicalContext:'Medieval cloth-trade city; birthplace of Holy Roman Emperor Charles V.',
    colonizer:'Spanish Netherlands', romanizedNative:'Gent'),
  Place(continent:'Europe', name:'Liège', modernCountry:'Belgium', iso3:'BEL', state:'Liège Province',
    historicalContext:'Industrial Walloon city; former prince-bishopric with independent medieval status.'),

  // ── Bosnia and Herzegovina ────────────────────────────────────────────────
  Place(continent:'Europe', name:'Sarajevo', modernCountry:'Bosnia and Herzegovina', iso3:'BIH', state:'Sarajevo Canton',
    historicalContext:'Site of 1914 assassination; Ottoman administrative centre for the Balkans.',
    colonizer:'Ottoman Empire, Austro-Hungarian Empire', nativeTribes:'South Slavs', romanizedNative:'Sarajevo'),

  // ── Bulgaria ─────────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Sofia', modernCountry:'Bulgaria', iso3:'BGR', state:'Sofia City Province',
    historicalContext:'Capital of Bulgaria; under Ottoman rule 1382–1878.',
    colonizer:'Byzantine Empire, Ottoman Empire', nativeTribes:'Thracians', romanizedNative:'Serdica'),
  Place(continent:'Europe', name:'Plovdiv', modernCountry:'Bulgaria', iso3:'BGR', state:'Plovdiv Province',
    historicalContext:'One of Europe\'s oldest continuously inhabited cities; Thracian then Roman.',
    colonizer:'Roman Empire, Ottoman Empire', nativeTribes:'Thracians', romanizedNative:'Philippopolis'),

  // ── Croatia ──────────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Zagreb', modernCountry:'Croatia', iso3:'HRV', state:'Zagreb County',
    historicalContext:'Capital of Croatia; part of Habsburg Empire; important Catholic records hub.',
    colonizer:'Habsburg Empire, Austro-Hungarian Empire', nativeTribes:'South Slavs', romanizedNative:'Agram'),
  Place(continent:'Europe', name:'Split', modernCountry:'Croatia', iso3:'HRV', state:'Split-Dalmatia County',
    historicalContext:'Built inside Diocletian\'s Palace; Dalmatia long under Venetian control.',
    colonizer:'Roman Empire, Venetian Republic', nativeTribes:'Illyrians', romanizedNative:'Spalato'),
  Place(continent:'Europe', name:'Dubrovnik', modernCountry:'Croatia', iso3:'HRV', state:'Dubrovnik-Neretva County',
    historicalContext:'The independent Republic of Ragusa 1358–1808; major maritime trading power.',
    colonizer:'Venetian Republic (briefly)', romanizedNative:'Ragusa'),

  // ── Czech Republic ───────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Prague', modernCountry:'Czech Republic', iso3:'CZE', state:'Prague',
    historicalContext:'Capital of Bohemia and the Holy Roman Empire; Jewish quarter among Europe\'s oldest.',
    colonizer:'Habsburg Empire', nativeTribes:'Celtic Boii, Slavs', romanizedNative:'Praha'),
  Place(continent:'Europe', name:'Brno', modernCountry:'Czech Republic', iso3:'CZE', state:'South Moravian Region',
    historicalContext:'Moravia\'s capital; heavy German-speaking population before 1945 expulsion.',
    colonizer:'Habsburg Empire', romanizedNative:'Brünn'),
  Place(continent:'Europe', name:'Ostrava', modernCountry:'Czech Republic', iso3:'CZE', state:'Moravian-Silesian Region',
    historicalContext:'Silesian mining city; disputed between Austria and Prussia historically.'),

  // ── Denmark ──────────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Copenhagen', modernCountry:'Denmark', iso3:'DNK', state:'Capital Region',
    historicalContext:'Capital of Denmark and formerly of a Scandinavian empire including Norway and Iceland.',
    nativeTribes:'Norse/Danish Vikings', romanizedNative:'Køpmannahavn'),
  Place(continent:'Europe', name:'Aarhus', modernCountry:'Denmark', iso3:'DNK', state:'Central Denmark Region',
    historicalContext:'Denmark\'s second city; Viking settlement and medieval bishopric.',
    nativeTribes:'Norse Vikings'),

  // ── Estonia ──────────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Tallinn', modernCountry:'Estonia', iso3:'EST', state:'Harju County',
    historicalContext:'Hanseatic League member; occupied by Denmark, Sweden, and Russia for centuries.',
    colonizer:'Denmark, Teutonic Knights, Sweden, Russian Empire', nativeTribes:'Estonians (Finno-Ugric)', romanizedNative:'Reval'),
  Place(continent:'Europe', name:'Tartu', modernCountry:'Estonia', iso3:'EST', state:'Tartu County',
    historicalContext:'University city; major centre of Estonian national awakening.',
    colonizer:'Teutonic Knights, Sweden, Russian Empire', romanizedNative:'Dorpat'),

  // ── Finland ──────────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Helsinki', modernCountry:'Finland', iso3:'FIN', state:'Uusimaa',
    historicalContext:'Capital; founded by Sweden in 1550, ceded to Russia in 1809, independent 1917.',
    colonizer:'Swedish Empire, Russian Empire', nativeTribes:'Finns (Finno-Ugric)', romanizedNative:'Helsingfors'),
  Place(continent:'Europe', name:'Turku', modernCountry:'Finland', iso3:'FIN', state:'Southwest Finland',
    historicalContext:'Oldest city in Finland; former capital under Swedish rule.',
    colonizer:'Swedish Empire', romanizedNative:'Åbo'),
  Place(continent:'Europe', name:'Tampere', modernCountry:'Finland', iso3:'FIN', state:'Pirkanmaa',
    historicalContext:'Major industrial centre; key city in 1918 Finnish Civil War.',
    colonizer:'Swedish Empire, Russian Empire'),
  Place(continent:'Europe', name:'Oulu', modernCountry:'Finland', iso3:'FIN', state:'North Ostrobothnia',
    historicalContext:'Northern Finnish city; important for Sámi and Finnish genealogical records.'),

  // ── France ───────────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Paris', modernCountry:'France', iso3:'FRA', state:'Île-de-France', subState:'Seine',
    historicalContext:'Capital of France; royal seat since Capetian dynasty; major civil records archive.',
    colonizer:'Roman Empire, Franks', nativeTribes:'Parisii (Gauls)', romanizedNative:'Lutetia'),
  Place(continent:'Europe', name:'Lyon', modernCountry:'France', iso3:'FRA', state:'Auvergne-Rhône-Alpes', subState:'Métropole de Lyon',
    historicalContext:'Roman capital of Gaul (Lugdunum); major silk trade and banking city.',
    colonizer:'Roman Empire', nativeTribes:'Gallic Celts', romanizedNative:'Lugdunum'),
  Place(continent:'Europe', name:'Marseille', modernCountry:'France', iso3:'FRA', state:'Provence-Alpes-Côte d\'Azur', subState:'Bouches-du-Rhône',
    historicalContext:'Greece\'s oldest colony in France (Massalia); major Mediterranean port.',
    colonizer:'Greek colonists, Roman Empire', nativeTribes:'Ligurian Celts', romanizedNative:'Massalia'),
  Place(continent:'Europe', name:'Bordeaux', modernCountry:'France', iso3:'FRA', state:'Nouvelle-Aquitaine', subState:'Gironde',
    historicalContext:'English Aquitaine for 300 years (1154–1453); wine trade hub.',
    colonizer:'Roman Empire, English Crown', nativeTribes:'Bituriges Vivisci', romanizedNative:'Burdigala'),
  Place(continent:'Europe', name:'Strasbourg', modernCountry:'France', iso3:'FRA', state:'Grand Est', subState:'Bas-Rhin',
    historicalContext:'Contested between France and Germany; Alsace-Lorraine records are bicultural.',
    colonizer:'Holy Roman Empire, German Empire', nativeTribes:'Germanic Alemanni', romanizedNative:'Argentoratum'),
  Place(continent:'Europe', name:'Nice', modernCountry:'France', iso3:'FRA', state:'Provence-Alpes-Côte d\'Azur', subState:'Alpes-Maritimes',
    historicalContext:'Part of the Duchy of Savoy until 1860; Italian-speaking genealogical records exist.',
    colonizer:'Roman Empire, Duchy of Savoy', nativeTribes:'Ligurian Celts', romanizedNative:'Nizza'),
  Place(continent:'Europe', name:'Nantes', modernCountry:'France', iso3:'FRA', state:'Pays de la Loire', subState:'Loire-Atlantique',
    historicalContext:'Edict of Nantes 1598 signed here; major slave-trade port in 18th century.'),
  Place(continent:'Europe', name:'Toulouse', modernCountry:'France', iso3:'FRA', state:'Occitanie', subState:'Haute-Garonne',
    historicalContext:'Capital of Visigoth kingdom; Cathar stronghold; Occitan language homeland.'),

  // ── Germany ──────────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Berlin', modernCountry:'Germany', iso3:'DEU', state:'Berlin',
    historicalContext:'Prussian capital then German Empire capital; reunified 1990; major archive hub.',
    colonizer:'Holy Roman Empire, Prussia', nativeTribes:'Slavic Hevelli', romanizedNative:'Cölln'),
  Place(continent:'Europe', name:'Munich', modernCountry:'Germany', iso3:'DEU', state:'Bavaria', subState:'Upper Bavaria', county:'Munich',
    historicalContext:'Capital of the Kingdom of Bavaria; major Catholic records repository.',
    colonizer:'Roman Empire, Wittelsbach Duchy', nativeTribes:'Baiuvarii (Germanic)', romanizedNative:'München'),
  Place(continent:'Europe', name:'Hamburg', modernCountry:'Germany', iso3:'DEU', state:'Hamburg',
    historicalContext:'Free Imperial City and Hanseatic League member; major emigration port to Americas.',
    colonizer:'Holy Roman Empire', nativeTribes:'Saxons', romanizedNative:'Hammaburg'),
  Place(continent:'Europe', name:'Frankfurt', modernCountry:'Germany', iso3:'DEU', state:'Hesse', county:'Frankfurt am Main',
    historicalContext:'Holy Roman Empire coronation city; major banking and commercial centre.',
    colonizer:'Roman Empire, Holy Roman Empire', nativeTribes:'Franks', romanizedNative:'Franconoford'),
  Place(continent:'Europe', name:'Cologne', modernCountry:'Germany', iso3:'DEU', state:'North Rhine-Westphalia', county:'Cologne',
    historicalContext:'Roman colonia; major medieval archbishopric; Rhine trade hub.',
    colonizer:'Roman Empire', nativeTribes:'Ubii (Germanic)', romanizedNative:'Colonia Agrippina'),
  Place(continent:'Europe', name:'Dresden', modernCountry:'Germany', iso3:'DEU', state:'Saxony', county:'Dresden',
    historicalContext:'Capital of Electoral Saxony; heavily bombed 1945; baroque architecture.',
    colonizer:'Holy Roman Empire, Kingdom of Saxony', nativeTribes:'Slavic Sorbians'),
  Place(continent:'Europe', name:'Leipzig', modernCountry:'Germany', iso3:'DEU', state:'Saxony', county:'Leipzig',
    historicalContext:'Major trade fair city; Battle of Nations 1813; Bach was Cantor here.'),
  Place(continent:'Europe', name:'Nuremberg', modernCountry:'Germany', iso3:'DEU', state:'Bavaria', subState:'Middle Franconia', county:'Nuremberg',
    historicalContext:'Imperial free city; site of Nazi war crimes trials.',
    colonizer:'Holy Roman Empire', romanizedNative:'Nürnberg'),
  Place(continent:'Europe', name:'Königsberg', modernCountry:'Germany', iso3:'DEU', state:'East Prussia',
    historicalContext:'Former Prussian capital; now Kaliningrad, Russia. Many German genealogical records.',
    colonizer:'Teutonic Knights, Prussia', nativeTribes:'Baltic Prussians', romanizedNative:'Kaliningrad',
    validTo:'1946-04-04T00:00:00.000Z'),

  // ── Greece ───────────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Athens', modernCountry:'Greece', iso3:'GRC', state:'Attica',
    historicalContext:'Birthplace of democracy; under Ottoman rule 1458–1833.',
    colonizer:'Roman Empire, Byzantine Empire, Ottoman Empire', nativeTribes:'Ancient Athenians', romanizedNative:'Athinai'),
  Place(continent:'Europe', name:'Thessaloniki', modernCountry:'Greece', iso3:'GRC', state:'Central Macedonia',
    historicalContext:'Major Byzantine city; large Sephardic Jewish community until WWII.',
    colonizer:'Roman Empire, Byzantine Empire, Ottoman Empire', nativeTribes:'Macedonians', romanizedNative:'Selanik'),

  // ── Hungary ──────────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Budapest', modernCountry:'Hungary', iso3:'HUN', state:'Budapest',
    historicalContext:'Union of Buda and Pest in 1873; capital of Kingdom of Hungary in Austro-Hungarian Empire.',
    colonizer:'Ottoman Empire, Habsburg Empire', nativeTribes:'Magyars, Avars, Celts', romanizedNative:'Aquincum'),
  Place(continent:'Europe', name:'Debrecen', modernCountry:'Hungary', iso3:'HUN', state:'Hajdú-Bihar County',
    historicalContext:'Protestant "Calvinist Rome" of Hungary; briefly capital in 1849 revolution.'),

  // ── Iceland ──────────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Reykjavik', modernCountry:'Iceland', iso3:'ISL', state:'Capital Region',
    historicalContext:'World\'s northernmost capital; settled by Norse Vikings ~870 AD.',
    nativeTribes:'Norse settlers (no indigenous population)', romanizedNative:'Reykjavík'),

  // ── Ireland ──────────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Dublin', modernCountry:'Ireland', iso3:'IRL', state:'Leinster', county:'Dublin',
    historicalContext:'Founded by Vikings; capital of British Ireland until 1922; major genealogy hub.',
    colonizer:'Norse Vikings, Anglo-Norman, British Empire', nativeTribes:'Gaels', romanizedNative:'Dubh Linn'),
  Place(continent:'Europe', name:'Cork', modernCountry:'Ireland', iso3:'IRL', state:'Munster', county:'Cork',
    historicalContext:'Second city of Ireland; major port for emigration during the Famine.',
    colonizer:'Norse Vikings, Anglo-Norman, British Empire', nativeTribes:'Gaels'),
  Place(continent:'Europe', name:'Galway', modernCountry:'Ireland', iso3:'IRL', state:'Connacht', county:'Galway',
    historicalContext:'Western gateway to Connaught; Gaeltacht Irish-speaking region nearby.',
    colonizer:'Anglo-Norman, British Empire', nativeTribes:'Gaels'),
  Place(continent:'Europe', name:'Limerick', modernCountry:'Ireland', iso3:'IRL', state:'Munster', county:'Limerick',
    historicalContext:'Viking-founded city on the Shannon; Treaty of Limerick 1691.',
    colonizer:'Norse Vikings, Anglo-Norman, British Empire', nativeTribes:'Gaels'),

  // ── Italy ────────────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Rome', modernCountry:'Italy', iso3:'ITA', state:'Lazio', county:'Rome',
    historicalContext:'Centre of the Roman Empire and Catholic Church; Vatican records vital for genealogy.',
    colonizer:'Roman Republic (expanded)', nativeTribes:'Latins, Sabines, Etruscans', romanizedNative:'Roma'),
  Place(continent:'Europe', name:'Milan', modernCountry:'Italy', iso3:'ITA', state:'Lombardy', county:'Milan',
    historicalContext:'Capital of the Duchy of Milan; under Spanish and Austrian rule before unification.',
    colonizer:'Roman Empire, Spanish Crown, Habsburg Austria', nativeTribes:'Celtic Insubres', romanizedNative:'Mediolanum'),
  Place(continent:'Europe', name:'Naples', modernCountry:'Italy', iso3:'ITA', state:'Campania', county:'Naples',
    historicalContext:'Capital of Kingdom of the Two Sicilies; major emigration source to Americas.',
    colonizer:'Greek colonists, Roman Empire, Spanish Crown', nativeTribes:'Oscans', romanizedNative:'Neapolis'),
  Place(continent:'Europe', name:'Venice', modernCountry:'Italy', iso3:'ITA', state:'Veneto', county:'Venice',
    historicalContext:'Republic of Venice lasted 1000+ years; major Mediterranean trading power.',
    colonizer:'Roman Empire (predecessor)', nativeTribes:'Veneti', romanizedNative:'Venetia'),
  Place(continent:'Europe', name:'Florence', modernCountry:'Italy', iso3:'ITA', state:'Tuscany', county:'Florence',
    historicalContext:'Medici seat; cradle of the Renaissance; Tuscany records among Italy\'s best preserved.',
    colonizer:'Roman Empire', nativeTribes:'Etruscans', romanizedNative:'Florentia'),
  Place(continent:'Europe', name:'Turin', modernCountry:'Italy', iso3:'ITA', state:'Piedmont', county:'Turin',
    historicalContext:'Capital of Kingdom of Sardinia; drove Italian unification in 1861.',
    colonizer:'Roman Empire, Duchy of Savoy', nativeTribes:'Ligurian Celts', romanizedNative:'Augusta Taurinorum'),
  Place(continent:'Europe', name:'Palermo', modernCountry:'Italy', iso3:'ITA', state:'Sicily', county:'Palermo',
    historicalContext:'Norman Kingdom of Sicily capital; Arab, Norman, and Spanish influences.',
    colonizer:'Phoenicians, Greeks, Romans, Arabs, Normans, Spanish', nativeTribes:'Sicani', romanizedNative:'Panormus'),
  Place(continent:'Europe', name:'Genoa', modernCountry:'Italy', iso3:'ITA', state:'Liguria', county:'Genoa',
    historicalContext:'Republic of Genoa rivalled Venice; founded Columbus and major banking dynasties.',
    colonizer:'Roman Empire', nativeTribes:'Ligurians', romanizedNative:'Genua'),
  Place(continent:'Europe', name:'Bologna', modernCountry:'Italy', iso3:'ITA', state:'Emilia-Romagna', county:'Bologna',
    historicalContext:'Home of world\'s oldest university (1088); Papal States territory.',
    colonizer:'Roman Empire, Papal States', nativeTribes:'Celtic Boii', romanizedNative:'Bononia'),

  // ── Latvia ───────────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Riga', modernCountry:'Latvia', iso3:'LVA', state:'Riga Region',
    historicalContext:'Hanseatic city; under German, Swedish, Russian, and Soviet rule.',
    colonizer:'Teutonic Knights, Sweden, Russian Empire', nativeTribes:'Latvians (Baltic)', romanizedNative:'Riga'),

  // ── Liechtenstein ────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Vaduz', modernCountry:'Liechtenstein', iso3:'LIE', state:'Vaduz',
    historicalContext:'Capital of the Principality of Liechtenstein since 1719.',
    colonizer:'Holy Roman Empire, Habsburg Austria'),

  // ── Lithuania ────────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Vilnius', modernCountry:'Lithuania', iso3:'LTU', state:'Vilnius County',
    historicalContext:'Capital of the Grand Duchy of Lithuania; significant Jewish (Litvak) community.',
    colonizer:'Polish-Lithuanian Commonwealth, Russian Empire', nativeTribes:'Lithuanians (Baltic)', romanizedNative:'Wilno / Wilna'),
  Place(continent:'Europe', name:'Kaunas', modernCountry:'Lithuania', iso3:'LTU', state:'Kaunas County',
    historicalContext:'Temporary capital during interwar period when Vilnius was under Polish control.',
    colonizer:'Russian Empire', romanizedNative:'Kovno'),

  // ── Luxembourg ───────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Luxembourg City', modernCountry:'Luxembourg', iso3:'LUX', state:'Luxembourg District',
    historicalContext:'Capital of Grand Duchy; fortress city passed between Habsburg, French, and Prussian control.',
    colonizer:'Habsburg Empire, France', nativeTribes:'Celtic Treveri'),

  // ── Malta ─────────────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Valletta', modernCountry:'Malta', iso3:'MLT', state:'South Eastern Region',
    historicalContext:'Capital founded by Knights of St. John 1566; British colony 1800–1964.',
    colonizer:'Knights of St. John, British Empire', nativeTribes:'Phoenicians, Romans', romanizedNative:'Valletta'),

  // ── Moldova ──────────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Chișinău', modernCountry:'Moldova', iso3:'MDA', state:'Chișinău Municipality',
    historicalContext:'Capital of Moldovan SSR; formerly part of Romania; large Jewish community historically.',
    colonizer:'Ottoman Empire, Russian Empire', romanizedNative:'Kishinev'),

  // ── Monaco ───────────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Monaco', modernCountry:'Monaco', iso3:'MCO', state:'Monaco',
    historicalContext:'Principality ruled by Grimaldi family since 1297.',
    colonizer:'Genoese Republic'),

  // ── Montenegro ───────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Podgorica', modernCountry:'Montenegro', iso3:'MNE', state:'Podgorica Municipality',
    historicalContext:'Capital of Montenegro; Ottoman and Yugoslav periods evident in records.',
    colonizer:'Ottoman Empire', romanizedNative:'Titograd'),

  // ── Netherlands ──────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Amsterdam', modernCountry:'Netherlands', iso3:'NLD', state:'North Holland', county:'Amsterdam',
    historicalContext:'Capital of Dutch Republic; major colonial and trade empire base.',
    colonizer:'Spanish Netherlands (resisted)', nativeTribes:'Frisians, Batavians', romanizedNative:'Amstelodamum'),
  Place(continent:'Europe', name:'The Hague', modernCountry:'Netherlands', iso3:'NLD', state:'South Holland',
    historicalContext:'Seat of Dutch government and parliament; home of International Court of Justice.'),
  Place(continent:'Europe', name:'Rotterdam', modernCountry:'Netherlands', iso3:'NLD', state:'South Holland', county:'Rotterdam',
    historicalContext:'World\'s busiest port for much of 20th century; emigration gateway to Americas.'),
  Place(continent:'Europe', name:'Utrecht', modernCountry:'Netherlands', iso3:'NLD', state:'Utrecht',
    historicalContext:'Treaty of Utrecht 1713; historic bishopric and university city.'),

  // ── North Macedonia ──────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Skopje', modernCountry:'North Macedonia', iso3:'MKD', state:'Skopje Region',
    historicalContext:'Capital; under Ottoman rule for 500 years; birthplace of Mother Teresa.',
    colonizer:'Byzantine Empire, Ottoman Empire', nativeTribes:'Macedonians', romanizedNative:'Scupi'),

  // ── Norway ───────────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Oslo', modernCountry:'Norway', iso3:'NOR', state:'Oslo',
    historicalContext:'Capital of Norway; in union with Denmark until 1814, then Sweden until 1905.',
    nativeTribes:'Norse Vikings, Sámi (north)', romanizedNative:'Christiania / Kristiania'),
  Place(continent:'Europe', name:'Bergen', modernCountry:'Norway', iso3:'NOR', state:'Vestland',
    historicalContext:'Former capital; Hanseatic League German quarter; gateway to Norwegian fjords.',
    colonizer:'Hanseatic League (merchant quarter)', nativeTribes:'Norse Vikings'),

  // ── Poland ───────────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Warsaw', modernCountry:'Poland', iso3:'POL', state:'Masovian Voivodeship', county:'Warsaw',
    historicalContext:'Capital of Poland; partitioned between Prussia, Russia, Austria 1795–1918; WW2 ghetto.',
    colonizer:'Prussia, Russian Empire, Nazi Germany', nativeTribes:'Mazovian Poles', romanizedNative:'Warszawa'),
  Place(continent:'Europe', name:'Kraków', modernCountry:'Poland', iso3:'POL', state:'Lesser Poland Voivodeship', county:'Kraków',
    historicalContext:'Medieval capital of Poland; Wawel Castle; Jewish Kazimierz district.',
    colonizer:'Habsburg Austria (partition era)', nativeTribes:'Vistulans', romanizedNative:'Cracovia'),
  Place(continent:'Europe', name:'Gdańsk', modernCountry:'Poland', iso3:'POL', state:'Pomeranian Voivodeship', county:'Gdańsk',
    historicalContext:'Free City of Danzig 1919–1939; German majority; WW2 began here.',
    colonizer:'Teutonic Knights, Prussia, Nazi Germany', nativeTribes:'Pomeranians', romanizedNative:'Danzig'),
  Place(continent:'Europe', name:'Wrocław', modernCountry:'Poland', iso3:'POL', state:'Lower Silesian Voivodeship', county:'Wrocław',
    historicalContext:'Historically German Breslau; Silesia transferred to Poland in 1945.',
    colonizer:'Habsburg Austria, Kingdom of Prussia', nativeTribes:'Silesian Slavs', romanizedNative:'Breslau'),
  Place(continent:'Europe', name:'Łódź', modernCountry:'Poland', iso3:'POL', state:'Łódź Voivodeship',
    historicalContext:'Major textile city; large Jewish community; Łódź Ghetto in WWII.',
    colonizer:'Russian Empire (partition era)'),
  Place(continent:'Europe', name:'Lwów', modernCountry:'Poland', iso3:'POL', state:'Lwów Oblast',
    historicalContext:'Now Lviv, Ukraine; historically Polish, Austrian, and Ukrainian; shifted post-WWII.',
    colonizer:'Habsburg Austria', nativeTribes:'Ruthenians', romanizedNative:'Lemberg / Lwów',
    validTo:'1945-01-01T00:00:00.000Z'),

  // ── Portugal ─────────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Lisbon', modernCountry:'Portugal', iso3:'PRT', state:'Lisbon District',
    historicalContext:'Capital of global Portuguese Empire; 1755 earthquake destroyed most records.',
    colonizer:'Roman Empire, Moorish Caliphate', nativeTribes:'Lusitanians', romanizedNative:'Olisipo'),
  Place(continent:'Europe', name:'Porto', modernCountry:'Portugal', iso3:'PRT', state:'Porto District',
    historicalContext:'Portugal\'s second city; origin of the country\'s name; port wine trade.',
    colonizer:'Roman Empire, Suebi Kingdom', nativeTribes:'Callaeci', romanizedNative:'Portus Cale'),

  // ── Romania ──────────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Bucharest', modernCountry:'Romania', iso3:'ROU', state:'Ilfov County',
    historicalContext:'Capital of Romania; former Ottoman vassal state.',
    colonizer:'Ottoman Empire, Russian Empire', nativeTribes:'Dacians', romanizedNative:'București'),
  Place(continent:'Europe', name:'Cluj-Napoca', modernCountry:'Romania', iso3:'ROU', state:'Cluj County',
    historicalContext:'Historic Transylvanian city; under Hungarian and Austrian rule for centuries.',
    colonizer:'Habsburg Empire, Austro-Hungarian Empire', nativeTribes:'Dacians', romanizedNative:'Kolozsvár / Klausenburg'),

  // ── Russia ───────────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Moscow', modernCountry:'Russia', iso3:'RUS', state:'Moscow Oblast',
    historicalContext:'Capital of the Tsardom of Russia and Soviet Union; vast genealogical archives.',
    colonizer:'Mongol Empire (subjugated)', nativeTribes:'Eastern Slavs', romanizedNative:'Moskva'),
  Place(continent:'Europe', name:'Saint Petersburg', modernCountry:'Russia', iso3:'RUS', state:'Leningrad Oblast',
    historicalContext:'Founded 1703 by Peter the Great; renamed Petrograd 1914, Leningrad 1924, reverted 1991.',
    nativeTribes:'Ingrian Finns', romanizedNative:'Petrograd / Leningrad'),
  Place(continent:'Europe', name:'Novosibirsk', modernCountry:'Russia', iso3:'RUS', state:'Novosibirsk Oblast',
    historicalContext:'Siberia\'s largest city; founded 1893 on Trans-Siberian Railway route.'),
  Place(continent:'Europe', name:'Yekaterinburg', modernCountry:'Russia', iso3:'RUS', state:'Sverdlovsk Oblast',
    historicalContext:'Site of Romanov family execution 1918; Ural region industrial centre.',
    romanizedNative:'Sverdlovsk (Soviet era)'),
  Place(continent:'Europe', name:'Kazan', modernCountry:'Russia', iso3:'RUS', state:'Tatarstan Republic',
    historicalContext:'Capital of Tatar Khanate; conquered by Ivan the Terrible 1552; Tatar cultural centre.',
    nativeTribes:'Tatars', romanizedNative:'Qazan'),
  Place(continent:'Europe', name:'Kaliningrad', modernCountry:'Russia', iso3:'RUS', state:'Kaliningrad Oblast',
    historicalContext:'Formerly Königsberg, Prussia; transferred to USSR after WWII; German records remain.',
    colonizer:'Teutonic Knights, Kingdom of Prussia', nativeTribes:'Baltic Old Prussians', romanizedNative:'Königsberg'),

  // ── San Marino ───────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'San Marino', modernCountry:'San Marino', iso3:'SMR', state:'San Marino',
    historicalContext:'World\'s oldest republic, traditionally founded 301 AD.',
    colonizer:'Papal States (surrounded by)'),

  // ── Serbia ───────────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Belgrade', modernCountry:'Serbia', iso3:'SRB', state:'Belgrade District',
    historicalContext:'Capital of Serbia; Ottoman rule 1521–1867; Yugoslavia capital 1918–1992.',
    colonizer:'Ottoman Empire, Austro-Hungarian Empire', nativeTribes:'Scordisci (Celtic-Illyrian)', romanizedNative:'Singidunum'),
  Place(continent:'Europe', name:'Novi Sad', modernCountry:'Serbia', iso3:'SRB', state:'South Bačka District',
    historicalContext:'Capital of Vojvodina; large Hungarian and German minority historically.',
    colonizer:'Ottoman Empire, Habsburg Empire'),

  // ── Slovakia ─────────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Bratislava', modernCountry:'Slovakia', iso3:'SVK', state:'Bratislava Region',
    historicalContext:'Capital of Kingdom of Hungary 1536–1783 when Buda was under Ottoman rule.',
    colonizer:'Habsburg Empire', nativeTribes:'Celtic Boii', romanizedNative:'Pressburg / Pozsony'),

  // ── Slovenia ─────────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Ljubljana', modernCountry:'Slovenia', iso3:'SVN', state:'Ljubljana Urban Municipality',
    historicalContext:'Capital of Slovenia; long part of Habsburg Empire as Laibach.',
    colonizer:'Roman Empire, Habsburg Empire', nativeTribes:'Illyrians', romanizedNative:'Laibach'),

  // ── Spain ────────────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Madrid', modernCountry:'Spain', iso3:'ESP', state:'Community of Madrid',
    historicalContext:'Capital of the Spanish Empire; centre of colonial administration for the Americas.',
    colonizer:'Moorish Caliphate, Castile', nativeTribes:'Carpetani (Iberian)', romanizedNative:'Matrice'),
  Place(continent:'Europe', name:'Barcelona', modernCountry:'Spain', iso3:'ESP', state:'Catalonia', county:'Barcelonès',
    historicalContext:'Capital of Catalonia; Roman colony; centre of Catalan language and culture.',
    colonizer:'Roman Empire, Moorish Caliphate', nativeTribes:'Laietani (Iberian)', romanizedNative:'Barcino'),
  Place(continent:'Europe', name:'Seville', modernCountry:'Spain', iso3:'ESP', state:'Andalusia', county:'Seville',
    historicalContext:'Gateway for Spanish colonial trade with the Americas; Columbus sailed from here.',
    colonizer:'Roman Empire, Moorish Caliphate', nativeTribes:'Turdetani', romanizedNative:'Hispalis'),
  Place(continent:'Europe', name:'Valencia', modernCountry:'Spain', iso3:'ESP', state:'Valencian Community', county:'Valencia',
    historicalContext:'Kingdom of Valencia 1238–1707; major Mediterranean port.',
    colonizer:'Roman Empire, Moorish Caliphate', nativeTribes:'Edetani (Iberian)', romanizedNative:'Valentia'),
  Place(continent:'Europe', name:'Granada', modernCountry:'Spain', iso3:'ESP', state:'Andalusia', county:'Granada',
    historicalContext:'Last Moorish kingdom in Iberia; fell to Castile 1492; Alhambra palace.',
    colonizer:'Moorish Caliphate', nativeTribes:'Bastetani (Iberian)', romanizedNative:'Garnata'),
  Place(continent:'Europe', name:'Bilbao', modernCountry:'Spain', iso3:'ESP', state:'Basque Country', county:'Biscay',
    historicalContext:'Basque Country industrial centre; Basque language (Euskara) preserved here.',
    nativeTribes:'Basques (pre-Indo-European)', romanizedNative:'Bilbo'),

  // ── Sweden ───────────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Stockholm', modernCountry:'Sweden', iso3:'SWE', state:'Stockholm County',
    historicalContext:'Capital of Sweden and formerly of the Swedish Empire; Scandinavia\'s largest city.',
    nativeTribes:'Norse Svear', romanizedNative:'Stockholm'),
  Place(continent:'Europe', name:'Gothenburg', modernCountry:'Sweden', iso3:'SWE', state:'Västra Götaland County',
    historicalContext:'Sweden\'s second city; major emigration port — millions left for America via here.',
    nativeTribes:'Norse Geats', romanizedNative:'Göteborg'),
  Place(continent:'Europe', name:'Malmö', modernCountry:'Sweden', iso3:'SWE', state:'Skåne County',
    historicalContext:'Part of Denmark until 1658 when Scania was ceded to Sweden.',
    nativeTribes:'Norse Danes/Swedes'),

  // ── Switzerland ──────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Bern', modernCountry:'Switzerland', iso3:'CHE', state:'Canton of Bern',
    historicalContext:'Federal capital of Switzerland; founded 1191 by Dukes of Zähringen.',
    colonizer:'Holy Roman Empire', nativeTribes:'Celtic Helvetii'),
  Place(continent:'Europe', name:'Zurich', modernCountry:'Switzerland', iso3:'CHE', state:'Canton of Zurich',
    historicalContext:'Largest Swiss city; Calvin\'s Reformation base; major financial centre.',
    colonizer:'Roman Empire, Habsburg Austria', nativeTribes:'Celtic Helvetii', romanizedNative:'Turicum'),
  Place(continent:'Europe', name:'Geneva', modernCountry:'Switzerland', iso3:'CHE', state:'Canton of Geneva',
    historicalContext:'John Calvin\'s city; seat of international organisations; Huguenot refugee hub.',
    colonizer:'Roman Empire, Duchy of Savoy', nativeTribes:'Celtic Allobroges', romanizedNative:'Genava'),

  // ── Ukraine ──────────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Kyiv', modernCountry:'Ukraine', iso3:'UKR', state:'Kyiv Oblast',
    historicalContext:'Cradle of Eastern Slavic civilization; Kievan Rus capital; under Polish and Russian rule.',
    colonizer:'Mongol Empire, Polish-Lithuanian Commonwealth, Russian Empire', nativeTribes:'Eastern Slavs', romanizedNative:'Kiev'),
  Place(continent:'Europe', name:'Lviv', modernCountry:'Ukraine', iso3:'UKR', state:'Lviv Oblast',
    historicalContext:'Formerly Polish Lwów and Austrian Lemberg; multicultural city with Polish/Ukrainian/Jewish roots.',
    colonizer:'Polish Kingdom, Habsburg Austria', nativeTribes:'Ruthenians', romanizedNative:'Lemberg / Lwów'),
  Place(continent:'Europe', name:'Odessa', modernCountry:'Ukraine', iso3:'UKR', state:'Odessa Oblast',
    historicalContext:'Black Sea port founded 1794 by Russia; major Jewish community (Odessa pogrom).',
    colonizer:'Ottoman Empire, Russian Empire', nativeTribes:'Pontic Greeks, Tatars'),
  Place(continent:'Europe', name:'Kharkiv', modernCountry:'Ukraine', iso3:'UKR', state:'Kharkiv Oblast',
    historicalContext:'First capital of Soviet Ukraine 1917–1934; major industrial centre.',
    colonizer:'Russian Empire'),

  // ── United Kingdom ───────────────────────────────────────────────────────
  Place(continent:'Europe', name:'London', modernCountry:'United Kingdom', iso3:'GBR', state:'England', subState:'Greater London', county:'City of London',
    historicalContext:'Capital of Great Britain and its global Empire; founded by Romans as Londinium.',
    colonizer:'Roman Empire, Anglo-Saxons, Normans', nativeTribes:'Celtic Britons', romanizedNative:'Londinium'),
  Place(continent:'Europe', name:'Edinburgh', modernCountry:'United Kingdom', iso3:'GBR', state:'Scotland', county:'City of Edinburgh',
    historicalContext:'Capital of Scotland; seat of Stuart monarchy; Scottish records held at New Register House.',
    colonizer:'Roman Empire (frontier), Norman', nativeTribes:'Picts, Gaels', romanizedNative:'Dunedin'),
  Place(continent:'Europe', name:'Manchester', modernCountry:'United Kingdom', iso3:'GBR', state:'England', subState:'Greater Manchester', county:'Manchester',
    historicalContext:'Birthplace of the Industrial Revolution; major Irish immigrant destination.',
    colonizer:'Roman Empire', nativeTribes:'Celtic Brigantes', romanizedNative:'Mamucium'),
  Place(continent:'Europe', name:'Birmingham', modernCountry:'United Kingdom', iso3:'GBR', state:'England', subState:'West Midlands', county:'Birmingham',
    historicalContext:'Industrial heartland; "city of a thousand trades"; centre of metal manufacturing.',
    colonizer:'Anglo-Saxons', nativeTribes:'Celtic Mercians'),
  Place(continent:'Europe', name:'Liverpool', modernCountry:'United Kingdom', iso3:'GBR', state:'England', subState:'Merseyside', county:'Liverpool',
    historicalContext:'Major slave-trade port; largest Irish immigrant community outside Ireland.',
    colonizer:'Norman', nativeTribes:'Celtic Brigantes'),
  Place(continent:'Europe', name:'Glasgow', modernCountry:'United Kingdom', iso3:'GBR', state:'Scotland', county:'Glasgow City',
    historicalContext:'Scotland\'s largest city; industrial powerhouse; Highland and Irish migration hub.',
    nativeTribes:'Picts, Britons of Strathclyde'),
  Place(continent:'Europe', name:'Cardiff', modernCountry:'United Kingdom', iso3:'GBR', state:'Wales', county:'Cardiff',
    historicalContext:'Capital of Wales; coal export hub; Welsh-language records from 18th century.',
    colonizer:'Roman Empire, Norman, English Crown', nativeTribes:'Celtic Silures', romanizedNative:'Caerdydd'),
  Place(continent:'Europe', name:'Belfast', modernCountry:'United Kingdom', iso3:'GBR', state:'Northern Ireland', county:'County Antrim / County Down',
    historicalContext:'Capital of Northern Ireland; linen and shipbuilding industries; Titanic built here.',
    colonizer:'Norman, English/Scottish plantation', nativeTribes:'Gaels'),
  Place(continent:'Europe', name:'York', modernCountry:'United Kingdom', iso3:'GBR', state:'England', subState:'North Yorkshire', county:'York',
    historicalContext:'Roman capital of Britannia; Viking Jorvik; medieval walled city.',
    colonizer:'Roman Empire, Norse Vikings, Normans', nativeTribes:'Celtic Brigantes', romanizedNative:'Eboracum'),

  // ── Vatican City ─────────────────────────────────────────────────────────
  Place(continent:'Europe', name:'Vatican City', modernCountry:'Vatican City', iso3:'VAT', state:'Vatican City',
    historicalContext:'Seat of the Catholic Church; Vatican Archives contain centuries of genealogical records.',
    colonizer:'Papal States (historical predecessor)'),
];
