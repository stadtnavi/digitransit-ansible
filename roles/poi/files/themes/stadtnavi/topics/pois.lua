-- ---------------------------------------------------------------------------
--
-- Theme: stadtnavi
-- Topic: pois
--
-- ---------------------------------------------------------------------------

local themepark, theme, cfg = ...

local parser = require 'themepark/parser'

local csv = require('lua-csv/csv')

-- ---------------------------------------------------------------------------

-- Map column names from the one used in the config to the internal one.
local map_columns = {
    ['Layer-Typ']           = 'layer_type',
    ['Oberkategorie Code']  = 'category1',
    ['Kategorie Code']      = 'category2',
    ['Unterkategorie Code'] = 'category3',
    ['OSM-Filter']          = 'condition',
    ['Eigenschaften']       = 'attributes',
}

-- Matches columns in the output table to the attribute class and type.
-- (Default type is 'text'.)
local attribute_columns = {
    address        = { class = 'address' },
    brand          = { class = 'brand' },
    changing_table = { class = 'changing_table' },
    cuisine        = { class = 'cuisine' },
    drinking_water = { class = 'drinking_water', type = 'boolean' },
    email          = { class = 'contact' },
    fee            = { class = 'fee', type = 'boolean' },
    name           = { class = 'name' },
    opening_hours  = { class = 'opening_hours' },
    operator       = { class = 'operator' },
    phone          = { class = 'contact' },
    website        = { class = 'contact' },
    wheelchair     = { class = 'wheelchair' },
}

-- Functions for attribute extraction.
local extract = {
    address = function(tags)
        if tags['addr:street'] and tags['addr:housenumber'] and tags['addr:postcode'] and tags['addr:city'] then
            return tags['addr:street'] .. ' ' ..
                   tags['addr:housenumber'] .. ', ' ..
                   tags['addr:postcode'] .. ' ' ..
                   tags['addr:city']
        end
    end,

    brand = function(tags)
        return tags.brand
    end,

    changing_table = function(tags)
        local value = tags['toilets:changing_table'] or tags.changing_table

        if value == 'no' then
            return nil
        end

        return value
    end,

    cuisine = function(tags)
        return tags.cuisine
    end,

    drinking_water = function(tags)
        return (tags.drinking_water == 'yes' and not tags['drinking_water:legal'] == 'no')
               or tags['drinking_water:legal'] == 'yes'
    end,

    email = function(tags)
        local email = tags.email or tags['contact:email']

        if email and email:match('^.+@[%a%d.-]+$') then
            return email
        end
    end,

    fee = function(tags)
        if tags.fee == 'yes' then
            return true
        end
        if tags.fee == 'no' then
            return false
        end
    end,

    name = function(tags)
        return tags.name or tags['name:de']
    end,

    opening_hours = function(tags)
        return tags.opening_hours
    end,

    operator = function(tags)
        return tags.operator
    end,

    phone = function(tags)
        local phone = tags.phone or tags['contact:phone']

        if phone and phone:match('^[%d +/.()-]+$') then
            return phone
        end
    end,

    website = function(tags)
        local website = tags.website or tags['contact:website'] or tags.url

        if website and website:match('^https?://') then
            return website
        end
    end,

    wheelchair = function(tags)
        local wheelchair_access = {
            yes     = 'yes',
            no      = 'no',
            limited = 'limited',
        }

        return wheelchair_access[tags.wheelchair] or 'unknown'
    end,

}

-- ---------------------------------------------------------------------------

local function create_table()
    local attribute_keys = {}
    for k, _ in pairs(attribute_columns) do
        attribute_keys[#attribute_keys + 1] = k
    end
    table.sort(attribute_keys)

    local columns = {
        { column = 'category1', type = 'text', not_null = true },
        { column = 'category2', type = 'text', not_null = true },
        { column = 'category3', type = 'text' },
    }

    for _, k in ipairs(attribute_keys) do
        columns[#columns + 1] = {
            column = k, type = (attribute_columns[k].type or 'text')
        }
    end

    if themepark.debug then
        print("Table columns:")
        for _, column in ipairs(columns) do
            print("  " .. column.column .. " (" .. column.type .. ")")
        end
    end

    themepark:add_table{
        name = 'pois',
        ids_type = 'any',
        geom = 'point',
        columns = themepark:columns(columns)
    }
end

-- ---------------------------------------------------------------------------

local function read_config(filename)
    local config = {}

    local f = csv.open(filename, {
        header = true,
        separator = ',',
    })
    for fields in f:lines() do
        local config_entry = {}
        for k, v in pairs(map_columns) do
            config_entry[v] = fields[k]
        end
        config[#config + 1] = config_entry
    end

    return config
end

-- ---------------------------------------------------------------------------

local poi_config = read_config(cfg.config)

local line = 1 -- start at 1 because first line had column headers
for _, d in ipairs(poi_config) do
    line = line + 1

    if d.layer_type == 'poi_layer' then
        local status, match = pcall(parser.parse, d.condition)
        if status then
            d.match = match

            local attribute_list = osm2pgsql.split_string(d.attributes, ',')
            d.attributes = {}
            d.attribute_classes = {}
            for _, a in ipairs(attribute_list) do
                if a:match("^[a-z_]+$") then
                    d.attribute_classes[a] = true
                    d.attributes[#d.attributes + 1] = a
                else
                    print("WARNING: Ignored invalid attribute class in line " .. line .. ": '" .. a .. "'")
                end
            end
            table.sort(d.attributes)
        else
            print("Ignoring category in line " .. line .. ": " .. match)
        end
    end
end

if themepark.debug then
    print("Config:")
    for _, config in ipairs(poi_config) do
        print("  " .. config.category1 .. "/"
                   .. config.category2 .. "/"
                   .. config.category3  .. ";"
                   .. table.concat(config.attributes, ',') .. ";"
                   .. config.condition)
    end
end

local attribute_classes = {}
for k, v in pairs(attribute_columns) do
    attribute_classes[v.class] = k
end

-- Add ad-hoc attribute classes
for _, config in ipairs(poi_config) do
    for _, a in ipairs(config.attributes) do
        if not attribute_columns[a] and not attribute_classes[a] then
            print("Adding ad-hoc attribute class '" .. a .. "'.")
            attribute_columns[a] = { class = a }
            extract[a] = function(tags)
                local value = tags[a]

                if value == 'no' then
                    return nil
                end

                return value
            end
        end
    end
end

if themepark.debug then
    print("Columns and their attribute classes:")
    for a, v in pairs(attribute_columns) do
        print("  " .. a .. ": " .. v.class)
    end
end

create_table()

-- ---------------------------------------------------------------------------

local function process_object(object, geom)
    for _, d in ipairs(poi_config) do
        if d.match and d.match(object.tags) then
            local data = {
                geom       = geom,
                category1  = d.category1,
                category2  = d.category2,
                category3  = d.category3 or '',
            }

            for column, attr in pairs(attribute_columns) do
                if d.attribute_classes[attr.class] then
                    data[column] = extract[column](object.tags)
                end
            end

            themepark:insert('pois', data)
        end
    end
end

-- ---------------------------------------------------------------------------

themepark:add_proc('node', function(object)
    process_object(object, object:as_point())
end)

themepark:add_proc('way', function(object)
    process_object(object, object:as_linestring():centroid())
end)

themepark:add_proc('relation', function(object)
    if object.type == 'multipolygon' then
        process_object(object, object:as_multipolygon():centroid())
    end
end)

-- ---------------------------------------------------------------------------
