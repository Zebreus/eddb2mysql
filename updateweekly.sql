--
-- Script to update the database with new data
-- Delta fields, systems_recently.csv and bodies7days.json, are released weekly
-- The listings table is also rebuilt, it sees ~10% change per week
-- Also requires the ed_import_schema.sql file
--

-- Add import tables
SOURCE ed_import_schema.sql;
DROP TABLE stations_import;

-- Load CSV data
LOAD DATA LOCAL INFILE 'systems_recently.csv' INTO TABLE systems_import FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n' IGNORE 1 LINES;
LOAD DATA LOCAL INFILE 'bodies7days.csv' INTO TABLE bodies_import FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n' IGNORE 1 LINES;
FLUSH TABLE systems_import,listings_import,bodies_import;

-- listings table rebuild
TRUNCATE TABLE listings;
LOAD DATA LOCAL INFILE 'listings.csv' INTO TABLE listings(eddb_id,station_id,commodity_id,supply,supply_bracket,buy_price,sell_price,demand,demand_bracket,collected_at) FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n' IGNORE 1 LINES;
FLUSH TABLE listings;

-- Merge imported data with tables via DELETE+INSERT
DELETE FROM systems WHERE eddb_id IN (SELECT eddb_id FROM systems_import);
INSERT IGNORE INTO systems(eddb_id,edsm_id,name,x,y,z,population,is_populated,government_id,allegiance_id,state_id,security_id,primary_economy_id,power,power_state_id,needs_permit,updated_at,controlling_minor_faction_id,reserve_type_id) SELECT eddb_id,edsm_id,name,x,y,z,population,is_populated,government_id,allegiance_id,state_id,security_id,primary_economy_id,power,power_state_id,needs_permit,updated_at,controlling_minor_faction_id,reserve_type_id FROM systems_import;
DELETE FROM bodies WHERE eddb_id IN (SELECT eddb_id FROM bodies_import);
INSERT IGNORE INTO bodies(eddb_id,bodyId,name,type,subType,offset,distanceToArrival,isMainStar,isScoopable,age,spectralClass,luminosity,absoluteMagnitude,solarMasses,solarRadius,surfaceTemperature,orbitalPeriod,semiMajorAxis,orbitalEccentricity,orbitalInclination,argOfPeriapsis,rotationalPeriod,rotationalPeriodTidallyLocked,axialTilt,updateTime,systemId) SELECT * FROM bodies_import;
FLUSH TABLE systems,bodies;

-- Cleanup import data
DROP TABLE systems_import;

-- Re-index and optimize tables
-- Probably only needs to happen every other month or so, but keeping on every update for now
SET @newid=0;
UPDATE systems SET id=(@newid:=@newid+1) ORDER BY id;
SET @newid=0;
UPDATE bodies SET id=(@newid:=@newid+1) ORDER BY id;
OPTIMIZE TABLE listings,systems,bodies;
