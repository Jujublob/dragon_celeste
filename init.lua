-- ==============================================================================
-- CELESTIAL DRAGON MOD (dragon_celeste)
-- Copyright (c) 2026 - Open Source (MIT License)
--
-- CREDITS & ATTRIBUTIONS:
-- • Dragon 3D model, dragon textures, and scale texture: 
--   Created by ElCeejo for the "Draconis" mod (adapted and recolored).
-- • Dragon egg 3D model and texture: 
--   Created by TNT42.dev for "dragon_celeste". 
--   (Written and explicit authorization from TNT42.dev has been obtained for use and distribution).
-- • Original armor textures: 
--   Created by davidthecreator (sole texture author of "3d_armor")
--   (recolored and adapted for celestial armor).
-- ==============================================================================

local S = minetest.get_translator("dragon_celeste")

-- ==============================================================================
-- SETTINGS & CONSTANTS
-- ==============================================================================
local BOOST_DURATION = 30  -- seconds
local BOOST_COOLDOWN = 20  -- seconds
local ARMOR_REFLECT_PERCENT = 50

local boost_time = {}
local boost_cd = {}

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
    description = S("Celestial Dragon Sword"),
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
        damage_groups = {fleshy = 10000},
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
-- 3. CELESTIAL ARMOR (with 3d_armor compatibility & Damage Reflection)
-- ==============================================================================
local armor_pieces = {
    {"casque", "Celestial Helmet", "head", "helmet"},
    {"plastron", "Celestial Chestplate", "torso", "chestplate"},
    {"jambieres", "Celestial Leggings", "legs", "leggings"},
    {"bottes", "Celestial Boots", "feet", "boots"}
}

for _, piece in ipairs(armor_pieces) do
    local id, Name, group, eng_id = piece[1], piece[2], piece[3], piece[4]
    
    local def = {
        description = S(Name),
        inventory_image = "3d_armor_inv_" .. eng_id .. "_mithril.png^[colorize:#00ffff:120",
        texture = "3d_armor_" .. eng_id .. "_mithril.png^[colorize:#00ffff:120",
        groups = {
            ["armor_"..group] = 1, 
            armor_heal = 16, 
            armor_use = 40,
            armor_fire = 1
        },
        armor_groups = {fleshy = 20}, -- 20% defense per piece
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

-- Full set bonus: reflect part of the melee damage back to the attacker safely
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

minetest.register_on_player_hpchange(function(player, hp_change, reason)
    if hp_change >= 0 then return hp_change end
    if count_celestial_armor(player) < 4 then return hp_change end
    
    if reason.type == "punch" and reason.object and reason.object ~= player then
        local obj = reason.object
        local dmg = math.max(1, math.floor(math.abs(hp_change) * ARMOR_REFLECT_PERCENT / 100))
        -- Use punch() instead of set_hp() to preserve mob drops and on_die events
        obj:punch(player, 1.0, {
            full_punch_interval = 1.0,
            damage_groups = {fleshy = dmg},
        })
    end
    return hp_change
end, true)

-- ==============================================================================
-- 4. SPEED-JUMP CRYSTAL (Timed Boost with Cooldown)
-- ==============================================================================
minetest.register_craftitem("dragon_celeste:bottes_boost_toggle", {
    description = S("Speed-Jump Crystal") .. "\n" .. S("Right-click to toggle speed and low gravity"),
    inventory_image = "default_mese_crystal.png^[colorize:#00ff00:150",
    stack_max = 1,
    on_use = function(itemstack, user)
        local name = user:get_player_name()
        if boost_time[name] then
            boost_time[name] = nil
            boost_cd[name] = BOOST_COOLDOWN
            user:set_physics_override({speed = 1.0, jump = 1.0, gravity = 1.0})
            minetest.chat_send_player(name, S(">>> Anti-gravity DEACTIVATED"))
        elseif boost_cd[name] then
            minetest.chat_send_player(name, S(">>> Boost recharging (@1s left)", math.ceil(boost_cd[name])))
        else
            boost_time[name] = BOOST_DURATION
            user:set_physics_override({speed = 10.0, jump = 1.0, gravity = 0.1})
            minetest.chat_send_player(name, S(">>> Anti-gravity ACTIVATED (@1s)", BOOST_DURATION))
        end
        return itemstack
    end,
})

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
        
        -- Boost timer logic (No forced reset on disconnect as requested)
        if boost_time[name] then
            boost_time[name] = boost_time[name] - step
            if boost_time[name] <= 0 then
                boost_time[name] = nil
                boost_cd[name] = BOOST_COOLDOWN
                player:set_physics_override({speed = 1.0, jump = 1.0, gravity = 1.0})
                minetest.chat_send_player(name, S(">>> Anti-gravity DEACTIVATED (Time's up)"))
            end
        elseif boost_cd[name] then
            boost_cd[name] = boost_cd[name] - step
            if boost_cd[name] <= 0 then
                boost_cd[name] = nil
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
-- 8. GIANT DRAGON EGG
-- ==============================================================================
minetest.register_node("dragon_celeste:oeuf_du_dragon_celeste", {
    description = S("Celestial Dragon Egg") .. "\n" .. S("Place it on a Celestite block to hatch"),
    drawtype = "mesh",
    mesh = "dragon_egg.obj",
    tiles = {"oeuf_du_dragon_celeste.png"},
    visual_scale = 10, -- Kept immense as explicitly requested
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
            minetest.chat_send_all(S("An immense power awakens... The Egg reacts to the Celestite!"))
            minetest.add_particlespawner({
                amount = 300, time = 3,
                minpos = {x=pos.x-5, y=pos.y, z=pos.z-5}, maxpos = {x=pos.x+5, y=pos.y+20, z=pos.z+5},
                minvel = {x=-2, y=2, z=-2}, maxvel = {x=2, y=10, z=2},
                texture = "default_mese_crystal.png^[colorize:#ffffff:255", glow = 14,
            })
            minetest.remove_node(pos)
            minetest.after(2.0, function()
                minetest.add_entity({x = pos.x, y = pos.y + 2, z = pos.z}, "dragon_celeste:dragon_celeste")
            end)
        else
            if placer and placer:is_player() then
                minetest.chat_send_player(placer:get_player_name(), S("This egg must be placed on a Celestite Block."))
            end
        end
    end,
})

-- ==============================================================================
-- 9. THE CELESTIAL DRAGON (Boss Stats, Taming, Healing, Mounting)
-- ==============================================================================
mobs:register_mob("dragon_celeste:dragon_celeste", {
    type = "animal",
    passive = false,
    attack_type = "dogfight",
    attack_players = false,
    attack_animals = false,
    attack_monsters = false, -- Does not attack other monsters
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
    rideable = true,
    static_save = true,

    drops = {
        {name = "dragon_celeste:ecaille", chance = 1, min = 28, max = 29},
        {name = "dragon_celeste:oeuf_du_dragon_celeste", chance = 1, min = 0, max = 1},
        {name = "dragon_celeste:bottes_boost_toggle", chance = 1, min = 0, max = 1},
        {name = "moreores:mithril_ingot", chance = 2, min = 2, max = 5}, -- Requires Moreores mod
        {name = "default:mese_crystal", chance = 3, min = 1, max = 3},
    },

    on_rightclick = function(self, clicker)
        local player_name = clicker:get_player_name()
        local item = clicker:get_wielded_item()
        
        -- 1. TAME THE DRAGON
        if item:get_name() == "dragon_celeste:bottes_boost_toggle" then
            if not self.owner or self.owner == "" then
                self.owner = player_name
                self.tamed = true
                item:take_item()
                clicker:set_wielded_item(item)
                minetest.chat_send_player(player_name, S(">>> You are now the absolute Master of this Celestial Dragon!"))
                return
            else
                minetest.chat_send_player(player_name, S(">>> This dragon already has a master!"))
                return
            end
        end

        -- 2. HEAL THE DRAGON WITH A SCALE
        if item:get_name() == "dragon_celeste:ecaille" then
            self.health = self.hp_max
            self.object:set_hp(self.hp_max)
            minetest.sound_play("default_dig_snappy", {object = self.object, gain = 1.0, max_distance = 20})
            
            local pos = self.object:get_pos()
            minetest.add_particlespawner({
                amount = 40, time = 1,
                minpos = {x=pos.x-5, y=pos.y+5, z=pos.z-5}, maxpos = {x=pos.x+5, y=pos.y+20, z=pos.z+5},
                minvel = {x=0, y=2, z=0}, maxvel = {x=0, y=5, z=0},
                texture = "heart.png",
                glow = 14, size = 4,
            })

            minetest.chat_send_player(player_name, S(">>> The Celestial Dragon has been fully healed!"))
            if not minetest.is_creative_enabled(player_name) then
                item:take_item()
                clicker:set_wielded_item(item)
            end
            return
        end
        
        -- 3. MOUNT / DISMOUNT
        if self.tamed and self.owner == player_name and item:get_name() == "" then
            if self.driver and self.driver == clicker then
                clicker:set_detach()
                self.driver = nil
                minetest.chat_send_player(player_name, S(">>> You dismount your celestial steed."))
            elseif not self.driver then
                clicker:set_attach(self.object, "", {x=0, y=200, z=0}, {x=0, y=0, z=0})
                self.driver = clicker
                minetest.chat_send_player(player_name, S(">>> You are riding the Dragon! Use WASD to fly, Space to ascend, Shift to descend. Right-click again to dismount."))
            end
        end
    end,

    on_punch = function(self, hitter, time_from_last_punch, tool_capabilities, dir, damage)
        if hitter and hitter:is_player() then
            if self.owner and self.owner == hitter:get_player_name() then
                return true -- Cancel damage if the master hits it
            end
        end
    end,

    on_step = function(self, dtime)
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
        
        -- PLAYER FLIGHT CONTROL
        if self.driver then
            local ctrl = self.driver:get_player_control()
            local yaw = self.driver:get_look_horizontal()
            
            if ctrl.up or ctrl.down or ctrl.left or ctrl.right or ctrl.jump or ctrl.sneak then
                self.object:set_yaw(yaw)
                local dir = minetest.yaw_to_dir(yaw)
                
                local speed = 35
                local y_vel = 0
                
                if ctrl.jump then y_vel = speed end
                if ctrl.sneak then y_vel = -speed end
                if ctrl.down then speed = -speed end
                if not ctrl.up and not ctrl.down then speed = 0 end
                
                self.object:set_velocity({
                    x = dir.x * speed, 
                    y = y_vel, 
                    z = dir.z * speed
                })
            else
                self.object:set_velocity({x=0, y=0, z=0})
            end
        end
    end,
})

-- ==============================================================================
-- 10. NATURAL SPAWNING (Extremely Rare)
-- ==============================================================================
if mobs and mobs.spawn then
    mobs:spawn({
        name = "dragon_celeste:dragon_celeste",
        nodes = {"air", "default:dirt_with_grass", "default:snowblock", "default:dirt_with_snow", "default:sand", "default:desert_sand", "default:leaves"},
        min_light = 0,
        max_light = 15,
        chance = 1000000000, -- Very rare
        active_object_count = 1,
        min_height = 0,
        max_height = 31000,
        spawn_by = "air",
    })
end