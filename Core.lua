-- ForeverEgo - Core : base de données, événements, type de serveur, commandes
local ADDON, ns = ...
_G.ForeverEgo = ns

local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.version = (GetMeta and GetMeta(ADDON, "Version")) or "?"

local PREFIX = "|cff33ccffForeverEgo|r : "
function ns.Print(...)
    print(PREFIX .. string.join(" ", tostringall(...)))
end

-------------------------------------------------------------------------------
-- Types de serveur
-------------------------------------------------------------------------------
ns.REALM_TYPES = { "PVE", "PVP", "RP", "RPPVP", "HC" }
ns.REALM_TYPE_LABELS = {
    PVE = "PvE", PVP = "PvP", RP = "RP", RPPVP = "RP-PvP", HC = "Hardcore",
}
ns.REALM_TYPE_DESC = {
    PVE = "PvE - Normal (JcE)",
    PVP = "PvP - Joueur contre joueur (JcJ)",
    RP = "RP - Jeu de rôle (JcE)",
    RPPVP = "RP-PvP - Jeu de rôle (JcJ)",
    HC = "Hardcore - Une seule vie",
}

-------------------------------------------------------------------------------
-- Base de données
-------------------------------------------------------------------------------
ns.DEFAULT_HEIGHT = 580

local DEFAULT_SETTINGS = {
    showAllTypes = false,
    style = "auto",
    collapsed = { armor = true, lang = true, class = true, other = true },
    hidden = {},
    minimap = { angle = 220, hide = false },
    width = 900,
    height = ns.DEFAULT_HEIGHT,
}

local function ApplyDefaults(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            if type(v) == "table" then
                dst[k] = {}
                ApplyDefaults(dst[k], v)
            else
                dst[k] = v
            end
        elseif type(v) == "table" and type(dst[k]) == "table" then
            ApplyDefaults(dst[k], v)
        end
    end
end

function ns.InitDB()
    ForeverEgoDB = ForeverEgoDB or {}
    local db = ForeverEgoDB
    db.chars = db.chars or {}
    db.realms = db.realms or {}
    db.settings = db.settings or {}
    ApplyDefaults(db.settings, DEFAULT_SETTINGS)
    ns.db = db

    -- Migration v2 : les personnages sont maintenant identifiés par leur GUID.
    -- Les anciennes fiches (clé "Prénom-Royaume") peuvent mélanger deux persos du même prénom : on les retire.
    if (db.version or 1) < 2 then
        local removed = 0
        for key in pairs(db.chars) do
            if not key:find("^Player%-") then
                db.chars[key] = nil
                removed = removed + 1
            end
        end
        wipe(db.settings.hidden)
        ns.migratedChars = removed
    end
    db.version = 2
    db.settings.sort = nil

    -- 0.4.0 : recettes allégées (nom des composants et lien de sort en double retirés)
    if not db.slimRecipes then
        for _, c in pairs(db.chars) do
            for _, d in pairs(c.recipes or {}) do
                for _, e in ipairs(d.list or {}) do
                    e.link = e.link or e.spell
                    e.spell = nil
                    for _, rg in ipairs(e.reag or {}) do
                        if rg.id then rg.name = nil end
                    end
                end
            end
        end
        db.slimRecipes = true
    end

    -- Suivi de version de l'addon (format 0.X.Y : X = mise à jour majeure, Y = mineure)
    if db.addonVersion ~= ns.version then
        ns.previousVersion = db.addonVersion or "nouvelle installation"
        db.addonVersion = ns.version
        ns.justUpdated = true
    end
end

-- Clé unique du personnage : son GUID (sur Forever plusieurs persos peuvent avoir le même prénom)
function ns.CurrentKey()
    return UnitGUID("player") or ((UnitName("player") or "?") .. "-" .. (GetRealmName() or "?"))
end

-- Prénom et nom de famille (WoW Forever : UnitName renvoie le nom de famille en 2e valeur)
function ns.GetPlayerNames()
    local name, surname = (UnitNameUnmodified or UnitName)("player")
    if type(surname) ~= "string" or surname == "" then surname = nil end
    return name, surname
end

function ns.FullName(c)
    if not c then return "?" end
    if c.surname then return (c.name or "?") .. " " .. c.surname end
    return c.name or "?"
end

-- Type de serveur fourni par le jeu (règles PvP / RP / Hardcore), nil si l'API n'existe pas
function ns.DetectRuleset()
    if not (C_GameRules and C_GameRules.IsGameRuleActive and Enum and Enum.GameRule) then return nil end
    local R = Enum.GameRule
    local function Active(rule)
        if rule == nil then return false end
        local ok, v = pcall(C_GameRules.IsGameRuleActive, rule)
        return ok and v and true or false
    end
    local pvp, rp, hc = Active(R.PvPRuleset), Active(R.RPRuleset), Active(R.HardcoreRuleset)
    if pvp and rp then return "RPPVP" end
    if pvp then return "PVP" end
    if rp then return "RP" end
    if hc then return "HC" end
    if R.PvPRuleset ~= nil then return "PVE" end
    return nil
end

function ns.CurrentRuleset()
    return ns.DetectRuleset() or ns.GetRealmType(GetRealmName())
end

function ns.CharRuleset(c)
    return c.ruleset or ns.GetRealmType(c.realm)
end

function ns.GetCurrentChar()
    local key = ns.CurrentKey()
    local c = ns.db.chars[key]
    if not c then
        c = { key = key }
        ns.db.chars[key] = c
    end
    c.name, c.surname = ns.GetPlayerNames()
    c.realm = GetRealmName()
    c.ruleset = ns.CurrentRuleset() or c.ruleset
    return c
end

function ns.GetRealmType(realm)
    local r = realm and ns.db.realms[realm]
    return r and r.type
end

function ns.SetRealmType(realm, t)
    ns.db.realms[realm] = ns.db.realms[realm] or {}
    ns.db.realms[realm].type = t
    if realm == GetRealmName() then ns.GetCurrentChar().ruleset = t end
    ns.Print(("Serveur |cffffd100%s|r défini comme |cff88ff88%s|r. Seuls les personnages des serveurs %s seront affichés.")
        :format(realm, ns.REALM_TYPE_LABELS[t], ns.REALM_TYPE_LABELS[t]))
    ns.RefreshUI()
end

-- Tentative de détection du type de serveur (simple suggestion, sauf Hardcore)
function ns.GuessRealmType()
    if C_GameRules and C_GameRules.IsHardcoreActive then
        local ok, hc = pcall(C_GameRules.IsHardcoreActive)
        if ok and hc then return "HC", true end
    end
    local pvpType = GetZonePVPInfo and GetZonePVPInfo()
    if pvpType == "contested" or pvpType == "hostile" then
        local desired = GetPVPDesired and GetPVPDesired()
        if UnitIsPVP("player") and not desired then
            return "PVP", false
        elseif not UnitIsPVP("player") then
            return "PVE", false
        end
    end
    return nil, false
end

-- Bouton / commande « type de serveur »
function ns.OpenRealmType()
    local detected = ns.DetectRuleset()
    if detected then
        ns.Print("Type de serveur détecté automatiquement : |cff88ff88" .. ns.REALM_TYPE_LABELS[detected] .. "|r")
    else
        ns.ShowRealmTypePopup(GetRealmName(), (ns.GuessRealmType()))
    end
end

function ns.CheckRealmType()
    local realm = GetRealmName()
    if ns.DetectRuleset() then return end -- détecté automatiquement par le jeu
    if not realm or ns.GetRealmType(realm) then return end
    local guess, sure = ns.GuessRealmType()
    if sure then
        ns.SetRealmType(realm, guess)
    else
        ns.ShowRealmTypePopup(realm, guess)
    end
end

-- Rang d'affichage d'un type de serveur (PvE, PvP, RP, RP-PvP, Hardcore, puis inconnu)
local TYPE_RANK = {}
for i, t in ipairs(ns.REALM_TYPES) do TYPE_RANK[t] = i end
function ns.TypeRank(t) return TYPE_RANK[t] or 99 end
function ns.CharGroup(c) return ns.CharRuleset(c) or "?" end

-------------------------------------------------------------------------------
-- Liste des personnages à afficher (filtre par type de serveur + tri)
-------------------------------------------------------------------------------
function ns.GetVisibleChars()
    local s = ns.db.settings
    local cur = ns.CurrentKey()
    local curType = ns.CurrentRuleset()
    local list, rank = {}, {}
    for key, c in pairs(ns.db.chars) do
        if c.name and (key == cur or not s.hidden[key]) then
            local t = ns.CharRuleset(c)
            if s.showAllTypes or key == cur or (curType and t == curType) then
                list[#list + 1] = c
                rank[c] = ns.TypeRank(t)
            end
        end
    end

    -- Tri automatique : groupe de type de serveur, puis niveau décroissant, puis nom
    table.sort(list, function(a, b)
        if rank[a] ~= rank[b] then return rank[a] < rank[b] end
        if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) > (b.level or 0) end
        if ns.FullName(a) ~= ns.FullName(b) then return ns.FullName(a) < ns.FullName(b) end
        return a.key < b.key
    end)
    return list, curType
end

-------------------------------------------------------------------------------
-- Planification des scans (anti-spam)
-------------------------------------------------------------------------------
local ORDER = { "basic", "skills", "reps", "raids", "gear", "recipes" }
local pending, timerRunning = {}, false
ns.suppress = {}

local function SafeCall(fn)
    if not fn then return end
    local ok, err = pcall(fn)
    if not ok then geterrorhandler()(err) end
end

local function Flush()
    timerRunning = false
    if not ns.db then return end
    -- Jamais de lecture pendant un combat : on reprend à la sortie du combat
    if InCombatLockdown() then
        ns.waitingCombat = true
        return
    end
    local scanners = {
        basic = ns.ScanBasic, skills = ns.ScanSkills, reps = ns.ScanReputations, raids = ns.ScanSavedInstances,
        gear = ns.ScanGear, recipes = ns.ScanRecipes,
    }
    for _, part in ipairs(ORDER) do
        if pending[part] then
            pending[part] = nil
            SafeCall(scanners[part])
        end
    end
    ns.RefreshUI()
end

function ns.Schedule(part, delay)
    if part == "all" then
        for _, p in ipairs(ORDER) do pending[p] = true end
    else
        pending[part] = true
    end
    if not timerRunning then
        timerRunning = true
        C_Timer.After(delay or 1, Flush)
    end
end

-- Les demandes de rafraîchissement d'une même image sont regroupées en une seule
local refreshQueued = false
local function DoRefreshUI()
    refreshQueued = false
    if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
    if ns.UI and ns.UI.RefreshGear then ns.UI.RefreshGear() end
    if ns.UI and ns.UI.RefreshCharList then ns.UI.RefreshCharList() end
    if ns.UI and ns.UI.RefreshRecipes then ns.UI.RefreshRecipes() end
end

function ns.RefreshUI()
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0, DoRefreshUI)
end

-------------------------------------------------------------------------------
-- Événements
-------------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ns.eventFrame = ev

local EVENTS = {
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT",
    "PLAYER_LEVEL_UP", "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_MONEY", "PLAYER_UPDATE_RESTING",
    "PLAYER_GUILD_UPDATE", "GUILD_ROSTER_UPDATE", "ZONE_CHANGED_NEW_AREA", "PLAYER_EQUIPMENT_CHANGED",
    "PLAYER_PVP_KILLS_CHANGED", "PLAYER_PVP_RANK_CHANGED",
    "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL",
    "UPDATE_FACTION", "CHAT_MSG_COMBAT_FACTION_CHANGE",
    "UPDATE_INSTANCE_INFO", "TIME_PLAYED_MSG",
    "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED",
    "NEW_RECIPE_LEARNED", "GET_ITEM_INFO_RECEIVED", "PLAYER_REGEN_ENABLED",
}
for _, e in ipairs(EVENTS) do pcall(ev.RegisterEvent, ev, e) end

local playedRequested = false

ev:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        ns.InitDB()
        if ns.Skin then ns.Skin.Init() end
        ns.GetCurrentChar()
        if ns.UI and ns.UI.CreateMinimapButton then ns.UI.CreateMinimapButton() end
        if ns.justUpdated then
            ns.Print(("version |cff88ff88%s|r chargée (avant : %s). Tape /fego aide pour les commandes.")
                :format(ns.version, ns.previousVersion))
        end
        if ns.migratedChars and ns.migratedChars > 0 then
            ns.Print("Base mise à jour : reconnecte-toi une fois avec chacun de tes personnages pour les ré-enregistrer.")
        end
        return
    end
    if not ns.db then return end

    if event == "PLAYER_ENTERING_WORLD" then
        if RequestRaidInfo then RequestRaidInfo() end
        if playedRequested then
            -- Simple changement de zone : métiers et réputations ont leurs propres événements
            ns.Schedule("basic", 2)
            return
        end
        ns.Schedule("all", 2)
        C_Timer.After(4, ns.CheckRealmType)
        if not playedRequested then
            playedRequested = true
            C_Timer.After(5, function() if ns.RequestPlayedSilently then ns.RequestPlayedSilently() end end)
        end
    elseif event == "PLAYER_LOGOUT" then
        -- À la déconnexion le jeu renvoie 0 pour l'or et l'XP : on ne met à jour que l'heure.
        local c = ns.db.chars[ns.CurrentKey()]
        if c then c.lastSeen = time() end
    elseif event == "SKILL_LINES_CHANGED" or event == "CHAT_MSG_SKILL" then
        if GetTime() >= (ns.suppress.skills or 0) then ns.Schedule("skills") end
    elseif event == "UPDATE_FACTION" or event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
        if GetTime() >= (ns.suppress.reps or 0) then ns.Schedule("reps") end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        ns.Schedule("basic")
        ns.Schedule("gear")
    elseif event == "UPDATE_INSTANCE_INFO" then
        ns.Schedule("raids")
    elseif event == "TRADE_SKILL_SHOW" then
        ns.tradeSkillOpen = true
        ns.Schedule("recipes", 1)
    elseif event == "TRADE_SKILL_CLOSE" then
        ns.tradeSkillOpen = false
    elseif event == "TRADE_SKILL_LIST_UPDATE" or event == "TRADE_SKILL_DATA_SOURCE_CHANGED" or event == "NEW_RECIPE_LEARNED" then
        if ns.tradeSkillOpen then ns.Schedule("recipes", 1) end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if ns.waitingCombat then
            ns.waitingCombat = false
            ns.Schedule("basic", 1)
        end
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if ns.UI and ns.UI.OnItemInfo then ns.UI.OnItemInfo() end
    elseif event == "TIME_PLAYED_MSG" then
        if ns.OnTimePlayed then ns.OnTimePlayed(...) end
    else
        ns.Schedule("basic")
    end
end)

-------------------------------------------------------------------------------
-- Commandes /fego
-------------------------------------------------------------------------------
-- Liste unique des commandes : utilisée par l'aide du chat et par le panneau d'options
ns.COMMANDS = {
    { "/fego", "Ouvrir / fermer la fenêtre" },
    { "/fego options", "Ouvrir ce panneau d'options" },
    { "/fego type [pve/pvp/rp/rppvp/hc]", "Type du serveur actuel (détecté automatiquement si possible)" },
    { "/fego tous", "Afficher / filtrer les personnages de tous les types de serveur" },
    { "/fego suppr Prénom Nom", "Supprimer un personnage de la base" },
    { "/fego afficher", "Ré-afficher les personnages masqués" },
    { "/fego nettoyer [jours]", "Lister les personnages absents depuis longtemps (90 jours par défaut)" },
    { "/fego nettoyer confirmer [jours]", "Supprimer ces personnages absents" },
    { "/fego minimap", "Afficher / masquer le bouton de la minicarte" },
    { "/fego scan", "Forcer la mise à jour du personnage actuel" },
    { "/fego style", "Style EllesmereUI (auto) ou Blizzard (puis /reload)" },
    { "/fego reset", "Recentrer la fenêtre au milieu de l'écran" },
    { "/fego version", "Afficher la version de l'addon" },
    { "/fego debug", "Informations de diagnostic" },
}

local function Help()
    ns.Print("v" .. ns.version .. " - commandes :")
    for _, c in ipairs(ns.COMMANDS) do
        print(("  |cffffd100%s|r : %s"):format(c[1], c[2]))
    end
end

SLASH_FOREVEREGO1 = "/fego"
SLASH_FOREVEREGO2 = "/foreverego"
SlashCmdList.FOREVEREGO = function(msg)
    if not ns.db then return end
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()
    local s = ns.db.settings

    if cmd == "" then
        ns.UI.Toggle()
    elseif cmd == "options" or cmd == "config" then
        if ns.OpenOptions then ns.OpenOptions() end
    elseif cmd == "type" then
        local t = (rest or ""):upper():gsub("[%s%-]", "")
        if t == "" then
            ns.OpenRealmType()
        elseif ns.DetectRuleset() then
            ns.OpenRealmType()
        elseif ns.REALM_TYPE_LABELS[t] then
            ns.SetRealmType(GetRealmName(), t)
        else
            ns.Print("Type inconnu. Utilise : pve, pvp, rp, rppvp ou hc.")
        end
    elseif cmd == "tous" or cmd == "all" then
        s.showAllTypes = not s.showAllTypes
        ns.Print(s.showAllTypes and "Affichage de tous les types de serveur." or "Affichage limité au type du serveur actuel.")
        ns.RefreshUI()
    elseif cmd == "suppr" or cmd == "delete" then
        local target = (rest or ""):lower()
        local found, count = nil, 0
        for key, c in pairs(ns.db.chars) do
            if key:lower() == target or ns.FullName(c):lower() == target then
                found, count = key, count + 1
            end
        end
        if count > 1 then
            ns.Print("Plusieurs personnages portent ce nom : décoche-les plutôt dans la liste « Personnages ».")
        elseif not found then
            ns.Print("Personnage introuvable. Format : /fego suppr Prénom Nom")
        elseif found == ns.CurrentKey() then
            ns.Print("Impossible de supprimer le personnage actuellement connecté.")
        else
            ns.db.chars[found] = nil
            s.hidden[found] = nil
            ns.Print("Personnage supprimé : " .. rest)
            ns.RefreshUI()
        end
    elseif cmd == "afficher" or cmd == "show" then
        wipe(s.hidden)
        ns.Print("Tous les personnages masqués sont de nouveau affichés.")
        ns.RefreshUI()
    elseif cmd == "minimap" then
        s.minimap.hide = not s.minimap.hide
        ns.UI.UpdateMinimapButton()
    elseif cmd == "debug" then
        local name, surname = ns.GetPlayerNames()
        ns.Print("Nom :", name, "| Nom de famille :", surname or "aucun", "| Type :", ns.DetectRuleset() or "non détecté")
        local SI = C_SkillInfo
        local num = SI and SI.GetNumSkillLines and SI.GetNumSkillLines() or (GetNumSkillLines and GetNumSkillLines()) or "API absente"
        ns.Print("Compétences : C_SkillInfo =", SI and "oui" or "non", "| lignes =", num)
        if SI and SI.GetSkillLineInfo and type(num) == "number" and num > 0 then
            for i = 1, math.min(num, 3) do
                local t = SI.GetSkillLineInfo(i)
                if type(t) == "table" then
                    local parts = {}
                    for k, v in pairs(t) do parts[#parts + 1] = k .. "=" .. tostring(v) end
                    table.sort(parts)
                    print("  " .. i .. ": " .. table.concat(parts, ", "))
                end
            end
        end
        local c = ns.db.chars[ns.CurrentKey()]
        local n = 0
        if c and c.skills then for _ in pairs(c.skills) do n = n + 1 end end
        ns.Print("Compétences enregistrées pour ce personnage :", n)
    elseif cmd == "version" or cmd == "v" then
        ns.Print("version |cff88ff88" .. ns.version .. "|r")
    elseif cmd == "style" then
        s.style = (s.style == "blizzard") and "auto" or "blizzard"
        if s.style == "auto" then
            ns.Print("Style : |cff88ff88EllesmereUI|r s'il est installé, sinon Blizzard. Tape /reload pour l'appliquer.")
        else
            ns.Print("Style : |cff88ff88Blizzard|r. Tape /reload pour l'appliquer.")
        end
    elseif cmd == "nettoyer" or cmd == "clean" then
        local confirm = rest:lower():find("confirmer", 1, true) ~= nil
        local days = tonumber(rest:match("%d+")) or 90
        local cur, limit, list = ns.CurrentKey(), time() - days * 86400, {}
        for key, c in pairs(ns.db.chars) do
            if key ~= cur and (c.lastSeen or 0) < limit then list[#list + 1] = key end
        end
        if #list == 0 then
            ns.Print(("Aucun personnage absent depuis plus de %d jours."):format(days))
        elseif not confirm then
            ns.Print(("%d personnage(s) absent(s) depuis plus de %d jours :"):format(#list, days))
            for _, key in ipairs(list) do
                local c = ns.db.chars[key]
                print(("  - %s (Niv. %d)"):format(ns.FullName(c), c.level or 0))
            end
            ns.Print(("Tape |cffffd100/fego nettoyer confirmer %d|r pour les supprimer définitivement."):format(days))
        else
            for _, key in ipairs(list) do
                ns.db.chars[key] = nil
                s.hidden[key] = nil
            end
            ns.Print(("%d personnage(s) supprimé(s)."):format(#list))
            ns.RefreshUI()
        end
    elseif cmd == "reset" then
        ns.UI.ResetSize()
        ns.Print("Fenêtre recentrée.")
    elseif cmd == "scan" then
        ns.Schedule("all", 0.1)
        ns.Print("Mise à jour du personnage...")
    else
        Help()
    end
end
