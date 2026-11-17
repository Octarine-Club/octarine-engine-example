-- scripts/lib/jungle_tilemap.lua
-- Builds chunked TilemapSystem data over `tilemaps/jungle.png` (320x96, 10x3 grid of 32x32 tiles)
-- incorporating the classic 25x20 `tilemaps/jungle.map` layout into stitchable 16x16 chunks
-- with semantic IntGrid collision channels and dynamic `Tree` props.

local M = {}

local TILE_COLS = 10
local TILE_SIZE = 32
local CHUNK_W   = 16
local CHUNK_H   = 16

-- Original 25x20 tilemap matrix from tilemaps/jungle.map (preserved in Lua so shipped .pak bundles
-- load without requiring loose .map files on disk).
M.CLASSIC_JUNGLE_MAP = {
    {21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21},
    {21,21,21,17,18,21,21,21,21,21,21,17,13,13,13,13,13,13,13,13,13,13,18,21,21},
    {21,21,21,16,19,21,21,21,21,21,21,11,25,26,08,25,26,15,09,10,08,08,14,18,21},
    {21,21,21,21,21,21,21,21,21,21,21,11,08,15,09,09,09,19,21,11,08,08,08,22,21},
    {21,21,21,21,21,21,21,21,21,21,21,11,08,14,18,21,21,21,21,11,08,08,08,22,21},
    {21,21,21,21,21,21,17,13,18,17,13,12,25,01,22,21,21,21,21,16,09,09,09,19,21},
    {21,21,21,21,21,21,11,08,22,11,08,02,25,07,14,13,18,21,21,21,17,13,13,18,21},
    {21,17,13,13,13,13,12,08,14,12,00,15,09,10,07,02,14,13,18,21,11,08,08,22,21},
    {21,11,15,09,09,09,10,25,07,00,08,22,21,16,10,04,08,08,22,21,11,08,08,22,21},
    {21,11,22,21,21,21,16,10,07,00,00,14,13,13,12,08,15,09,19,21,16,09,09,19,21},
    {21,11,22,21,21,21,21,11,28,27,04,20,01,06,08,15,19,21,21,21,17,13,13,13,18},
    {21,11,22,21,21,21,21,16,09,10,08,07,00,00,03,14,13,13,13,13,12,20,01,02,22},
    {21,11,22,21,21,21,21,21,21,11,08,00,00,00,04,08,08,08,08,08,08,07,00,03,22},
    {21,11,22,21,21,21,21,21,21,16,09,09,09,09,09,09,10,15,09,09,10,06,05,04,22},
    {17,12,14,13,18,21,21,21,21,21,21,21,21,21,21,21,16,19,21,21,16,09,09,09,19},
    {11,03,07,00,22,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21},
    {11,03,07,00,22,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21},
    {11,04,06,00,22,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21},
    {16,09,09,09,19,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21},
    {21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21},
}

local function collision_for_tile(tile_idx)
    if tile_idx == 21 or (tile_idx >= 9 and tile_idx <= 19) or tile_idx == 22 then
        return tilemap.TILE_CHASM
    elseif tile_idx == 25 or tile_idx == 26 then
        return tilemap.TILE_SOLID
    elseif tile_idx == 27 or tile_idx == 28 or tile_idx == 29 then
        return tilemap.TILE_WALL
    elseif tile_idx == 23 or tile_idx == 24 then
        return tilemap.TILE_SURFACE
    end
    return tilemap.TILE_EMPTY
end

local function make_template(id, biome, weight, tile_fn, extra_props)
    local tiles = {}
    local collisions = {}
    local props = {}

    for gy = 0, CHUNK_H - 1 do
        for gx = 0, CHUNK_W - 1 do
            local tidx = tile_fn(gx, gy)
            local tx = tidx % TILE_COLS
            local ty = math.floor(tidx / TILE_COLS)
            tiles[#tiles + 1] = {
                gx    = gx,
                gy    = gy,
                src_x = tx * TILE_SIZE,
                src_y = ty * TILE_SIZE,
            }
            collisions[gy * CHUNK_W + gx + 1] = collision_for_tile(tidx)
        end
    end

    if extra_props then
        for _, p in ipairs(extra_props) do
            props[#props + 1] = p
        end
    end

    return {
        id            = id,
        grid_width    = CHUNK_W,
        grid_height   = CHUNK_H,
        weight        = weight,
        biome         = biome,
        edge_north    = "open",
        edge_east     = "open",
        edge_south    = "open",
        edge_west     = "open",
        static_layers = {
            {
                name         = "Ground",
                tileset      = "tilemap-texture",
                render_layer = 0,
                render_depth = 0.0,
                tiles        = tiles,
            },
        },
        collisions = collisions,
        props      = props,
    }
end

local function build_templates()
    -- Template 1: Main island sampled directly from CLASSIC_JUNGLE_MAP cols 6..21, rows 2..17
    local tmpl_outpost = make_template("jungle_outpost", "jungle_island", 1.5, function(gx, gy)
        local map_row = M.CLASSIC_JUNGLE_MAP[gy + 3]
        if map_row then
            local v = map_row[gx + 7]
            if v ~= nil then return v end
        end
        return 0
    end, {
        { id = "Tree", x = 11 * TILE_SIZE + 8, y = 7 * TILE_SIZE,  width = 16, height = 32, fields = { kind = "palm" } },
        { id = "Tree", x = 14 * TILE_SIZE + 8, y = 10 * TILE_SIZE, width = 16, height = 32, fields = { kind = "palm" } },
        { id = "Tree", x = 8 * TILE_SIZE + 8,  y = 11 * TILE_SIZE, width = 16, height = 32, fields = { kind = "palm" } },
    })

    -- Template 2: River bridge crossing with stone cover & thicket barricades
    local tmpl_crossing = make_template("river_crossing", "river_delta", 1.0, function(gx, gy)
        -- Vertical river along cols 4..5 with a grass bridge across rows 6..9
        if (gx == 4 or gx == 5) and (gy < 6 or gy > 9) then
            return 21
        end
        if gx == 3 and (gy < 6 or gy > 9) then return 22 end
        if gx == 6 and (gy < 6 or gy > 9) then return 11 end
        if (gx == 4 or gx == 5) and (gy == 6 or gy == 9) then return 23 end
        if (gx == 10 or gx == 11) and (gy == 3 or gy == 12) then return 25 end
        if (gx == 12) and (gy == 4 or gy == 11) then return 27 end
        return ((gx + gy) % 5)
    end, {
        { id = "Tree", x = 2 * TILE_SIZE + 8,  y = 3 * TILE_SIZE,  width = 16, height = 32, fields = { kind = "palm" } },
        { id = "Tree", x = 13 * TILE_SIZE + 8, y = 8 * TILE_SIZE,  width = 16, height = 32, fields = { kind = "palm" } },
        { id = "Tree", x = 9 * TILE_SIZE + 8,  y = 13 * TILE_SIZE, width = 16, height = 32, fields = { kind = "palm" } },
    })

    -- Template 3: Highland clearing with rock clusters & wildflower pads
    local tmpl_highland = make_template("highland_clearing", "highland", 1.2, function(gx, gy)
        if (gx == 3 and gy == 3) or (gx == 12 and gy == 4) or (gx == 7 and gy == 12) then
            return 26
        end
        if (gx == 4 and gy == 11) or (gx == 11 and gy == 10) then
            return 28
        end
        if (gx >= 6 and gx <= 9) and (gy >= 6 and gy <= 8) then
            return 24
        end
        return ((gx * 3 + gy * 7) % 8)
    end, {
        { id = "Tree", x = 5 * TILE_SIZE + 8,  y = 2 * TILE_SIZE,  width = 16, height = 32, fields = { kind = "palm" } },
        { id = "Tree", x = 13 * TILE_SIZE + 8, y = 4 * TILE_SIZE,  width = 16, height = 32, fields = { kind = "palm" } },
        { id = "Tree", x = 3 * TILE_SIZE + 8,  y = 13 * TILE_SIZE, width = 16, height = 32, fields = { kind = "palm" } },
    })

    return { tmpl_outpost, tmpl_crossing, tmpl_highland }
end

function M.mount(opts)
    opts = opts or {}
    local on_tree_harvest = opts.on_tree_harvest

    -- Must register prop spawner BEFORE load_data because load_data populates active chunks immediately.
    tilemap.set_prop_spawner(function(id, worldX, worldY, fields, chunkX, chunkY, propIndex)
        if id ~= "Tree" then
            return nil
        end
        return load_entity({
            tag = "tree_prop",
            entity_mask = 2,
            components = {
                transform = { position = { x = worldX, y = worldY }, scale = { x = 1.5, y = 1.5 } },
                sprite = {
                    texture_asset_id = "tree",
                    width            = 16,
                    height           = 32,
                    layer            = 3,
                },
                box_collider = {
                    width          = 16,
                    height         = 24,
                    offset         = { x = 0, y = 4 },
                    collision_mask = 4,
                },
                chunk_resident = {
                    chunk_x    = chunkX,
                    chunk_y    = chunkY,
                    prop_index = propIndex,
                },
                script = {
                    cx = chunkX,
                    cy = chunkY,
                    pidx = propIndex,
                    harvested = false,
                    on_collision = function(self, entity, other)
                        if self.harvested then return end
                        self.harvested = true
                        tilemap.mark_prop_consumed(self.cx, self.cy, self.pidx)
                        if on_tree_harvest then
                            on_tree_harvest(worldX, worldY, self.cx, self.cy, self.pidx)
                        end
                        blam(entity)
                    end,
                },
            },
        })
    end)

    local data = {
        source_format     = "lua_data",
        tile_size         = TILE_SIZE,
        chunk_grid_width  = CHUNK_W,
        chunk_grid_height = CHUNK_H,
        tilesets = {
            {
                id        = "tilemap-texture",
                file      = "tilemaps/jungle.png",
                width     = 320,
                height    = 96,
                tile_size = TILE_SIZE,
            },
        },
        templates = build_templates(),
    }

    local ok = tilemap.load_data(data, {
        stitch_mode   = opts.stitch_mode or settings.get("preferred_stitch", "toroidal"),
        seed          = opts.seed or 2026,
        load_radius   = opts.load_radius or 1,
        unload_radius = opts.unload_radius or 2,
        tile_scale    = opts.tile_scale or 1.0,
    })
    return ok
end

return M
