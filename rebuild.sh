#!/bin/bash
#
# Script needs to:
# 1. Import schema to MySQL
# 2. Download/decompress/convert data from eddb/edsm
# 3. Get data into database via mysqlimport
# 4. Execute SQL code to build remaining tables
#
if [ ! -f ./mysqlinfo.txt ]; then
	echo "MySQL info not found, exiting"
	exit 1
fi
source ./mysqlinfo.txt
echo "Importing Schema"
mysql -u $mysqluser -p$mysqlpass -h $mysqlhost -D $mysqldb < ed_schema.sql
mysql -u $mysqluser -p$mysqlpass -h $mysqlhost -D $mysqldb < ed_import_schema.sql
echo "Downloading data files"
if [ ! -f ./factions.csv ]; then
	wget -O - -S --header="accept-encoding: gzip" https://eddb.io/archive/v6/factions.csv | gzip -dc | tail -n +2 > factions.csv
fi
if [ ! -f ./listings.csv ]; then
	wget -O - -S --header="accept-encoding: gzip" https://eddb.io/archive/v6/listings.csv | gzip -dc | tail -n +2 > listings.csv
fi
if [ ! -f ./systems_import.csv ]; then
	wget -O - -S --header="accept-encoding: gzip" https://eddb.io/archive/v6/systems.csv | gzip -dc | tail -n +2 | split -d -l 10000000 - systems_import.csv
	touch systems_import.csv
fi
# TODO get category from commodities.json into seperate table
if [ ! -f ./commodities.csv ]; then
	wget -O - -S --header="accept-encoding: gzip" https://eddb.io/archive/v6/commodities.json | gzip -dc | json2csv/bin/json2csv.js -f "id","name","category_id","average_price","is_rare","max_buy_price","max_sell_price","min_buy_price","min_sell_price","buy_price_lower_average","sell_price_upper_average","is_non_marketable","ed_id" | tail -n +2 > commodities.csv
fi
# TODO get group from modules.json into seperate table
if [ ! -f ./modules.csv ]; then
	wget -O - -S --header="accept-encoding: gzip" https://eddb.io/archive/v6/modules.json | gzip -dc | json2csv/bin/json2csv.js -f "id","group_id","class","rating","price","weapon_mode","missile_type","name","belongs_to","ed_id","ed_symbol","ship" | tail -n +2 > modules.csv
fi
# Missing fields on stations:
# "import_commodities","export_commodities","prohibited_commodities","economies","selling_ships","selling_modules"
if [ ! -f ./stations_import.csv ]; then
	wget -O - -S --header="accept-encoding: gzip" https://eddb.io/archive/v6/stations.json | gzip -dc | json2csv/bin/json2csv.js -f "id","name","system_id","updated_at","max_landing_pad_size","distance_to_star","government_id","allegiance_id","state_id","type_id","type","has_blackmarket","has_market","has_refuel","has_repair","has_rearm","has_outfitting","has_shipyard","has_docking","has_commodities","shipyard_updated_at","outfitting_updated_at","market_updated_at","is_planetary","settlement_size_id","settlement_size","settlement_security_id","settlement_security","body_id","controlling_minor_faction_id" | tail -n +2 > stations_import.csv
fi
# Missing fields in bodies:
# "discovery","parents","belts"
if [ ! -f ./bodies.csv ]; then
	wget -O - -S --header="accept-encoding: gzip" https://eddb.io/archive/v6/bodies_recently.jsonl | gzip -dc | json2csv/bin/json2csv.js -f "id","bodyId","name","type","subType","offset","distanceToArrival","isMainStar","isScoopable","age","spectralClass","luminosity","absoluteMagnitude","solarMasses","solarRadius","surfaceTemperature","orbitalPeriod","semiMajorAxis","orbitalEccentricity","orbitalInclination","argOfPeriapsis","rotationalPeriod","rotationalPeriodTidallyLocked","axialTilt","updateTime","systemId" | tail -n +2 | split -d -l 10000000 - bodies.csv
	touch bodies.csv
fi
echo "Loading data into MySQL"
# Import table loads
mysqlimport --local --fields-terminated-by=',' --lines-terminated-by='\n' --ignore -u $mysqluser -p$mysqlpass -h $mysqlhost $mysqldb systems_import.csv*
mysqlimport --local --fields-terminated-by=',' --lines-terminated-by='\n' --ignore -u $mysqluser -p$mysqlpass -h $mysqlhost $mysqldb stations_import.csv
# Direct table loads
mysqlimport --local --fields-terminated-by=',' --lines-terminated-by='\n' --ignore -u $mysqluser -p$mysqlpass -h $mysqlhost -c eddb_id,name,updated_at,government_id,allegiance_id,state_id,home_system_id,is_player_faction $mysqldb factions.csv
mysqlimport --local --fields-terminated-by=',' --lines-terminated-by='\n' --ignore -u $mysqluser -p$mysqlpass -h $mysqlhost -c eddb_id,station_id,commodity_id,supply,supply_bracket,buy_price,sell_price,demand,demand_bracket,collected_at $mysqldb listings.csv
mysqlimport --local --fields-terminated-by=',' --lines-terminated-by='\n' --ignore -u $mysqluser -p$mysqlpass -h $mysqlhost -c eddb_id,name,category_id,average_price,is_rare,max_buy_price,max_sell_price,min_buy_price,min_sell_price,buy_price_lower_average,sell_price_upper_average,is_non_marketable,ed_id $mysqldb commodities.csv
mysqlimport --local --fields-terminated-by=',' --lines-terminated-by='\n' --ignore -u $mysqluser -p$mysqlpass -h $mysqlhost -c eddb_id,group_id,class,rating,price,weapon_mode,missile_type,name,belongs_to,ed_id,ed_symbol,ship $mysqldb modules.csv
mysqlimport --local --fields-terminated-by=',' --lines-terminated-by='\n' --ignore -u $mysqluser -p$mysqlpass -h $mysqlhost -c eddb_id,bodyId,name,type,subType,offset,distanceToArrival,isMainStar,isScoopable,age,spectralClass,luminosity,absoluteMagnitude,solarMasses,solarRadius,surfaceTemperature,orbitalPeriod,semiMajorAxis,orbitalEccentricity,orbitalInclination,argOfPeriapsis,rotationalPeriod,rotationalPeriodTidallyLocked,axialTilt,updateTime,systemId $mysqldb bodies.csv*
echo "Building extra tables and cleaning up"
mysql -u $mysqluser -p$mysqlpass -h $mysqlhost -D $mysqldb < rebuild.sql
echo "Rebuild script complete"
