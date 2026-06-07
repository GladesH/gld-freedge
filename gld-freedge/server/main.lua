--[[
    fridge-degradation
    Ralentit la degradation des objets perissables (items avec `degrade`) places dans un frigo.

    Mecanisme ox_inventory :
      - Pour un item degradable, metadata.durability est un TIMESTAMP futur (os.time() + degrade*60)
        a partir duquel l'item est totalement degrade.
      - metadata.degrade est la duree totale de degradation, en minutes.
      - Pourcentage affiche = (durability - os.time()) * 100 / (degrade * 60)

    Pour ralentir sans "rafraichir" l'objet, on multiplie A LA FOIS le temps restant et `degrade`
    par le facteur : le pourcentage reste identique/continu, seul le rythme reel change.
    On stocke un flag metadata.fridge pour ne jamais appliquer deux fois l'effet.
]]

local factor = Config.FridgeMultiplier

-- Detection framework (purement informatif : la logique ne depend que d'ox_inventory)
local framework = (function()
    if GetResourceState('es_extended') == 'started' then return 'ESX' end
    if GetResourceState('qbx_core') == 'started' then return 'QBox' end
    if GetResourceState('qb-core') == 'started' then return 'QBCore' end
    return 'Standalone'
end)()

local function debug(...)
    if Config.Debug then
        print(('[fridge-degradation] %s'):format(string.format(...)))
    end
end

-- Pre-calcul des valeurs a rechercher dans l'id de stash.
-- Pour chaque entree on ajoute :
--   1) le hash du modele (GetHashKey) tel qu'il apparait dans l'id hrs ('-' -> 'n' comme hrs)
--   2) l'entree brute en minuscule (permet aussi un hash numerique ou un fragment d'id colle tel quel)
local fridgeMatches = {}
for i = 1, #Config.HashFridge do
    local entry = tostring(Config.HashFridge[i])
    fridgeMatches[#fridgeMatches + 1] = (tostring(GetHashKey(entry)):gsub('-', 'n')):lower()
    fridgeMatches[#fridgeMatches + 1] = entry:lower()
end

---@param invId string|number|nil
---@return boolean
local function isFridge(invId)
    if not invId then return false end
    invId = tostring(invId):lower()

    for i = 1, #fridgeMatches do
        if invId:find(fridgeMatches[i], 1, true) then return true end
    end

    return false
end

--- Applique ou retire l'effet frigo sur la metadata d'un slot.
---@param metadata table
---@param enter boolean true = entre au frigo, false = sort du frigo
---@return boolean changed
local function applyFridge(metadata, enter)
    -- Uniquement les items perissables (avec degrade). On ignore les durabilites statiques (armes, etc.)
    if not metadata or not metadata.degrade then return false end

    local now = os.time()
    local remaining = (metadata.durability or now) - now
    if remaining < 0 then remaining = 0 end

    if enter then
        if metadata.fridge then return false end -- deja au frigo
        metadata.durability = now + math.floor(remaining * factor)
        metadata.degrade = math.floor(metadata.degrade * factor)
        metadata.fridge = true
        return true
    else
        if not metadata.fridge then return false end -- n'etait pas au frigo
        metadata.durability = now + math.floor(remaining / factor)
        metadata.degrade = math.floor(metadata.degrade / factor)
        metadata.fridge = nil
        return true
    end
end

--- Ajuste l'item APRES son deplacement, directement sur le slot de destination.
--- On lit l'item reel via GetSlot puis on reecrit sa metadata via SetMetadata : c'est fiable
--- quelle que soit la version d'ox_inventory (contrairement a une mutation dans le hook,
--- qui peut etre ecrasee par le re-clonage interne lors du move).
---@param invId string|number
---@param slotId number
---@param enter boolean true = arrive dans un frigo, false = sort d'un frigo
local function adjustSlot(invId, slotId, enter)
    if not invId or type(slotId) ~= 'number' then return end

    -- Differe d'un tick : laisse le move se committer avant de lire/ecrire le slot.
    SetTimeout(0, function()
        local slot = exports.ox_inventory:GetSlot(invId, slotId)
        if not slot or not slot.metadata or not slot.metadata.degrade then return end

        -- Copie de la metadata pour ne pas muter l'objet vivant avant SetMetadata.
        local md = {}
        for k, v in pairs(slot.metadata) do md[k] = v end

        if applyFridge(md, enter) then
            exports.ox_inventory:SetMetadata(invId, slotId, md)
            if enter then
                debug('"%s" range au frigo -> degradation ralentie x%.1f (degrade=%smin)', slot.name, factor, md.degrade)
            else
                debug('"%s" sorti du frigo -> degradation normale (degrade=%smin)', slot.name, md.degrade)
            end
        end
    end)
end

local function onSwapItems(payload)
    if Config.Debug then
        debug('swap | from="%s" [%s] -> to="%s" [%s] | item=%s',
            tostring(payload.fromInventory), tostring(payload.fromType),
            tostring(payload.toInventory), tostring(payload.toType),
            (type(payload.fromSlot) == 'table' and payload.fromSlot.name) or '?')
    end

    local fromFridge = isFridge(payload.fromInventory)
    local toFridge = isFridge(payload.toInventory)

    if fromFridge == toFridge then return end -- meme contexte (les deux frigos ou aucun) : rien a faire

    -- Slot de destination de l'item principal (numero si slot vide, .slot si occupe)
    local toSlotId = (type(payload.toSlot) == 'number' and payload.toSlot)
        or (type(payload.toSlot) == 'table' and payload.toSlot.slot)
        or nil

    -- Item principal : il finit dans toInventory -> enter = toFridge
    adjustSlot(payload.toInventory, toSlotId, toFridge)

    -- Item secondaire (echange sur slot occupe) : il finit dans fromInventory -> enter = fromFridge
    if type(payload.toSlot) == 'table' and type(payload.fromSlot) == 'table' then
        adjustSlot(payload.fromInventory, payload.fromSlot.slot, fromFridge)
    end
    -- On ne retourne jamais false : on n'annule jamais le deplacement.
end

exports.ox_inventory:registerHook('swapItems', onSwapItems, {
    print = false,
})

CreateThread(function()
    print(('[fridge-degradation] Demarre (framework: %s | facteur: x%.1f).'):format(framework, factor))
end)
