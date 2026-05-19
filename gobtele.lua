-----------------------------------------------------------------------------------
------------------------ ГОШКИ - ТЕЛЕПОРТАТОРЫ ------------------------------------
-----------------------------------------------------------------------------------
-- Принцип работы: игрок ставит гошку, после чего идет в destination печатает команду .gobtele 4324121
-- В этот момент в базу складывается запись с текущей координатой игрока, регается ивент госсип.
-- Дальше при клике на гошку игрока будет телепортировать по этим координатам.

local SQL_createGobTeleports = [[
CREATE TABLE IF NOT EXISTS `gameobject_teleport` (
`guid` INT(10) UNSIGNED NOT NULL,
`entry` INT(10) UNSIGNED NOT NULL,
`position_x` FLOAT NOT NULL,
`position_y` FLOAT NOT NULL,
`position_z` FLOAT NOT NULL,
`orientation` FLOAT NOT NULL,
`map` INT(10) UNSIGNED NOT NULL,
`user` INT(10) UNSIGNED NOT NULL,
`phase` INT(10) UNSIGNED NOT NULL DEFAULT '1'
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB
;
]]
WorldDBQuery( SQL_createGobTeleports )

GoTeleport = {} -- гошки - телепортаторы

function GoTeleport.onGoTeleportGossip(event, player, object)
    local guid = tonumber(tostring(object:GetDBTableGUIDLow()))
    local coordsQuery = WorldDBQuery('SELECT map, position_x, position_y, position_z, orientation, phase FROM gameobject_teleport where guid = ' .. guid );
    if(coordsQuery ~= nil) then
        local coords = coordsQuery:GetRow();
        player:Teleport( coords['map'], coords['position_x'], coords['position_y'], coords['position_z'], coords['orientation'] );
    else
        return false
    end
end

function GoTeleport.assignGobjectTeleportEvents()
    local goTeleQuery = WorldDBQuery('SELECT DISTINCT entry FROM gameobject_teleport g WHERE EXISTS (SELECT * FROM gameobject_template gt WHERE gt.entry = g.entry)');
    if (goTeleQuery ~= nil) then
        local rowCount = goTeleQuery:GetRowCount();
        local entry;
        for var=1,rowCount,1 do
            entry = goTeleQuery:GetString(0);
            RegisterGameObjectGossipEvent(entry, 1, GoTeleport.onGoTeleportGossip);
            goTeleQuery:NextRow();
        end
    end
end
GoTeleport.assignGobjectTeleportEvents(); -- Регистрируем события на гошкотелепорте.

local function OnPlayerCommand(event, player, command)
    if (string.match(command, 'gobtele %d+$')) then -- Привязка телепорта к гошке
        local guid = string.match(command, '%d+$')
        if(player:GetGMRank() > 0)then
            local entryQ = WorldDBQuery('SELECT id FROM gameobject where guid = ' .. guid );
            if(entryQ ~= nil) then
                local entry = entryQ:GetString(0);
                local x, y, z, o = player:GetLocation();
                local map = player:GetMapId();
                local pid = player:GetAccountId();
                local guidQ = WorldDBQuery('SELECT * FROM gameobject_teleport where guid = ' .. guid );
                if(guidQ ~= nil) then
                    WorldDBQuery('UPDATE gameobject_teleport SET map = ' .. map ..', position_x = ' .. x .. ', position_y = ' .. y .. ', position_z = ' .. z .. ', orientation = ' .. o .. ', user = ' .. pid .. ', phase = ' .. 0 ..' where guid = ' .. guid );
                    player:SendBroadcastMessage("Телепорт для объекта " ..guid.. " ОБНОВЛЕН!");
                else
                    WorldDBQuery('INSERT INTO gameobject_teleport (guid, entry, map, position_x, position_y, position_z, orientation, user, phase) VALUES (' .. guid ..',' .. entry ..', '.. map ..',' .. x .. ', ' .. y .. ',' .. z .. ',' .. o .. ', ' .. pid .. ', ' .. 0 .. ')');
                    RegisterGameObjectGossipEvent(entry, 1, GoTeleport.onGoTeleportGossip);
                    player:SendBroadcastMessage("Телепорт для объекта " ..guid.. " СОЗДАН!");
                end
            else
                player:SendBroadcastMessage("Ошибка - неверно введен GUID объекта!");
                return false
            end
        end
        return false
    end
end

RegisterPlayerEvent(42, OnPlayerCommand)