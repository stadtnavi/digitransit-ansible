-- ---------------------------------------------------------------------------
--
-- Theme: stadtnavi
-- Topic: pois
--
-- ---------------------------------------------------------------------------

local themepark, theme, cfg = ...

local parser = require 'themepark/parser'

local csv = require('lua-csv/csv')

themepark:add_table{
    name = 'pois',
    ids_type = 'any',
    geom = 'point',
    columns = themepark:columns({
        { column = 'category1',     type = 'text', not_null = true },
        { column = 'category2',     type = 'text', not_null = true },
        { column = 'category3',     type = 'text' },
        { column = 'name',          type = 'text' }, -- filled if attribute class "name" is set
        { column = 'website',       type = 'text' }, -- filled if attribute class "contact" is set
        { column = 'phone',         type = 'text' }, -- filled if attribute class "contact" is set
        { column = 'email',         type = 'text' }, -- filled if attribute class "contact" is set
        { column = 'address',       type = 'text' }, -- filled if attribute class "address" is set
        { column = 'wheelchair',    type = 'text' }, -- filled if attribute class "wheelchair" is set
        { column = 'opening_hours', type = 'text' }, -- filled if attribute class "opening_hours" is set
        { column = 'cuisine',       type = 'text' }, -- filled if attribute class "cuisine" is set
        { column = 'brand',         type = 'text' }, -- filled if attribute class "brand" is set
        { column = 'operator',      type = 'text' }, -- filled if attribute class "operator" is set
        { column = 'fee',           type = 'boolean' }, -- filled if attribute class "fee" is set
    }),
}

local map_columns = {
    ['Oberkategorie Code'] = 'category1',
    ['Kategorie Code'] = 'category2',
    ['Unterkategorie Code'] = 'category3',
    ['OSM-Filter'] = 'condition',
    Eigenschaften = 'attributes',
}

local function read_config(filename)
    local config = {}

    local f = csv.open(filename, {
        header = true,
        separator = ',',
    })
    for fields in f:lines() do
        local cfg = {}
        for k, v in pairs(map_columns) do
            cfg[v] = fields[k]
        end
        config[#config + 1] = cfg
    end

    return config
end

local poi_config = read_config(cfg.config)

-- ---------------------------------------------------------------------------

local map_attributes = {
    ['küche'] = 'cuisine',
    ['Öffnungszeiten'] = 'opening_hours',
    adresse = 'address',
    brand = 'brand',
    email = 'contact',
    kostenpflichtig = 'fee',
    name = 'name',
    operator = 'operator',
    rollstuhlzugang = 'wheelchair',
    telefon = 'contact',
    telefonnummer = 'contact',
    url = 'contact',
}

local line = 1 -- start at 1 because first line had column headers
for _, d in ipairs(poi_config) do
    line = line + 1

--    print(d.category1, d.category2, d.category3, d.condition, d.attributes)

    local status, match = pcall(parser.parse, d.condition)
    if status then
        d.match = match

        local attribute_list = osm2pgsql.split_string(d.attributes, ',')
        d.attr = {}
        for _, a in ipairs(attribute_list) do
            d.attr[map_attributes[a:lower()] or ''] = true
        end
    else
        print("Ignoring category in line " .. line .. ": " .. match)
    end
end

-- ---------------------------------------------------------------------------
-- Functions for attribute extractions. These can be changed as needed.
-- ---------------------------------------------------------------------------

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

    cuisine = function(tags)
        return tags.cuisine
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

-- Matches columns in the output table to the attribute classifier
local attribute_columns = {
    address       = 'address',
    brand         = 'brand',
    cuisine       = 'cuisine',
    email         = 'contact',
    fee           = 'fee',
    name          = 'name',
    opening_hours = 'opening_hours',
    operator      = 'operator',
    phone         = 'contact',
    website       = 'contact',
    wheelchair    = 'wheelchair',
}

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
                if d.attr[attr] then
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
