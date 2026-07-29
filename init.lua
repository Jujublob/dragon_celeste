-- ==============================================================================
-- CRÉDITS ET ATTRIBUTIONS DU MOD DRAGON CÉLESTE
-- ==============================================================================
-- • Modèle 3D du dragon, textures du dragon et textures des écailles :
--   Créés par ElCeejo pour le mod "Draconis" (adaptés et recolorés).
--
-- • Modèle 3D et texture de l'œuf de dragon :
--   Créés par TNT42.dev pour le mod "dragon_celeste".
--
-- • Textures d'armure originales :
--   Créées par stujones11 et maintenues par TenPlus1 pour le mod "3d_armor" 
--   (recolorées et adaptées pour l'armure céleste).
-- ==============================================================================

-- ==============================================================================
-- MOD : DRAGON CÉLESTE
-- ==============================================================================

local S = minetest.get_translator("dragon_celeste")

-- ==============================================================================
-- 1. LES ÉCAILLES DU DRAGON CÉLESTE (POUR LE CRAFT)
-- ==============================================================================
minetest.register_craftitem("dragon_celeste:ecaille", {
    description = "Écaille de Dragon Céleste",
    inventory_image = "ecaille_du_dragon_celeste.png^[colorize:#00ffff:120",
    groups = {not_in_creative_inventory = 0},
})

-- ==============================================================================
-- 2. L'ÉPÉE DU DRAGON CÉLESTE (IMMENSE & TRAÎNÉE DE PARTICULES)
-- ==============================================================================
minetest.register_tool("dragon_celeste:epee_du_dragon_celeste", {
    description = "Épée du Dragon Céleste",
    inventory_image = "epee_celeste.png", 
    visual_scale = 10.0,
    wield_scale = {x=10.0, y=10.0, z=5.0},
    tool_capabilities = {
        full_punch_interval = 0.1,
        max_drop_level = 3,
        groupcaps = {
            fleshy = {times = {0.1, 0.1, 0.1}, uses = 0, maxlevel = 3},
        },
        damage_groups = {fleshy = 10000},
    },
    range = 15,
    groups = {not_in_creative_inventory = 0},
})

-- Recette de l'Épée
minetest.register_craft({
    output = "dragon_celeste:epee_du_dragon_celeste",
    recipe = {
        {"", "dragon_celeste:ecaille", ""},
        {"", "dragon_celeste:ecaille", ""},
        {"", "dragon_celeste:ecaille", ""}
    }
})

-- Particules de l'épée
minetest.register_globalstep(function(dtime)
    for _, player in ipairs(minetest.get_connected_players()) do
        local wielded = player:get_wielded_item()
        if wielded:get_name() == "dragon_celeste:epee_du_dragon_celeste" then
            local pos = player:get_pos()
            if pos and math.random() < 0.4 then
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
-- 3. L'ARMURE CÉLESTE
-- ==============================================================================
local armor_pieces = {
    {"casque", "Casque", "head", "helmet"},
    {"plastron", "Plastron", "torso", "chestplate"},
    {"jambieres", "Jambières", "legs", "leggings"},
    {"bottes", "Bottes", "feet", "boots"}
}

for _, piece in ipairs(armor_pieces) do
    local id, Name, group, eng_id = piece[1], piece[2], piece[3], piece[4]
    
    minetest.register_tool("dragon_celeste:armure_" .. id, {
        description = Name .. " du Dragon Céleste",
        inventory_image = "3d_armor_inv_" .. eng_id .. "_mithril.png^[colorize:#00ffff:120",
        texture = "3d_armor_" .. eng_id .. "_mithril.png^[colorize:#00ffff:120",
        groups = {["armor_"..group] = 1, armor_heal = 100, armor_use = 0, not_in_creative_inventory = 0},
        light_source = 15,
    })
end

minetest.register_craft({
    output = "dragon_celeste:armure_casque",
    recipe = {
        {"dragon_celeste:ecaille", "dragon_celeste:ecaille", "dragon_celeste:ecaille"},
        {"dragon_celeste:ecaille", "", "dragon_celeste:ecaille"},
    }
})
minetest.register_craft({
    output = "dragon_celeste:armure_plastron",
    recipe = {
        {"dragon_celeste:ecaille", "", "dragon_celeste:ecaille"},
        {"dragon_celeste:ecaille", "dragon_celeste:ecaille", "dragon_celeste:ecaille"},
        {"dragon_celeste:ecaille", "dragon_celeste:ecaille", "dragon_celeste:ecaille"}
    }
})
minetest.register_craft({
    output = "dragon_celeste:armure_jambieres",
    recipe = {
        {"dragon_celeste:ecaille", "dragon_celeste:ecaille", "dragon_celeste:ecaille"},
        {"dragon_celeste:ecaille", "", "dragon_celeste:ecaille"},
        {"dragon_celeste:ecaille", "", "dragon_celeste:ecaille"}
    }
})
minetest.register_craft({
    output = "dragon_celeste:armure_bottes",
    recipe = {
        {"dragon_celeste:ecaille", "", "dragon_celeste:ecaille"},
        {"dragon_celeste:ecaille", "", "dragon_celeste:ecaille"}
    }
})

-- ==============================================================================
-- 4. BOUTON BOOST DIVIN & PROTECTION
-- ==============================================================================
minetest.register_craftitem("dragon_celeste:bottes_boost_toggle", {
    description = "Cristal de Vitesse-Saut (Appuyez sur un dragon pour l'apprivoiser)",
    inventory_image = "default_mese_crystal.png^[colorize:#00ff00:150",
    stack_max = 1,
    groups = {not_in_creative_inventory = 0},
    on_use = function(itemstack, user, pointed_thing)
        local player_name = user:get_player_name()
        local physics = user:get_physics_override()
        if physics.speed > 1.0 then
            user:set_physics_override({speed = 1.0, jump = 1.0, gravity = 1.0})
            minetest.chat_send_player(player_name, ">>> Anti-gravité DÉSACTIVÉE")
        else
            user:set_physics_override({speed = 10.0, jump = 1.0, gravity = 0.1})
            minetest.chat_send_player(player_name, ">>> Anti-gravité ACTIVÉE")
        end
        return itemstack
    end,
})

minetest.register_on_player_hpchange(function(player, hp_change, reason)
    if hp_change >= 0 then return hp_change end
    local inv = player:get_inventory()
    if not inv or not inv:get_list("armor") then return hp_change end
    
    local is_wearing_celestial = false
    for _, stack in ipairs(inv:get_list("armor")) do
        if string.find(stack:get_name(), "dragon_celeste:armure_") then
            is_wearing_celestial = true
            break
        end
    end

    if is_wearing_celestial then
        if reason.type == "punch" and reason.object then
            local hitter = reason.object
            local current_hp = hitter:get_hp()
            hitter:set_hp(math.max(0, current_hp - math.abs(hp_change)))
        end
        return 0
    end
    return hp_change
end, true)

-- ==============================================================================
-- 5. LA PLANTE : FLEUR D'ÉTOILE CÉLESTE
-- ==============================================================================
minetest.register_node("dragon_celeste:fleur_etoile", {
    description = "Fleur d'Étoile Céleste (Soigne le dragon ou fait de la Célestite)",
    drawtype = "plantlike",
    tiles = {"fleur_etoile.png"},
    inventory_image = "fleur_etoile.png",
    paramtype = "light",
    sunlight_propagates = true,
    light_source = 12,
    walkable = false,
    buildable_to = true,
    groups = {snappy = 3, flora = 1, attached_node = 1, not_in_creative_inventory = 0},
    selection_box = {
        type = "fixed",
        fixed = {-0.3, -0.5, -0.3, 0.3, 0.5, 0.3}
    }
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
-- 6. LE BLOC DE CÉLESTITE
-- ==============================================================================
minetest.register_node("dragon_celeste:bloc_celestite", {
    description = "Bloc de Célestite",
    tiles = {"default_diamond_block.png^[colorize:#ffffff:200"},
    groups = {cracky = 1, level = 3, not_in_creative_inventory = 0},
    light_source = 14,
})

minetest.register_craft({
    output = "dragon_celeste:bloc_celestite",
    recipe = {
        {"dragon_celeste:fleur_etoile", "dragon_celeste:fleur_etoile", "dragon_celeste:fleur_etoile"},
        {"dragon_celeste:fleur_etoile", "dragon_celeste:fleur_etoile", "dragon_celeste:fleur_etoile"},
        {"dragon_celeste:fleur_etoile", "dragon_celeste:fleur_etoile", "dragon_celeste:fleur_etoile"},
    }
})

-- ==============================================================================
-- 7. L'OEUF DE DRAGON GÉANT
-- ==============================================================================
minetest.register_node("dragon_celeste:oeuf_du_dragon_celeste", {
    description = "Oeuf de Dragon Céleste",
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
    groups = {cracky = 1, level = 3, not_in_creative_inventory = 0},
    
    after_place_node = function(pos, placer, itemstack, pointed_thing)
        local node_under = minetest.get_node({x = pos.x, y = pos.y - 1, z = pos.z})
        if node_under.name == "dragon_celeste:bloc_celestite" then
            minetest.chat_send_all("Un pouvoir immense s'éveille... L'Œuf réagit à la Célestite !")
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
        end
    end,
})

-- ==============================================================================
-- 8. LE DRAGON CÉLESTE (BOSS GÉANT, VOL, DOMPTAGE, SOIN & CONTRÔLES)
-- ==============================================================================
local function get_dragon_drops()
    local drops = {}
    table.insert(drops, {name = "dragon_celeste:ecaille", chance = 1, min = 28, max = 29})
    table.insert(drops, {name = "dragon_celeste:oeuf_du_dragon_celeste", chance = 1, min = 0, max = 1})
    table.insert(drops, {name = "dragon_celeste:bottes_boost_toggle", chance = 1, min = 0, max = 1})
    return drops
end

mobs:register_mob("dragon_celeste:dragon_celeste", {
    type = "animal",          -- Il n'est plus considéré comme un monstre prédateur
    passive = false,          -- DOIT être sur "false" pour qu'il puisse riposter
    attack_type = "dogfight",
    attack_players = false,   -- IMPORTANT : l'empêche de cibler les joueurs à vue
    attack_animals = false,   -- L'empêche de chasser les vaches ou les moutons
    attack_monsters = true,  -- L'empêche de partir en guerre contre les zombies
    -- ... (la suite reste identique)
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
    drops = get_dragon_drops(),
    static_save = true,

    on_rightclick = function(self, clicker)
        local player_name = clicker:get_player_name()
        local item = clicker:get_wielded_item()
        
        -- 1. APPRIVOISER LE DRAGON
        if item:get_name() == "dragon_celeste:bottes_boost_toggle" then
            if not self.owner or self.owner == "" then
                self.owner = player_name
                self.tamed = true
                item:take_item()
                clicker:set_wielded_item(item)
                minetest.chat_send_player(player_name, ">>> Vous êtes désormais le Maître absolu de ce Dragon Céleste !")
                return
            else
                minetest.chat_send_player(player_name, ">>> Ce dragon a déjà un maître !")
                return
            end
        end

        -- 2. SOIGNER LE DRAGON AVEC LA FLEUR
        if item:get_name() == "dragon_celeste:fleur_etoile" then
            self.health = self.hp_max
            self.object:set_hp(self.hp_max)
            minetest.sound_play("default_dig_snappy", {object = self.object, gain = 1.0, max_distance = 20})
            
            -- Particules de soin
            local pos = self.object:get_pos()
            minetest.add_particlespawner({
                amount = 40, time = 1,
                minpos = {x=pos.x-5, y=pos.y+5, z=pos.z-5}, maxpos = {x=pos.x+5, y=pos.y+20, z=pos.z+5},
                minvel = {x=0, y=2, z=0}, maxvel = {x=0, y=5, z=0},
                texture = "heart.png",
                glow = 14, size = 4,
            })

            minetest.chat_send_player(player_name, ">>> Le Dragon Céleste a été entièrement soigné !")
            if not minetest.is_creative_enabled(player_name) then
                item:take_item()
                clicker:set_wielded_item(item)
            end
            return
        end
        
        -- 3. MONTER ET DESCENDRE DU DRAGON
        if self.tamed and self.owner == player_name and item:get_name() == "" then
            if self.driver and self.driver == clicker then
                clicker:set_detach()
                self.driver = nil
                minetest.chat_send_player(player_name, ">>> Vous descendez de votre monture.")
            elseif not self.driver then
                clicker:set_attach(self.object, "", {x=0, y=200, z=0}, {x=0, y=0, z=0})
                self.driver = clicker
                minetest.chat_send_player(player_name, ">>> Vous êtes sur le Dragon ! Utilisez ZQSD pour voler, Espace pour monter et Maj pour descendre. Re-cliquez pour descendre du dragon.")
            end
        end
    end,

    on_punch = function(self, hitter, time_from_last_punch, tool_capabilities, dir, damage)
        if hitter and hitter:is_player() then
            if self.owner and self.owner == hitter:get_player_name() then
                return true -- Annule les dégâts si le maître tape
            end
        end
    end,

    on_step = function(self, dtime)
        local pos = self.object:get_pos()
        if not pos then return end
        
        -- TRAÎNÉE DE PARTICULES
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
        
        -- CONTRÔLE DU VOL PAR LE JOUEUR
        if self.driver then
            local ctrl = self.driver:get_player_control()
            local yaw = self.driver:get_look_horizontal()
            
            if ctrl.up or ctrl.down or ctrl.left or ctrl.right or ctrl.jump or ctrl.sneak then
                self.object:set_yaw(yaw)
                local dir = minetest.yaw_to_dir(yaw)
                
                local speed = 35
                local y_vel = 0
                
                if ctrl.jump then y_vel = speed end    -- Espace pour monter
                if ctrl.sneak then y_vel = -speed end  -- Maj pour descendre
                if ctrl.down then speed = -speed end   -- Reculer
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
-- 9. APPARITION NATURELLE AMÉLIORÉE
-- ==============================================================================
if mobs and mobs.spawn then
    mobs:spawn({
        name = "dragon_celeste:dragon_celeste",
        nodes = {"air", "default:dirt_with_grass", "default:stone", "default:snowblock", "default:dirt_with_snow", "default:sand", "default:desert_sand", "default:leaves", "default:water_source"},
        min_light = 0,
        max_light = 15,
        chance = 500000,
        active_object_count = 1,
        min_height = 0,
        max_height = 31000,
        spawn_by = "air",
    })
end