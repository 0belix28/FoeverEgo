-- ForeverEgo - UI : fenêtre principale, popup du type de serveur, bouton minicarte
local ADDON, ns = ...
local UI = {}
ns.UI = UI

local floor, max, min, format = math.floor, math.max, math.min, string.format

local LABEL_W, COL_W, ROW_H = 180, 112, 16
local TOP_H, HEADER_H, FOOT_H = 58, 64, 28
local MIN_W = 420                   -- largeur minimale (barre de contrôles)
local BAND_H, GROUP_GAP = 18, 12  -- bandeau du type de serveur, espace entre deux groupes

-- Couleur de chaque groupe de type de serveur
local TYPE_COLOR = {
    PVE = { 0.30, 0.80, 0.35 },
    PVP = { 0.90, 0.28, 0.28 },
    RP = { 0.35, 0.60, 1.00 },
    RPPVP = { 0.75, 0.42, 1.00 },
    HC = { 1.00, 0.55, 0.15 },
    ["?"] = { 0.60, 0.60, 0.60 },
}

local CLASS_COLORS = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
local FACTION_ICON = {
    Alliance = "|TInterface\\TargetingFrame\\UI-PVP-Alliance:16:16:0:0:64:64:0:40:0:40|t",
    Horde = "|TInterface\\TargetingFrame\\UI-PVP-Horde:16:16:0:0:64:64:0:40:0:40|t",
}
local FACTION_COLOR = { Alliance = "ff4a8cff", Horde = "ffe03030" }
local GREY = "|cff666666-|r"
local Skin = ns.Skin

-------------------------------------------------------------------------------
-- Formatage
-------------------------------------------------------------------------------
local function FormatMoney(copper, full)
    copper = copper or 0
    local g, s, c = floor(copper / 10000), floor(copper / 100) % 100, copper % 100
    local G = "|TInterface\\MoneyFrame\\UI-GoldIcon:0|t"
    local S = "|TInterface\\MoneyFrame\\UI-SilverIcon:0|t"
    local C = "|TInterface\\MoneyFrame\\UI-CopperIcon:0|t"
    if full then return format("%d%s %d%s %d%s", g, G, s, S, c, C) end
    if g > 0 then return format("%s%s %d%s", BreakUpLargeNumbers and BreakUpLargeNumbers(g) or g, G, s, S) end
    if s > 0 then return format("%d%s %d%s", s, S, c, C) end
    return format("%d%s", c, C)
end

local function FormatDuration(sec)
    sec = floor(sec or 0)
    local d, h, m = floor(sec / 86400), floor(sec / 3600) % 24, floor(sec / 60) % 60
    if d > 0 then return format("%dj %dh", d, h) end
    if h > 0 then return format("%dh %dm", h, m) end
    return format("%dm", m)
end

local function Ago(t)
    if not t then return "?" end
    local diff = time() - t
    if diff < 3600 then return format("il y a %d min", max(1, floor(diff / 60))) end
    if diff < 86400 then return format("il y a %d h", floor(diff / 3600)) end
    return format("il y a %d j", floor(diff / 86400))
end

local function IsCurrent(c) return c.key == ns.CurrentKey() end

local function ClassColor(c)
    local cc = c.class and CLASS_COLORS[c.class]
    if cc then return cc.r, cc.g, cc.b end
    return 1, 1, 1
end

local function ColoredName(c)
    local r, g, b = ClassColor(c)
    return format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, ns.FullName(c))
end

local function ClassColored(c, text)
    local r, g, b = ClassColor(c)
    return format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, text or "")
end

local function TypeLabel(c)
    local t = ns.CharRuleset(c)
    return t and ns.REALM_TYPE_LABELS[t] or "?"
end

local function EstimatedRested(c)
    if not c.xpMax or c.xpMax == 0 then return 0 end
    local rested = c.rested or 0
    if not IsCurrent(c) and c.lastSeen then
        -- 5 % d'un niveau par 8 h en auberge, 4 fois moins ailleurs, plafond 150 %
        local rate = c.xpMax * 0.05 / (8 * 3600)
        if not c.resting then rate = rate / 4 end
        rested = rested + (time() - c.lastSeen) * rate
    end
    return min(rested, c.xpMax * 1.5)
end

local PROF_TIERS = { [75] = "Apprenti", [150] = "Compagnon", [225] = "Expert", [300] = "Artisan", [375] = "Maître" }

-------------------------------------------------------------------------------
-- Construction des lignes
-------------------------------------------------------------------------------
local function Section(rows, key, text, kind)
    rows[#rows + 1] = { kind = kind or "section", key = key, text = text }
    return not ns.db.settings.collapsed[key]
end

local function Row(rows, text, fn, indent)
    rows[#rows + 1] = { kind = "data", text = text, fn = fn, indent = indent }
end

local function Tip(title, ...)
    -- paires (libellé, valeur) ; une valeur nil saute la ligne ; un texte seul en dernier = note
    local n, lines = select("#", ...), { ... }
    return function(tt)
        tt:AddLine(title, 1, 0.82, 0)
        for i = 1, n, 2 do
            if i == n then
                if lines[i] then tt:AddLine(lines[i], 0.6, 0.6, 0.6, true) end
            elseif lines[i] and lines[i + 1] ~= nil then
                tt:AddDoubleLine(lines[i], tostring(lines[i + 1]), 0.8, 0.8, 0.8, 1, 1, 1)
            end
        end
    end
end

local function GeneralRows(rows)
    if not Section(rows, "general", "Général") then return end

    Row(rows, "Faction", function(c)
        if not c.faction then return end
        return format("%s |c%s%s|r", FACTION_ICON[c.faction] or "", FACTION_COLOR[c.faction] or "ffffffff", c.factionLocal or c.faction)
    end)
    Row(rows, "Niveau", function(c)
        return format("|cffffd100%d|r", c.level or 0)
    end)
    Row(rows, "Race", function(c) return c.race end)
    Row(rows, "Classe", function(c)
        if not c.className then return end
        local r, g, b = ClassColor(c)
        return format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, c.className)
    end)
    Row(rows, "Guilde", function(c)
        if not c.guild then return end
        return "|cff40ff40<" .. c.guild .. ">|r", nil, nil, nil, nil, Tip("Guilde", "Nom", c.guild, "Rang", c.guildRank or "?")
    end)
    Row(rows, "Rang de guilde", function(c) return c.guild and c.guildRank or nil end)
    Row(rows, "Niveau d'objet", function(c)
        if not c.ilvl or c.ilvl <= 0 then return end
        return format("%.1f", c.ilvl)
    end)
    Row(rows, "Zone", function(c)
        if not c.zone then return end
        return c.zone, nil, nil, nil, nil, Tip("Dernière position", "Zone", c.zone, "Sous-zone", (c.subzone ~= "" and c.subzone) or "-")
    end)
    Row(rows, "Dernière connexion", function(c)
        if IsCurrent(c) then return "|cff40ff40En ligne|r" end
        if not c.lastSeen then return end
        return Ago(c.lastSeen), nil, nil, nil, nil, Tip("Dernière connexion", "Date", date("%d/%m/%Y %H:%M", c.lastSeen))
    end)
end

local function ProgressRows(rows)
    if not Section(rows, "progress", "Progression") then return end

    Row(rows, "Expérience", function(c)
        if not c.level then return end
        if c.level >= (c.maxLevel or 60) then return "|cffffd100Niveau max|r" end
        if not c.xpMax or c.xpMax == 0 then return end
        local frac = c.xp / c.xpMax
        return format("%d%%", frac * 100), frac, 0.58, 0.0, 0.55,
            Tip("Expérience", "Niveau", c.level, "XP", format("%d / %d", c.xp, c.xpMax), "Restant", c.xpMax - c.xp)
    end)
    Row(rows, "XP de repos", function(c)
        if not c.level or c.level >= (c.maxLevel or 60) or not c.xpMax or c.xpMax == 0 then return end
        local est = EstimatedRested(c)
        local frac = est / (c.xpMax * 1.5)
        return format("+%d%%", est / c.xpMax * 100), frac, 0.0, 0.39, 0.88,
            Tip("XP de repos", "Estimation", format("%d XP (%d%% du niveau)", est, est / c.xpMax * 100),
                "Lors de la déconnexion", format("%d XP", c.rested or 0),
                "Au repos (auberge/ville)", c.resting and "Oui" or "Non",
                "Estimation basée sur le temps écoulé depuis la dernière connexion.")
    end)
    Row(rows, "Temps de jeu", function(c)
        if not c.played then return end
        local extra = IsCurrent(c) and c.playedAt and (time() - c.playedAt) or 0
        return FormatDuration(c.played + extra)
    end)
    Row(rows, "Temps à ce niveau", function(c)
        if not c.playedLevel then return end
        local extra = IsCurrent(c) and c.playedAt and (time() - c.playedAt) or 0
        return FormatDuration(c.playedLevel + extra)
    end)
    Row(rows, "Or", function(c)
        if not c.money then return end
        return FormatMoney(c.money), nil, nil, nil, nil, Tip("Or", "Total", FormatMoney(c.money, true))
    end)
end

local SKILL_SECTIONS = {
    { cat = "prof", key = "prof", title = "Métiers" },
    { cat = "secondary", key = "secondary", title = "Compétences secondaires" },
    -- Sections retirées en 0.2.2 (armes, armures, langues, classe, autres) :
    -- les données restent collectées, il suffit de remettre une ligne ici pour les réafficher.
}

local function SkillRows(rows, chars, sec)
    local names, seen = {}, {}
    for _, c in ipairs(chars) do
        if c.skills then
            for name, s in pairs(c.skills) do
                if s.cat == sec.cat and not seen[name] then
                    seen[name] = true
                    names[#names + 1] = name
                end
            end
        end
    end
    if #names == 0 then return end
    if not Section(rows, sec.key, format("%s (%d)", sec.title, #names)) then return end
    table.sort(names)

    for _, name in ipairs(names) do
        Row(rows, name, function(c)
            local s = c.skills and c.skills[name]
            if not s then return end
            if s.max <= 1 then return "|cff40ff40Appris|r" end
            local frac = s.rank / s.max
            local r, g, b
            if s.rank >= s.max then
                r, g, b = 0.15, 0.6, 0.15
            elseif sec.cat == "weapon" then
                r, g, b = 0.2, 0.45, 0.85
            else
                r, g, b = 0.75, 0.55, 0.1
            end
            local text = format("%d / %d", s.rank, s.max)
            local modText = s.mod ~= 0 and format("%+d", s.mod) or nil
            local tier = (sec.cat == "prof" or sec.cat == "secondary") and PROF_TIERS[s.max] or nil
            local note
            if IsCurrent(c) then
                note = "Clic gauche : ouvrir la fenêtre du métier"
            elseif ns.GetRecipes(c, name, s.id) then
                note = "Clic gauche : voir les recettes"
            else
                note = "Clic gauche : recettes (ouvre une fois ce métier avec ce personnage pour les enregistrer)"
            end
            return text, frac, r, g, b,
                Tip(name, "Rang", s.rank, "Bonus", modText, "Maximum", s.max, "Palier", tier,
                    "Catégorie", s.header, "Points restants", s.max - s.rank, note),
                function(ch) UI.ShowRecipes(ch, name, s.id) end
        end, true)
    end
end

-- JcJ : section à part, placée juste au-dessus des Réputations
local function HasPvP(chars)
    for _, c in ipairs(chars) do
        if (c.hk and c.hk > 0) or (c.pvpRank and c.pvpRank > 0) then return true end
    end
    return false
end

local function PvPRows(rows, chars)
    if not HasPvP(chars) then return end
    if not Section(rows, "pvp", "JcJ") then return end
    Row(rows, "Rang", function(c)
        if not c.pvpRankName then return end
        return c.pvpRankName, nil, nil, nil, nil, Tip("Rang JcJ", "Rang", c.pvpRank)
    end)
    Row(rows, "Victoires honorables", function(c)
        if not c.hk then return end
        return tostring(c.hk)
    end)
end

local function ReputationRows(rows, chars)
    local groups, groupList, seen = {}, {}, {}
    for _, c in ipairs(chars) do
        if c.reps then
            for name, d in pairs(c.reps) do
                if not seen[name] then
                    seen[name] = true
                    local gname = d.group or "Autres"
                    if not groups[gname] then
                        groups[gname] = { name = gname, factions = {}, order = d.order or 999 }
                        groupList[#groupList + 1] = groups[gname]
                    end
                    local grp = groups[gname]
                    grp.order = min(grp.order, d.order or 999)
                    grp.factions[#grp.factions + 1] = name
                end
            end
        end
    end
    if #groupList == 0 then return end
    if not Section(rows, "rep", format("Réputations (%d)", #groupList)) then return end
    table.sort(groupList, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.name < b.name
    end)

    for _, grp in ipairs(groupList) do
        if Section(rows, "rep:" .. grp.name, grp.name, "sub") then
            table.sort(grp.factions)
            for _, fname in ipairs(grp.factions) do
                Row(rows, fname, function(c)
                    local d = c.reps and c.reps[fname]
                    if not d then return end
                    local label = _G["FACTION_STANDING_LABEL" .. d.standing] or tostring(d.standing)
                    local span = d.max - d.min
                    local cur = d.value - d.min
                    local frac = span > 0 and cur / span or 1
                    local col = FACTION_BAR_COLORS and FACTION_BAR_COLORS[d.standing]
                    local r, g, b = 0.5, 0.5, 0.5
                    if col then r, g, b = col.r, col.g, col.b end
                    return label, frac, r, g, b,
                        Tip(fname, "Niveau", label, "Progression", format("%d / %d", cur, span),
                            "Total", d.value, "Groupe", d.group)
                end, true)
            end
        end
    end
end

local function LockoutRows(rows, chars)
    local names, seen, now = {}, {}, time()
    for _, c in ipairs(chars) do
        if c.lockouts then
            for name, l in pairs(c.lockouts) do
                if l.resetAt > now and not seen[name] then
                    seen[name] = true
                    names[#names + 1] = name
                end
            end
        end
    end
    if #names == 0 then return end
    if not Section(rows, "raids", format("Donjons & raids verrouillés (%d)", #names)) then return end
    table.sort(names)
    for _, name in ipairs(names) do
        Row(rows, name, function(c)
            local l = c.lockouts and c.lockouts[name]
            if not l or l.resetAt <= time() then return end
            local text = (l.numEnc > 0) and format("%d / %d", l.prog, l.numEnc) or "Verrouillé"
            local frac = (l.numEnc > 0) and (l.prog / l.numEnc) or 1
            return text, frac, 0.8, 0.3, 0.1,
                Tip(name, "Difficulté", l.diffName, "Boss tués", l.numEnc > 0 and format("%d / %d", l.prog, l.numEnc) or nil,
                    "Réinitialisation", date("%a %d/%m %H:%M", l.resetAt), "Dans", FormatDuration(l.resetAt - time()))
        end, true)
    end
end

local function BuildRows(chars)
    local rows = {}
    GeneralRows(rows)
    ProgressRows(rows)
    for _, sec in ipairs(SKILL_SECTIONS) do SkillRows(rows, chars, sec) end
    PvPRows(rows, chars)
    ReputationRows(rows, chars)
    LockoutRows(rows, chars)
    return rows
end

-------------------------------------------------------------------------------
-- Widgets (en-têtes de colonnes, lignes, cellules)
-------------------------------------------------------------------------------
local function HideTooltip() GameTooltip:Hide() end

local function CharTooltip(self)
    local c = self.char
    if not c then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(ns.FullName(c), ClassColor(c))
    GameTooltip:AddDoubleLine("Type de serveur", TypeLabel(c), 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddDoubleLine("Niveau", format("%d %s %s", c.level or 0, c.race or "", c.className or ""), 0.8, 0.8, 0.8, 1, 1, 1)
    if c.faction then
        GameTooltip:AddDoubleLine("Faction", c.factionLocal or c.faction, 0.8, 0.8, 0.8, 1, 1, 1)
    end
    if c.guild then
        GameTooltip:AddDoubleLine("Guilde", format("<%s> - %s", c.guild, c.guildRank or ""), 0.8, 0.8, 0.8, 0.25, 1, 0.25)
    end
    if c.money then
        GameTooltip:AddDoubleLine("Or", FormatMoney(c.money, true), 0.8, 0.8, 0.8, 1, 1, 1)
    end
    GameTooltip:AddDoubleLine("Dernière connexion", IsCurrent(c) and "En ligne" or Ago(c.lastSeen), 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Clic gauche : voir l'équipement", 0.6, 0.6, 0.6)
    GameTooltip:AddLine("Maj + clic droit : masquer ce personnage", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

-- Icône de classe (atlas moderne, sinon la planche des classes)
local function SetClassIcon(tex, class)
    if class and tex.SetAtlas and C_Texture and C_Texture.GetAtlasInfo
        and C_Texture.GetAtlasInfo("classicon-" .. class:lower()) then
        tex:SetAtlas("classicon-" .. class:lower())
        tex:SetTexCoord(0, 1, 0, 1)
        return true
    end
    local tc = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if tc then
        tex:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        local dx, dy = (tc[2] - tc[1]) * 0.08, (tc[4] - tc[3]) * 0.08
        tex:SetTexCoord(tc[1] + dx, tc[2] - dx, tc[3] + dy, tc[4] - dy)
        return true
    end
    tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    return false
end

-- Surbrillance de toute la colonne du personnage survolé
local function ShowColumn(j)
    local hl, x = UI.colHL, UI.colX and UI.colX[j]
    if not hl or not x then return end
    hl:ClearAllPoints()
    hl:SetPoint("TOPLEFT", UI.frame, "TOPLEFT", 8 + x - 2, -(TOP_H + BAND_H))
    hl:SetPoint("BOTTOMLEFT", UI.frame, "BOTTOMLEFT", 8 + x - 2, FOOT_H + 4)
    hl:SetWidth(COL_W)
    local r, g, b = 1, 1, 1
    if Skin.enabled and Skin.Accent then r, g, b = Skin.Accent() end
    hl.tex:SetColorTexture(r, g, b, 0.07)
    hl.top:SetColorTexture(r, g, b, 0.8)
    hl:Show()
end

local function HideColumn()
    if UI.colHL then UI.colHL:Hide() end
end

local function HeaderOnEnter(self)
    ShowColumn(self.col)
    CharTooltip(self)
end

local function HeaderOnLeave()
    HideColumn()
    GameTooltip:Hide()
end

local function GetHeader(j)
    local h = UI.headers[j]
    if h then return h end
    h = CreateFrame("Button", nil, UI.headerFrame)
    h:SetSize(COL_W - 4, HEADER_H)
    h.bg = h:CreateTexture(nil, "BACKGROUND")
    h.bg:SetAllPoints()
    h.col = j
    h.icon = h:CreateTexture(nil, "ARTWORK")
    h.icon:SetSize(20, 20)
    h.icon:SetPoint("TOP", 0, -3)
    h.iconBorder = h:CreateTexture(nil, "BORDER")
    h.iconBorder:SetPoint("TOPLEFT", h.icon, -1, 1)
    h.iconBorder:SetPoint("BOTTOMRIGHT", h.icon, 1, -1)
    h.name = h:CreateFontString(nil, "OVERLAY", "ForeverEgo_GameFontNormal")
    h.name:SetPoint("TOP", 0, -26)
    h.name:SetWidth(COL_W - 8)
    h.name:SetWordWrap(false)
    h.line2 = h:CreateFontString(nil, "OVERLAY", "ForeverEgo_GameFontHighlightSmall")
    h.line2:SetPoint("TOP", 0, -40)
    h.line2:SetWidth(COL_W - 8)
    h.line2:SetWordWrap(false)
    h.line3 = h:CreateFontString(nil, "OVERLAY", "ForeverEgo_GameFontHighlightSmall")
    h.line3:SetPoint("TOP", 0, -51)
    h.line3:SetWidth(COL_W - 8)
    h.line3:SetWordWrap(false)
    h:RegisterForClicks("AnyUp")
    h:SetScript("OnEnter", HeaderOnEnter)
    h:SetScript("OnLeave", HeaderOnLeave)
    h:SetScript("OnClick", function(self, button)
        if button == "LeftButton" and self.char then
            GameTooltip:Hide()
            UI.ShowGear(self.char)
        elseif button == "RightButton" and IsShiftKeyDown() and self.char then
            if IsCurrent(self.char) then
                ns.Print("Le personnage connecté ne peut pas être masqué.")
                return
            end
            ns.db.settings.hidden[self.char.key] = true
            ns.Print(self.char.key .. " masqué. Tape /fego afficher pour le ré-afficher.")
            GameTooltip:Hide()
            UI.Refresh()
        end
    end)
    UI.headers[j] = h
    return h
end

local function RowOnClick(self)
    if self.toggleKey then
        local col = ns.db.settings.collapsed
        col[self.toggleKey] = not col[self.toggleKey]
        UI.Refresh()
    end
end

local function RowOnEnter(self)
    if self.label:IsTruncated() then
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(self.label:GetText(), 1, 1, 1)
        GameTooltip:Show()
    end
end

local function GetRow(i)
    local r = UI.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, UI.content)
    r:SetHeight(ROW_H)
    r:SetPoint("TOPLEFT", UI.content, "TOPLEFT", 0, -(i - 1) * ROW_H)
    r:SetPoint("RIGHT", UI.content, "RIGHT")
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.label = r:CreateFontString(nil, "OVERLAY", "ForeverEgo_GameFontHighlightSmall")
    r.label:SetJustifyH("LEFT")
    r.label:SetWordWrap(false)
    r.cells = {}
    r:SetScript("OnClick", RowOnClick)
    r:SetScript("OnEnter", RowOnEnter)
    r:SetScript("OnLeave", HideTooltip)
    UI.rows[i] = r
    return r
end

local function CellOnEnter(self)
    ShowColumn(self.col)
    if not self.tip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    self.tip(GameTooltip, self.char)
    if self.char then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(ns.FullName(self.char), 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

local function CellOnLeave()
    HideColumn()
    GameTooltip:Hide()
end

local function CellOnMouseUp(self, button)
    if button == "LeftButton" and self.click and self.char and self:IsMouseOver() then
        GameTooltip:Hide()
        self.click(self.char)
    end
end

local function GetCell(r, j)
    local cell = r.cells[j]
    if cell then return cell end
    cell = CreateFrame("StatusBar", nil, r)
    cell:SetSize(COL_W - 4, ROW_H - 2)
    cell.col = j
    cell:SetStatusBarTexture(Skin.BarTexture())
    cell:SetMinMaxValues(0, 1)
    cell.fill = cell:GetStatusBarTexture()
    -- Reflet : moitié haute de la barre légèrement éclaircie
    cell.shine = cell:CreateTexture(nil, "ARTWORK", nil, 2)
    cell.shine:SetPoint("TOPLEFT", cell.fill, "TOPLEFT")
    cell.shine:SetPoint("BOTTOMRIGHT", cell.fill, "RIGHT")
    cell.shine:SetColorTexture(1, 1, 1, 0.12)
    cell.shine:Hide()
    cell.bg = cell:CreateTexture(nil, "BACKGROUND")
    cell.bg:SetAllPoints()
    cell.text = cell:CreateFontString(nil, "OVERLAY", "ForeverEgo_GameFontHighlightSmall")
    cell.text:SetPoint("LEFT", 2, 0)
    cell.text:SetPoint("RIGHT", -2, 0)
    cell.text:SetJustifyH("CENTER")
    cell.text:SetWordWrap(false)
    cell:EnableMouse(true)
    cell:SetScript("OnEnter", CellOnEnter)
    cell:SetScript("OnLeave", CellOnLeave)
    cell:SetScript("OnMouseUp", CellOnMouseUp)
    r.cells[j] = cell
    return cell
end

-- Dégradé horizontal : couleur assombrie à gauche, couleur vive à droite
local gradientOK = CreateColor ~= nil
local function SetBarGradient(cell, r, g, b)
    local fill = cell.fill
    if gradientOK then
        fill:SetVertexColor(1, 1, 1, 1)
        local ok = pcall(fill.SetGradient, fill, "HORIZONTAL",
            CreateColor(r * 0.45, g * 0.45, b * 0.45, 0.9), CreateColor(r, g, b, 0.9))
        if ok then return end
        gradientOK = false
    end
    cell:SetStatusBarColor(r, g, b, 0.8)
end

local function FillCell(cell, c, text, frac, br, bg, bb, tip, click)
    cell.char, cell.tip, cell.click = c, tip, click
    if text == nil then
        cell.text:SetText(GREY)
        cell:SetValue(0)
        cell.bg:SetColorTexture(0, 0, 0, 0)
        cell.shine:Hide()
        cell.tip, cell.click = nil, nil
        return
    end
    cell.text:SetText(text)
    if frac then
        frac = max(0, min(1, frac))
        cell:SetValue(frac)
        SetBarGradient(cell, br or 0.3, bg or 0.5, bb or 0.9)
        cell.bg:SetColorTexture(0, 0, 0, 0.5)
        cell.shine:SetShown(frac > 0)
    else
        cell:SetValue(0)
        cell.bg:SetColorTexture(0, 0, 0, 0)
        cell.shine:Hide()
    end
end

-- Bandeau coloré au-dessus d'un groupe de colonnes (PvE, PvP, RP, RP-PvP...)
local function GetBand(k)
    local b = UI.bands[k]
    if b then return b end
    b = CreateFrame("Frame", nil, UI.headerFrame)
    b:SetHeight(BAND_H - 3)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.line = b:CreateTexture(nil, "BORDER")
    b.line:SetPoint("BOTTOMLEFT")
    b.line:SetPoint("BOTTOMRIGHT")
    b.line:SetHeight(2)
    b.text = b:CreateFontString(nil, "OVERLAY", "ForeverEgo_GameFontNormalSmall")
    b.text:SetPoint("CENTER", 0, 1)
    b.text:SetWordWrap(false)
    UI.bands[k] = b
    return b
end

-- Trait vertical de séparation entre deux groupes, posé sur un cadre (ligne ou en-tête)
local function GetSep(owner, k)
    owner.seps = owner.seps or {}
    local t = owner.seps[k]
    if t then return t end
    t = owner:CreateTexture(nil, "ARTWORK")
    t:SetWidth(1)
    owner.seps[k] = t
    return t
end

local function PlaceSeps(owner, seps, alpha, top, bottom)
    for k, x in ipairs(seps) do
        local t = GetSep(owner, k)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", owner, "TOPLEFT", x, top or 0)
        t:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", x, bottom or 0)
        t:SetColorTexture(1, 1, 1, alpha)
        t:Show()
    end
    if owner.seps then
        for k = #seps + 1, #owner.seps do owner.seps[k]:Hide() end
    end
end

-- Position X de chaque colonne, groupes affichés et traits de séparation
local function LayoutColumns(cols)
    local colX, groups, seps = {}, {}, {}
    local x, prev = LABEL_W, nil
    for j, c in ipairs(cols) do
        local g = ns.CharGroup(c)
        if g ~= prev then
            if j > 1 then
                seps[#seps + 1] = x + floor(GROUP_GAP / 2) - 1
                x = x + GROUP_GAP
            end
            groups[#groups + 1] = { type = g, x = x, n = 0 }
        end
        local grp = groups[#groups]
        grp.n = grp.n + 1
        colX[j] = x + 2
        x = x + COL_W
        prev = g
    end
    return colX, groups, seps, x
end

-------------------------------------------------------------------------------
-- Fenêtre principale
-------------------------------------------------------------------------------
function UI.SavePosition()
    local f, s = UI.frame, ns.db.settings
    local left, top = f:GetLeft(), f:GetTop()
    if left and top then
        -- Ancrage par le coin haut-gauche : quand la hauteur change, la fenêtre grandit vers le bas
        s.point, s.relPoint, s.x, s.y = "TOPLEFT", "BOTTOMLEFT", left, top
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    else
        local point, _, relPoint, x, y = f:GetPoint(1)
        s.point, s.relPoint, s.x, s.y = point, relPoint, x, y
    end
end

local function MakeButton(parent, w, text, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    Skin.Button(b)
    return b
end

-- Hauteur maximale : celle de l'écran (moins une marge)
local function MaxHeight(f)
    local scale = max(f:GetEffectiveScale() / UIParent:GetEffectiveScale(), 0.01)
    return UIParent:GetHeight() / scale - 40
end

function UI.Create()
    if UI.frame then return end
    local s = ns.db.settings

    local f = CreateFrame("Frame", "ForeverEgoFrame", UIParent, "BasicFrameTemplateWithInset")
    UI.frame = f
    Skin.Frame(f)
    f:SetSize(s.width or 900, min(s.height or 580, MaxHeight(f)))
    if s.point then
        f:SetPoint(s.point, UIParent, s.relPoint, s.x, s.y)
    else
        f:SetPoint("CENTER")
    end
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:SetResizable(true)
    if f.SetResizeBounds then
        f:SetResizeBounds(MIN_W, 300, 4000, max(300, MaxHeight(f)))
    elseif f.SetMinResize then
        f:SetMinResize(MIN_W, 300)
    end
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        UI.SavePosition()
    end)
    f:Hide()
    tinsert(UISpecialFrames, "ForeverEgoFrame")

    local title = f.TitleText
    if not title then
        title = f:CreateFontString(nil, "OVERLAY", "ForeverEgo_GameFontHighlight")
        title:SetPoint("TOP", 0, -5)
    end
    title:SetText("ForeverEgo |cff888888v" .. ns.version .. "|r")

    -- Barre de contrôles
    local allCB = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    allCB:SetSize(24, 24)
    allCB:SetPoint("TOPLEFT", 10, -28)
    Skin.CheckBox(allCB)
    allCB.label = allCB:CreateFontString(nil, "OVERLAY", "ForeverEgo_GameFontNormalSmall")
    allCB.label:SetPoint("LEFT", allCB, "RIGHT", 2, 0)
    allCB.label:SetText("Tous les types de serveur")
    allCB:SetScript("OnClick", function(self)
        ns.db.settings.showAllTypes = self:GetChecked() and true or false
        UI.Refresh()
    end)
    UI.allCB = allCB


    -- Tri automatique par niveau (bouton de tri retiré en 0.2.5)
    UI.charsBtn = MakeButton(f, 110, "Personnages", function(self) UI.ToggleCharList(self) end)
    UI.charsBtn:SetPoint("LEFT", allCB.label, "RIGHT", 14, 0)


    -- En-têtes des personnages
    UI.headerFrame = CreateFrame("Frame", nil, f)
    UI.headerFrame:SetPoint("TOPLEFT", 8, -TOP_H)
    UI.headerFrame:SetPoint("TOPRIGHT", -30, -TOP_H)
    UI.headerFrame:SetHeight(BAND_H + HEADER_H)
    UI.bands = {}
    UI.countText = UI.headerFrame:CreateFontString(nil, "OVERLAY", "ForeverEgo_GameFontNormal")
    UI.countText:SetPoint("LEFT", 8, -floor(BAND_H / 2))
    UI.countText:SetWidth(LABEL_W - 12)
    UI.countText:SetJustifyH("LEFT")
    UI.headers = {}

    -- Zone défilante
    local sf = CreateFrame("ScrollFrame", "ForeverEgoScrollFrame", f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 8, -(TOP_H + BAND_H + HEADER_H + 2))
    sf:SetPoint("BOTTOMRIGHT", -30, FOOT_H + 4)
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(1, 1)
    sf:SetScrollChild(content)
    Skin.ScrollBar(sf)

    -- Surbrillance de colonne : au-dessus des lignes, sans capter la souris
    local hl = CreateFrame("Frame", nil, f)
    hl:SetFrameLevel(sf:GetFrameLevel() + 20)
    hl:EnableMouse(false)
    hl.tex = hl:CreateTexture(nil, "OVERLAY")
    hl.tex:SetAllPoints()
    hl.tex:SetBlendMode("ADD")
    hl.top = hl:CreateTexture(nil, "OVERLAY", nil, 1)
    hl.top:SetPoint("TOPLEFT")
    hl.top:SetPoint("TOPRIGHT")
    hl.top:SetHeight(2)
    hl:Hide()
    UI.colHL = hl
    UI.scroll, UI.content, UI.rows = sf, content, {}

    -- Pied de page
    UI.footText = f:CreateFontString(nil, "OVERLAY", "ForeverEgo_GameFontHighlightSmall")
    UI.footText:SetPoint("BOTTOMLEFT", 14, 11)
    UI.footText:SetJustifyH("LEFT")

    -- Taille automatique : largeur selon le nombre de personnages,
    -- hauteur selon les catégories dépliées (plus de poignée de redimensionnement)

    f:SetScript("OnShow", function()
        UI.Refresh()
        -- Convertit l'ancrage en coin haut-gauche : la fenêtre grandit vers le bas
        C_Timer.After(0, function() if UI.frame and UI.frame:IsShown() then UI.SavePosition() end end)
    end)
    f:SetScript("OnHide", function()
        if UI.charList then UI.charList:Hide() end
    end)
end

-- Replace la fenêtre au centre de l'écran (la taille, elle, est automatique)
function UI.ResetSize()
    UI.Create()
    local f, s = UI.frame, ns.db.settings
    f:StopMovingOrSizing()
    s.point, s.relPoint, s.x, s.y = nil, nil, nil, nil
    f:ClearAllPoints()
    f:SetPoint("CENTER")
    f:Show()
    UI.Refresh()
    C_Timer.After(0, function() if UI.frame then UI.SavePosition() end end)
end

function UI.Toggle()
    UI.Create()
    if UI.frame:IsShown() then UI.frame:Hide() else UI.frame:Show() end
end

function UI.Refresh()
    local f = UI.frame
    if not f or not f:IsShown() or not ns.db then return end
    local s = ns.db.settings
    Skin.UpdateAccent()
    local chars, curType = ns.GetVisibleChars()

    -- Contrôles
    UI.allCB:SetChecked(s.showAllTypes)

    -- Tous les personnages sur une seule page : la largeur de la fenêtre s'adapte
    local cols = chars
    local colX, groups, seps, usedW = LayoutColumns(cols)
    UI.colX = colX
    HideColumn()
    local maxW = UIParent:GetWidth() / max(f:GetEffectiveScale() / UIParent:GetEffectiveScale(), 0.01) - 20
    local frameW = min(max(MIN_W, usedW + 42), maxW)
    if math.abs(f:GetWidth() - frameW) > 0.5 then f:SetWidth(frameW) end
    local width = frameW - 38

    -- Nombre de personnages par type
    local typeCount = {}
    for _, c in ipairs(chars) do
        local g = ns.CharGroup(c)
        typeCount[g] = (typeCount[g] or 0) + 1
    end

    -- En-têtes
    UI.countText:SetText(format("%d personnage%s", #chars, #chars > 1 and "s" or ""))
    for k, grp in ipairs(groups) do
        local b = GetBand(k)
        local col = TYPE_COLOR[grp.type] or TYPE_COLOR["?"]
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", UI.headerFrame, "TOPLEFT", grp.x + 2, 0)
        b:SetWidth(grp.n * COL_W - 4)
        b.bg:SetColorTexture(col[1], col[2], col[3], 0.15)
        b.line:SetColorTexture(col[1], col[2], col[3], 0.9)
        local label = grp.type == "?" and "Type inconnu" or (ns.REALM_TYPE_LABELS[grp.type] or grp.type)
        b.text:SetWidth(grp.n * COL_W - 10)
        b.text:SetText(format("%s  |cffaaaaaa(%d)|r", label, typeCount[grp.type] or grp.n))
        b.text:SetTextColor(col[1], col[2], col[3])
        b:Show()
    end
    for k = #groups + 1, #UI.bands do UI.bands[k]:Hide() end
    PlaceSeps(UI.headerFrame, seps, 0.25)

    for j, c in ipairs(cols) do
        local h = GetHeader(j)
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", UI.headerFrame, "TOPLEFT", colX[j], -BAND_H)
        h.char = c
        SetClassIcon(h.icon, c.class)
        local cr, cg, cb = ClassColor(c)
        h.iconBorder:SetColorTexture(cr, cg, cb, 0.9)
        h.name:SetText(ClassColored(c, c.name or "?"))
        h.line2:SetText(c.surname and ClassColored(c, c.surname) or "")
        h.line3:SetText(format("%s Niv. %d |cffaaaaaa- %s|r", FACTION_ICON[c.faction] or "", c.level or 0, TypeLabel(c)))
        if IsCurrent(c) then
            h.bg:SetColorTexture(Skin.CurrentColor())
        else
            h.bg:SetColorTexture(1, 1, 1, 0.06)
        end
        h:Show()
    end
    for j = #cols + 1, #UI.headers do UI.headers[j]:Hide() end

    -- Lignes
    local rows = BuildRows(chars)
    UI.content:SetSize(width, max(1, #rows * ROW_H))

    -- Hauteur automatique : juste ce qu'il faut pour les lignes affichées, sans dépasser l'écran
    local chrome = TOP_H + BAND_H + HEADER_H + 2 + FOOT_H + 4
    local frameH = min(max(chrome + ROW_H * 3, chrome + #rows * ROW_H + 2), MaxHeight(f))
    if math.abs(f:GetHeight() - frameH) > 0.5 then f:SetHeight(frameH) end
    s.width, s.height = f:GetWidth(), frameH
    if chrome + #rows * ROW_H + 2 <= frameH then UI.scroll:SetVerticalScroll(0) end
    local stripe = 0
    for i, rd in ipairs(rows) do
        local r = GetRow(i)
        r.toggleKey = nil
        r.label:ClearAllPoints()
        if rd.kind == "section" or rd.kind == "sub" then
            local collapsed = s.collapsed[rd.key]
            local icon = collapsed and "|TInterface\\Buttons\\UI-PlusButton-Up:14|t " or "|TInterface\\Buttons\\UI-MinusButton-Up:14|t "
            r.toggleKey = rd.key
            if rd.kind == "section" then
                r.label:SetFontObject("ForeverEgo_GameFontNormal")
                r.label:SetPoint("LEFT", 4, 0)
                r.bg:SetColorTexture(Skin.SectionColor())
            else
                r.label:SetFontObject("ForeverEgo_GameFontNormalSmall")
                r.label:SetPoint("LEFT", 14, 0)
                r.bg:SetColorTexture(0.2, 0.2, 0.25, 0.4)
            end
            r.label:SetWidth(width - 20)
            r.label:SetText(icon .. rd.text)
            for _, cell in ipairs(r.cells) do cell:Hide() end
            PlaceSeps(r, {})
            stripe = 0
        else
            stripe = stripe + 1
            r.label:SetFontObject("ForeverEgo_GameFontHighlightSmall")
            local indent = rd.indent and 22 or 8
            r.label:SetPoint("LEFT", indent, 0)
            r.label:SetWidth(LABEL_W - indent - 4)
            r.label:SetText(rd.text)
            if stripe % 2 == 0 then
                r.bg:SetColorTexture(1, 1, 1, 0.04)
            else
                r.bg:SetColorTexture(0, 0, 0, 0)
            end
            for j, c in ipairs(cols) do
                local cell = GetCell(r, j)
                cell:ClearAllPoints()
                cell:SetPoint("LEFT", r, "LEFT", colX[j], 0)
                local ok, text, frac, br, bg, bb, tip, click = pcall(rd.fn, c)
                if not ok then text, frac, tip, click = "|cffff0000err|r", nil, nil, nil end
                FillCell(cell, c, text, frac, br, bg, bb, tip, click)
                cell:Show()
            end
            for j = #cols + 1, #r.cells do r.cells[j]:Hide() end
            PlaceSeps(r, seps, 0.18)
        end
        r:Show()
    end
    for i = #rows + 1, #UI.rows do UI.rows[i]:Hide() end

    -- Pied de page
    local total = 0
    for _, c in ipairs(chars) do total = total + (c.money or 0) end
    local filter = s.showAllTypes and "tous les serveurs"
        or (curType and ("serveurs " .. ns.REALM_TYPE_LABELS[curType]) or ("royaume " .. (GetRealmName() or "?")))
    UI.footText:SetText(format("Affichage : |cffffd100%s|r     Or total : %s", filter, FormatMoney(total)))
end

-------------------------------------------------------------------------------
-- Fenêtre d'équipement (clic gauche sur un personnage)
-------------------------------------------------------------------------------
local GetItemInfoFn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetQualityColor = (C_Item and C_Item.GetItemQualityColor) or GetItemQualityColor
local GEAR_ROW_H, GEAR_W = 20, 660

local function GearRowOnEnter(self)
    if not self.link then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(self.link)
    GameTooltip:Show()
end

local function GearRowOnClick(self)
    if not self.link then return end
    if HandleModifiedItemClick then
        HandleModifiedItemClick(self.link)
    elseif IsShiftKeyDown() and ChatEdit_InsertLink then
        ChatEdit_InsertLink(self.link)
    end
end

local function CreateGearFrame()
    local g = CreateFrame("Frame", "ForeverEgoGearFrame", UIParent, "BasicFrameTemplateWithInset")
    UI.gear = g
    Skin.Frame(g)
    local n = #ns.GEAR_SLOTS
    g:SetSize(GEAR_W, 80 + n * GEAR_ROW_H)
    g:SetPoint("CENTER", 0, 40)
    g:SetFrameStrata("DIALOG")
    g:SetToplevel(true)
    g:SetClampedToScreen(true)
    g:SetMovable(true)
    g:EnableMouse(true)
    g:RegisterForDrag("LeftButton")
    g:SetScript("OnDragStart", g.StartMoving)
    g:SetScript("OnDragStop", g.StopMovingOrSizing)
    tinsert(UISpecialFrames, "ForeverEgoGearFrame")

    g.title = g.TitleText
    if not g.title then
        g.title = g:CreateFontString(nil, "OVERLAY", "ForeverEgo_GameFontHighlight")
        g.title:SetPoint("TOP", 0, -5)
    end

    local function Header(text, x, w, justify)
        local fs = g:CreateFontString(nil, "OVERLAY", "ForeverEgo_GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", x, -32)
        fs:SetWidth(w)
        fs:SetJustifyH(justify or "LEFT")
        fs:SetText(text)
    end
    Header("Emplacement", 14, 85)
    Header("Objet", 104, 290)
    Header("iLvl", 400, 45, "CENTER")
    Header("Enchantement", 455, 190)

    g.rows = {}
    for i = 1, n do
        local r = CreateFrame("Button", nil, g)
        r:SetSize(GEAR_W - 20, GEAR_ROW_H)
        r:SetPoint("TOPLEFT", 10, -48 - (i - 1) * GEAR_ROW_H)
        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetAllPoints()
        r.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.05 or 0)
        r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

        r.slot = r:CreateFontString(nil, "OVERLAY", "ForeverEgo_GameFontHighlightSmall")
        r.slot:SetPoint("LEFT", 4, 0)
        r.slot:SetWidth(85)
        r.slot:SetJustifyH("LEFT")

        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(16, 16)
        r.icon:SetPoint("LEFT", 94, 0)

        r.item = r:CreateFontString(nil, "OVERLAY", "ForeverEgo_GameFontHighlightSmall")
        r.item:SetPoint("LEFT", 114, 0)
        r.item:SetWidth(272)
        r.item:SetJustifyH("LEFT")
        r.item:SetWordWrap(false)

        r.ilvl = r:CreateFontString(nil, "OVERLAY", "ForeverEgo_GameFontHighlightSmall")
        r.ilvl:SetPoint("LEFT", 390, 0)
        r.ilvl:SetWidth(45)
        r.ilvl:SetJustifyH("CENTER")

        r.ench = r:CreateFontString(nil, "OVERLAY", "ForeverEgo_GameFontHighlightSmall")
        r.ench:SetPoint("LEFT", 445, 0)
        r.ench:SetWidth(190)
        r.ench:SetJustifyH("LEFT")
        r.ench:SetWordWrap(false)

        r:SetScript("OnEnter", GearRowOnEnter)
        r:SetScript("OnLeave", HideTooltip)
        r:SetScript("OnClick", GearRowOnClick)
        g.rows[i] = r
    end

    g.foot = g:CreateFontString(nil, "OVERLAY", "ForeverEgo_GameFontNormalSmall")
    g.foot:SetPoint("BOTTOMLEFT", 14, 12)
    g.foot:SetPoint("BOTTOMRIGHT", -14, 12)
    g.foot:SetJustifyH("LEFT")
    g:Hide()
end

function UI.RefreshGear()
    local g = UI.gear
    if not g or not g:IsShown() or not g.charKey then return end
    local c = ns.db.chars[g.charKey]
    if not c then g:Hide() return end

    g.title:SetText(format("%s |cffaaaaaa(Niv. %d)|r", ColoredName(c), c.level or 0))
    local gear = c.gear
    local total, count = 0, 0
    for i, slot in ipairs(ns.GEAR_SLOTS) do
        local r = g.rows[i]
        local it = gear and gear[slot.id]
        r.slot:SetText(slot.name)
        if it then
            r.link = it.link
            r.icon:SetTexture(it.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            r.icon:Show()
            r.item:SetText(it.link)
            local ilvl, quality = it.ilvl, it.quality
            if not ilvl or not quality then
                local _, _, q, l = GetItemInfoFn(it.link)
                ilvl, quality = ilvl or l, quality or q
            end
            local qr, qg, qb = 1, 1, 1
            if quality and GetQualityColor then qr, qg, qb = GetQualityColor(quality) end
            r.ilvl:SetText(ilvl and tostring(ilvl) or "-")
            r.ilvl:SetTextColor(qr or 1, qg or 1, qb or 1)
            if it.enchant then
                r.ench:SetText("|cff1eff00" .. it.enchant .. "|r")
            elseif it.enchantId then
                r.ench:SetText("|cff1eff00Enchantement #" .. it.enchantId .. "|r")
            elseif slot.enchantable then
                r.ench:SetText("|cffff5555Aucun|r")
            else
                r.ench:SetText("|cff666666-|r")
            end
            if ilvl and slot.id ~= 4 and slot.id ~= 19 then
                total, count = total + ilvl, count + 1
            end
        else
            r.link = nil
            r.icon:Hide()
            r.item:SetText("|cff666666(vide)|r")
            r.ilvl:SetText("")
            r.ench:SetText("")
        end
    end

    if not gear then
        g.foot:SetText("Aucune donnée d'équipement : connecte-toi une fois avec ce personnage.")
    else
        local avg = count > 0 and format("%.1f", total / count) or "-"
        local when = IsCurrent(c) and "En ligne" or Ago(c.lastSeen)
        g.foot:SetText(format("Niveau d'objet moyen : |cffffffff%s|r     Mise à jour : |cffffffff%s|r     |cff888888Maj + clic : lien dans le chat|r", avg, when))
    end
end

function UI.ShowGear(c)
    if not UI.gear then CreateGearFrame() end
    local g = UI.gear
    if g:IsShown() and g.charKey == c.key then
        g:Hide()
        return
    end
    g.charKey = c.key
    g:Show()
    UI.RefreshGear()
end

-------------------------------------------------------------------------------
-- Fenêtre des recettes (clic gauche sur la barre d'un métier)
-------------------------------------------------------------------------------
local RECIPE_W, RECIPE_H, RROW_H, RHEAD_H = 540, 540, 34, 20
local DIFF_COLOR = {
    optimal = { 1, 0.5, 0.25 }, medium = { 1, 1, 0 }, easy = { 0.25, 0.75, 0.25 }, trivial = { 0.55, 0.55, 0.55 },
}
local DIFF_ORDER = { optimal = 1, medium = 2, easy = 3, trivial = 4 }
-- Métiers sans recettes : Dépeçage, Herboristerie, Pêche, Monte
local NO_RECIPES = { [393] = true, [182] = true, [356] = true, [762] = true }
local ItemNameByID = (C_Item and C_Item.GetItemNameByID) or function(id) return (GetItemInfo(id)) end

-- Noms des composants : gardés en mémoire pendant la session, jamais enregistrés (fichier plus léger)
local reagentNames = {}
local function ReagentName(rg)
    if rg.name then return rg.name end
    if not rg.id then return "?" end
    local n = reagentNames[rg.id]
    if not n then
        n = ItemNameByID(rg.id)
        if n then
            reagentNames[rg.id] = n
        elseif C_Item and C_Item.RequestLoadItemDataByID then
            pcall(C_Item.RequestLoadItemDataByID, rg.id)
        end
    end
    return n or ("Objet #" .. rg.id)
end

local function ReagentText(e)
    local parts = {}
    for _, rg in ipairs(e.reag or {}) do
        parts[#parts + 1] = format("%dx %s", rg.n or 1, ReagentName(rg))
    end
    return table.concat(parts, ", ")
end

local function RecipeRowOnEnter(self)
    local e = self.recipe
    if not e then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local link = e.link
    if link and pcall(GameTooltip.SetHyperlink, GameTooltip, link) then
        GameTooltip:AddLine(" ")
    else
        GameTooltip:AddLine(e.name, 1, 1, 1)
    end
    if e.reag and #e.reag > 0 then
        GameTooltip:AddLine("Composants :", 1, 0.82, 0)
        for _, rg in ipairs(e.reag) do
            GameTooltip:AddLine(format("  %dx %s", rg.n or 1, ReagentName(rg)), 1, 1, 1)
        end
    end
    GameTooltip:Show()
end

local function RecipeRowOnClick(self)
    local e = self.recipe
    local link = e and e.link
    if not link then return end
    if HandleModifiedItemClick then
        HandleModifiedItemClick(link)
    elseif IsShiftKeyDown() and ChatEdit_InsertLink then
        ChatEdit_InsertLink(link)
    end
end

local function CreateRecipeFrame()
    local f = CreateFrame("Frame", "ForeverEgoRecipeFrame", UIParent, "BasicFrameTemplateWithInset")
    UI.recipes = f
    Skin.Frame(f)
    f:SetSize(RECIPE_W, RECIPE_H)
    f:SetPoint("CENTER", 60, 20)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    tinsert(UISpecialFrames, "ForeverEgoRecipeFrame")

    f.title = f.TitleText
    if not f.title then
        f.title = f:CreateFontString(nil, "OVERLAY", "ForeverEgo_GameFontHighlight")
        f.title:SetPoint("TOP", 0, -5)
    end

    f.info = f:CreateFontString(nil, "OVERLAY", "ForeverEgo_GameFontNormalSmall")
    f.info:SetPoint("TOPLEFT", 16, -34)
    f.info:SetJustifyH("LEFT")

    local ok, search = pcall(CreateFrame, "EditBox", "ForeverEgoRecipeSearch", f, "SearchBoxTemplate")
    if not ok or not search then
        search = CreateFrame("EditBox", "ForeverEgoRecipeSearch2", f, "InputBoxTemplate")
    end
    search:SetSize(180, 20)
    search:SetPoint("TOPRIGHT", -18, -30)
    search:SetAutoFocus(false)
    search:HookScript("OnTextChanged", function() UI.RefreshRecipes() end)
    search:HookScript("OnEscapePressed", function(self) self:ClearFocus() end)
    Skin.EditBox(search)
    f.search = search

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -58)
    scroll:SetPoint("BOTTOMRIGHT", -32, 32)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(RECIPE_W - 46, 10)
    scroll:SetScrollChild(content)
    Skin.ScrollBar(scroll)
    f.scroll, f.content = scroll, content

    f.empty = content:CreateFontString(nil, "OVERLAY", "ForeverEgo_GameFontHighlight")
    f.empty:SetPoint("TOP", 0, -60)
    f.empty:SetWidth(RECIPE_W - 90)
    f.empty:SetJustifyH("CENTER")

    f.foot = f:CreateFontString(nil, "OVERLAY", "ForeverEgo_GameFontNormalSmall")
    f.foot:SetPoint("BOTTOMLEFT", 16, 12)
    f.foot:SetPoint("BOTTOMRIGHT", -16, 12)
    f.foot:SetJustifyH("LEFT")
    f.foot:SetText("|cffff8040Orange|r  |cffffff00Jaune|r  |cff40bf40Vert|r  |cff8c8c8cGris|r"
        .. "     |cff888888Maj + clic : lien dans le chat|r")

    f.rows = {}
    f:Hide()
end

local function GetRecipeRow(f, i)
    local r = f.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, f.content)
    r:SetPoint("LEFT", f.content, "LEFT")
    r:SetPoint("RIGHT", f.content, "RIGHT")
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.hl = r:CreateTexture(nil, "HIGHLIGHT")
    r.hl:SetAllPoints()
    r.hl:SetColorTexture(1, 1, 1, 0.08)

    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(26, 26)
    r.icon:SetPoint("LEFT", 4, 0)

    r.name = r:CreateFontString(nil, "OVERLAY", "ForeverEgo_GameFontNormal")
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)

    r.reag = r:CreateFontString(nil, "OVERLAY", "ForeverEgo_GameFontHighlightSmall")
    r.reag:SetPoint("BOTTOMLEFT", 36, 4)
    r.reag:SetPoint("RIGHT", -6, 0)
    r.reag:SetJustifyH("LEFT")
    r.reag:SetWordWrap(false)
    r.reag:SetTextColor(0.7, 0.7, 0.7)

    r:SetScript("OnEnter", RecipeRowOnEnter)
    r:SetScript("OnLeave", HideTooltip)
    r:SetScript("OnClick", RecipeRowOnClick)
    f.rows[i] = r
    return r
end

function UI.RefreshRecipes()
    local f = UI.recipes
    if not f or not f:IsShown() or not f.charKey then return end
    local c = ns.db.chars[f.charKey]
    if not c then f:Hide() return end

    local skill = c.skills and c.skills[f.skillName]
    local data = ns.GetRecipes(c, f.skillName, f.skillId)
    f.title:SetText(format("%s - %s", f.skillName, ColoredName(c)))

    local parts = {}
    local rank = (skill and skill.rank) or (data and data.rank)
    local maxRank = (skill and skill.max) or (data and data.max)
    if rank and maxRank then parts[#parts + 1] = format("Rang |cffffffff%d / %d|r", rank, maxRank) end
    if data then
        parts[#parts + 1] = format("|cffffffff%d|r recettes", #data.list)
        parts[#parts + 1] = "Mise à jour : |cffffffff" .. Ago(data.updated) .. "|r"
    end
    f.info:SetText(table.concat(parts, "     "))

    -- Liste filtrée et triée (catégorie, difficulté, nom)
    local query = (f.search:GetText() or ""):lower()
    local list = {}
    if data then
        for _, e in ipairs(data.list) do
            local match = query == "" or (e.name or ""):lower():find(query, 1, true)
            if not match then
                for _, rg in ipairs(e.reag or {}) do
                    if ReagentName(rg):lower():find(query, 1, true) then match = true break end
                end
            end
            if match then list[#list + 1] = e end
        end
    end
    table.sort(list, function(a, b)
        local ca, cb = a.cat or "~", b.cat or "~"
        if ca ~= cb then return ca < cb end
        local da, db = DIFF_ORDER[a.diff] or 5, DIFF_ORDER[b.diff] or 5
        if da ~= db then return da < db end
        return (a.name or "") < (b.name or "")
    end)

    local showCats = false
    for _, e in ipairs(list) do
        if e.cat ~= list[1].cat then showCats = true break end
    end

    local i, y, lastCat = 0, 0, nil
    for _, e in ipairs(list) do
        if showCats and e.cat ~= lastCat then
            lastCat = e.cat
            i = i + 1
            local r = GetRecipeRow(f, i)
            r.recipe = nil
            r:SetHeight(RHEAD_H)
            r:SetPoint("TOP", f.content, "TOP", 0, -y)
            r.bg:SetColorTexture(Skin.SectionColor())
            r.icon:Hide()
            r.name:ClearAllPoints()
            r.name:SetPoint("LEFT", 6, 0)
            r.name:SetPoint("RIGHT", -6, 0)
            r.name:SetText(e.cat or "Autres")
            r.name:SetTextColor(1, 0.82, 0)
            r.reag:SetText("")
            r:Show()
            y = y + RHEAD_H
        end
        i = i + 1
        local r = GetRecipeRow(f, i)
        r.recipe = e
        r:SetHeight(RROW_H)
        r:SetPoint("TOP", f.content, "TOP", 0, -y)
        r.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0)
        r.icon:SetTexture(e.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        r.icon:Show()
        r.name:ClearAllPoints()
        r.name:SetPoint("TOPLEFT", 36, -3)
        r.name:SetPoint("RIGHT", -6, 0)
        local made = ""
        if e.qmin and e.qmin > 1 then
            made = (e.qmax and e.qmax > e.qmin) and format(" |cffffffff(%d-%d)|r", e.qmin, e.qmax)
                or format(" |cffffffff(x%d)|r", e.qmin)
        end
        r.name:SetText((e.name or "?") .. made)
        local col = DIFF_COLOR[e.diff] or DIFF_COLOR.trivial
        r.name:SetTextColor(col[1], col[2], col[3])
        local rt = ReagentText(e)
        r.reag:SetText(rt ~= "" and rt or "|cff666666Aucun composant|r")
        r:Show()
        y = y + RROW_H
    end
    for j = i + 1, #f.rows do f.rows[j]:Hide() end
    f.content:SetHeight(max(10, y))

    if not data then
        if f.skillId and NO_RECIPES[f.skillId] then
            f.empty:SetText(f.skillName .. " n'a pas de recettes : c'est un métier de récolte.")
        else
            f.empty:SetText(format("Aucune recette enregistrée.\n\nConnecte-toi avec |cffffffff%s|r et ouvre une fois la fenêtre |cffffffff%s|r pour enregistrer ses recettes.", ns.FullName(c), f.skillName))
        end
        f.empty:Show()
    elseif #list == 0 then
        f.empty:SetText("Aucune recette ne correspond à la recherche.")
        f.empty:Show()
    else
        f.empty:Hide()
    end
end

-- Ouvre la vraie fenêtre du métier (personnage connecté uniquement)
local function OpenRealTradeSkill(skillId)
    if not skillId or NO_RECIPES[skillId] then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    local TS = C_TradeSkillUI
    if not TS or not TS.OpenTradeSkill then return false end
    local info = TS.GetBaseProfessionInfo and TS.GetBaseProfessionInfo()
    if ns.tradeSkillOpen and info and info.professionID == skillId and TS.CloseTradeSkill then
        pcall(TS.CloseTradeSkill)
        return true
    end
    local ok, res = pcall(TS.OpenTradeSkill, skillId)
    return ok and res ~= false
end

function UI.ShowRecipes(c, skillName, skillId)
    if IsCurrent(c) and OpenRealTradeSkill(skillId) then
        if UI.recipes then UI.recipes:Hide() end
        return
    end
    if not UI.recipes then CreateRecipeFrame() end
    local f = UI.recipes
    if f:IsShown() and f.charKey == c.key and f.skillName == skillName then
        f:Hide()
        return
    end
    f.charKey, f.skillName, f.skillId = c.key, skillName, skillId
    if f.search:GetText() ~= "" then f.search:SetText("") end
    f:Show()
    f.scroll:SetVerticalScroll(0)
    UI.RefreshRecipes()
end

local itemInfoPending = false
function UI.OnItemInfo()
    if itemInfoPending or not UI.recipes or not UI.recipes:IsShown() then return end
    itemInfoPending = true
    C_Timer.After(0.5, function()
        itemInfoPending = false
        UI.RefreshRecipes()
    end)
end

-------------------------------------------------------------------------------
-- Liste des personnages (activer / désactiver)
-------------------------------------------------------------------------------
local function CharItemOnClick(self)
    if self.charKey == ns.CurrentKey() then
        self:SetChecked(true)
        return
    end
    ns.db.settings.hidden[self.charKey] = (not self:GetChecked()) or nil
    UI.Refresh()
end

local function CharItemOnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.charKey == ns.CurrentKey() then
        GameTooltip:AddLine("Personnage connecté : toujours affiché.", 1, 1, 1)
    elseif self.filtered then
        GameTooltip:AddLine("Serveur d'un autre type :", 1, 0.5, 0.25)
        GameTooltip:AddLine("ce personnage n'apparaît que si « Tous les types de serveur » est coché.", 1, 1, 1, true)
    else
        GameTooltip:AddLine("Cocher / décocher pour l'afficher ou le masquer.", 1, 1, 1)
    end
    GameTooltip:Show()
end

function UI.RefreshCharList()
    local p = UI.charList
    if not p or not p:IsShown() then return end
    local s = ns.db.settings
    local list = {}
    for _, c in pairs(ns.db.chars) do
        if c.name then list[#list + 1] = c end
    end
    table.sort(list, function(a, b)
        local ta, tb = ns.TypeRank(ns.CharRuleset(a)), ns.TypeRank(ns.CharRuleset(b))
        if ta ~= tb then return ta < tb end
        if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) > (b.level or 0) end
        if ns.FullName(a) ~= ns.FullName(b) then return ns.FullName(a) < ns.FullName(b) end
        return a.key < b.key
    end)

    local cur = ns.CurrentKey()
    local curType = ns.CurrentRuleset()
    local width, anyFiltered = 260, false
    for i, c in ipairs(list) do
        local b = p.items[i]
        if not b then
            b = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
            Skin.CheckBox(b)
            b:SetSize(22, 22)
            b:SetPoint("TOPLEFT", 8, -44 - (i - 1) * 22)
            b.label = b:CreateFontString(nil, "OVERLAY", "ForeverEgo_GameFontHighlightSmall")
            b.label:SetPoint("LEFT", b, "RIGHT", 2, 0)
            b.label:SetJustifyH("LEFT")
            b:SetScript("OnClick", CharItemOnClick)
            b:SetScript("OnEnter", CharItemOnEnter)
            b:SetScript("OnLeave", HideTooltip)
            p.items[i] = b
        end
        local filtered = not s.showAllTypes and c.key ~= cur
            and (not curType or ns.CharRuleset(c) ~= curType)
        anyFiltered = anyFiltered or filtered
        b.charKey, b.filtered = c.key, filtered
        b:SetChecked(not s.hidden[c.key])
        b:SetEnabled(c.key ~= cur)
        local txt = format("%s |cffaaaaaa(Niv. %d - %s)|r", ColoredName(c), c.level or 0, TypeLabel(c))
        if filtered then txt = txt .. " |cffff8040*|r" end
        b.label:SetText(txt)
        b:Show()
        width = max(width, b.label:GetStringWidth() + 50)
    end
    for i = #list + 1, #p.items do p.items[i]:Hide() end

    local h = 44 + #list * 22 + 10
    if anyFiltered then
        p.note:Show()
        h = h + 16
    else
        p.note:Hide()
    end
    p:SetSize(width, h)
end

function UI.ToggleCharList(anchor)
    local p = UI.charList
    if not p then
        p = CreateFrame("Frame", "ForeverEgoCharList", UI.frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
        UI.charList = p
        p:SetFrameStrata("DIALOG")
        p:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        p:SetBackdropColor(0.05, 0.05, 0.1, 0.95)
        p:SetBackdropBorderColor(0.6, 0.6, 0.6)
        Skin.Panel(p)
        p:EnableMouse(true)
        local title = p:CreateFontString(nil, "OVERLAY", "ForeverEgo_GameFontHighlight")
        title:SetPoint("TOPLEFT", 12, -10)
        title:SetText("Personnages")
        local sub = p:CreateFontString(nil, "OVERLAY", "ForeverEgo_GameFontNormalSmall")
        sub:SetPoint("TOPLEFT", 12, -26)
        sub:SetText("Activer / désactiver vos personnages.")
        p.note = p:CreateFontString(nil, "OVERLAY", "ForeverEgo_GameFontDisableSmall")
        p.note:SetPoint("BOTTOMLEFT", 12, 10)
        p.note:SetText("|cffff8040*|r serveur d'un autre type (masqué par le filtre)")
        p.items = {}
        p:Hide()
    end
    if p:IsShown() then
        p:Hide()
        return
    end
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    p:Show()
    UI.RefreshCharList()
end

-------------------------------------------------------------------------------
-- Popup : type du serveur
-------------------------------------------------------------------------------
function ns.ShowRealmTypePopup(realm, guess)
    local p = UI.popup
    if not p then
        p = CreateFrame("Frame", "ForeverEgoRealmPopup", UIParent, "BasicFrameTemplateWithInset")
        UI.popup = p
        Skin.Frame(p)
        p:SetSize(320, 90 + #ns.REALM_TYPES * 28)
        p:SetPoint("CENTER", 0, 120)
        p:SetFrameStrata("DIALOG")
        p:SetClampedToScreen(true)
        p:SetMovable(true)
        p:EnableMouse(true)
        p:RegisterForDrag("LeftButton")
        p:SetScript("OnDragStart", p.StartMoving)
        p:SetScript("OnDragStop", p.StopMovingOrSizing)
        tinsert(UISpecialFrames, "ForeverEgoRealmPopup")
        local title = p.TitleText or p:CreateFontString(nil, "OVERLAY", "ForeverEgo_GameFontHighlight")
        if not p.TitleText then title:SetPoint("TOP", 0, -5) end
        title:SetText("ForeverEgo - Type de serveur")
        p.text = p:CreateFontString(nil, "OVERLAY", "ForeverEgo_GameFontHighlight")
        p.text:SetPoint("TOP", 0, -34)
        p.text:SetWidth(290)
        p.buttons = {}
        for i, t in ipairs(ns.REALM_TYPES) do
            local b = MakeButton(p, 250, ns.REALM_TYPE_DESC[t], function(self)
                ns.SetRealmType(p.realm, self.realmType)
                p:Hide()
            end)
            b.realmType = t
            b:SetPoint("TOP", p, "TOP", 0, -76 - (i - 1) * 28)
            p.buttons[i] = b
        end
    end
    p.realm = realm
    local txt = format("Quel est le type du serveur |cffffd100%s|r ?", realm or "?")
    if guess then
        txt = txt .. "\n|cff88ff88Suggestion : " .. ns.REALM_TYPE_LABELS[guess] .. "|r"
    end
    p.text:SetText(txt)
    for _, b in ipairs(p.buttons) do
        if b.realmType == guess or b.realmType == ns.GetRealmType(realm) then b:LockHighlight() else b:UnlockHighlight() end
    end
    p:Show()
end

-------------------------------------------------------------------------------
-- Bouton de la minicarte
-------------------------------------------------------------------------------
local function PlaceMinimapButton()
    local b = UI.minimapButton
    local angle = math.rad(ns.db.settings.minimap.angle or 220)
    local radius = (Minimap:GetWidth() / 2) + 5
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function UI.UpdateMinimapButton()
    if not UI.minimapButton then return end
    if ns.db.settings.minimap.hide then UI.minimapButton:Hide() else UI.minimapButton:Show() end
end

function UI.CreateMinimapButton()
    if UI.minimapButton or not Minimap then return end
    local b = CreateFrame("Button", "ForeverEgoMinimapButton", Minimap)
    UI.minimapButton = b
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(24, 24)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", 5, -4)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetTexture("Interface\\AddOns\\ForeverEgo\\Media\\Logo")
    icon:SetPoint("TOPLEFT", 7, -6)
    b.icon = icon
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")

    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            ns.OpenRealmType()
        else
            UI.Toggle()
        end
    end)
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            ns.db.settings.minimap.angle = math.deg(math.atan2(cy - my, cx - mx))
            PlaceMinimapButton()
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("ForeverEgo")
        GameTooltip:AddLine("Clic gauche : ouvrir / fermer", 1, 1, 1)
        GameTooltip:AddLine("Clic droit : type du serveur", 1, 1, 1)
        GameTooltip:AddLine("Glisser : déplacer le bouton", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", HideTooltip)

    PlaceMinimapButton()
    UI.UpdateMinimapButton()
end
