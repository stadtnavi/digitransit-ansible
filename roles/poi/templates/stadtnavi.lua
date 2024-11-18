-- ---------------------------------------------------------------------------
--
-- Stadtnavi osm2pgsql-Config
--
-- Configuration for the osm2pgsql Themepark framework
--
-- ---------------------------------------------------------------------------

local themepark = require('themepark')

themepark.debug = false

-- All features in all tables get a unique ID
themepark:set_option('unique_id', 'id')

-- ---------------------------------------------------------------------------

-- Enable these to get tables with (more or less) raw OSM data for debugging
--themepark:add_topic('basic/generic-points')
--themepark:add_topic('basic/generic-lines')
--themepark:add_topic('basic/generic-polygons')

-- This is the actual configuration of the "pois" table
themepark:add_topic('stadtnavi/pois', { config = os.getenv("STADTNAVI_CONFIG") })

-- ---------------------------------------------------------------------------
