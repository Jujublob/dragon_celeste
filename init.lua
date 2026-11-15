-- ==============================================================================
-- CELESTIAL DRAGON MOD (dragon_celeste)
-- Copyright (c) 2026 Jujublob - Open Source (MIT License)
--
-- CREDITS & ATTRIBUTIONS:
-- • Dragon 3D model, dragon textures, and scale texture:
--   Created by ElCeejo for the "Draconis" mod (adapted and recolored).
-- • Dragon egg 3D model and texture:
--   Created by TNT42.dev for "dragon_celeste".
-- • Original armor textures:
--   Created by davidthecreator (sole texture author of "3d_armor")
--   (recolored and adapted for celestial armor).
-- ==============================================================================

local S = minetest.get_translator("dragon_celeste")
local modpath = minetest.get_modpath("dragon_celeste")

-- ==============================================================================
-- SETTINGS & CONSTANTS (read from settingtypes.txt)
-- ==============================================================================
local settings = minetest.settings

local BOOST_DURATION            = tonumber(settings:get("dragon_celeste_boost_time")) or 30
local BOOST_COOLDOWN            = tonumber(settings:get("dragon_celeste_boost_cooldown")) or 20
local ARMOR_REFLECT_PERCENT     = tonumber(settings:get("dragon_celeste_armor_reflect")) or 50
local ARMOR_DEFENSE             = tonumber(settings:get("dragon_celeste_armor_defense")) or 20
local SWORD_DAMAGE              = tonumber(settings:get("dragon_celeste_sword_damage")) or 100
local SWORD_DRAGON_DAMAGE       = tonumber(settings:get("dragon_celeste_sword_dragon_damage")) or 10000
local SWORD_OTHER_DRAGON_DAMAGE = tonumber(settings:get("dragon_celeste_sword_other_dragon_damage")) or 1000
local NATURAL_SPAWN             = settings:get_bool("dragon_celeste_natural_spawn", true)
local SPAWN_CHANCE              = tonumber(settings:get("dragon_celeste_spawn_chance")) or 250000
local ATTACK_MONSTERS           = settings:get_bool("dragon_celeste_attack_monsters", false)
local PICKAXE_3X3               = settings:get_bool("dragon_celeste_pickaxe_3x3", true)
local DRAGON_FIRE_BREATH        = settings:get_bool("dragon_celeste_fire_breath", true)

-- Riding / following tuning
local RIDE_SPEED      = 35
local FOLLOW_SPEED    = 40
local FOLLOW_STOP     = 15    -- distance (nodes) at which the dragon stops near its owner
local FOLLOW_HEIGHT   = 10    -- hover height above the owner
local TELEPORT_DIST   = 150   -- if the owner is farther, the dragon teleports to them
local MOUNT_POS       = {x = 0, y = 200, z = 0}
-- Camera while riding (first person / third person), adjust to taste
local EYE_FIRST       = {x = 0, y = 0, z = 0}
local EYE_THIRD       = {x = 0, y = 8, z = -10}

local boost_time = {}
local boost_cd = {}

local function reset_physics(player)
    player:set_physics_override({speed = 1.0, jump = 1.0, gravity = 1.0})
end

-- ==============================================================================
-- UTILITY: Safely check if player has full celestial armor
-- ==============================================================================
local function count_celestial_armor(player)
    local inv = player:get_inventory()
    local list = inv and inv:get_list("armor")
    if not list then return 0 end
    local n = 0
    for _, stack in ipairs(list) do
        if stack:get_name():find("^dragon_celeste:armure_") then
            n = n + 1
        end
    end
    return n
end

-- ==============================================================================
-- 1. CELESTIAL DRAGON SCALE (Crafting Material)
-- ==============================================================================
minetest.register_craftitem("dragon_celeste:ecaille", {
    description = S("Celestial Dragon Scale"),
    inventory_image = "ecaille_du_dragon_celeste.png^[colorize:#00ffff:120",
})

-- ==============================================================================
-- 2. CELESTIAL DRAGON SWORD (Giant & Particle Trail)
-- ==============================================================================
minetest.register_tool("dragon_celeste:epee_du_dragon_celeste", {
    description = S("Celestial Dragon Sword") .. "\n" ..
        S("Deals 10,000 damage to Celestial Dragons, 1,000 to other dragons, 100 to other creatures"),
    inventory_image = "epee_celeste.png",
    visual_scale = 10.0,
    wield_scale = {x = 10.0, y = 10.0, z = 5.0},
    tool_capabilities = {
        full_punch_interval = 0.6,
        max_drop_level = 3,
        groupcaps = {
            fleshy = {times = {[1] = 0.1, [2] = 0.1, [3] = 0.1}, uses = 0, maxlevel = 3},
            snappy = {times = {[1] = 0.6, [2] = 0.3, [3] = 0.1}, uses = 4000, maxlevel = 3},
            choppy = {times = {[2] = 0.7, [3] = 0.35}, uses = 4000, maxlevel = 2},
        },
        damage_groups = {fleshy = SWORD_DAMAGE},
    },
    range = 15,
    sound = {breaks = "default_tool_breaks"},
})

minetest.register_craft({
    output = "dragon_celeste:epee_du_dragon_celeste",
    recipe = {
        {"", "dragon_celeste:ecaille", ""},
        {"", "dragon_celeste:ecaille", ""},
        {"", "dragon_celeste:ecaille", ""}
    }
})

-- ==============================================================================
-- 2b. SWORD BONUS DAMAGE AGAINST OTHER DRAGONS (Draconis, Water Dragons, etc.)
-- ==============================================================================
-- Deals 1,000 damage to fire, ice, and water dragons from external mods
minetest.register_on_mods_loaded(function()
    for name, def in pairs(minetest.registered_entities) do
        local lname = name:lower()
        local is_other_dragon = false
        if (lname:find("dragon") and not lname:find("dragon_celeste"))
                or lname:find("draconis")
                or lname:find("water_dragon")
                or lname:find("waterdragon") then
            is_other_dragon = true
        end

        if is_other_dragon and type(def) == "table" then
            local orig_on_punch = def.on_punch
            def.on_punch = function(self, hitter, time_from_last_punch, tool_capabilities, dir, damage)
                if hitter and hitter:is_player() then
                    local wielded = hitter:get_wielded_item()
                    if wielded and wielded:get_name() == "dragon_celeste:epee_du_dragon_celeste" then
                        local current_hp = self.health or self._hp or self.hp
                        if not current_hp and self.object then
                            current_hp = self.object:get_hp()
                        end
                        current_hp = current_hp or 0

                        local extra_dmg = SWORD_OTHER_DRAGON_DAMAGE - (damage or 0)
                        if extra_dmg > 0 then
                            local new_hp = math.max(0, current_hp - extra_dmg)
                            self.health = new_hp
                            if self._hp then self._hp = new_hp end
                            if self.hp then self.hp = new_hp end
                            if self.object then
                                self.object:set_hp(new_hp)
                            end
                        end

                        local pos = self.object and self.object:get_pos()
                        if pos then
                            minetest.sound_play("default_tool_breaks", {pos = pos, gain = 0.8, max_distance = 25})
                            minetest.add_particlespawner({
                                amount = 30, time = 0.4,
                                minpos = {x = pos.x - 1, y = pos.y + 1, z = pos.z - 1},
                                maxpos = {x = pos.x + 1, y = pos.y + 4, z = pos.z + 1},
                                minvel = {x = -3, y = 2, z = -3}, maxvel = {x = 3, y = 5, z = 3},
                                texture = "default_mese_crystal.png^[colorize:#00ffff:255",
                                glow = 14, size = 4,
                            })
                        end
                    end
                end
                if orig_on_punch then
                    return orig_on_punch(self, hitter, time_from_last_punch, tool_capabilities, dir, damage)
                end
            end
        end
    end
end)

-- ==============================================================================
-- 2c. CELESTIAL PICKAXE (stratospheric speed, 3x3 area)
-- ==============================================================================
local PICKAXE = "dragon_celeste:pioche_celeste"

minetest.register_tool(PICKAXE, {
    description = S("Celestial Pickaxe") .. "\n" .. S("Mines almost instantly, in a 3x3 area"),
    inventory_image = "pioche_celeste.png",
    visual_scale = 10.0,
    wield_scale = {x = 10.0, y = 10.0, z = 5.0},
    tool_capabilities = {
        full_punch_interval = 0.3,
        max_drop_level = 3,
        groupcaps = {
            cracky  = {times = {[1] = 0.03, [2] = 0.03, [3] = 0.03}, uses = 0, maxlevel = 3},
            crumbly = {times = {[1] = 0.02, [2] = 0.02, [3] = 0.02}, uses = 0, maxlevel = 3},
            choppy  = {times = {[1] = 0.03, [2] = 0.03, [3] = 0.03}, uses = 0, maxlevel = 3},
            snappy  = {times = {[1] = 0.02, [2] = 0.02, [3] = 0.02}, uses = 0, maxlevel = 3},
        },
        damage_groups = {fleshy = 20},
    },
    range = 15,
    sound = {breaks = "default_tool_breaks"},
})

do
    local m = "dragon_celeste:bottes_boost_toggle" -- Speed-Jump Crystal
    local sw = "dragon_celeste:epee_du_dragon_celeste"
    minetest.register_craft({
        output = PICKAXE,
        recipe = {
            {m, m, m},
            {"", sw, ""},
            {"", sw, ""},
        }
    })
end

-- 3x3 mining: also dig the 8 neighbours in the plane facing the player
local in_area_dig = false
minetest.register_on_dignode(function(pos, oldnode, digger)
    if not PICKAXE_3X3 or in_area_dig then return end
    if not digger or not digger:is_player() then return end
    local wield = digger:get_wielded_item()
    if wield:get_name() ~= PICKAXE then return end

    local look = digger:get_look_dir()
    local ax, ay, az = math.abs(look.x), math.abs(look.y), math.abs(look.z)
    local offsets = {}
    for a = -1, 1 do
        for b = -1, 1 do
            if not (a == 0 and b == 0) then
                if ay > ax and ay > az then
                    offsets[#offsets + 1] = {x = a, y = 0, z = b}
                elseif ax > az then
                    offsets[#offsets + 1] = {x = 0, y = a, z = b}
                else
                    offsets[#offsets + 1] = {x = a, y = b, z = 0}
                end
            end
        end
    end

    local caps = wield:get_tool_capabilities()
    local name = digger:get_player_name()
    in_area_dig = true
    for _, off in ipairs(offsets) do
        local np = vector.add(pos, off)
        local node = minetest.get_node_or_nil(np)
        if node and node.name ~= "air" and node.name ~= "ignore" then
            local def = minetest.registered_nodes[node.name]
            if def and def.diggable ~= false
                    and (not def.liquidtype or def.liquidtype == "none")
                    and minetest.get_dig_params(def.groups, caps).diggable then
                if minetest.is_protected(np, name) then
                    minetest.record_protection_violation(np, name)
                else
                    minetest.node_dig(np, node, digger)
                end
            end
        end
    end
    in_area_dig = false
end)

-- ==============================================================================
-- 3. CELESTIAL ARMOR (with 3d_armor compatibility & Damage Reflection)
-- ==============================================================================
local armor_pieces = {
    {"casque",    S("Celestial Helmet"),     "head",  "helmet"},
    {"plastron",  S("Celestial Chestplate"), "torso", "chestplate"},
    {"jambieres", S("Celestial Leggings"),   "legs",  "leggings"},
    {"bottes",    S("Celestial Boots"),      "feet",  "boots"}
}

for _, piece in ipairs(armor_pieces) do
    local id, desc, group, eng_id = piece[1], piece[2], piece[3], piece[4]

    local def = {
        description = desc .. "\n" .. S("Part of the Celestial set: full set reflects damage"),
        inventory_image = "3d_armor_inv_" .. eng_id .. "_mithril.png^[colorize:#00ffff:120",
        texture = "3d_armor_" .. eng_id .. "_mithril.png^[colorize:#00ffff:120",
        groups = {
            ["armor_" .. group] = 1,
            armor_heal = 16,
            armor_use = 40,
            armor_fire = 1
        },
        armor_groups = {fleshy = ARMOR_DEFENSE}, -- defense per piece
    }

    if armor and armor.register_armor then
        armor:register_armor("dragon_celeste:armure_" .. id, def)
    else
        minetest.register_tool("dragon_celeste:armure_" .. id, def)
    end
end

local s = "dragon_celeste:ecaille"
minetest.register_craft({output = "dragon_celeste:armure_casque", recipe = {{s, s, s}, {s, "", s}}})
minetest.register_craft({output = "dragon_celeste:armure_plastron", recipe = {{s, "", s}, {s, s, s}, {s, s, s}}})
minetest.register_craft({output = "dragon_celeste:armure_jambieres", recipe = {{s, s, s}, {s, "", s}, {s, "", s}}})
minetest.register_craft({output = "dragon_celeste:armure_bottes", recipe = {{s, "", s}, {s, "", s}}})

-- Full set bonus: reflect part of the melee damage back to the attacker.
-- The `reflecting` guard prevents an endless ping-pong between two players
-- who both wear the full set.
local reflecting = false
local armor_notified = {} -- track who has been notified of full set

minetest.register_on_player_hpchange(function(player, hp_change, reason)
    if hp_change >= 0 or reflecting then return hp_change end
    if count_celestial_armor(player) < 4 then return hp_change end

    if reason.type == "punch" and reason.object and reason.object ~= player then
        local obj = reason.object
        local dmg = math.max(1, math.floor(math.abs(hp_change) * ARMOR_REFLECT_PERCENT / 100))
        reflecting = true
        pcall(obj.punch, obj, player, 1.0, {
            full_punch_interval = 1.0,
            damage_groups = {fleshy = dmg},
        })
        reflecting = false
    end
    return hp_change
end, true)

-- Notify player when they equip/unequip the full celestial armor set
minetest.register_globalstep(function(dtime)
    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        local count = count_celestial_armor(player)
        if count >= 4 and not armor_notified[name] then
            armor_notified[name] = true
            minetest.chat_send_player(name, S(">>> Full Celestial Armor set equipped! Damage reflection is active."))
        elseif count < 4 and armor_notified[name] then
            armor_notified[name] = nil
        end
    end
end)

minetest.register_on_leaveplayer(function(player)
    armor_notified[player:get_player_name()] = nil
end)

-- ==============================================================================
-- 4. SPEED-JUMP CRYSTAL (Timed Boost with Cooldown)
-- ==============================================================================
local function toggle_boost(itemstack, user)
    if not user or not user:is_player() then return itemstack end
    local name = user:get_player_name()
    if boost_time[name] then
        boost_time[name] = nil
        boost_cd[name] = BOOST_COOLDOWN
        reset_physics(user)
        minetest.chat_send_player(name, S(">>> Anti-gravity DEACTIVATED"))
    elseif boost_cd[name] then
        minetest.chat_send_player(name, S(">>> Boost recharging (@1s left)", math.ceil(boost_cd[name])))
    else
        boost_time[name] = BOOST_DURATION
        user:set_physics_override({speed = 10.0, jump = 1.0, gravity = 0.1})
        minetest.chat_send_player(name, S(">>> Anti-gravity ACTIVATED (@1s)", BOOST_DURATION))
    end
    return itemstack
end

minetest.register_craftitem("dragon_celeste:bottes_boost_toggle", {
    description = S("Speed-Jump Crystal") .. "\n" .. S("Right-click to toggle speed and low gravity"),
    inventory_image = "default_mese_crystal.png^[colorize:#00ff00:150",
    stack_max = 1,
    on_use = toggle_boost,
    on_secondary_use = toggle_boost,
    on_place = function(itemstack, placer, pointed_thing)
        return toggle_boost(itemstack, placer)
    end,
})

-- Physics overrides are not saved across sessions: keep our state consistent
minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    boost_time[name] = nil
    boost_cd[name] = nil
    reset_physics(player)
end)
minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    boost_time[name] = nil
    boost_cd[name] = nil
end)
minetest.register_on_dieplayer(function(player)
    local name = player:get_player_name()
    boost_time[name] = nil
    boost_cd[name] = nil
    reset_physics(player)
end)

-- ==============================================================================
-- 5. OPTIMIZED GLOBALSTEP (Throttled to 4x/sec for particles & timers)
-- ==============================================================================
local step_acc = 0
minetest.register_globalstep(function(dtime)
    step_acc = step_acc + dtime
    if step_acc < 0.25 then return end
    local step = step_acc
    step_acc = 0

    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()

        if boost_time[name] then
            boost_time[name] = boost_time[name] - step
            if boost_time[name] <= 0 then
                boost_time[name] = nil
                boost_cd[name] = BOOST_COOLDOWN
                reset_physics(player)
                minetest.chat_send_player(name, S(">>> Anti-gravity DEACTIVATED (Time's up)"))
            end
        elseif boost_cd[name] then
            boost_cd[name] = boost_cd[name] - step
            if boost_cd[name] <= 0 then
                boost_cd[name] = nil
                minetest.chat_send_player(name, S(">>> Boost ready!"))
            end
        end

        -- Sword particle trail
        local wielded = player:get_wielded_item()
        if wielded:get_name() == "dragon_celeste:epee_du_dragon_celeste" then
            local pos = player:get_pos()
            if pos then
                minetest.add_particle({
                    pos = {x = pos.x + math.random(-1,1), y = pos.y + 1.5, z = pos.z + math.random(-1,1)},
                    velocity = {x = math.random(-2,2), y = math.random(1,3), z = math.random(-2,2)},
                    acceleration = {x = 0, y = -0.5, z = 0},
                    expirationtime = 0.8,
                    size = 4,
                    texture = "default_mese_crystal.png^[colorize:#00ffff:255",
                    glow = 14,
                })
            end
        end
    end
end)

-- ==============================================================================
-- 6. CELESTIAL STAR FLOWER
-- ==============================================================================
minetest.register_node("dragon_celeste:fleur_etoile", {
    description = S("Celestial Star Flower") .. "\n" .. S("Feed it to a dragon, or craft Celestite with it"),
    drawtype = "plantlike",
    tiles = {"fleur_etoile.png"},
    inventory_image = "fleur_etoile.png",
    paramtype = "light",
    sunlight_propagates = true,
    light_source = 12,
    walkable = false,
    buildable_to = true,
    groups = {snappy = 3, flora = 1, attached_node = 1, flammable = 1},
    selection_box = {type = "fixed", fixed = {-0.3, -0.5, -0.3, 0.3, 0.5, 0.3}}
})

minetest.register_decoration({
    name = "dragon_celeste:fleur_etoile_gen",
    deco_type = "simple",
    place_on = {"default:dirt_with_grass", "default:dirt_with_snow"},
    sidelen = 16,
    fill_ratio = 0.001,
    decoration = "dragon_celeste:fleur_etoile",
})

-- ==============================================================================
-- 7. CELESTITE BLOCK
-- ==============================================================================
minetest.register_node("dragon_celeste:bloc_celestite", {
    description = S("Celestite Block"),
    tiles = {"default_diamond_block.png^[colorize:#ffffff:200"},
    groups = {cracky = 1, level = 3},
    light_source = 14,
})

local f = "dragon_celeste:fleur_etoile"
minetest.register_craft({
    output = "dragon_celeste:bloc_celestite",
    recipe = {
        {f, f, f},
        {f, "default:diamondblock", f},
        {f, f, f},
    }
})

-- ==============================================================================
-- 8. GIANT DRAGON EGG (hatching auto-tames the dragon for the placer)
-- ==============================================================================
-- We track who placed the egg so the hatched dragon belongs to them.
local egg_placers = {} -- pos_hash -> player_name

minetest.register_node("dragon_celeste:oeuf_du_dragon_celeste", {
    description = S("Celestial Dragon Egg") .. "\n" .. S("Place it on a Celestite block to hatch"),
    drawtype = "mesh",
    mesh = "dragon_egg.obj",
    tiles = {"oeuf_du_dragon_celeste.png"},
    visual_scale = 10,
    paramtype = "light",
    walkable = true,
    collision_box = {
        type = "fixed",
        fixed = {-4, -0.5, -4, 4, 9.5, 4},
    },
    groups = {cracky = 1, level = 3},

    after_place_node = function(pos, placer, itemstack, pointed_thing)
        local node_under = minetest.get_node({x = pos.x, y = pos.y - 1, z = pos.z})
        if node_under.name == "dragon_celeste:bloc_celestite" then
            local placer_name = ""
            if placer and placer:is_player() then
                placer_name = placer:get_player_name()
            end

            minetest.chat_send_all(S("An immense power awakens... The Egg reacts to the Celestite!"))
            minetest.add_particlespawner({
                amount = 300, time = 3,
                minpos = {x=pos.x-5, y=pos.y, z=pos.z-5}, maxpos = {x=pos.x+5, y=pos.y+20, z=pos.z+5},
                minvel = {x=-2, y=2, z=-2}, maxvel = {x=2, y=10, z=2},
                texture = "default_mese_crystal.png^[colorize:#ffffff:255", glow = 14,
            })

            -- Sound effect for the hatching
            minetest.sound_play("default_glass_footstep", {pos = pos, gain = 1.5, max_distance = 50})

            minetest.remove_node(pos)
            -- Also consume the celestite block underneath
            minetest.remove_node({x = pos.x, y = pos.y - 1, z = pos.z})

            minetest.after(2.0, function()
                local dragon = minetest.add_entity(
                    {x = pos.x, y = pos.y + 2, z = pos.z},
                    "dragon_celeste:dragon_celeste"
                )
                -- Auto-tame the dragon for the player who placed the egg
                if dragon and placer_name ~= "" then
                    local ent = dragon:get_luaentity()
                    if ent then
                        ent.owner = placer_name
                        ent.tamed = true
                        ent.order = "follow"
                        -- Set a nametag so the player can see it's theirs
                        ent.nametag = S("@1's Dragon", placer_name)
                        ent.object:set_properties({
                            nametag = ent.nametag,
                            nametag_color = "#00FFFF",
                        })
                        local player = minetest.get_player_by_name(placer_name)
                        if player then
                            minetest.chat_send_player(placer_name,
                                S(">>> A Celestial Dragon has hatched and bonded with you!"))
                        end
                    end
                end
            end)
        else
            if placer and placer:is_player() then
                minetest.chat_send_player(placer:get_player_name(), S("This egg must be placed on a Celestite Block."))
            end
        end
    end,
})

-- ==============================================================================
-- 8b. CELESTIAL GUIDE BOOK
-- ==============================================================================
local function guide_text()
    return table.concat({
        S("The Celestial Dragon is a rare boss that never attacks first. Defeat it to obtain celestial materials."),
        S("Dragon scales are used to craft the Celestial Sword and the armour set."),
        S("Celestial Pickaxe: Mines almost instantly, in a 3x3 area."),
        S("Celestial Armour: A full set grants near-immunity and reflects part of the damage back to the attacker."),
        S("Speed-Jump Crystal: Right-click to toggle speed and low gravity. It must then recharge."),
        S("Star Flowers grow in grasslands and snowy biomes. Surround a diamond block with 8 of them to craft a Celestite Block. Place a dragon egg on it to hatch your own dragon."),
        S("Taming: Right-click a dragon with a Speed-Jump Crystal to become its master. It will then follow you. Sneak and right-click with an empty hand to toggle follow or stay."),
        S("Healing: Right-click a dragon with a Star Flower to restore part of its health (or with a Scale for full health)."),
        S("Riding: Right-click your dragon with an empty hand. Look in the direction you want to fly and press forward; jump to ascend, sneak to descend. Right-click again to dismount."),
        S("Naming: Sneak and right-click your dragon with the Celestial Guide Book to give it a custom name."),
        S("Dragon Breath: While riding, press the use key (right-click) to unleash a fire breath attack."),
    }, "\n\n")
end

local function show_guide(player)
    local name = player:get_player_name()
    local fs = "formspec_version[4]size[12,10]" ..
        "label[0.5,0.6;" .. minetest.formspec_escape(S("Celestial Dragon Guide")) .. "]" ..
        "textarea[0.5,1.1;11,7.4;;;" .. minetest.formspec_escape(guide_text()) .. "]" ..
        "button_exit[4,8.8;4,0.8;close;" .. minetest.formspec_escape(S("Close")) .. "]"
    minetest.show_formspec(name, "dragon_celeste:guide", fs)
end

minetest.register_craftitem("dragon_celeste:livre_celeste", {
    description = S("Celestial Dragon Guide") .. "\n" .. S("Explains how to use the mod"),
    inventory_image = "default_book.png^[colorize:#00ffff:120",
    stack_max = 1,
    on_use = function(itemstack, user)
        if user and user:is_player() then show_guide(user) end
        return itemstack
    end,
    on_secondary_use = function(itemstack, user)
        if user and user:is_player() then show_guide(user) end
        return itemstack
    end,
    on_place = function(itemstack, placer)
        if placer and placer:is_player() then show_guide(placer) end
        return itemstack
    end,
})

do
    local p = "default:paper"
    minetest.register_craft({
        output = "dragon_celeste:livre_celeste",
        recipe = {
            {p, f, p},
            {p, f, p},
        }
    })
end

-- ==============================================================================
-- 9. THE CELESTIAL DRAGON (Boss Stats, Taming, Following, Healing, Riding)
-- ==============================================================================
local riders = {}  -- player name -> dragon entity
local huds = {}    -- player name -> hud id

local function dismount(self)
    local name = self.dc_rider_name
    self.dc_rider_name = nil
    if not name then return end
    riders[name] = nil
    local player = minetest.get_player_by_name(name)
    if not player then return end

    player:set_detach()
    player:set_eye_offset({x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
    if player_api and player_api.player_attached then
        player_api.player_attached[name] = false
        pcall(player_api.set_animation, player, "stand", 30)
    end
    if huds[name] then
        player:hud_remove(huds[name])
        huds[name] = nil
    end
    -- put the player slightly above the dragon to avoid getting stuck
    local p = player:get_pos()
    if p then player:set_pos({x = p.x, y = p.y + 1, z = p.z}) end
end

local function mount(self, player)
    local name = player:get_player_name()
    if riders[name] then return end
    player:set_attach(self.object, "", MOUNT_POS, {x = 0, y = 0, z = 0})
    player:set_eye_offset(EYE_FIRST, EYE_THIRD)
    if player_api and player_api.player_attached then
        player_api.player_attached[name] = true
        pcall(player_api.set_animation, player, "sit", 30)
    end
    riders[name] = self
    self.dc_rider_name = name
    huds[name] = player:hud_add({
        type = "text",
        hud_elem_type = "text",
        position = {x = 0.5, y = 0.88},
        alignment = {x = 0, y = 0},
        offset = {x = 0, y = 0},
        text = "",
        number = 0x00FFFF,
        z_index = 100,
    })
    self.dc_hud_acc = 1 -- force an immediate HUD refresh
    minetest.chat_send_player(name, S(">>> You are riding the Dragon! Use WASD to fly, Space to ascend, Shift to descend. Right-click again to dismount."))
end

minetest.register_on_leaveplayer(function(player)
    local d = riders[player:get_player_name()]
    if d then dismount(d) end
end)
minetest.register_on_dieplayer(function(player)
    local d = riders[player:get_player_name()]
    if d then dismount(d) end
end)

-- ==============================================================================
-- 9b. FIRE BREATH ATTACK (while riding, right-click to breathe fire)
-- ==============================================================================
local breath_cooldown = {} -- player_name -> time remaining

local function dragon_fire_breath(dragon_ent, rider)
    local name = rider:get_player_name()
    if breath_cooldown[name] and breath_cooldown[name] > 0 then
        minetest.chat_send_player(name, S(">>> Dragon breath recharging (@1s)", math.ceil(breath_cooldown[name])))
        return
    end

    local pos = dragon_ent.object:get_pos()
    local look = rider:get_look_dir()
    if not pos or not look then return end

    breath_cooldown[name] = 5 -- 5 second cooldown

    -- Visual: fire particles in a cone in front of the dragon
    local start = {x = pos.x + look.x * 10, y = pos.y + 10 + look.y * 10, z = pos.z + look.z * 10}
    minetest.add_particlespawner({
        amount = 150, time = 0.8,
        minpos = start,
        maxpos = {x = start.x + look.x * 5, y = start.y + look.y * 5, z = start.z + look.z * 5},
        minvel = {x = look.x * 20, y = look.y * 20, z = look.z * 20},
        maxvel = {x = look.x * 40, y = look.y * 40 + 5, z = look.z * 40},
        minacc = {x = 0, y = -2, z = 0}, maxacc = {x = 0, y = 0, z = 0},
        minexptime = 0.5, maxexptime = 1.5,
        minsize = 6, maxsize = 12,
        texture = "default_torch_on_floor.png^[colorize:#ff6600:200",
        glow = 14,
    })

    -- Sound
    minetest.sound_play("default_cool_lava", {pos = start, gain = 1.2, max_distance = 40})

    -- Damage entities in a cone in front of the dragon
    local breath_range = 30
    local breath_dmg = 500
    local target_pos = {
        x = pos.x + look.x * breath_range,
        y = pos.y + 10 + look.y * breath_range,
        z = pos.z + look.z * breath_range,
    }

    for _, obj in ipairs(minetest.get_objects_inside_radius(target_pos, breath_range)) do
        if obj ~= dragon_ent.object and obj ~= rider then
            local is_player = obj:is_player()
            local ent = obj:get_luaentity()
            -- Don't damage the dragon's owner
            if is_player and obj:get_player_name() == dragon_ent.owner then
                -- skip owner
            elseif is_player or (ent and ent.name and ent.name ~= "dragon_celeste:dragon_celeste") then
                -- Check if the target is roughly in the cone (dot product check)
                local tpos = obj:get_pos()
                if tpos then
                    local dir_to_target = vector.normalize(vector.subtract(tpos, pos))
                    local dot = look.x * dir_to_target.x + look.y * dir_to_target.y + look.z * dir_to_target.z
                    if dot > 0.5 then -- within ~60 degree cone
                        obj:punch(dragon_ent.object, 1.0, {
                            full_punch_interval = 1.0,
                            damage_groups = {fleshy = breath_dmg},
                        })
                        -- Set target on fire visually
                        minetest.add_particlespawner({
                            amount = 20, time = 1.5,
                            minpos = {x = tpos.x - 0.5, y = tpos.y, z = tpos.z - 0.5},
                            maxpos = {x = tpos.x + 0.5, y = tpos.y + 2, z = tpos.z + 0.5},
                            minvel = {x = 0, y = 1, z = 0}, maxvel = {x = 0, y = 3, z = 0},
                            texture = "default_torch_on_floor.png^[colorize:#ff3300:200",
                            glow = 14, size = 3,
                        })
                    end
                end
            end
        end
    end

    minetest.chat_send_player(name, S(">>> DRAGON BREATH!"))
end

-- ==============================================================================
-- 9c. DRAGON NAMING (sneak + right-click with the Guide Book)
-- ==============================================================================
local naming_dragon = {} -- player_name -> dragon entity ref

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "dragon_celeste:name_dragon" then return false end
    local name = player:get_player_name()
    local dragon = naming_dragon[name]
    naming_dragon[name] = nil

    if not dragon or not dragon.object or not dragon.object:get_pos() then return true end

    if fields.save and fields.dragon_name then
        local new_name = fields.dragon_name:sub(1, 32) -- limit to 32 chars
        if new_name ~= "" then
            dragon.nametag = new_name
            dragon.object:set_properties({
                nametag = new_name,
                nametag_color = "#00FFFF",
            })
            minetest.chat_send_player(name, S(">>> Your dragon is now named: @1", new_name))
        end
    end
    return true
end)

-- ==============================================================================
-- 9d. /dragon CHAT COMMAND (check your dragon's stats)
-- ==============================================================================
minetest.register_chatcommand("dragon", {
    description = S("Check the status of your tamed Celestial Dragon"),
    func = function(name, param)
        local found = false
        for _, obj in ipairs(minetest.luaentities) do
            if obj.name == "dragon_celeste:dragon_celeste" and obj.owner == name then
                local hp = obj.health or 0
                local max_hp = obj.hp_max or 50000
                local pos = obj.object and obj.object:get_pos()
                local pos_str = pos and string.format("(%d, %d, %d)", pos.x, pos.y, pos.z) or "???"
                local dragon_name = obj.nametag or S("Unnamed")
                local order = obj.order or "follow"

                minetest.chat_send_player(name,
                    S(">>> Dragon: @1", dragon_name) .. "\n" ..
                    S("    HP: @1 / @2", math.floor(hp), math.floor(max_hp)) .. "\n" ..
                    S("    Position: @1", pos_str) .. "\n" ..
                    S("    Mode: @1", order))
                found = true
            end
        end
        if not found then
            minetest.chat_send_player(name, S(">>> You don't have a tamed Celestial Dragon."))
        end
    end,
})

-- ==============================================================================
-- 9e. DRAGON ENTITY REGISTRATION
-- ==============================================================================

local dragon_drops = {
    {name = "dragon_celeste:ecaille", chance = 1, min = 28, max = 29},
    {name = "dragon_celeste:oeuf_du_dragon_celeste", chance = 1, min = 0, max = 1},
    {name = "dragon_celeste:bottes_boost_toggle", chance = 1, min = 0, max = 1},
    {name = "default:mese_crystal", chance = 3, min = 1, max = 3},
}
-- Only drop mithril when moreores is installed (optional dependency)
if minetest.get_modpath("moreores") then
    dragon_drops[#dragon_drops + 1] = {name = "moreores:mithril_ingot", chance = 2, min = 2, max = 5}
end

mobs:register_mob("dragon_celeste:dragon_celeste", {
    type = "animal",
    passive = false,
    attack_type = "dogfight",
    attack_players = false,
    attack_animals = false,
    attack_monsters = ATTACK_MONSTERS,
    attack_npcs = false,
    group_attack = false,
    pathfinding = true,
    reach = 12,
    damage = 1000,
    hp_min = 30000,
    hp_max = 50000,
    armor = 10,
    collisionbox = {-8, 0, -8, 8, 20, 8},

    visual = "mesh",
    mesh = "dragon.b3d",
    textures = {{"dragon_texture.png"}},
    visual_size = {x = 100, y = 100},

    makes_footstep_sound = true,
    view_range = 100,
    walk_velocity = 20,
    run_velocity = 40,
    jump = true,
    fly = true,
    fly_in = "air",
    static_save = true,

    -- Immunities: lava, fire, fall, drowning
    immune_to = {
        {"default:lava_source", 0},
        {"default:lava_flowing", 0},
    },
    fall_damage = false,
    water_damage = 0,
    lava_damage = 0,

    drops = dragon_drops,

    on_rightclick = function(self, clicker)
        local player_name = clicker:get_player_name()
        local item = clicker:get_wielded_item()
        local item_name = item:get_name()
        local creative = minetest.is_creative_enabled(player_name)

        -- 0. FIRE BREATH (while riding, right-click fires breath)
        if self.dc_rider_name == player_name and DRAGON_FIRE_BREATH then
            dragon_fire_breath(self, clicker)
            return
        end

        -- 1. TAME THE DRAGON (Speed-Jump Crystal)
        if item_name == "dragon_celeste:bottes_boost_toggle" then
            if not self.owner or self.owner == "" then
                self.owner = player_name
                self.tamed = true
                self.order = "follow"
                -- Set nametag
                self.nametag = S("@1's Dragon", player_name)
                self.object:set_properties({
                    nametag = self.nametag,
                    nametag_color = "#00FFFF",
                })
                if not creative then
                    item:take_item()
                    clicker:set_wielded_item(item)
                end
                minetest.chat_send_player(player_name, S(">>> You are now the absolute Master of this Celestial Dragon!"))
            else
                minetest.chat_send_player(player_name, S(">>> This dragon already has a master!"))
            end
            return
        end

        -- 2. HEAL THE DRAGON WITH A SCALE (full) OR A STAR FLOWER (partial)
        if item_name == "dragon_celeste:ecaille" or item_name == "dragon_celeste:fleur_etoile" then
            local max_hp = self.hp_max or 50000
            if item_name == "dragon_celeste:ecaille" then
                self.health = max_hp
            else
                self.health = math.min(max_hp, (self.health or 0) + 5000)
            end
            -- BUG FIX: Update self.object HP to match self.health
            self.object:set_hp(self.health)
            minetest.sound_play("default_dig_snappy", {object = self.object, gain = 1.0, max_distance = 20})

            local pos = self.object:get_pos()
            if pos then
                minetest.add_particlespawner({
                    amount = 40, time = 1,
                    minpos = {x=pos.x-5, y=pos.y+5, z=pos.z-5}, maxpos = {x=pos.x+5, y=pos.y+20, z=pos.z+5},
                    minvel = {x=0, y=2, z=0}, maxvel = {x=0, y=5, z=0},
                    texture = "heart.png",
                    glow = 14, size = 4,
                })
            end

            if item_name == "dragon_celeste:ecaille" then
                minetest.chat_send_player(player_name, S(">>> The Celestial Dragon has been fully healed!"))
            else
                minetest.chat_send_player(player_name, S(">>> The Celestial Dragon has been healed!"))
            end
            if not creative then
                item:take_item()
                clicker:set_wielded_item(item)
            end
            return
        end

        -- 3. NAME THE DRAGON (sneak + right-click with Guide Book)
        if self.tamed and self.owner == player_name
                and item_name == "dragon_celeste:livre_celeste" then
            local ctrl = clicker:get_player_control()
            if ctrl.sneak then
                naming_dragon[player_name] = self
                local current_name = self.nametag or ""
                local fs = "formspec_version[4]size[8,4]" ..
                    "label[0.5,0.6;" .. minetest.formspec_escape(S("Name your Dragon")) .. "]" ..
                    "field[0.5,1.3;7,0.8;dragon_name;;" ..
                        minetest.formspec_escape(current_name) .. "]" ..
                    "button_exit[2,2.8;4,0.8;save;" .. minetest.formspec_escape(S("Save")) .. "]"
                minetest.show_formspec(player_name, "dragon_celeste:name_dragon", fs)
                return
            end
            -- Otherwise just open the guide
            show_guide(clicker)
            return
        end

        -- 4. OWNER ACTIONS (empty hand)
        if self.tamed and self.owner == player_name and item_name == "" then
            local ctrl = clicker:get_player_control()
            if self.dc_rider_name == player_name then
                dismount(self)
                minetest.chat_send_player(player_name, S(">>> You dismount your celestial steed."))
            elseif ctrl.sneak then
                -- Sneak + right-click: follow / stay
                if self.order == "stand" then
                    self.order = "follow"
                    minetest.chat_send_player(player_name, S(">>> The dragon will follow you."))
                else
                    self.order = "stand"
                    minetest.chat_send_player(player_name, S(">>> The dragon will stay here."))
                end
            elseif not self.dc_rider_name then
                mount(self, clicker)
            end
        end
    end,

    on_punch = function(self, hitter, time_from_last_punch, tool_capabilities, dir, damage)
        if hitter and hitter:is_player() then
            -- Owner can never damage their own dragon
            if self.owner and self.owner == hitter:get_player_name() then
                return true -- Cancel damage
            end

            -- Tamed dragons take 80% less damage from other players (protection)
            if self.tamed and self.owner and self.owner ~= "" then
                local wielded = hitter:get_wielded_item()
                if wielded and wielded:get_name() == "dragon_celeste:epee_du_dragon_celeste" then
                    -- Celestial sword still deals full bonus damage
                    local current_hp = self.health or 50000
                    local extra_dmg = SWORD_DRAGON_DAMAGE - (damage or 0)
                    if extra_dmg > 0 then
                        self.health = current_hp - extra_dmg
                    end
                else
                    -- Other weapons: 80% damage reduction on tamed dragons
                    self.health = (self.health or 50000) - math.floor((damage or 0) * 0.2)
                end
            else
                -- Wild dragon: Celestial sword bonus
                local wielded = hitter:get_wielded_item()
                if wielded and wielded:get_name() == "dragon_celeste:epee_du_dragon_celeste" then
                    local current_hp = self.health or self.object:get_hp() or 50000
                    local extra_dmg = SWORD_DRAGON_DAMAGE - (damage or 0)
                    if extra_dmg > 0 then
                        self.health = current_hp - extra_dmg
                    end
                end
            end

            -- Visual feedback for sword hits
            local wielded = hitter:get_wielded_item()
            if wielded and wielded:get_name() == "dragon_celeste:epee_du_dragon_celeste" then
                local pos = self.object:get_pos()
                if pos then
                    minetest.sound_play("default_tool_breaks", {pos = pos, gain = 1.0, max_distance = 30})
                    minetest.add_particlespawner({
                        amount = 40, time = 0.5,
                        minpos = {x = pos.x - 2, y = pos.y + 4, z = pos.z - 2},
                        maxpos = {x = pos.x + 2, y = pos.y + 12, z = pos.z + 2},
                        minvel = {x = -4, y = 2, z = -4}, maxvel = {x = 4, y = 6, z = 4},
                        texture = "default_mese_crystal.png^[colorize:#00ffff:255",
                        glow = 14, size = 5,
                    })
                end
            end
        end
    end,

    on_die = function(self, pos)
        dismount(self)
        -- Death announcement if the dragon was tamed
        if self.owner and self.owner ~= "" then
            local dragon_name = self.nametag or S("Celestial Dragon")
            minetest.chat_send_player(self.owner,
                S(">>> Your dragon @1 has fallen!", dragon_name))
        end
        -- Epic death particles
        if pos then
            minetest.add_particlespawner({
                amount = 200, time = 2,
                minpos = {x=pos.x-5, y=pos.y, z=pos.z-5},
                maxpos = {x=pos.x+5, y=pos.y+20, z=pos.z+5},
                minvel = {x=-5, y=5, z=-5}, maxvel = {x=5, y=15, z=5},
                texture = "default_mese_crystal.png^[colorize:#00ffff:255",
                glow = 14, size = 8,
            })
            minetest.sound_play("default_cool_lava", {pos = pos, gain = 2.0, max_distance = 60})
        end
    end,

    -- do_custom is the Mobs Redo hook run every step; returning false skips
    -- the default AI (which would otherwise override our velocity).
    do_custom = function(self, dtime)
        local pos = self.object:get_pos()
        if not pos then return end

        -- DRAGON PARTICLE TRAIL
        if math.random() < 0.6 then
            minetest.add_particle({
                pos = {x = pos.x + math.random(-4,4), y = pos.y + math.random(5, 18), z = pos.z + math.random(-4,4)},
                velocity = {x = math.random(-2,2), y = math.random(1,3), z = math.random(-2,2)},
                acceleration = {x = 0, y = -0.5, z = 0},
                expirationtime = 1.5,
                size = 15,
                texture = "default_mese_crystal.png^[colorize:#00ffff:255",
                glow = 14,
            })
        end

        -- BREATH COOLDOWN TIMER
        if self.dc_rider_name then
            local rname = self.dc_rider_name
            if breath_cooldown[rname] and breath_cooldown[rname] > 0 then
                breath_cooldown[rname] = breath_cooldown[rname] - dtime
                if breath_cooldown[rname] <= 0 then
                    breath_cooldown[rname] = nil
                end
            end
        end

        local rot = self.rotate or 0

        -- Drop a stale rider reference (e.g. after a server restart)
        local rname = self.dc_rider_name
        local rider = rname and riders[rname] == self and minetest.get_player_by_name(rname)
        if rname and not rider then
            dismount(self)
            rname = nil
        end

        -- PLAYER FLIGHT CONTROL
        if rider then
            local ctrl = rider:get_player_control()
            local yaw = rider:get_look_horizontal()
            local look = rider:get_look_dir()
            local vx, vy, vz = 0, 0, 0

            self.object:set_yaw(yaw + rot)
            if ctrl.up then
                vx, vy, vz = look.x * RIDE_SPEED, look.y * RIDE_SPEED, look.z * RIDE_SPEED
            elseif ctrl.down then
                local d = minetest.yaw_to_dir(yaw)
                vx, vz = -d.x * RIDE_SPEED * 0.5, -d.z * RIDE_SPEED * 0.5
            end
            if ctrl.jump then vy = vy + RIDE_SPEED * 0.6 end
            if ctrl.sneak then vy = vy - RIDE_SPEED * 0.6 end

            self.object:set_acceleration({x = 0, y = 0, z = 0})
            self.object:set_velocity({x = vx, y = vy, z = vz})

            -- HUD (refreshed twice per second) — BUG FIX: use self.health not get_hp()
            self.dc_hud_acc = (self.dc_hud_acc or 0) + dtime
            if self.dc_hud_acc >= 0.5 and huds[rname] then
                self.dc_hud_acc = 0
                local hp = math.floor(self.health or 0)
                local max_hp = math.floor(self.hp_max or 50000)
                local alt = math.floor(pos.y)
                local breath_status = ""
                if breath_cooldown[rname] and breath_cooldown[rname] > 0 then
                    breath_status = "  " .. S("Breath: @1s", math.ceil(breath_cooldown[rname]))
                else
                    breath_status = "  " .. S("Breath: READY")
                end
                rider:hud_change(huds[rname], "text",
                    S("Dragon HP: @1 / @2", hp, max_hp) .. "   " .. S("Altitude: @1", alt) .. breath_status .. "\n" ..
                    S("Look + forward: fly | Jump: up | Sneak: down | Right-click: fire breath"))
            end
            return false
        end

        -- FOLLOW THE OWNER
        if self.tamed and self.owner and self.owner ~= "" and self.order ~= "stand"
                and self.state ~= "attack" then
            local owner = minetest.get_player_by_name(self.owner)
            local opos = owner and owner:get_pos()
            if opos then
                local target = {x = opos.x, y = opos.y + FOLLOW_HEIGHT, z = opos.z}
                local dx, dy, dz = target.x - pos.x, target.y - pos.y, target.z - pos.z
                local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

                self.object:set_acceleration({x = 0, y = 0, z = 0})
                if dist > TELEPORT_DIST then
                    self.object:set_pos({x = target.x + FOLLOW_STOP, y = target.y, z = target.z})
                    self.object:set_velocity({x = 0, y = 0, z = 0})
                elseif dist > FOLLOW_STOP then
                    local speed = math.min(FOLLOW_SPEED, dist * 1.5)
                    self.object:set_yaw(math.atan2(-dx, dz) + rot)
                    self.object:set_velocity({
                        x = dx / dist * speed,
                        y = dy / dist * speed,
                        z = dz / dist * speed,
                    })
                else
                    self.object:set_velocity({x = 0, y = 0, z = 0})
                end
                return false
            end
        end
    end,
})

-- ==============================================================================
-- 10. NATURAL SPAWNING (Extremely Rare, configurable)
-- ==============================================================================
if NATURAL_SPAWN and mobs and mobs.spawn then
    mobs:spawn({
        name = "dragon_celeste:dragon_celeste",
        nodes = {"air", "default:dirt_with_grass", "default:snowblock", "default:dirt_with_snow", "default:sand", "default:desert_sand", "default:leaves"},
        min_light = 0,
        max_light = 15,
        chance = SPAWN_CHANCE,
        active_object_count = 1,
        min_height = 0,
        max_height = 31000,
        spawn_by = "air",
    })
end

-- ==============================================================================
-- 11. LOG
-- ==============================================================================
minetest.log("action", "[dragon_celeste] Celestial Dragon mod loaded successfully!")
