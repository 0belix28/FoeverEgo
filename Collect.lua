-- ForeverEgo - Collect : lecture des informations du personnage connecté
local ADDON, ns = ...

-------------------------------------------------------------------------------
-- Infos générales
-------------------------------------------------------------------------------
function ns.ScanBasic()
    local c = ns.GetCurrentChar()

    c.region = GetCurrentRegionName and GetCurrentRegionName() or c.region
    local className, classFile = UnitClass("player")
    c.className, c.class = className, classFile
    c.race = UnitRace("player")
    c.sex = UnitSex("player")
    c.faction, c.factionLocal = UnitFactionGroup("player")
    c.level = UnitLevel("player")
    c.maxLevel = (GetMaxPlayerLevel and GetMaxPlayerLevel()) or MAX_PLAYER_LEVEL or 60
    c.xp, c.xpMax = UnitXP("player"), UnitXPMax("player")
    c.rested = GetXPExhaustion() or 0
    c.resting = IsResting() and true or false
    c.money = GetMoney()
    c.zone = GetRealZoneText()
    c.subzone = GetSubZoneText()
    c.bind = GetBindLocation and GetBindLocation() or nil

    if GetAverageItemLevel then
        local avg, equipped = GetAverageItemLevel()
        c.ilvl = equipped or avg
    end

    if IsInGuild() then
        local g, rank = GetGuildInfo("player")
        if g then c.guild, c.guildRank = g, rank end
    else
        c.guild, c.guildRank = nil, nil
    end

    -- JcJ (système d'honneur Classic)
    if UnitPVPRank and GetPVPRankInfo then
        local r = UnitPVPRank("player")
        if r and r >= 5 then
            local name, num = GetPVPRankInfo(r)
            c.pvpRankName, c.pvpRank = name, num
        else
            c.pvpRankName, c.pvpRank = nil, 0
        end
    end
    if GetPVPLifetimeStats then
        local hk, _, highest = GetPVPLifetimeStats()
        c.hk, c.highestRank = hk, highest
    end

    c.lastSeen = time()
end

-------------------------------------------------------------------------------
-- Compétences (métiers, armes, armures, langues...)
-------------------------------------------------------------------------------
function ns.CategorizeSkillHeader(header)
    local s = (header or ""):lower()
    if s:find("armure") or s:find("armor") then return "armor" end
    if s:find("arme") or s:find("weapon") then return "weapon" end
    if s:find("secondaire") or s:find("secondary") then return "secondary" end
    if s:find("métier") or s:find("profession") or s:find("trade") then return "prof" end
    if s:find("langue") or s:find("language") then return "lang" end
    if s:find("class") then return "class" end
    return "other"
end

-- Catégories du jeu (skillLineCategoryID)
local SKILL_CATEGORY = { [6] = "weapon", [7] = "class", [8] = "armor", [9] = "secondary", [10] = "lang", [11] = "prof" }
local SECONDARY_IDS = { [129] = true, [185] = true, [356] = true, [762] = true } -- secourisme, cuisine, pêche, monte

-- WoW Forever : C_SkillInfo (renvoie une table) ; Classic : fonctions globales (valeurs multiples)
local SI = C_SkillInfo
local NumSkillLines = (SI and SI.GetNumSkillLines) or GetNumSkillLines
local RawSkillLineInfo = (SI and SI.GetSkillLineInfo) or GetSkillLineInfo
local ExpandSkill = (SI and SI.ExpandSkillHeader) or ExpandSkillHeader
local CollapseSkill = (SI and SI.CollapseSkillHeader) or CollapseSkillHeader

-- Renvoie une table normalisée : name, isHeader, isExpanded, rank, mod, max, id, category
local function SkillLine(i)
    local a, isHeader, isExpanded, rank, _, mod, maxRank = RawSkillLineInfo(i)
    if type(a) == "table" then
        local t = a
        local expanded = t.isExpanded
        if expanded == nil and t.isCollapsed ~= nil then expanded = not t.isCollapsed end
        if expanded == nil then expanded = true end
        return {
            name = t.name or t.skillName, isHeader = t.isHeader, isExpanded = expanded,
            rank = tonumber(t.rank or t.skillRank) or 0,
            mod = tonumber(t.skillModifier or t.modifier or t.rankModifier) or 0,
            max = tonumber(t.maxRank or t.skillMaxRank) or 0,
            id = t.skillID or t.skillLineID, category = t.skillLineCategoryID,
        }
    end
    if not a then return nil end
    return { name = a, isHeader = isHeader, isExpanded = isExpanded, rank = rank or 0, mod = mod or 0, max = maxRank or 0 }
end

function ns.ScanSkills()
    if not NumSkillLines or not RawSkillLineInfo then return end
    local c = ns.GetCurrentChar()
    if (NumSkillLines() or 0) == 0 then return end -- pas encore chargé

    -- Déplier toutes les catégories (en retenant celles qui étaient repliées)
    local collapsedNames = {}
    if ExpandSkill then
        for _ = 1, 5 do
            local changed = false
            for i = NumSkillLines(), 1, -1 do
                local s = SkillLine(i)
                if s and s.isHeader and not s.isExpanded then
                    collapsedNames[s.name] = true
                    ExpandSkill(i)
                    changed = true
                end
            end
            if not changed then break end
        end
    end

    local skills, cat, header = {}, "other", nil
    for i = 1, NumSkillLines() do
        local s = SkillLine(i)
        if s and s.name then
            if s.isHeader then
                header = s.name
                cat = ns.CategorizeSkillHeader(s.name)
            else
                local scat = cat
                if s.category and SKILL_CATEGORY[s.category] then scat = SKILL_CATEGORY[s.category] end
                if s.id and SECONDARY_IDS[s.id] then scat = "secondary" end
                skills[s.name] = {
                    cat = scat, header = header, order = i, id = s.id,
                    rank = s.rank, mod = s.mod, max = s.max,
                }
            end
        end
    end

    -- Replier à nouveau ce que le joueur avait replié
    if next(collapsedNames) and CollapseSkill then
        for i = NumSkillLines(), 1, -1 do
            local s = SkillLine(i)
            if s and s.isHeader and collapsedNames[s.name] then CollapseSkill(i) end
        end
    end
    ns.suppress.skills = GetTime() + 1.5

    if next(skills) then c.skills = skills end
end

-------------------------------------------------------------------------------
-- Réputations
-------------------------------------------------------------------------------
local hasNewRepAPI = C_Reputation and C_Reputation.GetFactionDataByIndex and true or false

local function NumFactions()
    if C_Reputation and C_Reputation.GetNumFactions then return C_Reputation.GetNumFactions() end
    return GetNumFactions()
end

-- name, standing, min, max, value, isHeader, isCollapsed, hasRep, isChild, id
local function FactionAt(i)
    if hasNewRepAPI then
        local d = C_Reputation.GetFactionDataByIndex(i)
        if not d then return end
        return d.name, d.reaction, d.currentReactionThreshold, d.nextReactionThreshold, d.currentStanding,
            d.isHeader, d.isCollapsed, d.isHeaderWithRep, d.isChild, d.factionID
    end
    local name, _, standing, bmin, bmax, value, _, _, isHeader, isCollapsed, hasRep, _, isChild, id = GetFactionInfo(i)
    return name, standing, bmin, bmax, value, isHeader, isCollapsed, hasRep, isChild, id
end

local function ExpandFaction(i)
    if C_Reputation and C_Reputation.ExpandFactionHeader then C_Reputation.ExpandFactionHeader(i) else ExpandFactionHeader(i) end
end

local function CollapseFaction(i)
    if C_Reputation and C_Reputation.CollapseFactionHeader then C_Reputation.CollapseFactionHeader(i) else CollapseFactionHeader(i) end
end

function ns.ScanReputations()
    local c = ns.GetCurrentChar()

    local collapsedNames = {}
    for _ = 1, 10 do
        local changed = false
        for i = NumFactions(), 1, -1 do
            local name, _, _, _, _, isHeader, isCollapsed = FactionAt(i)
            if name and isHeader and isCollapsed then
                collapsedNames[name] = true
                ExpandFaction(i)
                changed = true
            end
        end
        if not changed then break end
    end

    local reps, group = {}, nil
    for i = 1, NumFactions() do
        local name, standing, bmin, bmax, value, isHeader, _, hasRep, isChild, id = FactionAt(i)
        if name then
            if isHeader and not isChild then
                group = name
            end
            if (not isHeader) or hasRep then
                reps[name] = {
                    standing = standing or 4, min = bmin or 0, max = bmax or 0, value = value or 0,
                    group = (isHeader and not isChild) and name or group, id = id, order = i,
                }
            end
        end
    end

    if next(collapsedNames) then
        for i = NumFactions(), 1, -1 do
            local name, _, _, _, _, isHeader, isCollapsed = FactionAt(i)
            if name and isHeader and not isCollapsed and collapsedNames[name] then CollapseFaction(i) end
        end
    end
    ns.suppress.reps = GetTime() + 1.5

    if next(reps) then c.reps = reps end
end

-------------------------------------------------------------------------------
-- Donjons / raids verrouillés
-------------------------------------------------------------------------------
function ns.ScanSavedInstances()
    if not GetNumSavedInstances then return end
    local c = ns.GetCurrentChar()
    local lockouts, now = {}, time()
    for i = 1, GetNumSavedInstances() do
        local name, id, reset, _, locked, _, _, isRaid, maxPlayers, diffName, numEnc, encProg = GetSavedInstanceInfo(i)
        if name and locked and reset and reset > 0 then
            lockouts[name] = {
                id = id, resetAt = now + reset, isRaid = isRaid, maxPlayers = maxPlayers,
                diffName = diffName, numEnc = numEnc or 0, prog = encProg or 0,
            }
        end
    end
    c.lockouts = lockouts
end

-------------------------------------------------------------------------------
-- Équipement porté (+ enchantements)
-------------------------------------------------------------------------------
ns.GEAR_SLOTS = {
    { id = 1, name = "Tête", enchantable = true },
    { id = 2, name = "Cou" },
    { id = 3, name = "Épaules", enchantable = true },
    { id = 15, name = "Dos", enchantable = true },
    { id = 5, name = "Torse", enchantable = true },
    { id = 4, name = "Chemise" },
    { id = 19, name = "Tabard" },
    { id = 9, name = "Poignets", enchantable = true },
    { id = 10, name = "Mains", enchantable = true },
    { id = 6, name = "Taille" },
    { id = 7, name = "Jambes", enchantable = true },
    { id = 8, name = "Pieds", enchantable = true },
    { id = 11, name = "Doigt" },
    { id = 12, name = "Doigt" },
    { id = 13, name = "Bijou" },
    { id = 14, name = "Bijou" },
    { id = 16, name = "Main droite", enchantable = true },
    { id = 17, name = "Main gauche", enchantable = true },
    { id = 18, name = "À distance" },
}

local GetItemInfoFn = (C_Item and C_Item.GetItemInfo) or GetItemInfo

local scanTip
local function TooltipLines(itemString)
    if not scanTip then
        scanTip = CreateFrame("GameTooltip", "ForeverEgoScanTooltip", nil, "GameTooltipTemplate")
    end
    scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanTip:ClearLines()
    scanTip:SetHyperlink(itemString)
    local lines = {}
    for i = 2, scanTip:NumLines() do
        local fs = _G["ForeverEgoScanTooltipTextLeft" .. i]
        local t = fs and fs:GetText()
        if t and t ~= "" then lines[#lines + 1] = t end
    end
    scanTip:Hide()
    return lines
end

local enchantPattern
if ENCHANTED_TOOLTIP_LINE then
    enchantPattern = "^" .. ENCHANTED_TOOLTIP_LINE:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%s", "(.+)") .. "$"
end

-- Texte de l'enchantement : on compare l'infobulle de l'objet avec et sans enchantement,
-- la ligne en plus est l'enchantement.
function ns.GetEnchantText(link)
    local itemString = link:match("|H(item:[^|]+)|h") or link
    local enchantId = tonumber(itemString:match("^item:%d+:(%d*)") or "")
    if not enchantId or enchantId == 0 then return nil, nil end
    local base = itemString:gsub("^(item:%d+):%d*", "%1:", 1)
    local with, without = TooltipLines(itemString), TooltipLines(base)
    local count = {}
    for _, t in ipairs(without) do count[t] = (count[t] or 0) + 1 end
    for _, t in ipairs(with) do
        if (count[t] or 0) > 0 then
            count[t] = count[t] - 1
        else
            if enchantPattern then t = t:match(enchantPattern) or t end
            return t, enchantId
        end
    end
    return nil, enchantId
end

function ns.ScanGear()
    local c = ns.GetCurrentChar()
    local gear = {}
    for _, slot in ipairs(ns.GEAR_SLOTS) do
        local link = GetInventoryItemLink("player", slot.id)
        if link then
            local _, _, quality, ilvl = GetItemInfoFn(link)
            if GetDetailedItemLevelInfo then ilvl = GetDetailedItemLevelInfo(link) or ilvl end
            local ok, enchant, enchantId = pcall(ns.GetEnchantText, link)
            if not ok then enchant, enchantId = nil, nil end
            gear[slot.id] = {
                link = link,
                icon = GetInventoryItemTexture("player", slot.id),
                quality = quality,
                ilvl = ilvl,
                enchant = enchant,
                enchantId = enchantId,
            }
        end
    end
    c.gear = gear
end

-------------------------------------------------------------------------------
-- Temps de jeu (/played sans l'afficher dans le chat)
-------------------------------------------------------------------------------
local mutedFrames

function ns.RestorePlayedFrames()
    if not mutedFrames then return end
    for _, cf in ipairs(mutedFrames) do cf:RegisterEvent("TIME_PLAYED_MSG") end
    mutedFrames = nil
end

function ns.RequestPlayedSilently()
    if not RequestTimePlayed then return end
    mutedFrames = {}
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local cf = _G["ChatFrame" .. i]
        if cf and cf:IsEventRegistered("TIME_PLAYED_MSG") then
            cf:UnregisterEvent("TIME_PLAYED_MSG")
            mutedFrames[#mutedFrames + 1] = cf
        end
    end
    RequestTimePlayed()
    C_Timer.After(10, ns.RestorePlayedFrames) -- sécurité
end

function ns.OnTimePlayed(total, level)
    local c = ns.GetCurrentChar()
    c.played, c.playedLevel, c.playedAt = total, level, time()
    C_Timer.After(0, ns.RestorePlayedFrames)
    ns.RefreshUI()
end

-------------------------------------------------------------------------------
-- Recettes des métiers (enregistrées quand la fenêtre de métier est ouverte)
-------------------------------------------------------------------------------
local TS = C_TradeSkillUI
local ItemName = (C_Item and C_Item.GetItemNameByID) or function(id) return (GetItemInfo(id)) end
local RequestItem = C_Item and C_Item.RequestLoadItemDataByID

local DIFF_BY_ENUM = { [0] = "optimal", [1] = "medium", [2] = "easy", [3] = "trivial" }
if Enum and Enum.TradeskillRelativeDifficulty then
    local e = Enum.TradeskillRelativeDifficulty
    DIFF_BY_ENUM = {}
    if e.Optimal then DIFF_BY_ENUM[e.Optimal] = "optimal" end
    if e.Medium then DIFF_BY_ENUM[e.Medium] = "medium" end
    if e.Easy then DIFF_BY_ENUM[e.Easy] = "easy" end
    if e.Trivial then DIFF_BY_ENUM[e.Trivial] = "trivial" end
end

local function Call(fn, ...)
    if not fn then return nil end
    local ok, a, b, c, d, e, f = pcall(fn, ...)
    if ok then return a, b, c, d, e, f end
end

-- Faux quand on regarde le métier d'un autre joueur, d'une guilde ou d'un PNJ
local function IsOwnTradeSkill()
    if not TS then return true end
    if Call(TS.IsTradeSkillLinked) or Call(TS.IsTradeSkillGuild) or Call(TS.IsNPCCrafting) then return false end
    return true
end

-- Seul l'identifiant de l'objet est enregistré (le nom est retrouvé à l'affichage)
local function Reagent(itemID, count, name)
    if itemID then
        if RequestItem and not ItemName(itemID) then pcall(RequestItem, itemID) end
        return { id = itemID, n = count or 1 }
    end
    return { n = count or 1, name = name }
end

local function ScanModern()
    local info = Call(TS.GetBaseProfessionInfo)
    if not info or not info.professionID or info.professionID == 0 then return end
    local child = Call(TS.GetChildProfessionInfo)
    local ids = Call(TS.GetAllRecipeIDs)
    if not ids or #ids == 0 then return end

    local catNames = {}
    local function CatName(catID)
        if not catID then return nil end
        if catNames[catID] == nil then
            local ci = Call(TS.GetCategoryInfo, catID)
            catNames[catID] = (ci and ci.name) or false
        end
        return catNames[catID] or nil
    end

    local basic = Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic
    local list = {}
    for _, id in ipairs(ids) do
        local r = Call(TS.GetRecipeInfo, id)
        if r and r.learned and not r.isRecraft and not r.isDummyRecipe and r.name then
            local e = {
                id = id, name = r.name, icon = r.icon, cat = CatName(r.categoryID),
                diff = DIFF_BY_ENUM[r.relativeDifficulty] or "trivial",
                link = Call(TS.GetRecipeItemLink, id) or Call(TS.GetRecipeLink, id),
                reag = {},
            }
            local sch = Call(TS.GetRecipeSchematic, id, false)
            if sch then
                e.qmin, e.qmax = sch.quantityMin, sch.quantityMax
                for _, slot in ipairs(sch.reagentSlotSchematics or {}) do
                    if (not basic or slot.reagentType == basic or slot.required) and slot.reagents and slot.reagents[1] then
                        e.reag[#e.reag + 1] = Reagent(slot.reagents[1].itemID, slot.quantityRequired)
                    end
                end
            end
            list[#list + 1] = e
        end
    end
    local p = child and child.professionID and child.professionID ~= 0 and child or info
    return {
        id = info.parentProfessionID or info.professionID,
        name = info.parentProfessionName or info.professionName,
        rank = p.skillLevel, max = p.maxSkillLevel,
        list = list,
    }
end

-- Ancienne API (classique), au cas où
local CLASSIC_DIFF = { optimal = "optimal", medium = "medium", easy = "easy", trivial = "trivial" }
local function ScanClassic()
    if not GetNumTradeSkills or not GetTradeSkillLine then return end
    local profName, rank, maxRank = GetTradeSkillLine()
    local n = GetNumTradeSkills() or 0
    if not profName or profName == "UNKNOWN" or n == 0 then return end
    local list, cat = {}, nil
    for i = 1, n do
        local name, kind = GetTradeSkillInfo(i)
        if kind == "header" or kind == "subheader" then
            cat = name
        elseif name then
            local e = {
                name = name, cat = cat, diff = CLASSIC_DIFF[kind] or "trivial",
                icon = GetTradeSkillIcon and GetTradeSkillIcon(i),
                link = (GetTradeSkillItemLink and GetTradeSkillItemLink(i))
                    or (GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(i)),
                reag = {},
            }
            if GetTradeSkillNumMade then e.qmin, e.qmax = GetTradeSkillNumMade(i) end
            for j = 1, (GetTradeSkillNumReagents and GetTradeSkillNumReagents(i) or 0) do
                local rName, _, count = GetTradeSkillReagentInfo(i, j)
                local rLink = GetTradeSkillReagentItemLink and GetTradeSkillReagentItemLink(i, j)
                local rId = rLink and tonumber(rLink:match("item:(%d+)"))
                e.reag[#e.reag + 1] = Reagent(rId, count, rName)
            end
            list[#list + 1] = e
        end
    end
    return { name = profName, rank = rank, max = maxRank, list = list }
end

function ns.ScanRecipes()
    if not ns.tradeSkillOpen or not IsOwnTradeSkill() then return end
    local data
    if TS and TS.GetAllRecipeIDs and TS.GetBaseProfessionInfo then data = ScanModern() end
    if not data then data = ScanClassic() end
    if not data or not data.name or #data.list == 0 then return end

    local c = ns.GetCurrentChar()
    c.recipes = c.recipes or {}
    data.updated = time()
    c.recipes[data.name] = data
end

-- Retrouve les recettes enregistrées d'un métier (par identifiant puis par nom)
function ns.GetRecipes(c, skillName, skillId)
    if not c or not c.recipes then return nil end
    if c.recipes[skillName] then return c.recipes[skillName] end
    if skillId then
        for _, d in pairs(c.recipes) do
            if d.id == skillId then return d end
        end
    end
end
