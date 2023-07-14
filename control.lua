--------------------------
--FUNCTIONS---------------
--------------------------
--Is this mod entity? If yes true, othervise false
isModEntity = function(modEntity)
	if modEntity and modEntity.name ~= nil then		-- null fix
		--List of known entities
		if modEntity.name == "minigun-platform-mk1" 
			or modEntity.name == "rocket-platform-mk1" 
			or modEntity.name == "cannon-wagon-mk1" 
			or modEntity.name == "flamethrower-wagon-mk1"
			or modEntity.name == "radar-platform-mk1" then	
			return true
		end
	end
	return false
end

--Create turret as proxy to platform (data stored to table)
function createProxyTurretMinigun(position, surface, force)
	local proxy = surface.create_entity{
		name = "minigun-turret-mk1", 
		position = position, 
		force = force
	}
	return proxy
end

function createProxyTurretRocket(position, surface, force)
	local proxy = surface.create_entity{
		name = "rocket-turret-mk1", 
		position = position, 
		force = force
	}
	return proxy
end

function createProxyTurretCannon(position, surface, force)
	local proxy = surface.create_entity{
		name = "cannon-turret-mk1", 
		position = position, 
		force = force
	}
	return proxy
end

function createProxyTurretFlamethrower(position, surface, force)
	local proxy = surface.create_entity{
		name = "flamethrower-turret-mk1", 
		position = position, 
		force = force
	}
	return proxy
end

function createProxyRadar(position, surface, force)
	local proxy = surface.create_entity{
		name = "radar-mk1", 
		position = position, 
		force = force
	}
	return proxy
end

--Create initTurretPlatformList table to store data for proxy and platform or pass data if created
function initTurretPlatformList(tableValue)
	--If first time calling = create table?
	if tableValue == nil then
		return {}
	--if table created just pass values
	else
		return tableValue
	end
end

-------------
--ON_EVENTS--
-------------

--ON LOAD \/
--Prevent on load bug when no hp ws found
script.on_load(function(event)
	platformMaxHealth = 1000
end)
--ON LOAD /\


--ON BUILT \/--
function entityBuilt(event)
	--createdEntity reference (to simplify usage in this context)
	local createdEntity = {}
    if event.name == defines.events.script_raised_built then 
        createdEntity = event.entity
    else
        createdEntity = event.created_entity
    end
	
	--Is this mod entity?
	if isModEntity(createdEntity) then
		--createdPlatform now defines itself with created platform + turret (later on)
		local createdPlatform = {
			--Actual entity as class
			entity = createdEntity
		}
		
		if createdEntity.name == "minigun-platform-mk1" then
			--Create and define a proxy at the created entity position, surface, and force
			createdPlatform.proxy = createProxyTurretMinigun(
				createdEntity.position, 
				createdEntity.surface, 
				createdEntity.force
			)
		end 
		
		if createdEntity.name == "cannon-wagon-mk1" then		
			createdPlatform.proxy = createProxyTurretCannon(
				createdEntity.position, 
				createdEntity.surface, 
				createdEntity.force
			)
		end 
		
		if createdEntity.name == "rocket-platform-mk1" then		
			createdPlatform.proxy = createProxyTurretRocket(
				createdEntity.position, 
				createdEntity.surface, 
				createdEntity.force
			)
		end 
		
		if createdEntity.name == "flamethrower-wagon-mk1" then		
			createdPlatform.proxy = createProxyTurretFlamethrower(
				createdEntity.position, 
				createdEntity.surface, 
				createdEntity.force
			)
		end 
		
		if createdEntity.name == "radar-platform-mk1" then	
			createdPlatform.proxy = createProxyRadar(
				createdEntity.position, 
				createdEntity.surface, 
				createdEntity.force
			)
		end 
		
		--Create table "turretPlatformList" and store data (if null create, else just pass data)
		global.turretPlatformList = initTurretPlatformList(global.turretPlatformList)
		--Add created platform and turret to the table (list)
		table.insert(global.turretPlatformList, createdPlatform)
		
		--Define max health var (for reference)
		platformMaxHealth = 1000
	end
end

--ON_BUILT EVENT
script.on_event(defines.events.on_built_entity, entityBuilt)
script.on_event(defines.events.on_robot_built_entity, entityBuilt)
script.on_event(defines.events.script_raised_built, entityBuilt)
--ON BUILT /\--

--ON TICK \/--
-- Move each turret to follow its wagon and transfer ammo
function onTickMain(event)
    -- If turretPlatformList is not empty (turret and platform placed in world)
    if global.turretPlatformList ~= nil then
        -- For each individual createdPlatform
        for i, createdPlatform in ipairs(global.turretPlatformList) do
            -- Is this entity valid/nil?
            if createdPlatform.proxy ~= nil and createdPlatform.proxy.valid then
                -- Teleport the turret to the platform's position
                createdPlatform.proxy.teleport({
                    x = createdPlatform.entity.position.x,
                    y = createdPlatform.entity.position.y
                })

                -- Transfer ammo from platform to turret
                local cargoWagonInventory = createdPlatform.entity.get_inventory(defines.inventory.cargo_wagon)
                local turretInventory = createdPlatform.proxy.get_inventory(defines.inventory.turret_ammo)

                -- Iterate over the contents of the cargo wagon inventory
                for i = 1, #cargoWagonInventory do
                    local stack = cargoWagonInventory[i]
                    if stack.valid_for_read and turretInventory.can_insert(stack) then
                        -- Transfer the stack from the cargo wagon to the turret
                        local inserted_count = turretInventory.insert(stack)
                        stack.count = stack.count - inserted_count
                        if stack.count == 0 then
                            cargoWagonInventory[i].clear()
                        end
                    end
                end

                -- Taken damage to TURRET is applied to WAGON
                if event.tick % 20 == 3 then
                    local damageTaken = platformMaxHealth - createdPlatform.proxy.health
                    if damageTaken > 0 then
                        local platformCurrentHealth = createdPlatform.entity.health
                        if platformCurrentHealth <= damageTaken then
                            createdPlatform.proxy.destroy()
                            createdPlatform.entity.die()
                        else
                            createdPlatform.entity.health = platformCurrentHealth - damageTaken
                            createdPlatform.proxy.health = platformMaxHealth
                        end
                    end
                end
            end
        end
    end
end

script.on_event(defines.events.on_tick, onTickMain)
--ON TICK /\--

--ON PRE MINED (Remove turret when object not mined but going to be mined) \/--
-- If removed/destroyed
function entityRemoved(event)
	-- Is this a known entity?
	if isModEntity(event.entity) then
		local newFunction = function (val) 
			return val.entity == event.entity
		end
		
		local wagon = getWagonFromEntity(global.turretPlatformList, event.entity)
		
		-- If the wagon is still there
		if wagon ~= nil then
			if wagon.proxy ~= nil and wagon.proxy.valid then
				wagon.proxy.destroy()
				wagon.proxy = nil
			end
			
			-- Remove from the table
			global.turretPlatformList = nilIfEmptyTable(remove_if(newFunction, global.turretPlatformList))
		end
	end
end

script.on_event(defines.events.on_pre_player_mined_item, entityRemoved)
script.on_event(defines.events.on_robot_pre_mined, entityRemoved)
script.on_event(defines.events.script_raised_destroy, entityRemoved)
--ON PRE MINED (Remove turret when object not mined but going to be mined) /\--

--ON MINED (BUFFER for item) \/--
function entityMined(event)
	-- Is this a mod entity?
	if isModEntity(event.entity) then
		-- Define buffer for removed entity
		local bufferRemovedEntity = event.buffer
		
		-- Additional code here if needed
	end
end

script.on_event(defines.events.on_player_mined_entity, entityMined)
--ON MINED (BUFFER) /\--

function entityDestroyed(event)
	-- Is this a known entity?
	if isModEntity(event.entity) then
		local newFunction = function (val) 
			return val.entity == event.entity
		end
		
		local wagon = getWagonFromEntity(global.turretPlatformList, event.entity)
		
		-- If the wagon is still there
		if wagon ~= nil then
			if wagon.proxy ~= nil and wagon.proxy.valid then
				-- Add explosion
				wagon.proxy.destroy()
				-- Alternatively, you can use wagon.damage(10000, game.forces.enemy) instead of destroy
				wagon.proxy = nil
			end
			
			global.turretPlatformList = nilIfEmptyTable(remove_if(newFunction, global.turretPlatformList))
		end
	end
end

script.on_event(defines.events.on_entity_died, entityDestroyed)

function getWagonFromEntity(wagons, entity)
	if wagons == nil then return nil end
	
	for i, value in ipairs(wagons) do
		if isEntityValid(value.entity) and entity == value.entity then
			return value
		end
	end
end

-- Is this entity valid? (not null and valid)
function isEntityValid(validEntity)
	if validEntity ~= nil and validEntity.valid then
		return true
	end
	return false
end

function nilIfEmptyTable(value)
	if value == nil or #value < 1 then
		return nil
	else 
		return value
	end
end

function remove_if(func, arr)
	if arr == nil then return nil end
	local new_array = {}
	for _, v in ipairs(arr) do
		if not func(v) then table.insert(new_array, v) end
	end
	return new_array
end
