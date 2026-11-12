-- ForeverEgo - Skin : style graphique (Blizzard ou EllesmereUI)
local ADDON, ns = ...
local Skin = {}
ns.Skin = Skin

local WHITE = "Interface\\Buttons\\WHITE8X8"
local BLIZZ_BAR = "Interface\\TargetingFrame\\UI-StatusBar"
local DEFAULT_ACCENT = { 0.05, 0.82, 0.62 }

Skin.enabled = false
local accentList = {} -- { tex, alpha } : textures à la couleur d'accent

-------------------------------------------------------------------------------
-- Polices propres à ForeverEgo (copies des polices du jeu)
-------------------------------------------------------------------------------
local FONTS = { "GameFontNormal", "GameFontNormalSmall", "GameFontHighlight", "GameFontHighlightSmall", "GameFontDisableSmall" }
for _, name in ipairs(FONTS) do
    local obj = CreateFont("ForeverEgo_" .. name)
    if _G[name] then obj:CopyFontObject(_G[name]) end
end

local function EUI() return _G.EllesmereUI end

function Skin.Accent()
    local e = EUI()
    if e and e.GetAccentColor then
        local ok, r, g, b = pcall(e.GetAccentColor)
        if ok and r then return r, g, b end
    end
    return DEFAULT_ACCENT[1], DEFAULT_ACCENT[2], DEFAULT_ACCENT[3]
end

-- Police d'EllesmereUI (réessayée à l'ouverture des fenêtres si elle n'était pas encore prête)
local fontsDone = false
local function ApplyFonts()
    if fontsDone or not Skin.enabled then return end
    local e = EUI()
    local path
    if e and e.GetFontPath then
        local ok, p = pcall(e.GetFontPath)
        if ok and type(p) == "string" and p ~= "" then path = p end
    end
    if path then
        for _, name in ipairs(FONTS) do
            local src, obj = _G[name], _G["ForeverEgo_" .. name]
            if src and obj then
                local _, size, flags = src:GetFont()
                pcall(obj.SetFont, obj, path, size or 12, flags or "")
            end
        end
        fontsDone = true
    end
end

-- À appeler après le chargement des réglages (PLAYER_LOGIN)
function Skin.Init()
    local style = ns.db and ns.db.settings.style or "auto"
    local e = EUI()
    Skin.enabled = style ~= "blizzard" and e ~= nil and e.GetAccentColor ~= nil
    ApplyFonts()
end

function Skin.Name()
    return Skin.enabled and "EllesmereUI" or "Blizzard"
end

-------------------------------------------------------------------------------
-- Briques
-------------------------------------------------------------------------------
local function Accented(tex, alpha)
    accentList[#accentList + 1] = { tex, alpha or 1 }
    local r, g, b = Skin.Accent()
    tex:SetColorTexture(r, g, b, alpha or 1)
    return tex
end

-- Bordure d'un pixel ; accent = true pour la couleur d'accent
local function Border(frame, accent, r, g, b, a)
    local edges = {}
    local function Edge(p1, p2, horizontal)
        local t = frame:CreateTexture(nil, "OVERLAY", nil, 7)
        t:SetPoint(p1)
        t:SetPoint(p2)
        if horizontal then t:SetHeight(1) else t:SetWidth(1) end
        if accent then Accented(t, a or 1) else t:SetColorTexture(r or 0, g or 0, b or 0, a or 1) end
        edges[#edges + 1] = t
        return t
    end
    Edge("TOPLEFT", "TOPRIGHT", true)
    Edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
    Edge("TOPLEFT", "BOTTOMLEFT", false)
    Edge("TOPRIGHT", "BOTTOMRIGHT", false)
    return edges
end
Skin.Border = Border

local function SetEdgesColor(edges, r, g, b, a)
    for _, t in ipairs(edges) do t:SetColorTexture(r, g, b, a or 1) end
end

-- Cache toutes les textures existantes d'un cadre (celles du modèle Blizzard)
local function StripTextures(frame)
    if not frame then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("Texture") then
            region:SetTexture(nil)
            region:Hide()
        end
    end
end

local function ClearButtonTextures(b)
    for _, m in ipairs({ "Normal", "Pushed", "Highlight", "Disabled" }) do
        local clear = b["Clear" .. m .. "Texture"]
        if clear then
            pcall(clear, b)
        else
            local get = b["Get" .. m .. "Texture"]
            local t = get and get(b)
            if t then t:SetTexture(nil) end
        end
    end
end

-------------------------------------------------------------------------------
-- Éléments
-------------------------------------------------------------------------------
function Skin.BarTexture()
    return Skin.enabled and WHITE or BLIZZ_BAR
end

-- Fond des titres de section
function Skin.SectionColor()
    if Skin.enabled then
        local r, g, b = Skin.Accent()
        return r, g, b, 0.22
    end
    return 0.35, 0.28, 0.05, 0.45
end

-- Fond de la colonne du personnage connecté
function Skin.CurrentColor()
    if Skin.enabled then
        local r, g, b = Skin.Accent()
        return r, g, b, 0.16
    end
    return 0.2, 0.8, 0.2, 0.18
end

local function SkinCloseButton(btn)
    if not btn then return end
    ClearButtonTextures(btn)
    StripTextures(btn)
    btn:SetSize(20, 20)
    btn:ClearAllPoints()
    btn:SetPoint("TOPRIGHT", -3, -2)
    local x = btn:CreateFontString(nil, "OVERLAY", "ForeverEgo_GameFontHighlight")
    x:SetPoint("CENTER", 0, 0)
    x:SetText("x")
    btn:HookScript("OnEnter", function() local r, g, b = Skin.Accent() x:SetTextColor(r, g, b) end)
    btn:HookScript("OnLeave", function() x:SetTextColor(1, 1, 1) end)
end

-- Fenêtre (BasicFrameTemplateWithInset) : fond uni sombre, barre de titre, bordure d'accent
function Skin.Frame(f)
    if not Skin.enabled or not f then return end
    ApplyFonts()
    StripTextures(f)
    if f.NineSlice then f.NineSlice:Hide() end
    if f.Inset then f.Inset:Hide() end
    for _, k in ipairs({ "Bg", "TitleBg", "TopTileStreaks" }) do
        if f[k] and f[k].Hide then f[k]:Hide() end
    end

    local bg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetColorTexture(0.06, 0.06, 0.07, 0.96)

    local bar = f:CreateTexture(nil, "BACKGROUND", nil, -7)
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("TOPRIGHT", -1, -1)
    bar:SetHeight(23)
    bar:SetColorTexture(0.1, 0.1, 0.12, 1)

    local line = f:CreateTexture(nil, "BACKGROUND", nil, -6)
    line:SetPoint("TOPLEFT", bar, "BOTTOMLEFT")
    line:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT")
    line:SetHeight(1)
    Accented(line, 0.5)

    Border(f, true)
    if f.TitleText then f.TitleText:SetFontObject("ForeverEgo_GameFontHighlight") end
    SkinCloseButton(f.CloseButton)
end

-- Panneau simple (liste des personnages)
function Skin.Panel(p)
    if not Skin.enabled or not p then return end
    if p.SetBackdrop then p:SetBackdrop(nil) end
    local bg = p:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetColorTexture(0.06, 0.06, 0.07, 0.97)
    Border(p, true)
end

-- Bouton (UIPanelButtonTemplate)
function Skin.Button(b)
    if not Skin.enabled or not b then return end
    for _, k in ipairs({ "Left", "Middle", "Right", "LeftSeparator", "RightSeparator" }) do
        if b[k] and b[k].Hide then b[k]:Hide() end
    end
    ClearButtonTextures(b)
    StripTextures(b)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.12, 0.12, 0.14, 1)
    local edges = Border(b, false, 0.28, 0.28, 0.3, 1)
    b:HookScript("OnEnter", function(self)
        if self:IsEnabled() then local r, g, bl = Skin.Accent() SetEdgesColor(edges, r, g, bl, 1) end
    end)
    b:HookScript("OnLeave", function() SetEdgesColor(edges, 0.28, 0.28, 0.3, 1) end)
    b:HookScript("OnDisable", function() bg:SetColorTexture(0.08, 0.08, 0.09, 1) end)
    b:HookScript("OnEnable", function() bg:SetColorTexture(0.12, 0.12, 0.14, 1) end)
    b:SetNormalFontObject("ForeverEgo_GameFontHighlightSmall")
    b:SetHighlightFontObject("ForeverEgo_GameFontHighlightSmall")
    b:SetDisabledFontObject("ForeverEgo_GameFontDisableSmall")
end

-- Case à cocher (UICheckButtonTemplate) : petit carré, coche pleine à la couleur d'accent
function Skin.CheckBox(cb)
    if not Skin.enabled or not cb then return end
    ClearButtonTextures(cb)
    StripTextures(cb)
    if cb.SetCheckedTexture then pcall(cb.SetCheckedTexture, cb, "") end
    if cb.SetDisabledCheckedTexture then pcall(cb.SetDisabledCheckedTexture, cb, "") end

    -- Tout est dessiné sur la case elle-même (un sous-cadre passerait par-dessus la coche)
    local box = cb:CreateTexture(nil, "BACKGROUND")
    box:SetSize(16, 16)
    box:SetPoint("CENTER")
    box:SetColorTexture(0.08, 0.08, 0.09, 1)

    local edges = {}
    local function Edge(p1, p2, horizontal)
        local t = cb:CreateTexture(nil, "BORDER")
        t:SetPoint(p1, box, p1)
        t:SetPoint(p2, box, p2)
        if horizontal then t:SetHeight(1) else t:SetWidth(1) end
        edges[#edges + 1] = t
    end
    Edge("TOPLEFT", "TOPRIGHT", true)
    Edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
    Edge("TOPLEFT", "BOTTOMLEFT", false)
    Edge("TOPRIGHT", "BOTTOMRIGHT", false)

    local mark = cb:CreateTexture(nil, "ARTWORK")
    mark:SetPoint("TOPLEFT", box, "TOPLEFT", 3, -3)
    mark:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -3, 3)

    -- Cochée : bordure et carré intérieur à la couleur d'accent (grisés si la case est désactivée)
    local function Update()
        local checked, enabled = cb:GetChecked(), cb:IsEnabled()
        local r, g, b = Skin.Accent()
        if not enabled then r, g, b = 0.45, 0.45, 0.45 end
        if checked then
            mark:SetColorTexture(r, g, b, 1)
            mark:Show()
            SetEdgesColor(edges, r, g, b, 1)
        else
            mark:Hide()
            SetEdgesColor(edges, 0.32, 0.32, 0.35, 1)
        end
    end
    cb.FEUpdateSkin = Update
    hooksecurefunc(cb, "SetChecked", Update)
    cb:HookScript("OnClick", Update)
    cb:HookScript("OnShow", Update)
    cb:HookScript("OnEnable", Update)
    cb:HookScript("OnDisable", Update)
    cb:HookScript("OnEnter", function()
        if not cb:GetChecked() and cb:IsEnabled() then
            local r, g, b = Skin.Accent()
            SetEdgesColor(edges, r, g, b, 0.6)
        end
    end)
    cb:HookScript("OnLeave", Update)
    Update()
end

-- Barre de défilement (UIPanelScrollFrameTemplate) : fine, curseur à la couleur d'accent
function Skin.ScrollBar(sf)
    if not Skin.enabled or not sf then return end
    local sb = sf.ScrollBar or (sf:GetName() and _G[sf:GetName() .. "ScrollBar"])
    if not sb then return end
    local name = sb:GetName()
    local up = sb.ScrollUpButton or (name and _G[name .. "ScrollUpButton"])
    local down = sb.ScrollDownButton or (name and _G[name .. "ScrollDownButton"])
    if up then up:SetAlpha(0) up:EnableMouse(false) end
    if down then down:SetAlpha(0) down:EnableMouse(false) end
    local thumb = sb.GetThumbTexture and sb:GetThumbTexture()
    for _, region in ipairs({ sb:GetRegions() }) do
        if region ~= thumb and region:IsObjectType("Texture") then region:SetAlpha(0) end
    end
    if sb.Background then sb.Background:SetAlpha(0) end
    local track = sb:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("TOP", 0, 14)
    track:SetPoint("BOTTOM", 0, -14)
    track:SetWidth(4)
    track:SetColorTexture(1, 1, 1, 0.06)
    if thumb then
        thumb:SetTexture(WHITE)
        thumb:SetSize(4, 40)
        accentList[#accentList + 1] = { thumb, 0.8, vertex = true }
        local r, g, b = Skin.Accent()
        thumb:SetVertexColor(r, g, b, 0.8)
    end
end

-- Champ de recherche (SearchBoxTemplate / InputBoxTemplate)
function Skin.EditBox(eb)
    if not Skin.enabled or not eb then return end
    for _, k in ipairs({ "Left", "Middle", "Right", "Mid" }) do
        if eb[k] and eb[k].Hide then eb[k]:Hide() end
    end
    local name = eb:GetName()
    if name then
        for _, k in ipairs({ "Left", "Middle", "Right", "Mid" }) do
            local t = _G[name .. k]
            if t and t.Hide then t:Hide() end
        end
    end
    local bg = eb:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", -4, 0)
    bg:SetPoint("BOTTOMRIGHT", 0, 0)
    bg:SetColorTexture(0.1, 0.1, 0.12, 1)
    local holder = CreateFrame("Frame", nil, eb)
    holder:SetAllPoints(bg)
    local edges = Border(holder, false, 0.28, 0.28, 0.3, 1)
    eb:HookScript("OnEditFocusGained", function() local r, g, b = Skin.Accent() SetEdgesColor(edges, r, g, b, 1) end)
    eb:HookScript("OnEditFocusLost", function() SetEdgesColor(edges, 0.28, 0.28, 0.3, 1) end)
    eb:SetFontObject("ForeverEgo_GameFontHighlightSmall")
end

-- Recolore tout ce qui suit l'accent (si la couleur a changé dans EllesmereUI)
local lastR, lastG, lastB
function Skin.UpdateAccent()
    if not Skin.enabled then return end
    local r, g, b = Skin.Accent()
    if r == lastR and g == lastG and b == lastB then return end
    lastR, lastG, lastB = r, g, b
    for _, e in ipairs(accentList) do
        if e.vertex then e[1]:SetVertexColor(r, g, b, e[2]) else e[1]:SetColorTexture(r, g, b, e[2]) end
    end
end
