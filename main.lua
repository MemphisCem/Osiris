script_name('OsirisCH')
script_author('MonetError')
script_version('1.0 Beta')
script_description('OsirisCH чит на Arizona RP Mobile. Активация по нажатию на водяной знак или командой /osiris')

-- MonetLoader / MoonLoader + mimgui. Файл сохранять в UTF-8 (без BOM).

local imgui    = require 'mimgui'
local ffi      = require 'ffi'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local okIni, inicfg = pcall(require, 'inicfg')

local CFG_FILE = 'Mir menu.ini'
local DEFAULTS = {
    -- внешний вид
    scale = 100, textScale = 100, rounding = 14, bgAlpha = 97,
    -- акцент
    accR = 255, accG = 255, accB = 255,
    rainbow = false, rainbowSpeed = 30,
    -- ватермарка
    wmShow = true,
    wmName = 'OsirisCH', wmUser = '@MonetError', wmGame = 'Arizona Mobile',
    wmCorner = 0, wmMargin = 4, wmScale = 100, wmAlpha = 90,
    wmFps = false, wmTime = false,
    wmGlow = true, wmShine = true, wmPulse = true,
    -- эффекты
    fxAnim = true, fxGlow = true, fxLine = true, fxBorder = true,
}
for _, k in ipairs({ 'speedhack', 'jumphack', 'airbrake', 'silentaim', 'rapid', 'blockWeather', 'metkatp',
    'antimask', 'antifreeze', 'anticaptcha', 'espPBox', 'espPSkel', 'espPNick', 'espPTrace', 'espPDist',
    'espCBox', 'espCDist', 'espCStatus', 'espCName', 'light', 'twOn', 'spammer', 'carGod', 'carFuel',
    'carFastExit', 'carFly', 'carNoBike', 'carFastBrake', 'carSpeedhack', 'wmPing', 'spamInf',
    'cameraFov', 'cameraZoom', 'freeCam', 'camHideHud', 'camHideNicks', 'camBubbles', 'attachTrailer', 'renderRuda', 'renderDeer', 'renderGift',
    'noCJ', 'customRun', 'infRun', 'autoRun', 'clickWarp', 'renderTrash', 'renderStash', 'renderHighTree', 'renderApple', 'renderPlum', 'renderCoconut', 'renderGraffiti' }) do DEFAULTS[k] = false end
DEFAULTS.spamText = 'Hello'
for k, v in pairs({ speedVal = 10, jumpVal = 10, gameTime = 12, gameWeather = 1, skinId = 0,
    saFov = 30, saRange = 100, rapidSpeed = 50, carSpeed = 200, carAccel = 50, spamDelay = 1000, spamCount = 10,
    cameraFovValue = 101, cameraZoomValue = 55, trailerRadius = 150, freeCamSpeed = 20, runSet = 1 }) do DEFAULTS[k] = v end
for k, c in pairs({ espPBox = { 255, 72, 72 }, espPSkel = { 255, 255, 255 }, espPNick = { 255, 255, 255 },
    espPTrace = { 60, 212, 255 }, espPDist = { 255, 222, 60 }, espCBox = { 72, 230, 120 }, espCDist = { 255, 222, 60 }, espCName = { 255, 255, 255 } }) do
    DEFAULTS[k .. 'R'], DEFAULTS[k .. 'G'], DEFAULTS[k .. 'B'] = c[1], c[2], c[3]
end
for _, k in ipairs({ 'streamChat', 'autoDrugs', 'autoLock', 'autoFill', 'autoDomkrat' }) do DEFAULTS[k] = false end
DEFAULTS.drugsCount = 3
DEFAULTS.fillTo = 100
local STR_KEYS = { wmName = true, wmUser = true, wmGame = true, spamText = true }

local function copy(t) local r = {} for k, v in pairs(t) do r[k] = v end return r end

local ini = { main = copy(DEFAULTS) }
if okIni then
    local ok, res = pcall(inicfg.load, { main = copy(DEFAULTS) }, CFG_FILE)
    if ok and res then ini = res end
end

local T = {}
for k, v in pairs(DEFAULTS) do
    local cur = ini.main and ini.main[k]
    if cur == nil then cur = v end
    if type(v) == 'boolean' then
        T[k] = imgui.new.bool(cur == true or cur == 'true')
    elseif type(v) == 'string' then
        T[k] = imgui.new.char[64](tostring(cur):sub(1, 60))
    else
        T[k] = imgui.new.int(tonumber(cur) or v)
    end
end

-- текст ватермарки нельзя менять: всегда значения по умолчанию
for _, k in ipairs({ 'wmName', 'wmUser', 'wmGame' }) do
    ffi.fill(T[k], 64)
    ffi.copy(T[k], DEFAULTS[k])
end

local function collect()
    local t = {}
    for k, v in pairs(T) do
        if STR_KEYS[k] then
            t[k] = (ffi.string(v):gsub('[;=\r\n]', ''))
        else
            t[k] = v[0]
        end
    end
    return t
end
local function serialize(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys)
    local p = {}
    for _, k in ipairs(keys) do p[#p + 1] = k .. '=' .. tostring(t[k]) end
    return table.concat(p, ';')
end
local lastSnap = serialize(collect())
local function saveCfg(force)
    if not okIni then return end
    local t = collect()
    local s = serialize(t)
    if force or s ~= lastSnap then
        ini.main = t
        pcall(inicfg.save, ini, CFG_FILE)
        lastSnap = s
    end
end
local function resetAll()
    for k, v in pairs(DEFAULTS) do
        if STR_KEYS[k] then
            ffi.fill(T[k], 64)
            ffi.copy(T[k], v)
        else
            T[k][0] = v
        end
    end
end

local V2, V4 = imgui.ImVec2, imgui.ImVec4
local WinState = imgui.new.bool(false)
local MP = {}  -- позиция меню (двигается за шапку)
local K = 1.0      -- масштаб под разрешение экрана
local UI = 1.0     -- K * пользовательский размер меню
local WS = 1.0     -- масштаб шрифта меню
local GA = 1.0     -- глобальная прозрачность для ручной отрисовки
local menuA = 0.0
local LIGHT = false

local function P(v) return v * UI end
local function clamp(x, a, b) return math.max(a, math.min(b, x)) end
local function lerp(a, b, t) return a + (b - a) * t end

local function msg(text)
    if sampAddChatMessage then
        sampAddChatMessage(u8:decode('{FFFFFF}[OsirisCH] ' .. text), -1)
    end
end

local function hsv2rgb(h, s, v)
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    i = i % 6
    if i == 0 then return v, t, p
    elseif i == 1 then return q, v, p
    elseif i == 2 then return p, v, t
    elseif i == 3 then return p, q, v
    elseif i == 4 then return t, p, v
    else return v, p, q end
end

-- акцентный цвет
local ACC = { r = 1, g = 1, b = 1, lum = 1, on = { 0.04, 0.04, 0.05 } }
local function updateAccent()
    local r, g, b
    if T.rainbow[0] then
        r, g, b = hsv2rgb((os.clock() * T.rainbowSpeed[0] / 200) % 1, 0.75, 1)
    else
        r, g, b = T.accR[0] / 255, T.accG[0] / 255, T.accB[0] / 255
    end
    ACC.r, ACC.g, ACC.b = r, g, b
    ACC.lum = 0.299 * r + 0.587 * g + 0.114 * b
    ACC.on = ACC.lum > 0.55 and { 0.04, 0.04, 0.05 } or { 1, 1, 1 }
end

local function RAW(r, g, b, a)
    return imgui.ColorConvertFloat4ToU32(V4(r, g, b, (a or 1) * GA))
end
local function G(v) return LIGHT and (1 - v) or v end
local function U32(r, g, b, a)
    if LIGHT then r, g, b = 1 - r, 1 - g, 1 - b end
    return RAW(r, g, b, a)
end
local function AC(a) return RAW(ACC.r, ACC.g, ACC.b, a or 1) end
local function ONC(a) return RAW(ACC.on[1], ACC.on[2], ACC.on[3], a or 1) end

-- мягкое свечение вокруг прямоугольника
local function glow(dl, x1, y1, x2, y2, rounding, spread, strength)
    local steps = 9
    for i = steps, 1, -1 do
        local e = spread * i / steps
        dl:AddRectFilled(V2(x1 - e, y1 - e), V2(x2 + e, y2 + e), AC(strength), rounding + e)
    end
end

-- иконка (глаз-мишень)
local function drawIcon(dl, cx, cy, r, pulse)
    local t = os.clock()
    dl:AddCircleFilled(V2(cx, cy), r, U32(0.06, 0.06, 0.07, 1), 36)
    if pulse then
        local p = (t * 0.8) % 1
        dl:AddCircle(V2(cx, cy), r + r * 0.45 * p, AC((1 - p) * 0.6), 36, math.max(1, r * 0.08))
    end
    dl:AddCircle(V2(cx, cy), r, AC(1), 36, math.max(1.5, r * 0.13))
    dl:AddCircleFilled(V2(cx, cy), r * 0.52, AC(1), 32)
    dl:AddCircleFilled(V2(cx, cy), r * 0.25, U32(0.05, 0.05, 0.06, 1), 24)
    dl:AddCircleFilled(V2(cx - r * 0.09, cy - r * 0.09), r * 0.08, U32(1, 1, 1, 0.9), 12)
end

imgui.OnInitialize(function()
    local io = imgui.GetIO()
    io.IniFilename = nil
    local _, sh = getScreenResolution()
    K = clamp(sh / 800, 0.9, 2.0)

    local ranges = io.Fonts:GetGlyphRangesCyrillic()
    local cands = {}
    pcall(function() cands[#cands + 1] = getFolderPath(0x14) .. '\\segoeui.ttf' end)
    pcall(function() cands[#cands + 1] = getFolderPath(0x14) .. '\\arial.ttf' end)
    pcall(function() cands[#cands + 1] = getWorkingDirectory() .. '/resource/fonts/arial.ttf' end)
    pcall(function() cands[#cands + 1] = getWorkingDirectory() .. '/resource/fonts/trebucbd.ttf' end)
    cands[#cands + 1] = '/system/fonts/Roboto-Regular.ttf'
    cands[#cands + 1] = '/system/fonts/NotoSans-Regular.ttf'
    cands[#cands + 1] = '/system/fonts/DroidSans.ttf'

    local loaded = false
    for _, p in ipairs(cands) do
        local okF, exists = pcall(doesFileExist, p)
        if okF and exists then
            local ok = pcall(function() io.Fonts:AddFontFromFileTTF(p, 16 * K, nil, ranges) end)
            if ok then loaded = true break end
        end
    end
    if not loaded then io.Fonts:AddFontDefault() end
end)

local HV = {}
local function hoverAnim(id, hovered)
    HV[id] = HV[id] or 0
    HV[id] = lerp(HV[id], hovered and 1 or 0, math.min(1, imgui.GetIO().DeltaTime * 14))
    return HV[id]
end

local drawTabIcon
local SCROLLED, SLIDER_ACT = false, false
local function Tap() return imgui.IsItemDeactivated() and not SCROLLED end
local ROW_BG = { 0.085, 0.085, 0.092 }

local function Section(text)
    local dl = imgui.GetWindowDrawList()
    local pos = imgui.GetCursorScreenPos()
    local th = imgui.GetTextLineHeight()
    dl:AddRectFilled(pos, V2(pos.x + P(4), pos.y + th), AC(1), P(2))
    dl:AddText(V2(pos.x + P(12), pos.y), U32(1, 1, 1, 1), text)
    imgui.Dummy(V2(1, th + P(4)))
end

local function Toggle(id, title, gear)
    local v = T[id]
    local dl = imgui.GetWindowDrawList()
    local pos = imgui.GetCursorScreenPos()
    local w = imgui.GetContentRegionAvail().x
    local th = imgui.GetTextLineHeight()
    local h = th + P(38)

    local gw = gear and P(64) or 0
    imgui.InvisibleButton('##tg' .. id, V2(w - gw, h))
    if Tap() then v[0] = not v[0] end
    local hov = hoverAnim('tg' .. id, imgui.IsItemHovered())

    local target = v[0] and 1 or 0
    HV['on' .. id] = HV['on' .. id] or target
    HV['on' .. id] = lerp(HV['on' .. id], target, math.min(1, imgui.GetIO().DeltaTime * 16))
    local t = HV['on' .. id]

    local g = ROW_BG[1] + 0.04 * hov
    dl:AddRectFilled(pos, V2(pos.x + w, pos.y + h), U32(g, g, g + 0.007, 1), P(10))
    dl:AddText(V2(pos.x + P(16), pos.y + (h - th) / 2), U32(0.96, 0.96, 0.96, 1), title)

    local sh = th + P(12)
    local sw = sh * 1.85
    local sx, sy = pos.x + w - gw - sw - P(14), pos.y + (h - sh) / 2
    local off = 0.26
    dl:AddRectFilled(V2(sx, sy), V2(sx + sw, sy + sh),
        RAW(lerp(G(off), ACC.r, t), lerp(G(off), ACC.g, t), lerp(G(off), ACC.b, t), 1), sh / 2)
    local kr = sh / 2 - P(3)
    local kcx = sx + sh / 2 + (sw - sh) * t
    local k = lerp(G(0.95), ACC.on[1], t)
    local k2 = lerp(G(0.95), ACC.on[2], t)
    local k3 = lerp(G(0.95), ACC.on[3], t)
    dl:AddCircleFilled(V2(kcx, sy + sh / 2), kr, RAW(k, k2, k3, 1), 24)

    if gear then
        local gx = pos.x + w - gw
        imgui.SetCursorScreenPos(V2(gx, pos.y))
        imgui.InvisibleButton('##gr' .. id, V2(gw, h))
        if Tap() then imgui.OpenPopup(gear) end
        local gh = hoverAnim('gr' .. id, imgui.IsItemHovered())
        local c = lerp(0.6, 1, gh)
        drawTabIcon(dl, 5, gx + gw / 2 - P(4), pos.y + h / 2, P(14), U32(c, c, c, 1))
        imgui.SetCursorScreenPos(pos)
        imgui.Dummy(V2(w, h))
    end
end

-- строка с шестерёнкой (открывает окно настроек)
local function GearRow(title, popup)
    local dl = imgui.GetWindowDrawList()
    local pos = imgui.GetCursorScreenPos()
    local w = imgui.GetContentRegionAvail().x
    local th = imgui.GetTextLineHeight()
    local h = th + P(38)
    imgui.InvisibleButton('##gw' .. popup, V2(w, h))
    if Tap() then imgui.OpenPopup(popup) end
    local hov = hoverAnim('gw' .. popup, imgui.IsItemHovered())
    local g = ROW_BG[1] + 0.04 * hov
    dl:AddRectFilled(pos, V2(pos.x + w, pos.y + h), U32(g, g, g + 0.007, 1), P(10))
    dl:AddText(V2(pos.x + P(16), pos.y + (h - th) / 2), U32(0.96, 0.96, 0.96, 1), title)
    local c = lerp(0.6, 1, hov)
    drawTabIcon(dl, 5, pos.x + w - P(34), pos.y + h / 2, P(14), U32(c, c, c, 1))
end

local function SliderRow(id, label, mn, mx, fmt, grab, dim)
    local dl = imgui.GetWindowDrawList()
    local pos = imgui.GetCursorScreenPos()
    local w = imgui.GetContentRegionAvail().x
    local th = imgui.GetTextLineHeight()
    local fh = imgui.GetFrameHeight()
    local h = P(10) + th + P(6) + fh + P(10)

    local oldGA = GA
    if dim then GA = GA * 0.4 end
    imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, GA)

    dl:AddRectFilled(pos, V2(pos.x + w, pos.y + h), U32(ROW_BG[1], ROW_BG[2], ROW_BG[3], 1), P(10))
    dl:AddText(V2(pos.x + P(16), pos.y + P(10)), U32(0.96, 0.96, 0.96, 1), label)

    imgui.SetCursorScreenPos(V2(pos.x + P(12), pos.y + P(10) + th + P(6)))
    imgui.PushItemWidth(w - P(24))
    if grab then
        imgui.PushStyleColor(imgui.Col.SliderGrab, grab)
        imgui.PushStyleColor(imgui.Col.SliderGrabActive, grab)
    end
    imgui.SliderInt('##sl' .. id, T[id], mn, mx, fmt)
    if imgui.IsItemActive() then SLIDER_ACT = true end
    if grab then imgui.PopStyleColor(2) end
    imgui.PopItemWidth()
    imgui.PopStyleVar()
    GA = oldGA

    imgui.SetCursorScreenPos(pos)
    imgui.Dummy(V2(w, h))
end

local function InputRow(id, label)
    local dl = imgui.GetWindowDrawList()
    local pos = imgui.GetCursorScreenPos()
    local w = imgui.GetContentRegionAvail().x
    local th = imgui.GetTextLineHeight()
    local fh = imgui.GetFrameHeight()
    local h = P(10) + th + P(6) + fh + P(10)

    dl:AddRectFilled(pos, V2(pos.x + w, pos.y + h), U32(ROW_BG[1], ROW_BG[2], ROW_BG[3], 1), P(10))
    dl:AddText(V2(pos.x + P(16), pos.y + P(10)), U32(0.96, 0.96, 0.96, 1), label)
    imgui.SetCursorScreenPos(V2(pos.x + P(12), pos.y + P(10) + th + P(6)))
    imgui.PushItemWidth(w - P(24))
    imgui.InputText('##in' .. id, T[id], ffi.sizeof(T[id]))
    if imgui.IsItemActive() then SLIDER_ACT = true end
    imgui.PopItemWidth()
    imgui.SetCursorScreenPos(pos)
    imgui.Dummy(V2(w, h))
end

-- поле для ввода числа (ID цифрами)
local function IntRow(id, label, mn, mx)
    local dl = imgui.GetWindowDrawList()
    local pos = imgui.GetCursorScreenPos()
    local w = imgui.GetContentRegionAvail().x
    local th = imgui.GetTextLineHeight()
    local h = P(10) + th + P(6) + imgui.GetFrameHeight() + P(10)
    dl:AddRectFilled(pos, V2(pos.x + w, pos.y + h), U32(ROW_BG[1], ROW_BG[2], ROW_BG[3], 1), P(10))
    dl:AddText(V2(pos.x + P(16), pos.y + P(10)), U32(0.96, 0.96, 0.96, 1), label)
    imgui.SetCursorScreenPos(V2(pos.x + P(12), pos.y + P(10) + th + P(6)))
    imgui.PushItemWidth(w - P(24))
    imgui.InputInt('##ii' .. id, T[id], 0, 0)
    if imgui.IsItemActive() then SLIDER_ACT = true end
    imgui.PopItemWidth()
    T[id][0] = clamp(T[id][0], mn, mx)
    imgui.SetCursorScreenPos(pos)
    imgui.Dummy(V2(w, h))
end

local function ButtonGrid(id, labels, cols, isSel, onClick)
    local dl = imgui.GetWindowDrawList()
    local pos = imgui.GetCursorScreenPos()
    local w = imgui.GetContentRegionAvail().x
    local th = imgui.GetTextLineHeight()
    local gap = P(8)
    local cw = (w - gap * (cols - 1)) / cols
    local ch = th + P(20)
    local rows = math.ceil(#labels / cols)
    for i, label in ipairs(labels) do
        local cx = pos.x + ((i - 1) % cols) * (cw + gap)
        local cy = pos.y + math.floor((i - 1) / cols) * (ch + gap)
        imgui.SetCursorScreenPos(V2(cx, cy))
        imgui.InvisibleButton('##bg' .. id .. i, V2(cw, ch))
        local hov = imgui.IsItemHovered()
        if Tap() then onClick(i) end
        local sel = isSel(i)
        local bgc
        if sel then bgc = AC(1)
        elseif hov then bgc = U32(0.16, 0.16, 0.17, 1)
        else bgc = U32(0.10, 0.10, 0.11, 1) end
        dl:AddRectFilled(V2(cx, cy), V2(cx + cw, cy + ch), bgc, P(10))
        if not sel then
            dl:AddRect(V2(cx, cy), V2(cx + cw, cy + ch), hov and AC(0.8) or U32(1, 1, 1, 0.07), P(10))
        end
        local ts = imgui.CalcTextSize(label)
        dl:AddText(V2(cx + (cw - ts.x) / 2, cy + (ch - ts.y) / 2),
            sel and ONC(1) or U32(0.95, 0.95, 0.95, 1), label)
    end
    imgui.SetCursorScreenPos(pos)
    imgui.Dummy(V2(w, rows * ch + (rows - 1) * gap))
end

local SWATCH = {
    { 255, 255, 255 }, { 255, 72, 72 }, { 255, 150, 40 }, { 255, 222, 60 }, { 72, 230, 120 },
    { 60, 212, 255 }, { 84, 124, 255 }, { 172, 92, 255 }, { 255, 92, 204 },
}
local function Swatches()
    local dl = imgui.GetWindowDrawList()
    local pos = imgui.GetCursorScreenPos()
    local w = imgui.GetContentRegionAvail().x
    local n = #SWATCH
    local d = math.min(P(30), (w - (n - 1) * P(4)) / n)
    local gap = (w - n * d) / (n - 1)
    local top = pos.y + P(4)
    for i, c in ipairs(SWATCH) do
        local x = pos.x + (i - 1) * (d + gap)
        imgui.SetCursorScreenPos(V2(x, top))
        imgui.InvisibleButton('##sw' .. i, V2(d, d))
        local hov = imgui.IsItemHovered()
        if Tap() then
            T.rainbow[0] = false
            T.accR[0], T.accG[0], T.accB[0] = c[1], c[2], c[3]
        end
        local sel = (not T.rainbow[0]) and T.accR[0] == c[1] and T.accG[0] == c[2] and T.accB[0] == c[3]
        local cx, cy = x + d / 2, top + d / 2
        dl:AddCircleFilled(V2(cx, cy), d / 2 - (hov and 0 or P(1.5)), RAW(c[1] / 255, c[2] / 255, c[3] / 255, 1), 28)
        if sel then dl:AddCircle(V2(cx, cy), d / 2 + P(3), U32(1, 1, 1, 1), 28, P(2)) end
    end
    imgui.SetCursorScreenPos(pos)
    imgui.Dummy(V2(w, d + P(10)))
end

local function ColorPreview()
    local dl = imgui.GetWindowDrawList()
    local pos = imgui.GetCursorScreenPos()
    local w = imgui.GetContentRegionAvail().x
    local h = P(46)
    glow(dl, pos.x, pos.y, pos.x + w, pos.y + h, P(12), P(8), 0.02)
    dl:AddRectFilled(pos, V2(pos.x + w, pos.y + h), AC(1), P(12))
    local txt = string.format('#%02X%02X%02X',
        math.floor(ACC.r * 255 + 0.5), math.floor(ACC.g * 255 + 0.5), math.floor(ACC.b * 255 + 0.5))
    local ts = imgui.CalcTextSize(txt)
    dl:AddText(V2(pos.x + (w - ts.x) / 2, pos.y + (h - ts.y) / 2), ONC(1), txt)
    imgui.Dummy(V2(w, h))
end

-- красивая кнопка закрытия (крестик вращается при наведении)
local function CloseButton(id, size)
    local dl = imgui.GetWindowDrawList()
    local pos = imgui.GetCursorScreenPos()
    imgui.InvisibleButton(id, V2(size, size))
    local clicked = imgui.IsItemClicked(0)
    local t = hoverAnim(id, imgui.IsItemHovered() or imgui.IsItemActive())
    local cx, cy = pos.x + size / 2, pos.y + size / 2

    if t > 0.01 then glow(dl, cx - size / 2, cy - size / 2, cx + size / 2, cy + size / 2, size / 2, P(8), 0.03 * t) end
    local base = G(0.13)
    dl:AddCircleFilled(V2(cx, cy), size / 2,
        RAW(lerp(base, 0.90, t), lerp(base, 0.15, t), lerp(base, 0.15, t), 1), 36)
    dl:AddCircle(V2(cx, cy), size / 2, AC(lerp(0.45, 0.0, t)), 36, P(1.5))

    local d = size * 0.19
    local ang = t * math.pi / 2
    local cr = lerp(G(0.95), 1, t)
    local cg = lerp(G(0.95), 1, t)
    local cb = lerp(G(0.95), 1, t)
    local col = RAW(cr, cg, cb, 1)
    for _, base_a in ipairs({ math.pi / 4, -math.pi / 4 }) do
        local a = base_a + ang
        local dx, dy = math.cos(a) * d, math.sin(a) * d
        dl:AddLine(V2(cx - dx, cy - dy), V2(cx + dx, cy + dy), col, P(2.4))
    end
    return clicked
end

local LOGFILE = (function()
    local ok, d = pcall(getWorkingDirectory)
    return (ok and d or '.') .. '/config/Mir chat log.txt'
end)()
local LOG, LOGVER = {}, 0
local SKIN_LIST = {
{0,'Carl "CJ" Johnson (Main Character)'},
{1,'The Truth'},
{2,'Maccer'},
{3,'Andre'},
{4,'Barry "Big Bear" Thorne [Thin]'},
{5,'Barry "Big Bear" Thorne [Big]'},
{6,'Emmet'},
{7,'Taxi Driver/Train Driver'},
{8,'Janitor'},
{9,'Normal Ped'},
{10,'Old Woman'},
{11,'Casino croupier'},
{12,'Rich Woman'},
{13,'Street Girl'},
{14,'Normal Ped'},
{15,'Mr.Whittaker (RS Haul Owner)'},
{16,'Airport Ground Worker'},
{17,'Businessman'},
{18,'Beach Visitor'},
{19,'DJ'},
{20,'Rich Guy (Madd Dogg\'s Manager)'},
{21,'Normal Ped'},
{22,'Normal Ped'},
{23,'BMXer'},
{24,'Madd Dogg Bodyguard'},
{25,'Madd Dogg Bodyguard'},
{26,'Backpacker'},
{27,'Construction Worker'},
{28,'Drug Dealer'},
{29,'Drug Dealer'},
{30,'Drug Dealer'},
{31,'Farm-Town inhabitant'},
{32,'Farm-Town inhabitant'},
{33,'Farm-Town inhabitant'},
{34,'Farm-Town inhabitant'},
{35,'Gardener'},
{36,'Golfer'},
{37,'Golfer'},
{38,'Normal Ped'},
{39,'Normal Ped'},
{40,'Normal Ped'},
{41,'Normal Ped'},
{42,'Jethro'},
{43,'Normal Ped'},
{44,'Normal Ped'},
{45,'Beach Visitor'},
{46,'Normal Ped'},
{47,'Normal Ped'},
{48,'Normal Ped'},
{49,'Snakehead (Da Nang)'},
{50,'Mechanic'},
{51,'Mountain Biker'},
{52,'Mountain Biker'},
{53,'Unknown'},
{54,'Normal Ped'},
{55,'Normal Ped'},
{56,'Normal Ped'},
{57,'Oriental Ped'},
{58,'Oriental Ped'},
{59,'Normal Ped'},
{60,'Normal Ped'},
{61,'Pilot'},
{62,'Colonel Fuhrberger'},
{63,'Prostitute'},
{64,'Prostitute'},
{65,'Kendl Johnson'},
{66,'Pool Player'},
{67,'Pool Player'},
{68,'Priest/Preacher'},
{69,'Normal Ped'},
{70,'Scientist'},
{71,'Security Guard'},
{72,'Hippy'},
{73,'Hippy'},
{74,'-'},
{75,'Prostitute'},
{76,'Stewardess'},
{77,'Homeless'},
{78,'Homeless'},
{79,'Homeless'},
{80,'Boxer'},
{81,'Boxer'},
{82,'Black Elvis'},
{83,'White Elvis'},
{84,'Blue Elvis'},
{85,'Prostitute'},
{86,'Ryder with robbery mask'},
{87,'Stripper'},
{88,'Normal Ped'},
{89,'Normal Ped'},
{90,'Jogger'},
{91,'Rich Woman'},
{92,'Rollerskater'},
{93,'Normal Ped'},
{94,'Normal Ped'},
{95,'Normal Ped, Works at Dillimore Gas Station'},
{96,'Jogger'},
{97,'Lifeguard'},
{98,'Normal Ped'},
{99,'Rollerskater'},
{100,'Biker'},
{101,'Normal Ped'},
{102,'Balla'},
{103,'Balla'},
{104,'Balla'},
{105,'Grove Street Families'},
{106,'Grove Street Families'},
{107,'Grove Street Families'},
{108,'Los Santos Vagos'},
{109,'Los Santos Vagos'},
{110,'Los Santos Vagos'},
{111,'The Russian Mafia'},
{112,'The Russian Mafia'},
{113,'The Russian Mafia'},
{114,'Varios Los Aztecas'},
{115,'Varios Los Aztecas'},
{116,'Varios Los Aztecas'},
{117,'Triad'},
{118,'Triad'},
{119,'Johhny Sindacco'},
{120,'Triad Boss'},
{121,'Da Nang Boy'},
{122,'Da Nang Boy'},
{123,'Da Nang Boy'},
{124,'The Mafia'},
{125,'The Mafia'},
{126,'The Mafia'},
{127,'The Mafia'},
{128,'Farm Inhabitant'},
{129,'Farm Inhabitant'},
{130,'Farm Inhabitant'},
{131,'Farm Inhabitant'},
{132,'Farm Inhabitant'},
{133,'Farm Inhabitant'},
{134,'Homeless'},
{135,'Homeless'},
{136,'Normal Ped'},
{137,'Homeless'},
{138,'Beach Visitor'},
{139,'Beach Visitor'},
{140,'Beach Visitor'},
{141,'Businesswoman'},
{142,'Taxi Driver'},
{143,'Crack Maker'},
{144,'Crack Maker'},
{145,'Crack Maker'},
{146,'Crack Maker'},
{147,'Businessman'},
{148,'Businesswoman'},
{149,'Big Smoke Armored'},
{150,'Businesswoman'},
{151,'Normal Ped'},
{152,'Prostitute'},
{153,'Construction Worker'},
{154,'Beach Visitor'},
{155,'Well Stacked Pizza Worker'},
{156,'Barber'},
{157,'Hillbilly'},
{158,'Farmer'},
{159,'Hillbilly'},
{160,'Hillbilly'},
{161,'Farmer'},
{162,'Hillbilly'},
{163,'Black Bouncer'},
{164,'White Bouncer'},
{165,'White MIB agent'},
{166,'Black MIB agent'},
{167,'Cluckin\' Bell Worker'},
{168,'Hotdog/Chilli Dog Vendor'},
{169,'Normal Ped'},
{170,'Normal Ped'},
{171,'Blackjack Dealer'},
{172,'Casino croupier'},
{173,'San Fierro Rifa'},
{174,'San Fierro Rifa'},
{175,'San Fierro Rifa'},
{176,'Barber'},
{177,'Barber'},
{178,'Whore'},
{179,'Ammunation Salesman'},
{180,'Tattoo Artist'},
{181,'Punk'},
{182,'Cab Driver'},
{183,'Normal Ped'},
{184,'Normal Ped'},
{185,'Normal Ped'},
{186,'Normal Ped'},
{187,'Businessman'},
{188,'Normal Ped'},
{189,'Valet'},
{190,'Barbara Schternvart'},
{191,'Helena Wankstein'},
{192,'Michelle Cannes'},
{193,'Katie Zhan'},
{194,'Millie Perkins'},
{195,'Denise Robinson'},
{196,'Farm-Town inhabitant'},
{197,'Hillbilly'},
{198,'Farm-Town inhabitant'},
{199,'Farm-Town inhabitant'},
{200,'Hillbilly'},
{201,'Farmer'},
{202,'Farmer'},
{203,'Karate Teacher'},
{204,'Karate Teacher'},
{205,'Burger Shot Cashier'},
{206,'Cab Driver'},
{207,'Prostitute'},
{208,'Su Xi Mu (Suzie)'},
{209,'Oriental Noodle stand vendor'},
{210,'Oriental Boating School Instructor'},
{211,'Clothes shop staff'},
{212,'Homeless'},
{213,'Weird old man'},
{214,'Waitress (Maria Latore)'},
{215,'Normal Ped'},
{216,'Normal Ped'},
{217,'Clothes shop staff'},
{218,'Normal Ped'},
{219,'Rich Woman'},
{220,'Cab Driver'},
{221,'Normal Ped'},
{222,'Normal Ped'},
{223,'Normal Ped'},
{224,'Normal Ped'},
{225,'Normal Ped'},
{226,'Normal Ped'},
{227,'Oriental Businessman'},
{228,'Oriental Ped'},
{229,'Oriental Ped'},
{230,'Homeless'},
{231,'Normal Ped'},
{232,'Normal Ped'},
{233,'Normal Ped'},
{234,'Cab Driver'},
{235,'Normal Ped'},
{236,'Normal Ped'},
{237,'Prostitute'},
{238,'Prostitute'},
{239,'Homeless'},
{240,'The D.A'},
{241,'Afro-American'},
{242,'Mexican'},
{243,'Prostitute'},
{244,'Stripper'},
{245,'Prostitute'},
{246,'Stripper'},
{247,'Biker'},
{248,'Biker'},
{249,'Pimp'},
{250,'Normal Ped'},
{251,'Lifeguard'},
{252,'Naked Valet'},
{253,'Bus Driver'},
{254,'Biker Drug Dealer'},
{255,'Chauffeur (Limo Driver)'},
{256,'Stripper'},
{257,'Stripper'},
{258,'Heckler'},
{259,'Heckler'},
{260,'Construction Worker'},
{261,'Cab driver'},
{262,'Cab driver'},
{263,'Normal Ped'},
{264,'Clown (Ice-cream Van Driver)'},
{265,'Officer Frank Tenpenny (Corrupt Cop)'},
{266,'Officer Eddie Pulaski (Corrupt Cop)'},
{267,'Officer Jimmy Hernandez'},
{268,'Dwaine/Dwayne'},
{269,'Melvin "Big Smoke" Harris (Mission)'},
{270,'Sean \'Sweet\' Johnson'},
{271,'Lance \'Ryder\' Wilson'},
{272,'Mafia Boss'},
{273,'T-Bone Mendez'},
{274,'Paramedic (Emergency Medical Technician)'},
{275,'Paramedic (Emergency Medical Technician)'},
{276,'Paramedic (Emergency Medical Technician)'},
{277,'Firefighter'},
{278,'Firefighter'},
{279,'Firefighter'},
{280,'Los Santos Police Officer'},
{281,'San Fierro Police Officer'},
{282,'Las Venturas Police Officer'},
{283,'County Sheriff'},
{284,'LSPD Motorbike Cop'},
{285,'S.W.A.T Special Forces'},
{286,'Federal Agent'},
{287,'San Andreas Army'},
{288,'Desert Sheriff'},
{289,'Zero'},
{290,'Ken Rosenberg'},
{291,'Kent Paul'},
{292,'Cesar Vialpando'},
{293,'Jeffery "OG Loc" Martin/Cross'},
{294,'Wu Zi Mu (Woozie)'},
{295,'Michael Toreno'},
{296,'Jizzy B.'},
{297,'Madd Dogg'},
{298,'Catalina'},
{299,'Claude Speed'},
{300,'Los Santos Police Officer (Without gun holster)'},
{301,'San Fierro Police Officer (Without gun holster)'},
{302,'Las Venturas Police Officer (Without gun holster)'},
{303,'Los Santos Police Officer (Without uniform)'},
{304,'Los Santos Police Officer (Without uniform)'},
{305,'Las Venturas Police Officer (Without uniform)'},
{306,'Los Santos Police Officer'},
{307,'San Fierro Police Officer'},
{308,'San Fierro Paramedic (Emergency Medical Technician)'},
{309,'Las Venturas Police Officer'},
{310,'Country Sheriff (Without hat)'},
{311,'Desert Sheriff (Without hat)'},
{312,'albert'},
{313,'amiran'},
{314,'bathory'},
{315,'brulov'},
{316,'creed'},
{317,'delorenzy'},
{318,'edvardbil'},
{319,'lj'},
{329,'evaelfie'},
{332,'feduk'},
{340,'kovalevsky'},
{382,'litvin'},
{383,'maras'},
{398,'morgershtern'},
{399,'nurmagamedov'},
{795,'oxymiron'},
{796,'dante'},
{797,'ravyazan'},
{798,'romeru'},
{799,'sammason'},
{907,'shurigina'},
{908,'valik'},
{999,'umpa_lump'},
{1206,'basta'},
{1326,'byzova'},
{1573,'dzyuba'},
{1699,'urgant'},
{2883,'khovanksy'},
{2884,'lukashenko'},
{3136,'maddyson'},
{3137,'noize'},
{3138,'technic'},
{3139,'restorator'},
{3140,'richi'},
{3141,'sashagrey'},
{3142,'yurydud'},
{3143,'snowman'},
{3144,'elf'},
{3145,'farmernewyear'},
{3146,'dedmoroz'},
{3147,'yoda'},
{3148,'leshiy'},
{3149,'newshuba'},
{3150,'deer'},
{3151,'penguin'},
{3152,'snegurochka'},
{3153,'footba'},
{3154,'elfa'},
{3159,'gentelman1'},
{3160,'gentelman2'},
{3161,'gentelman3'},
{3162,'gentelman4'},
{3163,'gentelman5'},
{3164,'gentelman6'},
{3165,'minecraft1'},
{3166,'minecraft2'},
{3176,'minecraft3'},
{3177,'minecraft4'},
{3179,'minecraft5'},
{3180,'minecraft6'},
{3181,'minecraft7'},
{3182,'minecraft8'},
{3183,'minecraft9'},
{3184,'minecraft10'},
{3185,'navalny'},
{3186,'putin'},
{3188,'ironman'},
{3189,'spiderman'},
{3190,'venom'},
{3191,'captainamerica'},
{3192,'batman'},
{3225,'anonimys'},
{3226,'rabbit1'},
{3227,'rabbit2'},
{3228,'rabbit3'},
{3229,'rabbit4'},
{3230,'rabbit5'},
{3231,'rabbitfarmer'},
{3349,'alpachino'},
{3416,'bradpitt'},
{3429,'dikaprio'},
{3610,'disel'},
{3611,'kianu'},
{3784,'imask'},
{3870,'robertjr'},
{3871,'shwarz'},
{3883,'statham'},
{3889,'tarantino'},
{4549,'stalone'},
{4763,'murphy'},
{4764,'hardy'},
{4765,'tyson'},
{4766,'kanye'},
{4767,'mcgregor'},
{4768,'travolta'},
{4769,'cluni'},
{4770,'markcyker'},
{4771,'dwaynej'},
{4772,'kage'},
{4773,'will'},
{4804,'aaron'},
{4805,'cooper'},
{5085,'defo'},
{5090,'evans'},
{5091,'ryan'},
{5092,'hannem'},
{5093,'hbirth1'},
{5094,'hbirth2'},
{5095,'hbirth3'},
{5096,'hbirth4'},
{5097,'hbirth5'},
{5098,'hbirth6'},
{5099,'hbirth7'},
{5100,'hbirth8'},
{5101,'hbirth9'},
{5102,'hbirth10'},
{5103,'jackiechan'},
{5104,'maccon'},
{5376,'matt'},
{5377,'morgan'},
{5378,'tatum'},
{5379,'polyok'},
{5380,'wood'},
{5381,'beth'},
{5382,'big_g'},
{5383,'gnom'},
{5384,'goblin1'},
{5385,'goblin2'},
{5386,'goblin3'},
{5387,'grinchjim'},
{5388,'lmike'},
{5389,'morty'},
{5683,'olen'},
{5684,'osel'},
{5685,'rick'},
{5686,'rofls'},
{5687,'yeti'},
{5688,'fiona'},
{5689,'fionah'},
{5690,'shrek'},
{5691,'shrek2'},
{5692,'wolf'},
{6014,'hall0'},
{6015,'hall1'},
{6016,'hall2'},
{6017,'hall4'},
{6018,'hall5'},
{6019,'hall6'},
{6020,'hall7'},
{6021,'hasbik'},
{6022,'hellmem'},
{6023,'pubgmaskgirl'},
{6024,'pubgmaskman'},
{6025,'pubggirl1'},
{6026,'pubgman1'},
{6027,'pubggirl2'},
{6028,'pubgman2'},
{6029,'pubggirl3'},
{6030,'pubgman3'},
{6031,'pubggirl4'},
{6032,'pubgman4'},
{6545,'adidas'},
{6546,'farquad'},
{6547,'gwendolyn'},
{6548,'jizzly'},
{6549,'marat'},
{6550,'palto'},
{6551,'ptich'},
{6552,'summer'},
{6557,'aura'},
{6558,'aza'},
{6559,'crack1'},
{6560,'fishscale'},
{6561,'gojo'},
{6562,'midas'},
{6563,'nalog1'},
{6583,'nalog2'},
{6584,'ninja'},
{6585,'yen'},
{6586,'twinl'},
{6587,'twinr'},
{6588,'taker'},
{6589,'jrc'},
{6590,'peely'},
{6591,'huntert'},
{6592,'hogan'},
{6593,'hbk'},
{6594,'egg'},
{6595,'cena'},
{6596,'stonegolem'},
{6597,'wildcat'},
{6598,'cat1'},
{6599,'braun'},
{6627,'irina'},
{6661,'ak'},
{6662,'bandit'},
{6663,'degtyarev'},
{6664,'dolgovec'},
{6665,'karl'},
{6666,'me4eniy'},
{6667,'natasha'},
{6668,'penek'},
{6669,'sidorovich'},
{6670,'vova'},
{6671,'wanderer'},
{6672,'wolter'},
{6689,'girl1'},
{6690,'girl2'},
{6691,'men1'},
{6692,'dmen4'},
{6701,'billie'},
{6703,'belleniko'},
{6704,'dit'},
{6705,'dvoreckov'},
{6706,'ernesto'},
{6707,'gorshok'},
{6708,'noro'},
{6791,'zomfat'},
{6792,'zomskin'},
{6793,'davydj'},
{6794,'pir3'},
{6795,'pirat'},
{6796,'pirm1'},
{6797,'pirw2'},
{6798,'fpirat'},
{9202,'5ka'},
{11786,'shock'},
{11787,'sclaus'},
{11789,'barrel'},
{11790,'lock'},
{11791,'jackx'},
{11792,'jackskel'},
{11793,'sally'},
{11795,'antim'},
{11796,'facevoid'},
{11797,'phantoml'},
{11798,'pudge'},
{11799,'ringm'},
{11801,'voker'},
{11802,'wking'},
{11803,'amf'},
{11804,'lanaya'},
{11805,'marci'},
{11807,'rilai'},
{11808,'joke'},
{11809,'supa'},
{11812,'traxa'},
{11813,'mummy_boi'},
{11814,'ogboogie'},
{12032,'devilboss'},
{12033,'icec'},
{12034,'biggi'},
{12035,'tupak'},
{12036,'locd'},
{12037,'arocky'},
{12038,'corleone'},
{12039,'alt'},
{12040,'lfam1'},
{12041,'llsv1'},
{12042,'xtentacion'},
{12043,'treho'},
{12044,'snoop'},
{12045,'diedn'},
{12046,'yoland'},
{12047,'skuf'},
{12061,'behemoth'},
{12062,'cursekid'},
{12063,'xmsmayor'},
{12151,'invisible'},
{12152,'hika1'},
{12153,'hika2'},
{12154,'hika3'},
{12155,'hika4'},
{12156,'hika5'},
{12157,'babka1'},
{12158,'babka2'},
{12159,'depo'},
{12160,'diva'},
{12161,'dtrump'},
{12162,'face'},
{12163,'grib1'},
{12164,'grib2'},
{12165,'molly'},
{12166,'nagiev'},
{12167,'nvasil'},
{12168,'rabitgrl'},
{12169,'slavik'},
{12171,'harly'},
{12176,'rab_m'},
{12177,'rab_w'},
{12178,'farmer'},
{12182,'pharaoh'},
{12183,'mercy'},
{12184,'fox2'},
{12185,'judy2'},
{12186,'schlg'},
{12187,'schlm'},
{12188,'larin'},
{12392,'armyponch'},
{12395,'ghrid'},
{12415,'10pencivil'},
{12491,'zomb1_n'},
{12492,'zombie2_n'},
{12493,'zomb3_n'},
{12494,'skeleton'},
{12592,'b_lich'},
{12593,'b_lich1'},
{12594,'dcfranz'},
{12595,'drak'},
{12596,'frank1'},
{12597,'helsing'},
{12608,'lich'},
{12609,'rooster'},
{12610,'jan'},
{12612,'sabrina2'},
{12617,'vdra'},
{12629,'ellie'},
{12641,'toph'},
{12642,'aang'},
{12643,'zuko'},
{12644,'pubgf'},
{12645,'pubgm1'},
{12646,'pubg1'},
{12647,'pubg2'},
{12648,'asuka'},
{12649,'rei'},
{12650,'mell'},
{12654,'baiden'},
{12655,'bumbl'},
{12656,'demorog'},
{12658,'optimus'},
{12660,'acuddle'},
{12661,'vi'},
{12662,'castor'},
{12663,'crazy8'},
{12664,'doggo'},
{12665,'fallenl'},
{12667,'sanboy'},
{12672,'bunny1'},
{12673,'bunny2'},
{12674,'bunny3'},
{12675,'shagg'},
{12676,'alien'},
{12700,'chistmasbomj1'},
{12701,'chistmasbomj2'},
{12702,'chistmasbomj3'},
{12703,'chistmasbomj4'},
{12704,'chistmasbomj5'},
{12705,'elf2021'},
{12706,'grinch'},
{12707,'littlebill'},
{12708,'santa'},
{12709,'yearroliki1'},
{12710,'yearroliki2'},
{12711,'yearroliki3'},
{12712,'yearroliki4'},
{12778,'yoda1'},
{12779,'warh1'},
{12780,'stray'},
{12781,'spcfarm'},
{12782,'grut'},
{12784,'doom'},
{12785,'cosmom'},
{12786,'chik'},
{12787,'bomjr'},
{12788,'bomjb'},
{13945,'footbal'},
{13946,'minefarmer'},
{13947,'villager'},
{13956,'minechiken'},
{13979,'tramp1'},
{13980,'tramp2'},
{14003,'minechiken_big'},
{14006,'fox1'},
{14008,'judy1'},
{14009,'dora2'},
{14043,'bob1'},
{14048,'rollerm'},
{14049,'rollerw'},
{14050,'prcatg'},
{14051,'pkiberg'},
{14052,'pscm'},
{14053,'ppanam'},
{14054,'ppunk'},
{14055,'pbiker'},
{14056,'photdog'},
{14057,'pcat'},
{14082,'ksam'},
{14083,'panm'},
{14084,'rbcat'},
{14085,'robo_chicken'},
{14088,'moroz'},
{14089,'moroz2'},
{14114,'chicken2'},
{14146,'quincy'},
{14147,'seagers'},
{14148,'eb'},
{14169,'artur'},
{14192,'bbt'},
{14266,'a4'},
{14267,'acad'},
{14268,'beast'},
{14269,'brian'},
{14270,'dvid'},
{14271,'fil'},
{14272,'ghoul'},
{14273,'homeland'},
{14274,'kosmos'},
{14275,'malfoy'},
{14276,'marshm'},
{14277,'meow'},
{14278,'pchela'},
{14279,'roger'},
{14280,'lucif'},
{14337,'belik'},
{14339,'hran'},
{14341,'bratok'},
{14342,'conor'},
{14343,'daeneris'},
{14344,'eilish'},
{14345,'graims'},
{14346,'joel'},
{14347,'kratos'},
{14348,'levi'},
{14349,'merser'},
{14350,'mia'},
{14351,'reizor'},
{14352,'silver'},
{14353,'snoy'},
{14354,'tris'},
{14358,'kolabaka'},
{14925,'canae'},
{14926,'stark'},
{14938,'kalkin'},
{14939,'roblox'},
{14986,'friren'},
{14987,'itpedia'},
{15010,'bestavto'},
{15011,'bestavtobar'},
{15012,'bestclad'},
{15013,'bestcliver'},
{15014,'bestcr'},
{15015,'bestshaxt'},
{15016,'mortaljax'},
{15017,'mortalliu'},
{15018,'mortalnoob'},
{15019,'mortalsony'},
{15020,'shut'},
{15021,'mortaltsung'},
{15022,'mortraiden'},
{15023,'mortscorpion'},
{15024,'mortsub'},
{15065,'new1'},
{15066,'new2'},
{15067,'new3'},
{15068,'new4'},
{15069,'new5'},
{15070,'new6'},
{15071,'new7'},
{15072,'new8'},
{15073,'new9'},
{15074,'new10'},
{15075,'new11'},
{15076,'new12'},
{15077,'new13'},
{15078,'new14'},
{15079,'new15'},
{15080,'new16'},
{15081,'new17'},
{15082,'new18'},
{15083,'new19'},
{15084,'new20'},
{15086,'03bestcar'},
{15087,'03besthouse'},
{15088,'03bomj'},
{15089,'03bomj1'},
{15090,'03bomj2'},
{15091,'03brayant'},
{15092,'03chiken'},
{15093,'03cristiano'},
{15094,'03messi'},
{15095,'03ovechkin'},
{15096,'03usyk'},
{15097,'03zelenskiy'},
{15128,'fol1'},
{15129,'fol2'},
{15130,'fol3'},
{15131,'glent2'},
{15164,'armybomj1'},
{15165,'armybomj2'},
{15166,'bsty'},
{15176,'sahur'},
{15177,'shpio'},
{15179,'golem'},
{15194,'boatkid'},
{15224,'tron'},
{15225,'wolf1'},
{15226,'raragorn'},
{15227,'gats'},
{15228,'gimli'},
{15229,'galadriel'},
{15230,'frodo'},
{15231,'gandelf'},
{15232,'golum'},
{15267,'frank_big'},
{15268,'lich_big'},
{15269,'zomb1_n1'},
{15288,'zomb2_n2'},
{15289,'zomb3_n3'},
{15290,'ghos'},
{15296,'family1'},
{15297,'family2'},
{15298,'family3'},
{15299,'family4'},
{15300,'family5'},
{15301,'family6'},
{15302,'family7'},
{15303,'family8'},
{15304,'family9'},
{15305,'family10'},
{15306,'family11'},
{15307,'family12'},
{15308,'family13'},
{15309,'family14'},
{15310,'family15'},
{15311,'family16'},
{15312,'family17'},
{15313,'family18'},
{15314,'family19'},
{15315,'family20'},
{15316,'family21'},
{15317,'family22'},
{15318,'family23'},
{15319,'family24'},
{15320,'family25'},
{15321,'family26'},
{15322,'family27'},
{15323,'family28'},
{15324,'family29'},
{15325,'family30'},
{15400,'arab1'},
{15401,'arab2'},
{15402,'bomj1'},
{15403,'bomj3'},
{15404,'maneken'},
{15405,'bukin'},
{15406,'fenni'},
{15408,'frankg'},
{15409,'ghost'},
{15410,'iza'},
{15411,'katsu'},
{15412,'maysonv'},
{15413,'michael'},
{15440,'velma'},
{15441,'pcon'},
{15448,'hika'},
{15450,'phil'},
{15458,'vc_skin1'},
{15459,'vc_skin2'},
{15460,'vc_skin3'},
{15461,'vc_skin4'},
{15462,'vc_skin5'},
{15463,'vc_skin6'},
{15464,'vc_skin7'},
{15465,'vc_skin8'},
{15466,'vc_skin9'},
{15467,'vc_skin10'},
{15468,'vc_skin11'},
{15469,'vc_skin12'},
{15470,'vc_skin13'},
{15471,'vc_skin14'},
{15472,'vc_skin15'},
{15473,'vc_skin16'},
{15474,'vc_skin17'},
{15475,'vc_skin18'},
{15476,'vc_skin19'},
{15477,'vc_skin20'},
{15478,'vc_skin21'},
{15479,'vc_skin22'},
{15480,'vc_skin23'},
{15481,'vc_skin24'},
{15482,'vc_skin25'},
{15483,'vc_skin26'},
{15484,'vc_skin27'},
{15516,'carti'},
{15530,'ant'},
{15531,'antxs'},
{15532,'mary'},
{15533,'prbos'},
{15534,'prish'},
{15535,'raiden'},
{15536,'sidni'},
{15537,'spcfarmxs'},
{15538,'ham2'},
{15557,'vercetti'},
{15567,'zomb_big'},
{15570,'scooby'},
{15571,'scooby_hallowen'},
{15573,'werewolf'},
{15577,'antoha'},
{15578,'aqua'},
{15579,'beetlej'},
{15588,'csgo'},
{15589,'csparrow'},
{15593,'denji'},
{15596,'dpool'},
{15598,'dvoreck'},
{15600,'edit'},
{15601,'fester'},
{15603,'ghost_bomj'},
{15604,'ghost_cj'},
{15606,'ghost_ponchik'},
{15611,'ghost_stantz'},
{15612,'hyde'},
{15613,'jewish'},
{15614,'kolyan'},
{15615,'krug'},
{15616,'kult'},
{15617,'larisa'},
{15624,'arab3'},
{15625,'lego'},
{15633,'polyok2'},
{15644,'leps'},
{15645,'kirkov'},
{15696,'bomj001'},
{15697,'bomj002'},
{15698,'bomj003'},
{15699,'bomj004'},
{15700,'bomjclassic1'},
{15701,'bomjclassic2'},
{15702,'bomjclassic3'},
{15703,'bomjclassic4'},
{15704,'bomjclassic5'},
{15705,'bomjg001'},
{15706,'bomjg002'},
{15707,'leshen'},
{15709,'makima'},
{15712,'nsparrow'},
{15714,'durov'},
{15715,'hitok'},
{15716,'judge'},
{15717,'power'},
{15718,'sndk'},
{15719,'sherf'},
{15726,'slender2'},
{15727,'bigbomj1'},
{15728,'bigbomj2'},
{15729,'bigbomj3'},
{15732,'swensd'},
{15774,'sfpd1'},
{15775,'verka'},
{15789,'bojack'},
{15790,'viking'},
{15803,'bomjy'},
{15804,'spacehik'},
{15823,'antxl'},
{15825,'spedf'},
{15826,'spedm'},
{15827,'man_wolf'},
{15828,'bladev'},
{15867,'vovan'},
{15868,'wolvr'},
{15884,'zombie_man3'},
{15890,'blog1'},
{15891,'blog2'},
{15892,'blog3'},
{15893,'blog4'},
{15894,'blog5'},
{15895,'pcon2'},
{15896,'blog7'},
{15899,'tidex1'},
{15900,'tidex2'},
{15901,'tidex3'},
{15945,'bomjg1'},
{15947,'bomjg2'},
{15948,'bomjm'},
{15949,'bomz3'},
{15958,'reedus'},
{15966,'hnina'},
{15967,'hzombie1'},
{15968,'hzombie2'},
{15969,'hzombie3'},
{15970,'hzombie4'},
{15971,'hzombie5'},
{15972,'hzombie6'},
{15973,'hzombie7'},
{15974,'hzombie8'},
{15975,'hzombie9'},
{15976,'ork'},
{15977,'szombie1'},
{15978,'szombie2'},
{15979,'szombie3'},
{15980,'szombie5'},
{15981,'szombie4'},
{15982,'szombie6'},
{15983,'szombie7'},
{15984,'szombie8'},
{15985,'bigfoot_man'},
{15986,'clown_man'},
{15987,'fredi_street'},
{15988,'jayson_friday13'},
{15989,'mymia_man'},
{15990,'zombie_girl1'},
{15991,'zombie_man1'},
{15992,'zombie_man2'},
{15994,'zombie_man4'},
{16810,'bomz4'},
{16815,'gimpy_diffuse'},
{16816,'leatherface'},
{16817,'nlo'},
{16818,'piggsy'},
{16819,'yasher'},
{16820,'zombieevil'},
{16830,'snowman3'},
{16831,'cyberpunk_lucy'},
{16832,'cyberpunk_rebecca'},
{16833,'cyberpunk_david'},
{16834,'dora'},
{16835,'maybe_baby'},
{16836,'witch'},
{16837,'addams'},
{16838,'harly_queen'},
{16839,'scream'},
{16840,'alice_madness'},
{16841,'geralt_witcher'},
{16843,'trevor'},
{16844,'dark_elf'},
{16845,'leshiy_new'},
{16846,'light_elf'},
{16847,'chiken'},
{16848,'snowman1'},
{16849,'snowman2'},
{16850,'ciri_witcher'},
{16851,'albert_mironov'},
{16852,'valentin'},
{16853,'dsher'},
{16854,'usatiycop'},
{16891,'mayson'},
{16901,'jinx'},
{16902,'ortega'},
{16905,'svat'},
{16960,'admingirl1'},
{16961,'admingirl2'},
{16962,'adminman1'},
{16963,'adminman3'},
{16965,'adminman4'},
{16966,'adminman5'},
{16967,'adminman6'},
{16968,'adminman7'},
{16997,'security1'},
{16998,'security2'},
{16999,'security3'},
{17475,'security4'},
{17476,'willi'},
{17477,'tan'},
{17478,'snape'},
{17479,'ron'},
{17480,'luci'},
{17481,'hermiona'},
{17482,'harry'},
{17483,'hagrid'},
{17484,'draco'},
{18131,'aragon'},
{18132,'cbale'},
{18133,'gandalf'},
{18134,'gordon'},
{18135,'hansel'},
{18136,'johny'},
{18137,'kupidon'},
{18138,'legolas'},
{18139,'rblue'},
{18140,'rred'},
{18141,'rwhite'},
{18142,'stalin'},
{18143,'stiller'},
{18144,'tylerd'},
{18145,'beliy'},
{18146,'bodrov'},
{18147,'letov'},
{18148,'mavrodi'},
{18149,'bomj2'},
{18150,'drockw'},
{18151,'tsoy'},
{18162,'mehanika69'},
{18163,'kenobi'},
{18168,'vader'}
}
local SKIN_APPLY, SKIN_RESET, SKIN_ID, SKIN_ORIG, SKIN_CHECK = false, false, nil, nil, 0
function SKIN_SET(id)
    local ok, res, myId = pcall(sampGetPlayerIdByCharHandle, PLAYER_PED)
    if not ok or not res then return end
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt32(bs, myId)
    raknetBitStreamWriteInt32(bs, id)
    raknetEmulRpcReceiveBitStream(153, bs)
    raknetDeleteBitStream(bs)
end
pcall(function()
    local f = io.open(LOGFILE, 'r')
    if f then for l in f:lines() do LOG[#LOG + 1] = l end f:close() end
    while #LOG > 300 do table.remove(LOG, 1) end
end)
local function logAdd(line)
    LOG[#LOG + 1] = line
    if #LOG > 500 then table.remove(LOG, 1) end
    LOGVER = LOGVER + 1
    pcall(function()
        local f = io.open(LOGFILE, 'a')
        if f then f:write(line, '\n') f:close() end
    end)
end
local function logRaw(prefix, text)
    local ok, t = pcall(u8, tostring(text))
    if not ok then t = tostring(text) end
    t = t:gsub('{%x%x%x%x%x%x}', '')
    logAdd(os.date('[%H:%M:%S] ') .. prefix .. t)
end
local airSpeed = 0.3
local okSE, sampev = pcall(require, 'samp.events')
if okSE and sampev then
    function sampev.onServerMessage(color, text) logRaw('', text) end
    function sampev.onSendChat(message) logRaw('> ', message) end
    function sampev.onSendCommand(cmd) logRaw('> ', cmd) end
    function sampev.onSetWeather(w) if T.blockWeather[0] or T.twOn[0] then return false end end
    function sampev.onSetPlayerTime(h, m) if T.twOn[0] then return false end end
    function sampev.onSetWorldTime(h) if T.twOn[0] then return false end end
    -- Adapted from MonetLoaderOSS AirBrake example (GPL-3.0).
    -- Keep outgoing sync movement aligned with the mobile AirBrake movement.
    function sampev.onSendPlayerSync(data)
        if T.airbrake[0] and data and data.moveSpeed then
            local heading = math.rad(getCharHeading(PLAYER_PED))
            local amount = math.min(airSpeed, 1.0)
            data.moveSpeed.x = math.sin(-heading) * amount
            data.moveSpeed.y = math.cos(-heading) * amount
        end
    end
    function sampev.onSendVehicleSync(data)
        if T.airbrake[0] and data and data.moveSpeed then
            local heading = math.rad(getCharHeading(PLAYER_PED))
            local amount = math.min(airSpeed, 2.0)
            data.moveSpeed.x = math.sin(-heading) * amount
            data.moveSpeed.y = math.cos(-heading) * amount
        end
    end
end

local LOGBUF = imgui.new.char[65536]()
local logShown = -1
local function logText()
    local parts, size = {}, 0
    for i = #LOG, 1, -1 do
        size = size + #LOG[i] + 1
        if size > 64000 then break end
        table.insert(parts, 1, LOG[i])
    end
    return table.concat(parts, '\n')
end
local function LogBody()
    if imgui.IsMouseClicked(0) then SCROLLED = false end
    imgui.BeginChild('##logl', V2(imgui.GetContentRegionAvail().x, P(420)), false)
    imgui.SetWindowFontScale(WS)
    local bw = imgui.CalcTextSize('Копировать').x + P(24)
    if #LOG == 0 then imgui.TextDisabled('Лог пуст') end
    for i = #LOG, math.max(1, #LOG - 150), -1 do
        local line = LOG[i]
        if imgui.Button('Копировать##lg' .. i, V2(bw, 0)) and not SCROLLED then
            imgui.SetClipboardText(line)
            msg('Сообщение скопировано')
        end
        imgui.SameLine(0, P(10))
        imgui.TextWrapped(line)
        imgui.Dummy(V2(1, P(2)))
    end
    if imgui.IsWindowHovered() and imgui.IsMouseDragging(0, 8) then
        SCROLLED = true
        imgui.SetScrollY(imgui.GetScrollY() - imgui.GetIO().MouseDelta.y)
    end
    imgui.EndChild()
    local w = (imgui.GetContentRegionAvail().x - P(8)) / 2
    if imgui.Button('Скопировать всё', V2(w, 0)) then
        imgui.SetClipboardText(logText())
        msg('Лог скопирован')
    end
    imgui.SameLine(0, P(8))
    if imgui.Button('Очистить', V2(w, 0)) then
        LOG = {}
        LOGVER = LOGVER + 1
        pcall(function() local f = io.open(LOGFILE, 'w') if f then f:close() end end)
    end
end


local widgetsOK, widgets = pcall(require, 'widgets')
local airWasInCar, airLastCar = false, nil
local airLastEnabled = false
local flySpeed = 0
local flyWasOn = false
local flyLastCar = nil
local playerFont = nil
pcall(function() playerFont = renderCreateFont('Arial', 18, 1 + 4) end)
local gtaESP = nil
pcall(function()
    ffi.cdef[[
        typedef struct OsirisRwV3d { float x; float y; float z; } OsirisRwV3d;
        void _ZN4CPed15GetBonePositionER5RwV3djb(void* thiz, OsirisRwV3d* posn, unsigned int bone, bool calledFromCam);
    ]]
    gtaESP = ffi.load('GTASA')
end)
local function getBonePosition(char, bone)
    assert(gtaESP and type(getCharPointer) == 'function', 'bone API unavailable')
    local pedptr = ffi.cast('void*', getCharPointer(char))
    local pos = ffi.new('OsirisRwV3d[1]')
    gtaESP._ZN4CPed15GetBonePositionER5RwV3djb(pedptr, pos, bone, false)
    return pos[0].x, pos[0].y, pos[0].z
end

local function rgbU32(key, alpha)
    local r = (T[key .. 'R'] and T[key .. 'R'][0] or 255) / 255
    local g = (T[key .. 'G'] and T[key .. 'G'][0] or 255) / 255
    local b = (T[key .. 'B'] and T[key .. 'B'][0] or 255) / 255
    return imgui.ColorConvertFloat4ToU32(V4(r, g, b, alpha or 1))
end

local function safeCall(fn, ...)
    if type(fn) ~= 'function' then return false end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then return false end
    return true, a, b, c, d
end

local function getScreenPoint(x, y, z)
    if type(convert3DCoordsToScreenEx) == 'function' then
        local ok, visible, sx, sy = pcall(convert3DCoordsToScreenEx, x, y, z)
        if ok then
            if type(visible) == 'boolean' then return visible, sx, sy end
            if type(visible) == 'number' and type(sx) == 'number' then return true, visible, sx end
        end
    end
    if type(convert3DCoordsToScreen) == 'function' then
        local ok, sx, sy = pcall(convert3DCoordsToScreen, x, y, z)
        if ok and type(sx) == 'number' and type(sy) == 'number' then return true, sx, sy end
    end
    return false, 0, 0
end

local function worldPosForChar(char)
    if type(getOffsetFromCharInWorldCoords) == 'function' then
        local ok, x, y, z = pcall(getOffsetFromCharInWorldCoords, char, 0, 0, 0)
        if ok then return x, y, z end
    end
    if type(getCharCoordinates) == 'function' then
        local ok, x, y, z = pcall(getCharCoordinates, char)
        if ok then return x, y, z end
    end
end

local function drawPlayerESP()
    if not (T.espPBox[0] or T.espPNick[0] or T.espPDist[0] or T.espPTrace[0] or T.espPSkel[0]) then return end
    if type(getAllChars) ~= 'function' or type(sampGetPlayerIdByCharHandle) ~= 'function'
        or type(convert3DCoordsToScreenEx) ~= 'function' then return end

    local okDraw, draw = pcall(function() return imgui.GetBackgroundDrawList() end)
    if not okDraw or not draw then return end
    local okRes, sw, sh = pcall(getScreenResolution)
    if not okRes or type(sw) ~= 'number' or type(sh) ~= 'number' then return end

    local px, py, pz = 0, 0, 0
    pcall(function() px, py, pz = getCharCoordinates(PLAYER_PED) end)

    -- Skeleton links use known GTA:SA ped bone IDs; failure to read a bone
    -- only disables that segment and does not break the other ESP elements.
    local bonePairs = {
        {3, 4}, {4, 5}, {3, 21}, {21, 22}, {22, 23},
        {3, 31}, {31, 32}, {32, 33}, {3, 41}, {41, 42},
        {42, 43}, {3, 51}, {51, 52}, {52, 53}
    }

    local okChars, chars = pcall(getAllChars)
    if not okChars or type(chars) ~= 'table' then return end

    for _, char in ipairs(chars) do
        pcall(function()
            if char == PLAYER_PED then return end
            if type(doesCharExist) == 'function' and not doesCharExist(char) then return end
            if type(isCharOnScreen) == 'function' and not isCharOnScreen(char) then return end

            local okId, found, id = pcall(sampGetPlayerIdByCharHandle, char)
            if not okId or not found or id == nil then return end

            local x, y, z
            if type(getOffsetFromCharInWorldCoords) == 'function' then
                local okPos
                okPos, x, y, z = pcall(getOffsetFromCharInWorldCoords, char, 0.0, 0.0, 0.0)
                if not okPos then x, y, z = nil, nil, nil end
            end
            if type(x) ~= 'number' or type(y) ~= 'number' or type(z) ~= 'number' then
                if type(getCharCoordinates) ~= 'function' then return end
                local okPos
                okPos, x, y, z = pcall(getCharCoordinates, char)
                if not okPos then return end
            end
            if type(x) ~= 'number' or type(y) ~= 'number' or type(z) ~= 'number' then return end

            local okHead, hv, hx, hy = pcall(convert3DCoordsToScreenEx, x, y, z + 1.0)
            local okFoot, fv, fx, fy = pcall(convert3DCoordsToScreenEx, x, y, z - 1.0)
            if not okHead or not okFoot or not hv or not fv
                or type(hx) ~= 'number' or type(hy) ~= 'number'
                or type(fx) ~= 'number' or type(fy) ~= 'number' then return end

            local top, bottom = math.min(hy, fy), math.max(hy, fy)
            local height = math.max(5, bottom - top)
            local width = math.max(3, height * 0.25)
            local left, right = hx - width, hx + width
            local boxCol, nickCol = rgbU32('espPBox'), rgbU32('espPNick')
            local hp, armour = 0, 0
            if type(sampGetPlayerHealth) == 'function' then
                pcall(function() hp = tonumber(sampGetPlayerHealth(id)) or 0 end)
            end
            if type(sampGetPlayerArmor) == 'function' then
                pcall(function() armour = tonumber(sampGetPlayerArmor(id)) or 0 end)
            end
            hp = math.max(0, math.min(100, hp))
            armour = math.max(0, math.min(100, armour))

            if T.espPBox[0] then
                if type(renderDrawBoxWithBorder) ~= 'function' then
                    draw:AddRect(V2(left, top), V2(right, bottom), boxCol, 0, 0, 1.5)
                end
                draw:AddRectFilled(V2(left - 5, top), V2(left - 2, bottom), imgui.ColorConvertFloat4ToU32(V4(0.12, 0.12, 0.12, 0.9)))
                if hp > 0 then
                    draw:AddRectFilled(V2(left - 5, bottom - height * hp / 100), V2(left - 2, bottom), imgui.ColorConvertFloat4ToU32(V4(0.2, 0.9, 0.25, 1)))
                end
                draw:AddRectFilled(V2(right + 2, top), V2(right + 5, bottom), imgui.ColorConvertFloat4ToU32(V4(0.12, 0.12, 0.12, 0.9)))
                if armour > 0 then
                    draw:AddRectFilled(V2(right + 2, bottom - height * armour / 100), V2(right + 5, bottom), imgui.ColorConvertFloat4ToU32(V4(0.25, 0.65, 1, 1)))
                end
            end


            if T.espPSkel[0] and type(getBonePosition) == 'function' then
                for _, pair in ipairs(bonePairs) do
                    local ok1, bx1, by1, bz1 = pcall(getBonePosition, char, pair[1])
                    local ok2, bx2, by2, bz2 = pcall(getBonePosition, char, pair[2])
                    if ok1 and ok2 and type(bx1) == 'number' and type(by1) == 'number' and type(bz1) == 'number'
                        and type(bx2) == 'number' and type(by2) == 'number' and type(bz2) == 'number' then
                        local a1, v1, sx1, sy1 = pcall(convert3DCoordsToScreenEx, bx1, by1, bz1)
                        local a2, v2, sx2, sy2 = pcall(convert3DCoordsToScreenEx, bx2, by2, bz2)
                        if a1 and a2 and v1 and v2 and type(sx1) == 'number' and type(sy1) == 'number'
                            and type(sx2) == 'number' and type(sy2) == 'number' then
                            draw:AddLine(V2(sx1, sy1), V2(sx2, sy2), rgbU32('espPSkel'), 1.4)
                        end
                    end
                end
            end
        end)
    end
end

-- Draw ESP in the overlay frame, not in the slower gameplay tick.
imgui.OnFrame(function()
    return not (type(isGamePaused) == 'function' and isGamePaused())
end, function()
    pcall(drawPlayerESP)
end)

local function setPlayerCarCoordinatesFixed(x, y, z)
    local ox, oy, oz = getCharCoordinates(PLAYER_PED)
    setCharCoordinates(PLAYER_PED, ox, oy, oz)
    local nx, ny, nz = getCharCoordinates(PLAYER_PED)
    setCharCoordinates(PLAYER_PED, x - (nx - ox), y - (ny - oy), z - (nz - oz))
end

local function getMoveSpeed(heading, amount)
    return math.sin(-math.rad(heading)) * amount, math.cos(-math.rad(heading)) * amount
end

-- AirBrake movement adapted from MonetLoaderOSS/example/AirBrake.lua (GPL-3.0).
-- Original reference: https://github.com/xefinity/MonetLoaderOSS/blob/main/example/AirBrake.lua
local function restoreAirBrake()
    pcall(function()
        if airLastCar and type(doesVehicleExist) == 'function' and doesVehicleExist(airLastCar) and airWasInCar then
            freezeCarPosition(airLastCar, false)
            setCarCollision(airLastCar, true)
        end
        if not airWasInCar then
            freezeCharPosition(PLAYER_PED, false)
            setCharCollision(PLAYER_PED, true)
            if type(setCharVelocity) == 'function' then setCharVelocity(PLAYER_PED, 0.0, 0.0, 0.0) end
        end
    end)
    airWasInCar, airLastCar = false, nil
end

-- Movement follows MonetLoaderOSS/example/AirBrake.lua; the menu toggle controls activation.
local function processSpecialWidgets()
    local delta = 0
    if WIDGET_ZOOM_IN and isWidgetPressed(WIDGET_ZOOM_IN) then delta = delta + airSpeed / 2 end
    if WIDGET_ZOOM_OUT and isWidgetPressed(WIDGET_ZOOM_OUT) then delta = delta - airSpeed / 2 end
    if WIDGET_VIDEO_POKER_ADD_COIN and isWidgetPressed(WIDGET_VIDEO_POKER_ADD_COIN) then
        airSpeed = math.min(3.5, airSpeed + 0.01)
        if type(printStringNow) == 'function' then printStringNow('Speed: ' .. string.format('%.2f', airSpeed), 500) end
    end
    if WIDGET_VIDEO_POKER_REMOVE_COIN and isWidgetPressed(WIDGET_VIDEO_POKER_REMOVE_COIN) then
        airSpeed = math.max(0.1, airSpeed - 0.01)
        if type(printStringNow) == 'function' then printStringNow('Speed: ' .. string.format('%.2f', airSpeed), 500) end
    end
    return delta
end

local function processAirBrake()
    if not widgetsOK or type(isWidgetPressedEx) ~= 'function' then return end
    local x1, y1, z1 = getActiveCameraCoordinates()
    local x, y, z = getActiveCameraPointAt()
    local angle = -math.rad(getHeadingFromVector2d(x - x1, y - y1))
    if isCharInAnyCar(PLAYER_PED) then
        local car = storeCarCharIsInNoSave(PLAYER_PED)
        if car ~= airLastCar and airLastCar ~= nil and doesVehicleExist(airLastCar) and airWasInCar then
            freezeCarPosition(airLastCar, false)
            setCarCollision(airLastCar, true)
        end
        airWasInCar, airLastCar = true, car
        freezeCarPosition(car, true)
        setCarCollision(car, false)
        local result, ax, ay = isWidgetPressedEx(WIDGET_VEHICLE_STEER_ANALOG, 0)
        if not result then ax, ay = 0, 0 end
        local ix, iy = ax / 127, ay / 127
        local cx, cy, cz = getCharCoordinates(PLAYER_PED)
        cx = cx - math.sin(angle) * airSpeed * iy + math.cos(angle) * airSpeed * ix
        cy = cy - math.cos(angle) * airSpeed * iy - math.sin(angle) * airSpeed * ix
        cz = cz + processSpecialWidgets()
        setPlayerCarCoordinatesFixed(cx, cy, cz)
        setCarHeading(car, math.deg(-angle))
        if ix ~= 0 and type(restoreCameraJumpcut) == 'function' then restoreCameraJumpcut() end
    else
        if airWasInCar and airLastCar ~= nil and doesVehicleExist(airLastCar) then
            freezeCarPosition(airLastCar, false)
            setCarCollision(airLastCar, true)
        end
        airWasInCar = false
        freezeCharPosition(PLAYER_PED, true)
        setCharCollision(PLAYER_PED, false)
        local result, ax, ay = isWidgetPressedEx(WIDGET_PED_MOVE, 0)
        if not result then ax, ay = 0, 0 end
        local ix, iy = ax / 127, ay / 127
        local cx, cy, cz = getCharCoordinates(PLAYER_PED)
        cx = cx - math.sin(angle) * airSpeed * iy + math.cos(angle) * airSpeed * ix
        cy = cy - math.cos(angle) * airSpeed * iy - math.sin(angle) * airSpeed * ix
        cz = cz + processSpecialWidgets()
        setCharCoordinatesNoOffset(PLAYER_PED, cx, cy, cz)
        setCharHeading(PLAYER_PED, math.deg(-angle))
        if type(setCharVelocity) == 'function' then setCharVelocity(PLAYER_PED, 0.0, 0.0, 0.0) end
        if ix ~= 0 and type(restoreCameraJumpcut) == 'function' then restoreCameraJumpcut() end
    end
end

local function processFlyCar()
    if not widgetsOK or not isCharInAnyCar(PLAYER_PED) then flySpeed = 0; return end
    local car = storeCarCharIsInNoSave(PLAYER_PED)
    local speed = getCarSpeed(car)
    setCarHeavy(car, false)
    setCarProofs(car, true, true, true, true, true)
    setCharCanBeKnockedOffBike(car, false)
    local result, ax, ay = isWidgetPressedEx(WIDGET_VEHICLE_STEER_ANALOG, 0)
    if result then setCarRotationVelocity(car, ay / 64.0, 0.0, ax / -64.0) end
    if isWidgetPressed(WIDGET_ACCELERATE) and speed <= 200.0 then flySpeed = math.min(flySpeed + 0.4, 200.0) end
    if isWidgetPressed(WIDGET_BRAKE) then flySpeed = math.max(0, flySpeed - 0.3) end
    if isWidgetPressed(WIDGET_HANDBRAKE) then
        flySpeed = 0
        setCarRotationVelocity(car, 0,0,0)
        setCarRoll(car, 0)
    end
    setCarForwardSpeed(car, flySpeed)
    flyLastCar = car
end


-- Render maps ported from Miku Project Reborn.
local renderModels = {
    renderGift = { [19054] = 'Подарок', [19055] = 'Подарок', [19056] = 'Подарок', [19057] = 'Подарок', [19058] = 'Подарок' },
    renderTrash = { [2670] = 'Мусор', [2673] = 'Мусор', [2674] = 'Мусор', [2677] = 'Мусор' },
    renderStash = { [2680] = 'Клад', [16317] = 'Клад', [1271] = 'Клад', [16302] = 'Клад' },
    renderHighTree = { [729] = 'Дерево высшего качества' },
    renderApple = { [19576] = 'Яблоко/слива', [895] = 'Яблочное дерево' },
    renderPlum = { [19576] = 'Яблоко/слива', [883] = 'Сливовое дерево' },
    renderCoconut = { [19344] = 'Кокос', [674] = 'Кокосовое дерево' },
    renderGraffiti = { [1490] = 'Граффити', [1524] = 'Граффити', [1525] = 'Граффити', [1526] = 'Граффити', [1527] = 'Граффити', [1528] = 'Граффити', [1529] = 'Граффити', [1530] = 'Граффити', [1531] = 'Граффити', [14840] = 'Граффити', [17969] = 'Граффити', [18659] = 'Граффити', [18660] = 'Граффити', [18661] = 'Граффити', [18662] = 'Граффити', [18663] = 'Граффити', [18664] = 'Граффити', [18665] = 'Граффити', [18666] = 'Граффити', [18667] = 'Граффити' },
}
local function renderAnyEnabled()
    for key in pairs(renderModels) do if T[key] and T[key][0] then return true end end
    return false
end
local function renderLabelForModel(model)
    for key, models in pairs(renderModels) do
        if T[key] and T[key][0] and models[model] then return models[model] end
    end
end
local renderFont = nil
pcall(function() renderFont = renderCreateFont('Arial', 20, 1 + 4) end)
local function ensureFonts()
    if not playerFont then pcall(function() playerFont = renderCreateFont('Arial', 18, 1 + 4) end) end
    if not renderFont then pcall(function() renderFont = renderCreateFont('Arial', 20, 1 + 4) end) end
end
-- FreeCam: логика из CamHack V5 (MTG MODS), режим Joystick + Widgets
local cam = { active = false, x = 0, y = 0, z = 0, angZ = 0, angY = 0, hudHidden = false, nicksHidden = false }
local cameraOverrideWasActive = false
local trailerTarget = nil
local trailerButtonWasPressed = false

local function camSpeed() return math.max(0.01, math.min(2.0, T.freeCamSpeed[0] / 100)) end
local function camApply() setFixedCameraPosition(cam.x, cam.y, cam.z, 0.0, 0.0, 0.0) end
local function camUpdate()
    local rz, ry = math.rad(cam.angZ), math.rad(cam.angY)
    local cy = math.cos(ry)
    pointCameraAtPoint(cam.x + math.sin(rz) * cy, cam.y + math.cos(rz) * cy, cam.z + math.sin(ry), 2)
end
-- dz: поворот направления относительно взгляда, pitch: учитывать наклон камеры (знак = направление по Z)
local function camStep(dz, pitch)
    local sp = camSpeed()
    local rz = math.rad(cam.angZ + dz)
    local k = pitch and math.cos(math.rad(cam.angY)) or 1.0
    cam.x = cam.x + math.sin(rz) * k * sp
    cam.y = cam.y + math.cos(rz) * k * sp
    if pitch then cam.z = cam.z + math.sin(math.rad(cam.angY)) * pitch * sp end
    camApply()
end
local function camForward() camStep(0, 1) end
local function camBack() camStep(180, -1) end
local function camLeft() camStep(-90) end
local function camRight() camStep(90) end
local function camLeftForward() camStep(-45, 1) end
local function camRightForward() camStep(45, 1) end
local function camLeftBack() camStep(-135, -1) end
local function camRightBack() camStep(135, -1) end
local function camUp() cam.z = cam.z + camSpeed(); camApply() end
local function camDown() cam.z = cam.z - camSpeed(); camApply() end
local function camAngle(dir)
    cam.angZ = (cam.angZ + dir * (1 + camSpeed() / 10)) % 360.0
    camUpdate()
end
local function camSpeedAdd(d)
    T.freeCamSpeed[0] = math.max(1, math.min(200, T.freeCamSpeed[0] + d))
    if type(printStringNow) == 'function' then
        pcall(printStringNow, '[FreeCam] Speed: ' .. string.format('%.2f', camSpeed()), 300)
    end
end
local function camJoystick(x, y)
    local nx, ny = x / 127.0, y / 127.0
    if nx > 0.5 then
        if ny > 0.5 then camRightBack() elseif ny < -0.5 then camRightForward() else camRight() end
    elseif nx < -0.5 then
        if ny > 0.5 then camLeftBack() elseif ny < -0.5 then camLeftForward() else camLeft() end
    else
        if ny > 0.5 then camBack() elseif ny < -0.5 then camForward() end
    end
    camUpdate()
end

-- скрыть/показать ники над головой (RPC 80, как в CamHack)
local function camHideNicks(hide)
    if type(getAllChars) ~= 'function' or type(raknetNewBitStream) ~= 'function' then return end
    for _, ch in ipairs(getAllChars()) do
        local ok, id = sampGetPlayerIdByCharHandle(ch)
        if ok then
            local bs = raknetNewBitStream()
            raknetBitStreamWriteInt16(bs, tonumber(id))
            raknetBitStreamWriteInt8(bs, hide and 0 or 1)
            raknetEmulRpcReceiveBitStream(80, bs)
            raknetDeleteBitStream(bs)
        end
    end
end

local function camOn()
    cam.x, cam.y, cam.z = getCharCoordinates(PLAYER_PED)
    cam.angZ = -getCharHeading(PLAYER_PED)
    cam.angY = 0.0
    camApply()
    cam.active = true
    if T.camHideNicks[0] then pcall(camHideNicks, true); cam.nicksHidden = true end
end

local function camOff()
    cam.active = false
    pcall(restoreCameraJumpcut)
    pcall(setCameraBehindPlayer)
    if cam.hudHidden then
        pcall(displayRadar, true); pcall(displayHud, true)
        cam.hudHidden = false
    end
    if cam.nicksHidden then pcall(camHideNicks, false); cam.nicksHidden = false end
end

local function processFreeCam()
    if T.freeCam[0] and not cam.active then
        local ok = pcall(camOn)
        if not ok then cam.active = false; T.freeCam[0] = false end
        return
    elseif not T.freeCam[0] then
        if cam.active then camOff() end
        return
    end

    camUpdate()
    -- HUD
    if T.camHideHud[0] and not cam.hudHidden then
        pcall(displayRadar, false); pcall(displayHud, false); cam.hudHidden = true
    elseif not T.camHideHud[0] and cam.hudHidden then
        pcall(displayRadar, true); pcall(displayHud, true); cam.hudHidden = false
    end
    -- ники
    if T.camHideNicks[0] and not cam.nicksHidden then
        pcall(camHideNicks, true); cam.nicksHidden = true
    elseif not T.camHideNicks[0] and cam.nicksHidden then
        pcall(camHideNicks, false); cam.nicksHidden = false
    end

    if not widgetsOK then return end
    if WIDGET_ZOOM_IN and isWidgetPressed(WIDGET_ZOOM_IN) then camSpeedAdd(1) end
    if WIDGET_ZOOM_OUT and isWidgetPressed(WIDGET_ZOOM_OUT) then camSpeedAdd(-1) end
    if WIDGET_CRANE_UP and isWidgetPressed(WIDGET_CRANE_UP) then camUp() end
    if WIDGET_CRANE_DOWN and isWidgetPressed(WIDGET_CRANE_DOWN) then camDown() end
    if WIDGET_RACE_LEFT and isWidgetPressed(WIDGET_RACE_LEFT) then camAngle(-1) end
    if WIDGET_RACE_RIGHT and isWidgetPressed(WIDGET_RACE_RIGHT) then camAngle(1) end
    if WIDGET_PED_MOVE then
        local ok, pressed, ax, ay = pcall(isWidgetPressedEx, WIDGET_PED_MOVE, 0)
        if ok and pressed and ax and ay and (ax ~= 0 or ay ~= 0) then camJoystick(ax, ay) end
    end
    if WIDGET_MISSION_CANCEL and isWidgetPressed(WIDGET_MISSION_CANCEL) then
        T.freeCam[0] = false
        camOff()
    end
end

if okSE and sampev then
    local prevAim = sampev.onSendAimSync
    function sampev.onSendAimSync(...)
        if cam.active then return false end
        if prevAim then return prevAim(...) end
    end
    local prevBubble = sampev.onPlayerChatBubble
    function sampev.onPlayerChatBubble(pid, color, distance, duration, message)
        if cam.active and T.camBubbles[0] then return { pid, color, 9999, duration, message } end
        if prevBubble then return prevBubble(pid, color, distance, duration, message) end
    end
end


local function processCamera()
    local cameraOverride = T.cameraFov[0] or T.cameraZoom[0]
    if cameraOverride then
        cameraOverrideWasActive = true
        local fov = T.cameraZoom[0] and T.cameraZoomValue[0] or T.cameraFovValue[0]
        if type(cameraSetLerpFov) == 'function' then pcall(cameraSetLerpFov, fov, fov, 100, true) end
    elseif cameraOverrideWasActive then
        cameraOverrideWasActive = false
        if type(restoreCameraJumpcut) == 'function' then pcall(restoreCameraJumpcut) end
    end

    processFreeCam()
end

ATR_CLICK = false
ATR_SHOW = false
local function processTrailer()
    local click = ATR_CLICK
    ATR_CLICK = false
    ATR_SHOW = false
    if not T.attachTrailer[0] then trailerTarget = nil; trailerButtonWasPressed = false; return end
    if not (type(isCharInAnyCar) == 'function' and isCharInAnyCar(PLAYER_PED)
        and type(getAllVehicles) == 'function' and type(getDriverOfCar) == 'function') then
        trailerTarget = nil
        trailerButtonWasPressed = false
        return
    end
    local cab = storeCarCharIsInNoSave(PLAYER_PED)
    if getDriverOfCar(cab) ~= PLAYER_PED then trailerTarget = nil; trailerButtonWasPressed = false; return end
    ATR_SHOW = true
    local sw, sh = getScreenResolution()
    local size = math.max(40, math.min(500, T.trailerRadius[0]))
    local x1, y1 = sw / 2 - size / 2, sh / 3.3 - size / 2
    local x2, y2 = x1 + size, y1 + size
    trailerTarget = nil
    local okCars, cars = pcall(getAllVehicles)
    if okCars and type(cars) == 'table' then
        local px, py, pz = getCharCoordinates(PLAYER_PED)
        for _, veh in ipairs(cars) do
            if veh ~= cab then
                local okTarget = pcall(function()
                    if doesVehicleExist(veh) and (type(isCarOnScreen) ~= 'function' or isCarOnScreen(veh)) then
                        local vx, vy, vz = getCarCoordinates(veh)
                        local sx, sy = convert3DCoordsToScreen(vx, vy, vz)
                        if type(sx) == 'number' and type(sy) == 'number'
                            and sx >= x1 and sx <= x2 and sy >= y1 and sy <= y2
                            and getDistanceBetweenCoords3d(px, py, pz, vx, vy, vz) <= 20 then
                            trailerTarget = veh
                            if type(renderDrawLine) == 'function' then
                                renderDrawLine(sx, sy, x1 + size / 2, y1 + size / 2, 3, 0xFFFFFFFF)
                            end
                        end
                    end
                end)
                if trailerTarget then break end
            end
        end
    end
    if type(renderDrawLine) == 'function' then
        local c = trailerTarget and 0xB8FCFFFF or 0xFFFFFFFF
        renderDrawLine(x1, y1, x2, y1, 3, c)
        renderDrawLine(x1, y1, x1, y2, 3, c)
        renderDrawLine(x1, y2, x2, y2, 3, c)
        renderDrawLine(x2, y1, x2, y2, 3, c)
    end
    if click and not trailerTarget and okCars and type(cars) == 'table' then
        local px, py, pz = getCharCoordinates(PLAYER_PED)
        local best = 21
        for _, veh in ipairs(cars) do
            pcall(function()
                if veh ~= cab and doesVehicleExist(veh) then
                    local vx, vy, vz = getCarCoordinates(veh)
                    local d = getDistanceBetweenCoords3d(px, py, pz, vx, vy, vz)
                    if d < best then best, trailerTarget = d, veh end
                end
            end)
        end
    end
    local pressed = false
    if type(isWidgetPressed) == 'function' and WIDGET_ARCADE_RESET then
        local okPressed, value = pcall(isWidgetPressed, WIDGET_ARCADE_RESET)
        pressed = okPressed and value or false
    end
    if trailerTarget and (click or (pressed and not trailerButtonWasPressed)) then
        local selected = trailerTarget
        local okAt, errAt = pcall(function()
            if isTrailerAttachedToCab(selected, cab) then
                detachTrailerFromCab(selected, cab)
            else
                attachTrailerToCab(selected, cab)
            end
        end)
        if not okAt then msg('Attach Trailer: ' .. tostring(errAt)) end
        trailerTarget = nil
    end
    trailerButtonWasPressed = pressed
end

local function processRender()
    if renderFont and T.renderRuda[0] and type(sampIs3dTextDefined) == 'function' and type(sampGet3dTextInfoById) == 'function' then
        for id = 0, 2048 do
            pcall(function()
                if sampIs3dTextDefined(id) then
                    local text, _, x, y, z = sampGet3dTextInfoById(id)
                    if type(text) == 'string' and text:find(u8:decode('ресурсов'), 1, true) and isPointOnScreen(x,y,z,3.0) then
                        local px,py,pz = getCharCoordinates(PLAYER_PED)
                        local sx,sy = convert3DCoordsToScreen(x,y,z); local pxs,pys = convert3DCoordsToScreen(px,py,pz)
                        local dist = math.floor(getDistanceBetweenCoords3d(x,y,z,px,py,pz))
                        renderDrawLine(sx,sy,pxs,pys,2,0xB8B8FCFF)
                        renderFontDrawText(renderFont, u8:decode('Руда\nDIST: '..dist..'m'), sx,sy,-1)
                    end
                end
            end)
        end
    end
    if renderFont and T.renderDeer[0] and type(getAllChars) == 'function' then
        pcall(function()
            local px,py,pz = getCharCoordinates(PLAYER_PED)
            local sx,sy = convert3DCoordsToScreen(px,py,pz)
            for _, ch in ipairs(getAllChars()) do
                if ch ~= PLAYER_PED and getCharModel(ch) == 3150 then
                    local x,y,z = getCharCoordinates(ch)
                    if isPointOnScreen(x,y,z,0) then
                        local tx,ty = convert3DCoordsToScreen(x,y,z)
                        local d = math.floor(getDistanceBetweenCoords3d(px,py,pz,x,y,z))
                        renderDrawLine(sx,sy,tx,ty,1,0xB8B8FCFF)
                        renderFontDrawText(renderFont, u8:decode('Олень\nDIST: '..d..'m'), tx,ty,-1)
                    end
                end
            end
        end)
    end
    if renderFont and renderAnyEnabled() and type(getAllObjects) == 'function' then
        pcall(function()
            local px,py,pz = getCharCoordinates(PLAYER_PED)
            local sx,sy = convert3DCoordsToScreen(px,py,pz)
            for _, obj in pairs(getAllObjects()) do
                pcall(function()
                    if (type(isObjectOnScreen) ~= 'function' or isObjectOnScreen(obj)) then
                        local label = renderLabelForModel(getObjectModel(obj))
                        if label then
                            local resObj, x, y, z = getObjectCoordinates(obj)
                            if resObj and type(x) == 'number' and type(y) == 'number' and type(z) == 'number' then
                                local dist = math.floor(getDistanceBetweenCoords3d(px,py,pz,x,y,z))
                                local tx,ty = convert3DCoordsToScreen(x,y,z)
                                renderDrawLine(sx,sy,tx,ty,1,0xB8B8FCFF)
                                renderFontDrawText(renderFont, u8:decode(label..'\nDIST: '..dist..'m'), tx,ty,-1)
                            end
                        end
                    end
                end)
            end
        end)
    end
end

local MKX = {
    targetId = -1, targetPed = nil, bikeWas = false, lastBlip = nil,
    weapons = {
        [22] = { dmg = 8.25,  distance = 35 },  [23] = { dmg = 13.2,  distance = 35 },
        [24] = { dmg = 46.2,  distance = 35 },  [25] = { dmg = 3.3,   distance = 40 },
        [26] = { dmg = 3.3,   distance = 35 },  [27] = { dmg = 4.95,  distance = 40 },
        [28] = { dmg = 6.6,   distance = 35 },  [29] = { dmg = 8.25,  distance = 45 },
        [30] = { dmg = 9.9,   distance = 70 },  [31] = { dmg = 9.9,   distance = 90 },
        [32] = { dmg = 6.6,   distance = 35 },  [33] = { dmg = 24.75, distance = 100 },
        [34] = { dmg = 41.25, distance = 320 }, [38] = { dmg = 46.2,  distance = 75 },
    },
    rapidAnims = { 'PYTHON_CROUCHFIRE', 'PYTHON_FIRE', 'PYTHON_FIRE_POOR', 'PYTHON_CROCUCHRELOAD',
        'RIFLE_CROUCHFIRE', 'RIFLE_CROUCHLOAD', 'RIFLE_FIRE', 'RIFLE_FIRE_POOR', 'RIFLE_LOAD',
        'SHOTGUN_CROUCHFIRE', 'SHOTGUN_FIRE', 'SHOTGUN_FIRE_POOR', 'SILENCED_CROUCH_RELOAD',
        'SILENCED_CROUCH_FIRE', 'SILENCED_FIRE', 'SILENCED_RELOAD', 'TEC_crouchfire', 'TEC_crouchreload',
        'TEC_fire', 'TEC_reload', 'UZI_crouchfire', 'UZI_crouchreload', 'UZI_fire', 'UZI_fire_poor',
        'UZI_reload', 'idle_rocket', 'Rocket_Fire', 'run_rocket', 'walk_rocket', 'WALK_start_rocket',
        'WEAPON_sniper' },
}

function MKX.rand() return math.random(-50, 50) / 100 end

-- радиус круга SilentAim в пикселях (как getpx() в Miku)
function MKX.radiusPx()
    local w = select(1, getScreenResolution())
    local fov = getCameraFov()
    if not fov or fov <= 0 then fov = 70 end
    return ((w / 2) / fov) * T.saFov[0]
end

function MKX.rgbaSplit(c)
    return bit.band(bit.rshift(c, 24), 0xFF), bit.band(bit.rshift(c, 16), 0xFF),
        bit.band(bit.rshift(c, 8), 0xFF), bit.band(c, 0xFF)
end
function MKX.rgbaJoin(r, g, b, a)
    return bit.bor(a, bit.lshift(b, 8), bit.lshift(g, 16), bit.lshift(r, 24))
end

-- Anti-Captcha: отправка клика / подтверждения загрузки интерфейса (Arizona)
function MKX.frontendClick(interfaceid, id, subid, json)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 63)
    raknetBitStreamWriteInt8(bs, interfaceid)
    raknetBitStreamWriteInt32(bs, id)
    raknetBitStreamWriteInt32(bs, subid)
    raknetBitStreamWriteInt32(bs, #json)
    raknetBitStreamWriteString(bs, json)
    raknetSendBitStreamEx(bs, 1, 10, 1)
    raknetDeleteBitStream(bs)
end
function MKX.interfaceLoaded(interfaceid, flag)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 66)
    raknetBitStreamWriteInt8(bs, interfaceid)
    raknetBitStreamWriteBool(bs, flag)
    raknetSendBitStreamEx(bs, 1, 10, 1)
    raknetDeleteBitStream(bs)
end

pcall(function()
    addEventHandler('onReceivePacket', function(id, bs)
        if not T.anticaptcha[0] or id ~= 220 then return end
        raknetBitStreamIgnoreBits(bs, 8)
        local ptype = raknetBitStreamReadInt8(bs)
        if ptype == 84 then
            local interfaceid = raknetBitStreamReadInt8(bs)
            raknetBitStreamReadInt8(bs)
            if interfaceid == 81 then
                lua_thread.create(function()
                    wait(100)
                    MKX.frontendClick(81, 0, 0, '')
                end)
                return false
            end
        elseif ptype == 62 then
            local interfaceid = raknetBitStreamReadInt8(bs)
            local toggle = raknetBitStreamReadBool(bs)
            if interfaceid == 81 then
                MKX.interfaceLoaded(81, toggle)
                return false
            end
        end
    end)
end)

if okSE and sampev then
    -- Anti-Freeze
    function sampev.onTogglePlayerControllable(controllable)
        if T.antifreeze[0] then return false end
    end

    -- Anti-Mask: снимаем скрытие ника/цвета у игроков в масках
    function sampev.onPlayerStreamIn(id, team, model, position, rotation, color, fight)
        if T.antimask[0] then
            local r, g, b, a = MKX.rgbaSplit(color)
            if a >= 0 and a <= 4 then
                return { id, team, model, position, rotation, MKX.rgbaJoin(r, g, b, 0xAA), fight }
            end
        end
    end
    function sampev.onSetPlayerColor(id, color)
        if T.antimask[0] then
            local r, g, b, a = MKX.rgbaSplit(color)
            if a >= 0 and a <= 4 then
                local bs = raknetNewBitStream()
                raknetBitStreamWriteInt16(bs, id)
                raknetBitStreamWriteInt32(bs, MKX.rgbaJoin(r, g, b, 0xAA))
                raknetEmulRpcReceiveBitStream(72, bs)
                raknetDeleteBitStream(bs)
                return false
            end
        end
    end

    -- SilentAim: подмена цели в bullet sync
    function sampev.onSendBulletSync(sync)
        if not T.silentaim[0] or MKX.targetId < 0 then return end
        local res, ok, ped = pcall(sampGetCharHandleBySampPlayerId, MKX.targetId)
        if not (res and ok and ped) then return end
        local weapon = MKX.weapons[getCurrentCharWeapon(PLAYER_PED)]
        if not weapon or sync.targetType == 1 then return end
        local mx, my, mz = getCharCoordinates(PLAYER_PED)
        local x, y, z = getCharCoordinates(ped)
        if not isLineOfSightClear(x, y, z, mx, my, mz, true, true, false, true, false) then return end
        sync.targetType = 1
        sync.targetId = MKX.targetId
        sync.center = { x = MKX.rand(), y = MKX.rand(), z = MKX.rand() }
        sync.target = { x = x + MKX.rand(), y = y + MKX.rand(), z = z + MKX.rand() }
        pcall(sampSendGiveDamage, MKX.targetId, weapon.dmg, getCurrentCharWeapon(PLAYER_PED), 3)
    end
end

-- SilentAim: поиск цели в круге FOV + отрисовка круга
imgui.OnFrame(function()
    return T.silentaim[0] and not (type(isGamePaused) == 'function' and isGamePaused())
end, function(self)
    self.HideCursor = true
    local xw, yw = getScreenResolution()
    local cx, cy = xw / 2, yw / 2.5
    local rad = MKX.radiusPx()
    local dl = imgui.GetBackgroundDrawList()
    if isCharOnFoot(PLAYER_PED) then
        local c = imgui.ColorConvertFloat4ToU32
        dl:AddCircleFilled(V2(cx, cy), 3, c(V4(1, 1, 1, 1)), 32)
        dl:AddCircleFilled(V2(cx, cy), rad, c(V4(1, 1, 1, 0.12)), 96)
        dl:AddCircle(V2(cx, cy), rad, c(V4(1, 1, 1, 0.7)), 96, 2)
        local weapon = MKX.weapons[getCurrentCharWeapon(PLAYER_PED)]
        local maxDist = math.min(T.saRange[0], weapon and weapon.distance or T.saRange[0])
        local px, py, pz = getCharCoordinates(PLAYER_PED)
        local found = nil
        if weapon then
            for _, ch in ipairs(getAllChars()) do
                if ch ~= PLAYER_PED then
                    local okId, id = sampGetPlayerIdByCharHandle(ch)
                    if okId and isCharOnScreen(ch) then
                        local x, y, z = getCharCoordinates(ch)
                        local sx, sy = convert3DCoordsToScreen(x, y, z)
                        if sx and math.sqrt((sx - cx) ^ 2 + (sy - cy) ^ 2) <= rad
                            and getDistanceBetweenCoords3d(px, py, pz, x, y, z) <= maxDist then
                            dl:AddLine(V2(cx, cy), V2(sx, sy), c(V4(1, 1, 1, 1)), 2)
                            dl:AddCircleFilled(V2(sx, sy), 3, c(V4(1, 1, 1, 1)), 16)
                            found = ch
                            MKX.targetId = id
                            break
                        end
                    end
                end
            end
        end
        MKX.targetPed = found
        if not found then MKX.targetId = -1 end
    else
        MKX.targetPed, MKX.targetId = nil, -1
    end
end)

-- покадровая логика: Rapid, NoBike, MetkaTP
-- Боксы игроков из WallHack (MonetLoader example): render-функции вызываем из основного потока
local function hex6(key)
    return string.format('{%02X%02X%02X}', T[key .. 'R'][0], T[key .. 'G'][0], T[key .. 'B'][0])
end
local function argb(key)
    return 0xFF000000 + T[key .. 'R'][0] * 65536 + T[key .. 'G'][0] * 256 + T[key .. 'B'][0]
end

function MKX.boxes()
    local wantP = T.espPBox[0] or T.espPNick[0] or T.espPDist[0] or T.espPTrace[0]
    local wantC = T.espCBox[0] or T.espCName[0] or T.espCDist[0] or T.espCStatus[0]
    if not (wantP or wantC) then return end
    if type(renderDrawBoxWithBorder) ~= 'function' or type(getAllChars) ~= 'function' then return end
    local sw, sh = getScreenResolution()
    local font = playerFont
    local fh = (font and renderGetFontDrawHeight(font)) or 14
    local px, py, pz = getCharCoordinates(PLAYER_PED)

    if wantP then
        for _, char in ipairs(getAllChars()) do
            pcall(function()
                if char == PLAYER_PED or not isCharOnScreen(char) then return end
                local result, id = sampGetPlayerIdByCharHandle(char)
                if not result then return end
                local x, y, z = getOffsetFromCharInWorldCoords(char, 0, 0, 0)
                local headx, heady = convert3DCoordsToScreen(x, y, z + 1.0)
                local footx, footy = convert3DCoordsToScreen(x, y, z - 1.0)
                local width = math.abs((heady - footy) * 0.25)

                if T.espPTrace[0] and type(renderDrawLine) == 'function' then
                    renderDrawLine(sw / 2, sh, footx, footy, 2, argb('espPTrace'))
                end
                if T.espPBox[0] then
                    renderDrawBoxWithBorder(headx - width, heady, math.abs(2 * width), math.abs(footy - heady), 0, sh * 0.005, argb('espPBox'))
                end
                if font and T.espPNick[0] then
                    local nick = sampGetPlayerNickname(id) or ('ID' .. id)
                    local hp = tonumber(sampGetPlayerHealth(id)) or 0
                    local ap = tonumber(sampGetPlayerArmor(id)) or 0
                    local tag = string.format('%s%s [%d] - {FF0000}%.0fhp {BBBBBB}%.0fap', hex6('espPNick'), nick, id, hp, ap)
                    local len = renderGetFontDrawTextLength(font, tag)
                    renderFontDrawText(font, tag, headx - len / 2, heady - fh * 1.2, argb('espPNick'))
                end
                if font and T.espPDist[0] then
                    local d = getDistanceBetweenCoords3d(px, py, pz, x, y, z)
                    local txt = string.format('%.0fm', d)
                    local len = renderGetFontDrawTextLength(font, txt)
                    renderFontDrawText(font, txt, footx - len / 2, footy + 2, argb('espPDist'))
                end
            end)
        end
    end

    if wantC and type(getAllVehicles) == 'function' then
        local myCar = nil
        if isCharInAnyCar(PLAYER_PED) then myCar = storeCarCharIsInNoSave(PLAYER_PED) end
        for _, car in ipairs(getAllVehicles()) do
            pcall(function()
                if car == myCar or not doesVehicleExist(car) or not isCarOnScreen(car) then return end
                local x, y, z = getCarCoordinates(car)
                local topx, topy = convert3DCoordsToScreen(x, y, z + 1.1)
                local botx, boty = convert3DCoordsToScreen(x, y, z - 0.7)
                local h = math.abs(boty - topy)
                local w = h * 0.55
                local top = math.min(topy, boty)
                if T.espCBox[0] then
                    renderDrawBoxWithBorder(topx - w, top, w * 2, h, 0, sh * 0.004, argb('espCBox'))
                end
                if not font then return end
                local lines = {}
                if T.espCName[0] then
                    local name
                    if type(getNameOfVehicleModel) == 'function' then
                        local okN, n = pcall(getNameOfVehicleModel, getCarModel(car))
                        if okN and n and n ~= '' then name = n end
                    end
                    name = name or ('Model ' .. tostring(getCarModel(car)))
                    local okV, found, vid = pcall(sampGetVehicleIdByCarHandle, car)
                    if okV and found then name = name .. ' [' .. vid .. ']' end
                    lines[#lines + 1] = { hex6('espCName') .. name, argb('espCName') }
                end
                if T.espCStatus[0] then
                    local okL, st = pcall(getCarDoorLockStatus, car)
                    local unlocked = (not okL) or st == 0 or st == 1
                    lines[#lines + 1] = { unlocked and '{40FF40}Unlocked' or '{FF4040}Locked', 0xFFFFFFFF }
                end
                if T.espCDist[0] then
                    local d = getDistanceBetweenCoords3d(px, py, pz, x, y, z)
                    lines[#lines + 1] = { string.format('%.0fm', d), argb('espCDist') }
                end
                -- строки рисуем снизу вверх над боксом
                for i = #lines, 1, -1 do
                    local txt = lines[i][1]
                    local len = renderGetFontDrawTextLength(font, txt)
                    renderFontDrawText(font, txt, topx - len / 2, top - fh * (#lines - i + 1) - 2, lines[i][2])
                end
            end)
        end
    end
end

function MKX.tick()
    pcall(MKX.boxes)
    if T.rapid[0] then
        local sp = math.max(1, T.rapidSpeed[0] / 10)
        for _, anim in ipairs(MKX.rapidAnims) do setCharAnimSpeed(PLAYER_PED, anim, sp) end
    end

    if T.carNoBike[0] then
        MKX.bikeWas = true
        if isCharInAnyCar(PLAYER_PED) then
            local car = storeCarCharIsInNoSave(PLAYER_PED)
            setCharCanBeKnockedOffBike(PLAYER_PED, not isCarInWater(car))
        end
    elseif MKX.bikeWas then
        MKX.bikeWas = false
        setCharCanBeKnockedOffBike(PLAYER_PED, false)
    end

    -- MetkaTP: при постановке/смене метки на карте телепортирует к ней
    if T.metkatp[0] then
        local has, x, y, z = getTargetBlipCoordinates()
        if has then
            local key = ('%.1f:%.1f'):format(x, y)
            if key ~= MKX.lastBlip then
                MKX.lastBlip = key
                local ok, fx, fy, fz = getTargetBlipCoordinatesFixed()
                if ok then
                    if isCharInAnyCar(PLAYER_PED) then
                        setCarCoordinates(storeCarCharIsInNoSave(PLAYER_PED), fx, fy, fz)
                    else
                        setCharCoordinates(PLAYER_PED, fx, fy, fz)
                    end
                end
            end
        else
            MKX.lastBlip = nil
        end
    else
        MKX.lastBlip = nil
    end
end
function getTargetBlipCoordinatesFixed()
    local ok, x, y, z = getTargetBlipCoordinates()
    if not ok then return false end
    requestCollision(x, y)
    loadScene(x, y, z)
    return getTargetBlipCoordinates()
end


RUN = { sets = {
    { 'Дефолт', 'man', nil }, { 'CJ', 'PLAYER', nil }, { 'Берсерк', 'berserk', 'berserk' },
    { 'Фрирен', 'friren1', 'friren1' }, { 'Друид', 'druid', 'druid' }, { 'Личь', 'lich1', 'lich1' },
    { 'Викинг', 'viking1', 'viking1' }, { 'Обратень', 'werewolf1', 'werewolf1' },
    { 'Ведьма', 'witch1', 'witch1' }, { 'Роллер', 'skatef', 'skatef' } },
    key = nil, tired = nil, wasInCar = false }
pcall(function()
    local hook = require 'monethook'
    local gta = ffi.load('GTASA')
    pcall(ffi.cdef, [[
        void* _ZN4CPad6GetPadEi(int num);
        uint8_t _ZN4CPad9GetSprintEi(void* thiz, int playerid);
    ]])
    RUN.orig = hook.new('uint8_t(*)(void*, int)', function(thiz, playerid)
        if T.customRun[0] and T.autoRun[0] and playerid == 0 then return 1 end
        return RUN.orig(thiz, playerid)
    end, ffi.cast('uintptr_t', ffi.cast('void*', gta._ZN4CPad9GetSprintEi)))
end)
function RUN.apply(on)
    lua_thread.create(function()
        pcall(function()
            if on then
                local set = RUN.sets[T.runSet[0]] or RUN.sets[1]
                if set[3] then
                    requestAnimation(set[3])
                    local n = 0
                    while not hasAnimationLoaded(set[3]) and n < 300 do wait(10); n = n + 1 end
                end
                setAnimGroupForChar(PLAYER_PED, set[2])
            else
                setAnimGroupForChar(PLAYER_PED, isCharMale(PLAYER_PED) and 'man' or 'woman')
            end
            clearCharTasksImmediately(PLAYER_PED)
        end)
    end)
end
function RUN.tick()
    local on = T.customRun[0]
    local key = (on and '1' or '0') .. T.runSet[0]
    if key ~= RUN.key then
        local first = RUN.key == nil
        RUN.key = key
        if on or not first then RUN.apply(on) end
    end
    local tired = on and T.infRun[0]
    if tired ~= RUN.tired then
        RUN.tired = tired
        pcall(setPlayerNeverGetsTired, PLAYER_HANDLE, tired and true or false)
    end
    local inCar = isCharInAnyCar(PLAYER_PED)
    if RUN.wasInCar and not inCar and on then
        lua_thread.create(function() wait(150); RUN.apply(true) end)
    end
    RUN.wasInCar = inCar
end

CW = { active = false, marker = nil, info = nil, was = false, font = nil, car = nil, t0 = 0, names = {} }
function CW.clear()
    if CW.marker then pcall(removeUser3dMarker, CW.marker); CW.marker = nil end
end
function CW.teleport(x, y, z)
    if isCharInAnyCar(PLAYER_PED) then setCarCoordinates(storeCarCharIsInNoSave(PLAYER_PED), x, y, z)
    else setCharCoordinates(PLAYER_PED, x, y, z) end
end
function CW.freeSeat(car)
    if doesCharExist(getDriverOfCar(car)) then
        for i = 0, getMaximumNumberOfPassengers(car) do
            if isCarPassengerSeatFree(car, i) then return i + 1 end
        end
        return nil
    end
    return 0
end
function CW.jump(car)
    local seat = CW.freeSeat(car)
    if not seat then return false end
    if seat == 0 then warpCharIntoCar(PLAYER_PED, car) else warpCharIntoCarAsPassenger(PLAYER_PED, car, seat - 1) end
    restoreCameraJumpcut()
    return true
end
function CW.touch(evt, id, sx, sy)
    if id ~= 0 or os.clock() - CW.t0 < 0.3 then return end
    local sw, sh = getScreenResolution()
    if sy > sh - 170 * K then return end -- зона кнопки ClickWarp / Attach Trailer
    if not (sx >= 0 and sy >= 0 and sx < sw and sy < sh) then return end
    local px, py, pz = convertScreenCoordsToWorld3D(sx, sy, 700.0)
    local cx, cy, cz = getActiveCameraCoordinates()
    local res, cp = processLineOfSight(cx, cy, cz, px, py, pz, true, true, false, true, false, false, false)
    if not (res and cp.entity ~= 0) then return end
    local n = cp.normal
    local x, y, z = cp.pos[1] - n[1] * 0.1, cp.pos[2] - n[2] * 0.1, cp.pos[3] - n[3] * 0.1
    local zo = (n[3] >= 0.5) and 1 or 300
    local res2, cp2 = processLineOfSight(x, y, z + zo, x, y, z - 0.3, true, true, false, true, false, false, false)
    if not res2 then return end
    x, y, z = cp2.pos[1], cp2.pos[2], cp2.pos[3] + 1
    local mx, my, mz = getCharCoordinates(PLAYER_PED)
    CW.info = { x = sx - 2, y = sy - 2, dist = getDistanceBetweenCoords3d(mx, my, mz, x, y, z), car = nil, color = 0xAAFFFFFF }
    CW.car = nil
    if cp.entityType == 2 then
        local car = getVehiclePointerHandle(cp.entity)
        if doesVehicleExist(car) and (not isCharInAnyCar(PLAYER_PED) or storeCarCharIsInNoSave(PLAYER_PED) ~= car) then
            CW.car = car
            CW.info.car, CW.info.color = car, 0xFFFFFFFF
        end
    end
    CW.clear()
    CW.marker = createUser3dMarker(x, y, z + 0.3, 4)
    if evt == 1 then
        if not (CW.car and CW.jump(CW.car)) then CW.teleport(x, y, z) end
        CW.clear()
        CW.info, CW.active = nil, false
    end
end
function onTouch(evt, id, x, y)
    if T.clickWarp[0] and CW.active then
        local ok, err = pcall(CW.touch, evt, id, x, y)
        if not ok and err ~= CW.lastErr then CW.lastErr = err; msg('ClickWarp: ' .. tostring(err)) end
    end
end
function CW.toggle()
    if CW.active then CW.clear(); CW.info = nil else CW.t0 = os.clock() end
    CW.active = not CW.active
    printStringNow(CW.active and 'Choose position' or 'You canceled choice', 3000)
end
function CW.tick()
    if not T.clickWarp[0] then
        if CW.active then CW.active = false; CW.clear(); CW.info = nil end
        CW.was, CW.on = false, false
        return
    end
    if not CW.on then CW.on = true; if not CW.active then CW.toggle() end end -- сразу режим выбора при включении
    local pressed = false
    if WIDGET_KISS then pcall(function() pressed = isWidgetPressed(WIDGET_KISS) end) end
    if pressed and not CW.was then CW.toggle() end
    CW.was = pressed
    if CW.active and CW.marker and CW.info then
        if not CW.font then CW.font = renderCreateFont('Arial', 17, 4) end
        local h = renderGetFontDrawHeight(CW.font)
        local i = CW.info
        renderFontDrawText(CW.font, 'Left your finger from the screen to teleport', i.x, i.y - h * 3 - 150, i.color)
        renderFontDrawText(CW.font, string.format('%0.2fm', i.dist), i.x, i.y - h * 2 - 150, 0xEEEEEEEE)
        if i.car then
            local nm = tostring(getCarModel(i.car))
            pcall(function() nm = getNameOfVehicleModel(getCarModel(i.car)) or nm end)
            renderFontDrawText(CW.font, nm, i.x, i.y - h - 150, 0xEEEEEEEE)
        end
    end
end

local twWas, lastSpam, spamSent, spamWas = false, 0, 0, false
local cjLast, cjWas = 0, false
godWas, carSpdLast, cjInit = false, 0, false
CJ_DO = false
OSA = { chat = {}, gas = {}, flipT = nil, flipped = false }
function OSA.cp(s) return u8:decode(s) end

-- ---------- Stream Chat ----------
function OSA.tickChat()
    if not T.streamChat[0] then return end
    if not OSA.font then OSA.font = renderCreateFont('Arial', 10, 5) end
    local sw, sh = getScreenResolution()
    local x, y0, lh, maxLines = sw - 350, sh - 400, 18, 5
    local flag = 0x90000000
    renderFontDrawText(OSA.font, OSA.cp('Чат в зоне стрима:'), x, y0, 0x80FFFFFF, flag)
    local n = math.min(maxLines, #OSA.chat)
    local fh = renderGetFontDrawHeight(OSA.font)
    for k = 1, n do
        local e = OSA.chat[#OSA.chat - n + k]
        local slot = maxLines - n + k
        local y = y0 + slot * lh
        local line = e.name .. ': ' .. e.text
        local len = renderGetFontDrawTextLength(OSA.font, line)
        renderDrawBox(x - 4, y - 2, len + 8, fh + 4, 0xB4000D14)
        renderFontDrawText(OSA.font, line, x, y, 0xFFFFFFFF, flag)
    end
end

-- ---------- Auto Domkrat (AutoFlip) ----------
local function qmul(a, b, c, d, w, x, y, z)
    return a * w - b * x - c * y - d * z, a * x + b * w + c * z - d * y,
           a * y - b * z + c * w + d * x, a * z + b * y - c * x + d * w
end
local function qrot(x, y, z, a, b, c, d)
    local a1, b1, c1, d1 = qmul(a, b, c, d, 0, x, y, z)
    local _, b2, c2, d2 = qmul(a1, b1, c1, d1, a, -b, -c, -d)
    return b2, c2, d2
end
function OSA.tickFlip()
    local upside = false
    if T.autoDomkrat[0] and isCharInAnyCar(PLAYER_PED) then
        local car = storeCarCharIsInNoSave(PLAYER_PED)
        local ok, res = pcall(function()
            local x, y, z, w = getVehicleQuaternion(car)
            if x and y and z and w then
                local _, _, vz = qrot(0, 0, 1, w, x, y, z)
                return vz < 0
            end
            return isCarUpsidedown(car)
        end)
        upside = ok and res == true
    end
    if upside then
        if not OSA.flipT then OSA.flipT = os.clock() end
        if not OSA.flipped and os.clock() - OSA.flipT >= 0.75 then
            OSA.flipped = true
            sampSendChat('/domkrat')
        end
    else
        OSA.flipT, OSA.flipped = nil, false
    end
end

-- ---------- Auto Fill ----------
local GAS_ID, HUD_ID = 48, 8
function OSA.click(iid, id, subid, json)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 63)
    raknetBitStreamWriteInt8(bs, iid)
    raknetBitStreamWriteInt32(bs, id)
    raknetBitStreamWriteInt32(bs, subid)
    raknetBitStreamWriteInt16(bs, #json)
    raknetBitStreamWriteString(bs, json)
    raknetSendBitStreamEx(bs, 1, 10, 1)
    raknetDeleteBitStream(bs)
end
function OSA.ifaceState(iid, state)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 66)
    raknetBitStreamWriteInt8(bs, iid)
    raknetBitStreamWriteBool(bs, state)
    raknetSendBitStreamEx(bs, 1, 10, 1)
    raknetDeleteBitStream(bs)
end
function OSA.interact()
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 63)
    raknetBitStreamWriteInt8(bs, 8)
    raknetBitStreamWriteInt32(bs, 7)
    raknetBitStreamWriteInt32(bs, -1)
    raknetBitStreamWriteInt16(bs, 0)
    raknetBitStreamWriteString(bs, '')
    raknetSendBitStreamEx(bs, 1, 7, 1)
    raknetDeleteBitStream(bs)
end
function OSA.fill()
    local g = OSA.gas
    if not g.typ or not g.max or not g.cur then OSA.gas = {} return end
    local target = math.min(g.max, T.fillTo[0])
    local amount = target - g.cur
    if amount > 0 then
        msg(string.format('[AutoFill] Заправка: %s, %d л', tostring(g.typ.title), amount))
        OSA.click(GAS_ID, -1, 0, string.format('%d,%d', g.typ.id, amount))
    end
    OSA.gas = {}
end
function OSA.onFrontend(iid, subid, json)
    if iid == GAS_ID then
        if subid == 0 then
            local arr = decodeJson(json) or {}
            for _, gt in ipairs(arr) do
                if gt.available == 1 then OSA.gas.typ = gt break end
            end
        elseif subid == 2 then
            OSA.gas.max = tonumber(json)
        elseif subid == 3 then
            OSA.gas.cur = tonumber(json)
            lua_thread.create(function() wait(100) OSA.fill() end)
        end
        return false
    elseif iid == HUD_ID and subid == 15 then
        local t = decodeJson(json)
        if t and type(t.title) == 'string' and t.title:find(OSA.cp('Заправиться'), 1, true) then
            lua_thread.create(function() wait(50) OSA.interact() end)
        end
    end
end

pcall(function()
    addEventHandler('onReceivePacket', function(id, bs)
        if id ~= 220 or not T.autoFill[0] then return end
        if raknetBitStreamResetReadPointer then raknetBitStreamResetReadPointer(bs) end
        raknetBitStreamIgnoreBits(bs, 8)
        local ptype = raknetBitStreamReadInt8(bs)
        if ptype == 84 then
            local iid = raknetBitStreamReadInt8(bs)
            local subid = raknetBitStreamReadInt8(bs)
            local len = raknetBitStreamReadInt16(bs)
            local enc = raknetBitStreamReadInt8(bs)
            local json = (enc ~= 0) and raknetBitStreamDecodeString(bs, len + enc) or raknetBitStreamReadString(bs, len)
            return OSA.onFrontend(iid, subid, json)
        elseif ptype == 62 then
            local iid = raknetBitStreamReadInt8(bs)
            local toggle = raknetBitStreamReadBool(bs)
            if iid == GAS_ID then
                OSA.ifaceState(iid, toggle)
                return false
            end
        end
    end)
end)

-- ---------- samp.events хуки ----------
if okSE and sampev then
    local prevMsg = sampev.onServerMessage
    function sampev.onServerMessage(color, text)
        if T.autoDrugs[0] and type(text) == 'string' and
            (text:find(OSA.cp('У вас началась сильная ломка'), 1, true) or
             text:find(OSA.cp('Вашему персонажу нужно принять'), 1, true)) then
            sampSendChat('/usedrugs ' .. tostring(T.drugsCount[0]))
        end
        if prevMsg then return prevMsg(color, text) end
    end

    local prevBubble = sampev.onPlayerChatBubble
    function sampev.onPlayerChatBubble(pid, color, dist, duration, text)
        if T.streamChat[0] and type(text) == 'string' then
            pcall(function()
                local nick = sampGetPlayerNickname(pid) or ''
                local pc = string.sub(bit.tohex(sampGetPlayerColor(pid) or 0xFFFFFF, 8), 3, 8)
                local mc = string.sub(bit.tohex(color or 0xFFFFFF, 8), 3, 8)
                table.insert(OSA.chat, { name = '{' .. pc .. '}' .. nick .. ' [' .. pid .. ']', text = '{' .. mc .. '}' .. text })
                while #OSA.chat > 50 do table.remove(OSA.chat, 1) end
            end)
        end
        if prevBubble then return prevBubble(pid, color, dist, duration, text) end
    end

    local prevEnter = sampev.onSendEnterVehicle
    function sampev.onSendEnterVehicle(id, pass)
        if T.autoLock[0] then
            lua_thread.create(function()
                while not isCharInAnyCar(PLAYER_PED) do wait(0) end
                wait(250) sampSendChat('/lock')
                wait(500) sampSendChat('/key')
                wait(500) sampSendChat('/engine')
            end)
        end
        if prevEnter then return prevEnter(id, pass) end
    end

    local prevExit = sampev.onSendExitVehicle
    function sampev.onSendExitVehicle(id)
        if T.autoLock[0] then
            lua_thread.create(function()
                local ok, car = sampGetCarHandleBySampVehicleId(id)
                if ok and getCarDoorLockStatus(car) == 0 then sampSendChat('/lock') end
                wait(500)
                if isCharInAnyCar(PLAYER_PED) then sampSendChat('/key') end
            end)
        end
        if prevExit then return prevExit(id) end
    end
end

function OSA.tick()
    OSA.tickChat()
    OSA.tickFlip()
end


local function tick()
    ensureFonts()
    pcall(processCamera)
    pcall(processTrailer)
    pcall(processRender)
    pcall(RUN.tick)
    pcall(CW.tick)
    pcall(MKX.tick)
    pcall(OSA.tick)
    -- AirBrake: use MonetLoader's mobile analog-widget controls.
    if T.airbrake[0] and not airLastEnabled then
        airLastEnabled = true
        if not widgetsOK then msg('AirBrake: библиотека widgets недоступна') end
    elseif not T.airbrake[0] and airLastEnabled then
        airLastEnabled = false
        restoreAirBrake()
    end
    if T.airbrake[0] and widgetsOK then
        local airOk = pcall(processAirBrake)
        if not airOk then
            pcall(restoreAirBrake)
            T.airbrake[0] = false
            airLastEnabled = false
            msg('AirBrake отключён: ошибка управления')
        end
    end

    -- FlyCar uses the stock MonetLoader example controls, but follows Osiris toggle.
    if T.carFly[0] then
        flyWasOn = true
        pcall(processFlyCar)
    elseif flyWasOn then
        flyWasOn = false
        flySpeed = 0
        pcall(function()
            if flyLastCar and doesVehicleExist(flyLastCar) then
                setCarProofs(flyLastCar, false, false, false, false, false)
                setCharCanBeKnockedOffBike(flyLastCar, true)
            end
        end)
        flyLastCar = nil
    end

    -- Vehicle toggles (логика из Miku Project Reborn).
    if isCharInAnyCar and isCharInAnyCar(PLAYER_PED) then
        local car = storeCarCharIsInNoSave(PLAYER_PED)
        if T.carGod[0] then
            godWas = true
            pcall(setCarProofs, car, true, true, true, true, true)
        elseif godWas and not T.carFly[0] then
            godWas = false
            pcall(setCarProofs, car, false, false, false, false, false)
        end
        if T.carFuel[0] then pcall(switchCarEngine, car, true) end
        if T.carFastBrake[0] and widgetsOK and WIDGET_HORN and isWidgetPressed(WIDGET_HORN) then
            pcall(function()
                local x, y, z = getCarCoordinates(car)
                setCarCoordinates(car, x, y, z)
            end)
        end
        if T.carFastExit[0] and widgetsOK and WIDGET_ENTER_CAR and isWidgetPressed(WIDGET_ENTER_CAR) then
            pcall(function()
                local x, y, z = getCarCoordinates(car)
                warpCharFromCarToCoord(PLAYER_PED, x, y, z)
            end)
        end
        if T.carSpeedhack[0] and widgetsOK and isWidgetPressed(WIDGET_ACCELERATE) then
            if os.clock() - carSpdLast >= 0.01 then
                carSpdLast = os.clock()
                pcall(function()
                    local limit = math.max(1, math.min(600, T.carSpeed[0])) / 100
                    local mult = 1 + math.max(1, math.min(100, T.carAccel[0])) / 250
                    local vx, vy, vz = getCarSpeedVector(car)
                    local mag = math.sqrt(vx * vx + vy * vy)
                    if mag < 0.04 then
                        local hd = getCarHeading(car)
                        local fx, fy = getMoveSpeed(hd, 0.04)
                        vx, vy, mag = fx, fy, 0.04
                    end
                    local target = math.min(mag * mult, limit)
                    if target > mag then
                        local k = target / mag
                        setCarMoveSpeed(car, vx * k, vy * k, vz)
                    end
                end)
            end
        end
    end

    -- Player movement toggles (guarded to avoid calling missing APIs on builds that lack them).
    if T.speedhack[0] and type(getCharVelocity) == 'function' and type(setCharVelocity) == 'function' then
        pcall(function()
            if isCharInAnyCar(PLAYER_PED) then return end
            local x, y, z = getCharVelocity(PLAYER_PED)
            local mag = math.sqrt(x * x + y * y)
            if mag > 0.02 then
                local factor = 1 + math.max(0, math.min(100, T.speedVal[0])) / 25
                local nm = math.min(mag * factor, 1.5)
                setCharVelocity(PLAYER_PED, x / mag * nm, y / mag * nm, z)
            end
        end)
    end
    if T.jumphack[0] and type(setCharVelocity) == 'function' then
        pcall(function()
            local pressed = false
            if widgetsOK and WIDGET_JUMP and isWidgetPressed(WIDGET_JUMP) then pressed = true end
            if not pressed and type(isButtonPressed) == 'function' and isButtonPressed(PLAYER_HANDLE, 14) then pressed = true end
            if pressed and not isCharInAnyCar(PLAYER_PED) then
                local x, y, z = getCharVelocity(PLAYER_PED)
                setCharVelocity(PLAYER_PED, x, y, math.max(z, T.jumpVal[0] / 25))
            end
        end)
    end
    if not cjInit then cjInit = true; if T.noCJ[0] then CJ_DO = true end end
    if CJ_DO then
        CJ_DO = false
        pcall(function()
            if T.noCJ[0] then
                setAnimGroupForChar(PLAYER_PED, 'PLAYER')
            else
                setAnimGroupForChar(PLAYER_PED, isCharMale(PLAYER_PED) and 'MAN' or 'WOMAN')
            end
        end)
    end
    if T.twOn[0] then
        twWas = true
        if setTimeOfDay then setTimeOfDay(T.gameTime[0], 0) end
        if forceWeatherNow then forceWeatherNow(T.gameWeather[0]) end
    elseif twWas then
        twWas = false
        if releaseWeather then releaseWeather() end
    end
    -- Skinchanger (метод из Visual Skins): эмуляция RPC 153 + удержание скина
    if SKIN_APPLY then
        SKIN_APPLY = false
        if not SKIN_ORIG then pcall(function() SKIN_ORIG = getCharModel(PLAYER_PED) end) end
        SKIN_ID = T.skinId[0]
        SKIN_CHECK = 0
    end
    if SKIN_ID and os.clock() - SKIN_CHECK >= 0.5 then
        SKIN_CHECK = os.clock()
        pcall(function()
            if getCharModel(PLAYER_PED) ~= SKIN_ID then SKIN_SET(SKIN_ID) end
        end)
    end
    if SKIN_RESET then
        SKIN_RESET = false
        local o = SKIN_ORIG
        SKIN_ID = nil
        if o then pcall(SKIN_SET, o) end
    end
    if T.spammer[0] then
        if not spamWas then spamWas, spamSent, lastSpam = true, 0, 0 end
        if os.clock() - lastSpam >= T.spamDelay[0] / 1000 then
            lastSpam = os.clock()
            local txt = ffi.string(T.spamText)
            if txt ~= '' then sampSendChat(u8:decode(txt)) end
            spamSent = spamSent + 1
            if not T.spamInf[0] and spamSent >= T.spamCount[0] then T.spammer[0] = false end
        end
    else
        spamWas = false
    end
end

local function Popup(id, title, body, wd)
    imgui.SetNextWindowSize(V2(P(wd or 360), 0), imgui.Cond.Always)
    if imgui.BeginPopup(id) then
        imgui.SetWindowFontScale(WS)
        Section(title)
        body()
        imgui.EndPopup()
    end
end

local CP = imgui.new.float[3]()
local function ColorPick(key)
    local kr, kg, kb = key .. 'R', key .. 'G', key .. 'B'
    local function r8(x) return math.floor(x * 255 + 0.5) end
    if r8(CP[0]) ~= T[kr][0] or r8(CP[1]) ~= T[kg][0] or r8(CP[2]) ~= T[kb][0] then
        CP[0], CP[1], CP[2] = T[kr][0] / 255, T[kg][0] / 255, T[kb][0] / 255
    end
    imgui.PushItemWidth(P(280))
    if imgui.ColorPicker3('##cp' .. key, CP, 0) then
        T[kr][0], T[kg][0], T[kb][0] = r8(CP[0]), r8(CP[1]), r8(CP[2])
        if key == 'acc' then T.rainbow[0] = false end
    end
    imgui.PopItemWidth()
end

-- sampConnectToServer на Arizona Mobile вызывает нулевой указатель (SIGSEGV),
-- pcall это не ловит, поэтому нативный connect не используем.
-- Только дисконнект: клиент сам вернёт в меню/переподключит.
local function doReconnect()
    pcall(function()
        sampDisconnectWithReason(false)
    end)
    msg('Переподключение...')
end

local UPD = {
    VERSION = '1.1',
    VERSION_URL = 'https://raw.githubusercontent.com/MemphisCem/Osiris/refs/heads/main/version.txt',
    SCRIPT_URL  = 'https://raw.githubusercontent.com/MemphisCem/Osiris/refs/heads/main/main.lua',
    state = 'idle',
    overlay = false,
    available = false,
    ver = '', date = '', changes = {},
    err = '',
    startT = 0,
    res = nil,
    rect = { x = 0, y = 0, w = 0, h = 0, r = 0 },
}

UPD.jobs = {}
UPD.keep = {}
UPD.q = {}  -- очередь действий: скачивание запускается только из основного потока (main), не из imgui-кадра

function UPD.tmpName(prefix)
    UPD.seq = (UPD.seq or 0) + 1
    return getWorkingDirectory() .. '/' .. prefix .. os.time() .. '_' .. UPD.seq .. '.tmp'
end

function UPD.dl(url, tmp, cb)
    local okM, ml = pcall(require, 'moonloader')
    if not okM or not downloadUrlToFile then cb(false) return end
    local st = ml.download_status
    local fin = st.STATUSEX_ENDDOWNLOAD or st.STATUS_ENDDOWNLOADDATA
    local job = { tmp = tmp, cb = cb, t = os.clock(), done = false }
    local fn = function(id, status)
        if status == fin then job.done = true end
    end
    UPD.keep[#UPD.keep + 1] = fn
    local okD = pcall(downloadUrlToFile, url, tmp, fn)
    if not okD then cb(false) return end
    UPD.jobs[#UPD.jobs + 1] = job
end

function UPD.pump()
    while #UPD.q > 0 do
        local f = table.remove(UPD.q, 1)
        pcall(f)
    end
    if UPD.reloadAt and os.clock() >= UPD.reloadAt then
        UPD.reloadAt = nil
        thisScript():reload()
        return
    end
    for n = #UPD.jobs, 1, -1 do
        local job = UPD.jobs[n]
        local el = os.clock() - job.t
        if job.done and el > 0.3 then
            table.remove(UPD.jobs, n)
            job.cb(true)
        elseif el > 25 then
            table.remove(UPD.jobs, n)
            job.cb(false)
        end
    end
end

function UPD.parse(path)
    local f = io.open(path, 'r')
    if not f then return nil end
    local txt = f:read('*a')
    f:close()
    os.remove(path)
    local lines = {}
    for l in txt:gsub('\r', ''):gmatch('[^\n]+') do
        l = l:match('^%s*(.-)%s*$')
        if l ~= '' then lines[#lines + 1] = l end
    end
    if #lines == 0 then return nil end
    lines[1] = lines[1]:gsub('^\239\187\191', '')
    local info = { ver = lines[1], date = lines[2] or '', changes = {} }
    for k = 3, #lines do
        local c = lines[k]:gsub('^[%-%*]%s*', ''):gsub('^%d+[%)%.]%s*', '')
        info.changes[#info.changes + 1] = c
    end
    return info
end

function UPD.apply(silent)
    local r = UPD.res
    UPD.res = nil
    if not r or not r.ok then
        UPD.state = silent and 'idle' or 'error'
        UPD.err = 'Не удалось проверить обновления'
        return
    end
    local i = r.info
    UPD.ver, UPD.date, UPD.changes = i.ver, i.date, i.changes
    if i.ver ~= UPD.VERSION then
        UPD.available = true
        UPD.state = 'found'
        if silent then msg('Доступно обновление v' .. i.ver .. ': Setting - Обновления') end
    else
        UPD.available = false
        UPD.state = 'none'
    end
end

function UPD.check(silent)
    if UPD.state == 'checking' or UPD.state == 'downloading' or UPD.state == 'done' or UPD.queued then return end
    if not silent then
        UPD.state = 'checking'
        UPD.overlay = true
        UPD.startT = os.clock()
    end
    UPD.res = nil
    UPD.queued = true
    UPD.q[#UPD.q + 1] = function()
        UPD.queued = false
        local tmp = UPD.tmpName('osiris_v_')
        UPD.dl(UPD.VERSION_URL, tmp, function(ok)
            local info = ok and UPD.parse(tmp) or nil
            UPD.res = { ok = info ~= nil and info.ver ~= '', info = info }
            if silent then UPD.apply(true) end
        end)
    end
end

function UPD.start()
    UPD.state = 'downloading'
    UPD.q[#UPD.q + 1] = function()
    local tmp = UPD.tmpName('osiris_n_')
    UPD.dl(UPD.SCRIPT_URL, tmp, function(ok)
        local data
        if ok then
            local f = io.open(tmp, 'rb')
            if f then data = f:read('*a') f:close() end
            os.remove(tmp)
        end
        if not data or not data:find('script_name') then
            UPD.state = 'error'
            UPD.err = 'Не удалось скачать обновление'
            return
        end
        local out = io.open(thisScript().path, 'wb')
        if not out then
            UPD.state = 'error'
            UPD.err = 'Не удалось записать файл'
            return
        end
        out:write(data)
        out:close()
        UPD.state = 'done'
        UPD.reloadAt = os.clock() + 2
    end)
    end
end

function UPD.sec()
    Section('Обновления')
    imgui.TextColored(V4(G(0.7), G(0.7), G(0.7), 1), 'Текущая версия: v' .. UPD.VERSION)
    if UPD.available then
        imgui.TextColored(V4(ACC.r, ACC.g, ACC.b, 1), 'Доступна новая версия: v' .. UPD.ver)
    elseif UPD.state == 'none' then
        imgui.TextColored(V4(0.4, 0.9, 0.4, 1), 'Вы на последней версии')
    end
    imgui.Dummy(V2(0, P(6)))
    if imgui.Button('Проверить на наличие обновлений', V2(-1, P(52))) then UPD.check(false) end
    if UPD.available then
        imgui.Dummy(V2(0, P(4)))
        if imgui.Button('Показать обновление', V2(-1, P(52))) then UPD.overlay = true end
    end
    imgui.Dummy(V2(0, P(6)))
end

local TABS = { 'Main', 'ESP', 'Car', 'Bot', 'Auto', 'Chat', 'Setting' }
local ICONS = { 1, 2, 3, 4, 8, 7, 5 }
local curTab = 1
local SIZES = { 80, 100, 125, 150 }
local CORNERS = { 'Слева сверху', 'Справа сверху', 'Слева снизу', 'Справа снизу' }

local function secAppearance()
    Section('Внешний вид')
    ButtonGrid('size', { 'Малый', 'Средний', 'Большой', 'Огромный' }, 4,
        function(i) return T.scale[0] == SIZES[i] end,
        function(i) T.scale[0] = SIZES[i] end)
    SliderRow('scale', 'Размер меню', 60, 200, '%d%%')
    SliderRow('textScale', 'Размер текста', 80, 140, '%d%%')
    SliderRow('rounding', 'Скругление углов', 0, 30, '%d')
    SliderRow('bgAlpha', 'Непрозрачность фона', 40, 100, '%d%%')
    imgui.Dummy(V2(0, P(6)))
end

local function secAccent()
    Section('Акцентный цвет')
    ColorPreview()
    Swatches()
    if imgui.Button('Выбрать любой цвет', V2(imgui.GetContentRegionAvail().x, imgui.GetTextLineHeight() + P(18))) then
        imgui.OpenPopup('p_acc')
    end
    Popup('p_acc', 'Выбор цвета', function() ColorPick('acc') end)
    Section('Тема')
    ButtonGrid('theme', { 'Тёмная', 'Светлая' }, 2,
        function(i) return T.light[0] == (i == 2) end,
        function(i)
            T.light[0] = (i == 2)
            if i == 2 and T.accR[0] + T.accG[0] + T.accB[0] > 600 then
                T.rainbow[0] = false
                T.accR[0], T.accG[0], T.accB[0] = 84, 124, 255
            end
        end)
    imgui.Dummy(V2(0, P(4)))
    Toggle('rainbow', 'Радужный акцент')
    SliderRow('rainbowSpeed', 'Скорость смены цвета', 5, 100, '%d%%', nil, not T.rainbow[0])
    imgui.Dummy(V2(0, P(6)))
end

local function secWatermark()
    if T.wmScale[0] < 1 then T.wmScale[0] = 1 end
    if T.wmScale[0] > 100 then T.wmScale[0] = 100 end
    Section('Ватермарка')
    Toggle('wmShow', 'Показывать ватермарку')
    ButtonGrid('corner', CORNERS, 2,
        function(i) return T.wmCorner[0] == i - 1 end,
        function(i) T.wmCorner[0] = i - 1 end)
    imgui.Dummy(V2(0, P(2)))
    SliderRow('wmScale', 'Размер ватермарки', 1, 100, '%d%%')
    SliderRow('wmAlpha', 'Непрозрачность', 20, 100, '%d%%')
    SliderRow('wmMargin', 'Отступ от края', 0, 120, '%d')
    Toggle('wmFps', 'Показывать FPS')
    Toggle('wmPing', 'Показывать пинг')
    Toggle('wmTime', 'Показывать время')
    imgui.Dummy(V2(0, P(6)))
end

local function secEffects()
    Section('Эффекты')
    Toggle('fxAnim', 'Анимация открытия меню')
    Toggle('fxGlow', 'Свечение меню')
    Toggle('fxLine', 'Акцентная линия сверху')
    Toggle('fxBorder', 'Обводка меню')
    Toggle('wmGlow', 'Свечение ватермарки')
    Toggle('wmShine', 'Блик на ватермарке')
    Toggle('wmPulse', 'Пульсация иконки')
    imgui.Dummy(V2(0, P(6)))
end

-- верхние вкладки внутри каждой вкладки слева
local SUBS = {
    { 'Character', 'Camera' },
    { 'Main', 'Car', 'Render' },
    { 'Main', 'Attach Trailer' },
    { 'Шахта', 'ТСР', 'НФерма', 'ФермаЛИХ', 'Автобус', 'Завод' },
    {},
    {},
    { 'Внешний вид', 'Цвет', 'Ватермарка', 'Эффекты', 'Обновления' },
}
local subTab = { 1, 1, 1, 1, 1, 1, 1 }

-- иконки вкладок (рисуются вручную)
function drawTabIcon(dl, kind, cx, cy, r, col)
    local th = math.max(1.5, r * 0.18)
    if kind == 1 then -- домик
        dl:AddLine(V2(cx - r, cy - r * 0.05), V2(cx, cy - r), col, th)
        dl:AddLine(V2(cx, cy - r), V2(cx + r, cy - r * 0.05), col, th)
        dl:AddRect(V2(cx - r * 0.68, cy - r * 0.05), V2(cx + r * 0.68, cy + r * 0.9), col, r * 0.12, 0, th)
        dl:AddRectFilled(V2(cx - r * 0.18, cy + r * 0.3), V2(cx + r * 0.18, cy + r * 0.9), col, r * 0.06)
    elseif kind == 2 then -- глаз
        local n = 16
        local px, pu, pl
        for i = 0, n do
            local x = cx - r + 2 * r * i / n
            local k = math.sin(math.pi * i / n) * r * 0.62
            local cu, cl = V2(x, cy - k), V2(x, cy + k)
            if pu then
                dl:AddLine(pu, cu, col, th)
                dl:AddLine(pl, cl, col, th)
            end
            pu, pl = cu, cl
        end
        dl:AddCircleFilled(V2(cx, cy), r * 0.3, col, 20)
    elseif kind == 3 then -- машина
        dl:AddRect(V2(cx - r, cy - r * 0.1), V2(cx + r, cy + r * 0.55), col, r * 0.2, 0, th)
        dl:AddLine(V2(cx - r * 0.6, cy - r * 0.1), V2(cx - r * 0.35, cy - r * 0.62), col, th)
        dl:AddLine(V2(cx - r * 0.35, cy - r * 0.62), V2(cx + r * 0.35, cy - r * 0.62), col, th)
        dl:AddLine(V2(cx + r * 0.35, cy - r * 0.62), V2(cx + r * 0.6, cy - r * 0.1), col, th)
        dl:AddCircleFilled(V2(cx - r * 0.5, cy + r * 0.58), r * 0.24, col, 16)
        dl:AddCircleFilled(V2(cx + r * 0.5, cy + r * 0.58), r * 0.24, col, 16)
    elseif kind == 4 then -- бот
        dl:AddRect(V2(cx - r * 0.85, cy - r * 0.4), V2(cx + r * 0.85, cy + r * 0.85), col, r * 0.25, 0, th)
        dl:AddLine(V2(cx, cy - r * 0.4), V2(cx, cy - r * 0.85), col, th)
        dl:AddCircleFilled(V2(cx, cy - r * 0.92), r * 0.14, col, 12)
        dl:AddCircleFilled(V2(cx - r * 0.38, cy + r * 0.2), r * 0.17, col, 14)
        dl:AddCircleFilled(V2(cx + r * 0.38, cy + r * 0.2), r * 0.17, col, 14)
    elseif kind == 8 then -- молния для Auto
        dl:AddLine(V2(cx + r * 0.18, cy - r), V2(cx - r * 0.42, cy + r * 0.08), col, th * 1.35)
        dl:AddLine(V2(cx - r * 0.42, cy + r * 0.08), V2(cx + r * 0.02, cy + r * 0.08), col, th * 1.35)
        dl:AddLine(V2(cx + r * 0.02, cy + r * 0.08), V2(cx - r * 0.18, cy + r), col, th * 1.35)
        dl:AddLine(V2(cx - r * 0.18, cy + r), V2(cx + r * 0.42, cy - r * 0.12), col, th * 1.35)
        dl:AddLine(V2(cx + r * 0.42, cy - r * 0.12), V2(cx + r * 0.02, cy - r * 0.12), col, th * 1.35)
        dl:AddLine(V2(cx + r * 0.02, cy - r * 0.12), V2(cx + r * 0.18, cy - r), col, th * 1.35)
    elseif kind == 7 then -- чат
        dl:AddRect(V2(cx - r, cy - r * 0.8), V2(cx + r, cy + r * 0.4), col, r * 0.3, 0, th)
        dl:AddLine(V2(cx - r * 0.45, cy + r * 0.4), V2(cx - r * 0.6, cy + r * 0.95), col, th)
        dl:AddLine(V2(cx - r * 0.6, cy + r * 0.95), V2(cx + r * 0.05, cy + r * 0.4), col, th)
        for i = -1, 1 do dl:AddCircleFilled(V2(cx + i * r * 0.45, cy - r * 0.2), r * 0.13, col, 10) end
    else -- шестерёнка
        for i = 0, 7 do
            local a = i * math.pi / 4
            local ca, sa = math.cos(a), math.sin(a)
            dl:AddLine(V2(cx + ca * r * 0.62, cy + sa * r * 0.62), V2(cx + ca * r, cy + sa * r), col, th * 1.6)
        end
        dl:AddCircle(V2(cx, cy), r * 0.62, col, 24, th)
        dl:AddCircleFilled(V2(cx, cy), r * 0.2, col, 14)
    end
end

-- боковая панель с вкладками
local function Sidebar()
    imgui.SetWindowFontScale(WS)
    local dl = imgui.GetWindowDrawList()
    local th = imgui.GetTextLineHeight()
    local w = imgui.GetContentRegionAvail().x
    local h = th + P(38)
    for i, name in ipairs(TABS) do
        local pos = imgui.GetCursorScreenPos()
        imgui.InvisibleButton('##side' .. i, V2(w, h))
        if imgui.IsItemClicked(0) then curTab = i end
        local hov = hoverAnim('sh' .. i, imgui.IsItemHovered())
        local sel = (curTab == i) and 1 or 0
        HV['ss' .. i] = lerp(HV['ss' .. i] or sel, sel, math.min(1, imgui.GetIO().DeltaTime * 14))
        local t = HV['ss' .. i]

        local p2 = V2(pos.x + w, pos.y + h)
        dl:AddRectFilled(pos, p2, U32(1, 1, 1, 0.05 * hov * (1 - t)), P(12))
        if t > 0.01 then
            dl:AddRectFilled(pos, p2, AC(0.14 * t), P(12))
            dl:AddRect(pos, p2, AC(0.9 * t), P(12))
            local bh = (h - P(16)) * t
            dl:AddRectFilled(V2(pos.x + P(5), pos.y + h / 2 - bh / 2), V2(pos.x + P(8), pos.y + h / 2 + bh / 2), AC(t), P(2))
        end
        local g = G(0.68)
        local col = RAW(lerp(g, ACC.r, t), lerp(g, ACC.g, t), lerp(g, ACC.b, t), 1)
        drawTabIcon(dl, ICONS[i], pos.x + P(36), pos.y + h / 2, P(14), col)
        local ts = imgui.CalcTextSize(name)
        local tg = lerp(0.78, 1, t)
        dl:AddText(V2(pos.x + P(64), pos.y + (h - ts.y) / 2), U32(tg, tg, tg, 1), name)
    end
end

-- верхние вкладки внутри выбранной вкладки
local function SubTabsBar()
    local dl = imgui.GetWindowDrawList()
    local th = imgui.GetTextLineHeight()
    local list = SUBS[curTab]
    if #list == 0 then return end
    if subTab[curTab] > #list then subTab[curTab] = 1 end
    local start = imgui.GetCursorScreenPos()
    local w = imgui.GetContentRegionAvail().x
    local h = th + P(18)
    local x = start.x
    for i, name in ipairs(list) do
        local ts = imgui.CalcTextSize(name)
        local tw = ts.x + P(38)
        local key = 'sub' .. curTab .. '_' .. i
        imgui.SetCursorScreenPos(V2(x, start.y))
        imgui.InvisibleButton('##' .. key, V2(tw, h))
        if imgui.IsItemClicked(0) then subTab[curTab] = i end
        local hov = hoverAnim(key .. 'h', imgui.IsItemHovered())
        local sel = (subTab[curTab] == i) and 1 or 0
        HV[key] = lerp(HV[key] or sel, sel, math.min(1, imgui.GetIO().DeltaTime * 14))
        local t = HV[key]

        local p1, p2 = V2(x, start.y), V2(x + tw, start.y + h)
        if t > 0.02 then glow(dl, p1.x, p1.y, p2.x, p2.y, h / 2, P(8), 0.035 * t) end
        local base = G(0.10) + (LIGHT and -0.05 or 0.05) * hov
        dl:AddRectFilled(p1, p2, RAW(lerp(base, ACC.r, t), lerp(base, ACC.g, t), lerp(base, ACC.b, t), 1), h / 2)
        if t < 0.98 then
            dl:AddRect(p1, p2, U32(1, 1, 1, (0.07 + 0.12 * hov) * (1 - t)), h / 2)
        end
        local c0 = G(0.92)
        dl:AddText(V2(x + (tw - ts.x) / 2, start.y + (h - ts.y) / 2),
            RAW(lerp(c0, ACC.on[1], t), lerp(c0, ACC.on[2], t), lerp(c0, ACC.on[3], t), 1), name)
        x = x + tw + P(8)
    end
    imgui.SetCursorScreenPos(start)
    imgui.Dummy(V2(w, h))
    local lp = imgui.GetCursorScreenPos()
    dl:AddLine(V2(lp.x, lp.y + P(2)), V2(lp.x + w, lp.y + P(2)), U32(1, 1, 1, 0.08), 1)
    imgui.Dummy(V2(1, P(6)))
end

local function secMain()
    Toggle('silentaim', 'SilentAim', 'p_sa')
    Popup('p_sa', 'SilentAim', function()
        SliderRow('saFov', 'FOV', 1, 180, '%d')
        SliderRow('saRange', 'Дальность', 10, 300, '%d')
    end)
    Toggle('rapid', 'Rapid', 'p_rapid')
    Popup('p_rapid', 'Rapid', function() SliderRow('rapidSpeed', 'Скорость', 1, 100, '%d') end)
    Toggle('blockWeather', 'Block Server Weather')
    Toggle('metkatp', 'MetkaTP')
    Toggle('antimask', 'Anti-Mask')
    Toggle('antifreeze', 'Anti-Freeze')
    Toggle('anticaptcha', 'Anti-Captcha')
    imgui.PushStyleColor(imgui.Col.Button, V4(ACC.r, ACC.g, ACC.b, 1))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, V4(ACC.r, ACC.g, ACC.b, 0.85))
    imgui.PushStyleColor(imgui.Col.ButtonActive, V4(ACC.r, ACC.g, ACC.b, 0.65))
    imgui.PushStyleColor(imgui.Col.Text, V4(ACC.on[1], ACC.on[2], ACC.on[3], 1))
    if imgui.Button('Reconnect', V2(imgui.GetContentRegionAvail().x, imgui.GetTextLineHeight() + P(18))) then doReconnect() end
    imgui.PopStyleColor(4)
    imgui.Dummy(V2(0, P(6)))
end

local function secCamera()
    Toggle('cameraFov', 'FOV', 'p_camera_fov')
    Popup('p_camera_fov', 'FOV settings', function()
        SliderRow('cameraFovValue', 'Camera FOV', 50, 130, '%d')
    end)
    Toggle('freeCam', 'Free Cam', 'p_freecam')
    Popup('p_freecam', 'Free Cam settings', function()
        SliderRow('freeCamSpeed', 'Скорость камеры', 1, 200, '%d%%')
        Toggle('camHideHud', 'Скрывать HUD в режиме камеры')
        Toggle('camHideNicks', 'Скрывать ники в режиме камеры')
        Toggle('camBubbles', 'Видеть текст над головой (дальность)')
        imgui.TextDisabled('Джойстик — движение, стрелки up/down — высота')
        imgui.TextDisabled('Стрелки по бокам — поворот, + / - — скорость')
        imgui.TextDisabled('Кнопка X (отмена) — выход из камеры')
    end)
    imgui.Dummy(V2(0, P(6)))
end

OSA.sec = function()
    Toggle('autoDrugs', 'Auto Drugs', 'p_adrugs')
    Popup('p_adrugs', 'Auto Drugs', function() SliderRow('drugsCount', 'Количество', 1, 30, '%d') end)
    Toggle('autoLock', 'Auto Lock Car')
    Toggle('autoFill', 'Auto Fill', 'p_afill')
    Popup('p_afill', 'Auto Fill', function() SliderRow('fillTo', 'Заправлять до (л)', 1, 200, '%d') end)
    Toggle('autoDomkrat', 'Auto Domkrat')
end


local function secCharacter()
    Toggle('speedhack', 'SpeedHack', 'p_speed')
    Popup('p_speed', 'SpeedHack', function() SliderRow('speedVal', 'Скорость', 1, 100, '%d') end)
    Toggle('jumphack', 'JumpHack', 'p_jump')
    Popup('p_jump', 'JumpHack', function() SliderRow('jumpVal', 'Высота прыжка', 1, 100, '%d') end)
    Toggle('airbrake', 'AirBrake')
    GearRow('Время и погода', 'p_tw')
    Popup('p_tw', 'Время и погода', function()
        Toggle('twOn', 'Применять время и погоду')
        SliderRow('gameTime', 'Время (час)', 0, 23, '%d')
        SliderRow('gameWeather', 'ID погоды', 0, 45, '%d')
    end)
    GearRow('Skinchanger', 'p_skin')
    Popup('p_skin', 'Skinchanger', function()
        IntRow('skinId', 'ID скина', 0, 30000)
        imgui.BeginChild('##skinlist', V2(0, P(300)), true)
        for _, sk in ipairs(SKIN_LIST) do
            if imgui.Selectable(sk[1] .. ' - ' .. sk[2], T.skinId[0] == sk[1]) then
                T.skinId[0] = sk[1]
                SKIN_APPLY = true
            end
        end
        imgui.EndChild()
        if imgui.Button('Применить', V2(imgui.GetContentRegionAvail().x, imgui.GetTextLineHeight() + P(18))) then SKIN_APPLY = true end
        if imgui.Button('Сбросить', V2(imgui.GetContentRegionAvail().x, imgui.GetTextLineHeight() + P(18))) then SKIN_RESET = true end
    end)

    -- Остальные функции прежней вкладки Main возвращены в Character.
    Toggle('silentaim', 'SilentAim', 'p_sa')
    Popup('p_sa', 'SilentAim', function()
        SliderRow('saFov', 'FOV', 1, 180, '%d')
        SliderRow('saRange', 'Дальность', 10, 300, '%d')
    end)
    Toggle('rapid', 'Rapid', 'p_rapid')
    Popup('p_rapid', 'Rapid', function() SliderRow('rapidSpeed', 'Скорость', 1, 100, '%d') end)
    Toggle('blockWeather', 'Block Server Weather')
    Toggle('metkatp', 'MetkaTP')
    Toggle('antimask', 'Anti-Mask')
    Toggle('antifreeze', 'Anti-Freeze')
    Toggle('anticaptcha', 'Anti-Captcha')
    Toggle('streamChat', 'Stream Chat')
    Toggle('clickWarp', 'ClickWarp')
    Toggle('customRun', 'Кастомный бег', 'p_customrun')
    Popup('p_customrun', 'Кастомный бег', function()
        Toggle('infRun', 'Бесконечный бег')
        Toggle('autoRun', 'Автобег')
        for i, s in ipairs(RUN.sets) do
            if imgui.RadioButtonBool(s[1] .. '##rs' .. i, T.runSet[0] == i) then T.runSet[0] = i end
        end
    end)
    imgui.PushStyleColor(imgui.Col.Button, V4(ACC.r, ACC.g, ACC.b, 1))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, V4(ACC.r, ACC.g, ACC.b, 0.85))
    imgui.PushStyleColor(imgui.Col.ButtonActive, V4(ACC.r, ACC.g, ACC.b, 0.65))
    imgui.PushStyleColor(imgui.Col.Text, V4(ACC.on[1], ACC.on[2], ACC.on[3], 1))
    if imgui.Button('Reconnect', V2(imgui.GetContentRegionAvail().x, imgui.GetTextLineHeight() + P(18))) then doReconnect() end
    imgui.PopStyleColor(4)
    imgui.Dummy(V2(0, P(6)))
end

local function colorToggle(id, title)
    Toggle(id, title, 'p_' .. id)
    Popup('p_' .. id, title .. ' — цвет', function() ColorPick(id) end)
end

local function secEspPlayers()
    colorToggle('espPBox', 'Box')
    colorToggle('espPSkel', 'Skeleton')
    colorToggle('espPNick', 'Nick & HP/Armour')
    colorToggle('espPTrace', 'Tracers')
    colorToggle('espPDist', 'Distance')
    imgui.Dummy(V2(0, P(6)))
end

local function secEspCars()
    colorToggle('espCBox', 'Box')
    colorToggle('espCDist', 'Distance')
    Toggle('espCStatus', 'Status (Lock / Unlock)')
    colorToggle('espCName', 'Name Car')
    imgui.Dummy(V2(0, P(6)))
end

local function secCar()
    Toggle('carGod', 'Vehicle God Mode')
    Toggle('carFuel', 'Infinite Fuel')
    Toggle('carFastExit', 'Fast Exit')
    Toggle('carFly', 'CarFly')
    Toggle('carNoBike', 'NoBike')
    Toggle('carFastBrake', 'Fast Brake')
    Toggle('carSpeedhack', 'SpeedHack', 'p_carspeed')
    Popup('p_carspeed', 'Car SpeedHack', function()
        SliderRow('carSpeed', 'Скорость', 1, 600, '%d')
        SliderRow('carAccel', 'Ускорение', 1, 100, '%d')
    end)
    imgui.Dummy(V2(0, P(6)))
end

local function secCarTrailer()
    Toggle('attachTrailer', 'Attach Trailer')
    SliderRow('trailerRadius', 'Радиус выбора', 40, 500, '%d')
    imgui.TextDisabled('Наведите рамку на прицеп и нажмите кнопку «Прицепить / Отцепить» внизу экрана.')
    imgui.Dummy(V2(0, P(6)))
end

local function secEspRender()
    Section('Render')
    Toggle('renderRuda', 'Руда')
    Toggle('renderDeer', 'Олень')
    Toggle('renderHighTree', 'Дерево высшего качества')
    Toggle('renderGift', 'Подарки')
    Toggle('renderStash', 'Клад')
    Toggle('renderApple', 'Яблочные деревья')
    Toggle('renderPlum', 'Сливовые деревья')
    Toggle('renderCoconut', 'Кокосы')
    Toggle('renderTrash', 'Мусор')
    Toggle('renderGraffiti', 'Граффити')
    imgui.Dummy(V2(0, P(6)))
end

local function secChat()
    Toggle('spammer', 'Spammer', 'p_spam')
    Popup('p_spam', 'Spammer', function()
        InputRow('spamText', 'Текст сообщения')
        SliderRow('spamDelay', 'Задержка (мс)', 200, 10000, '%d')
        Toggle('spamInf', 'Бесконечно')
        IntRow('spamCount', 'Сколько раз отправить (цифрами)', 1, 100000)
        imgui.TextDisabled(('Отправлено: %d'):format(spamSent))
    end)
    local w = imgui.GetContentRegionAvail().x
    if imgui.Button('Logger — открыть лог чата', V2(w, imgui.GetTextLineHeight() + P(20))) then
        imgui.OpenPopup('p_log')
    end
    Popup('p_log', 'Logger', LogBody, 760)
    imgui.Dummy(V2(0, P(6)))
end

local secBotMine, secBotFarm, secBotLih, secBotBus, secBotTsr, secBotZavod
-- Блок ботов вынесен в функцию: лимит Lua 200 локальных переменных на главный чанк.
local function __botSection()
local BOT = { cur = 1, rt = nil, ore = {}, arr = {}, jumpAt = 0, ore_busy = false,
              hay = 0, mv = false, tx = 0, ty = 0, tz = 0, farmOn = false }
for _, k in ipairs({ 'botMine', 'botMineNoCol', 'botMineEsp', 'botMineStopDlg', 'botFarm', 'botFarmCaptcha', 'botFarmEsp' }) do
    T[k] = imgui.new.bool(false)
end
BOT.routeA = {
{478.113,875.681,-30.237},{479.266,875.782,-30.353},{480.428,875.651,-30.453},{481.136,874.713,-30.490},{481.659,873.663,-30.507},{482.198,872.558,-30.525},
{482.740,871.487,-30.543},{483.294,870.437,-30.564},{483.886,869.352,-30.598},{484.461,868.316,-30.713},{485.053,867.260,-30.645},{485.636,866.230,-30.494},
{486.236,865.193,-30.343},{486.858,864.142,-30.191},{487.481,863.120,-30.081},{488.111,862.112,-30.051},{488.813,861.068,-30.019},{489.895,860.597,-29.994},
{490.893,859.942,-29.966},{491.696,859.105,-29.937},{492.367,858.134,-29.907},{493.045,857.054,-29.874},{493.824,856.171,-29.844},{494.613,855.292,-29.815},
{495.378,854.406,-29.818},{496.112,853.498,-29.837},{496.533,852.363,-29.862},{496.953,851.310,-29.885},{497.482,850.281,-29.908},{498.062,849.219,-29.792},
{498.762,848.294,-29.653},{499.771,847.704,-29.585},{500.822,847.079,-29.512},{501.699,846.261,-29.424},{502.544,845.381,-29.358},{503.365,844.497,-29.290},
{504.110,843.694,-29.228},{504.993,842.741,-29.155},{505.784,841.815,-28.919},{506.481,840.812,-28.627},{507.165,839.860,-28.352},{507.986,838.898,-28.086},
{508.748,837.878,-27.743},{509.263,836.975,-27.297},{509.865,835.966,-26.911},{510.613,834.932,-26.622},{511.444,833.973,-26.359},{512.333,833.085,-26.118},
{513.341,832.348,-25.927},{514.388,831.631,-25.801},{515.413,830.834,-25.758},{516.173,829.871,-25.655},{516.864,828.758,-25.565},{517.366,827.608,-25.508},
{517.332,826.356,-25.379},{517.303,825.044,-25.244},{517.867,823.891,-25.194},{518.486,822.757,-25.152},{519.009,821.649,-25.102},{518.933,820.385,-24.967},
{518.652,819.186,-24.814},{518.455,817.932,-24.666},{517.796,816.872,-24.483},{516.879,816.111,-24.274},{515.882,815.230,-24.102},{515.120,814.207,-24.012},
{514.473,813.295,-23.548},{513.792,812.270,-23.338},{513.315,811.188,-23.172},{512.772,810.040,-22.992},{512.004,809.035,-22.806},{511.140,808.142,-22.628},
{510.110,807.427,-22.449},{509.117,806.820,-22.283},{508.082,806.090,-22.102},{507.144,805.348,-21.945},{506.160,804.659,-21.945},{505.079,803.973,-21.945},
{504.438,802.972,-21.945},{504.763,801.757,-21.945},{505.443,800.788,-21.945},{506.182,799.820,-21.945},{507.202,799.013,-21.945},{508.334,798.664,-21.945},
{509.567,798.405,-21.945},{510.843,798.544,-21.945},{512.083,798.660,-21.945},{513.336,798.654,-21.992},{514.493,798.299,-22.084},{515.311,797.439,-21.895},
{516.261,796.724,-21.846},{517.461,796.426,-21.805},{518.681,796.556,-21.779},{519.849,796.387,-21.744},{520.962,796.059,-21.705},{522.160,795.736,-21.649},
{523.317,795.410,-21.545},{524.483,795.052,-21.432},{525.446,794.477,-21.277},{526.302,793.653,-21.069},{527.224,792.845,-20.906},{528.186,792.120,-20.860},
{529.128,791.435,-20.814},{530.163,790.707,-20.762},{531.169,790.032,-20.666},{532.233,789.341,-20.538},{533.250,788.714,-20.412},{534.310,788.115,-20.281},
{535.429,787.499,-20.144},{536.489,786.953,-20.016},{537.582,786.466,-19.885},{538.703,785.940,-19.751},{539.756,785.378,-19.623},{540.807,784.814,-19.494},
{541.833,784.300,-19.370},{543.044,784.345,-19.244},{544.272,784.502,-19.118},{545.282,785.198,-19.033},{545.539,786.389,-19.042},{545.460,787.650,-19.088},
{545.096,788.840,-19.300},{544.706,789.982,-19.586},{544.575,791.197,-19.880},{544.887,792.494,-20.130},{545.221,793.658,-20.338},{545.167,794.518,-21.311},
{545.332,795.234,-22.456},{546.117,795.790,-23.552},{547.208,796.141,-24.124},{548.318,796.402,-24.524},{549.567,796.609,-24.954},{550.734,796.756,-25.345},
{551.869,796.872,-25.719},{553.140,796.960,-26.128},{554.288,797.019,-26.492},{555.547,797.071,-26.833},{556.765,797.111,-27.142},{557.978,797.148,-27.450},
{559.283,797.232,-27.782},{560.465,797.732,-28.088},{561.744,798.013,-28.094},{562.959,797.842,-28.056},{564.145,797.545,-28.154},{565.369,797.223,-28.255},
{566.601,796.920,-28.357},{567.944,796.676,-28.465},{569.201,796.494,-28.566},{570.478,796.302,-28.668},{571.812,796.093,-28.775},{573.023,796.412,-28.859},
{574.223,796.718,-28.942},{575.412,796.808,-29.030},{576.726,796.857,-29.129},{578.061,796.883,-29.283},{579.249,796.880,-29.442},{580.533,796.855,-29.615},
{581.708,796.729,-29.777},{582.993,796.412,-29.962},{584.197,796.114,-30.122},{585.427,795.832,-30.265},{586.716,795.537,-30.416},{587.934,795.252,-30.559},
{589.153,794.923,-30.702},{590.367,794.535,-30.845},{591.540,794.159,-30.982},{592.769,793.789,-31.127},{593.925,793.444,-31.263},{595.105,793.080,-31.401},
{596.357,792.657,-31.549},{597.474,792.262,-31.680},{598.728,791.804,-31.828},{599.871,791.385,-31.963},{600.980,790.971,-32.071},{602.144,790.491,-32.072},
{603.275,790.065,-32.073},{604.531,789.678,-32.073},{605.741,789.312,-32.074},{606.893,788.963,-32.074},{608.155,788.581,-32.074},{609.286,788.239,-32.074},
{610.464,787.882,-32.073},{611.618,787.542,-32.073},{612.779,787.220,-32.072},{613.987,786.888,-32.072},{615.125,786.576,-32.071},{616.370,786.234,-32.070},
{617.598,785.886,-32.070},{618.800,785.508,-32.069},{620.042,785.256,-32.008},{621.243,785.138,-31.903},{622.433,785.030,-31.800},{623.652,784.919,-31.694},
{624.861,784.810,-31.589},{626.142,784.694,-31.477},{627.387,784.532,-31.369},{628.539,784.256,-31.273},{629.761,784.011,-31.183},{630.963,783.925,-31.093},
{632.208,783.901,-30.998},{633.374,783.884,-30.910},{634.567,783.702,-30.822},{635.691,783.118,-30.745},{636.797,782.671,-30.668},{637.973,782.403,-30.582},
{639.189,782.189,-30.493},{640.469,782.034,-30.398},{641.704,781.933,-30.305},{642.880,781.859,-30.226},{644.081,782.036,-30.226},{645.213,782.446,-30.225},
{646.378,782.689,-30.224},{647.600,782.898,-30.223},{648.858,783.111,-30.223},{650.137,783.336,-30.223},{651.398,783.578,-30.223},{652.658,783.776,-30.223},
{653.977,783.830,-30.223},{655.206,784.036,-30.223},{656.468,784.302,-30.223},{657.634,784.549,-30.222},{658.839,784.821,-30.222},{660.107,785.186,-30.222},
{661.314,785.556,-30.222},{662.554,785.957,-30.221},{663.709,786.253,-30.221},{664.917,786.312,-30.223},{666.224,786.382,-30.224},{667.482,786.495,-30.225},
{668.759,786.662,-30.226},{669.954,786.871,-30.227},{670.952,787.106,-30.228},{672.225,787.456,-30.228},{673.442,787.802,-30.230},{674.630,788.169,-30.233},
{675.841,788.619,-30.235},{676.983,789.082,-30.235},{678.145,789.581,-30.234},{679.282,790.110,-30.234},{680.386,790.676,-30.233},{681.484,791.322,-30.233},
{682.517,791.983,-30.232},{683.601,792.700,-30.231},{684.622,793.380,-30.230},{685.747,793.826,-30.230},{687.007,794.208,-30.232},{688.080,794.631,-30.234},
{689.132,795.229,-30.235},{690.159,795.851,-30.235},{691.184,796.497,-30.234},{692.082,797.337,-30.234},{692.666,798.354,-30.232},{693.194,799.378,-30.230},
{693.788,800.522,-30.228},{694.374,801.588,-30.226},{695.013,802.727,-30.144},{695.623,803.797,-29.898},{696.257,804.862,-29.849},{696.829,806.032,-29.831},
{697.407,807.006,-29.821},{698.173,808.063,-29.819},{698.918,809.104,-29.816},{699.566,810.113,-29.808},{700.213,811.211,-29.794},{700.898,812.243,-29.787},
{701.614,813.265,-29.783},{702.271,814.252,-29.777},{702.918,815.319,-29.951},{703.542,816.365,-30.222},{704.175,817.394,-30.222},{704.809,818.451,-30.223},
{705.370,819.580,-30.223},{705.944,820.692,-30.224},{706.640,821.797,-30.225},{707.318,822.826,-30.226},{708.003,823.861,-30.227},{708.676,824.907,-30.228},
{709.309,826.004,-30.229},{709.930,827.146,-30.229},{710.557,828.211,-30.230},{711.338,829.198,-30.231},{712.064,830.124,-30.232},{712.749,831.124,-30.233},
{713.352,832.177,-30.234},{713.862,833.230,-30.234},{714.361,834.326,-30.235},{714.848,835.462,-30.235},{715.265,836.554,-30.235},{715.448,837.754,-30.235},
{715.652,838.914,-30.234},{715.957,840.063,-30.235},{716.296,841.263,-30.235},{716.540,842.392,-30.236},{716.603,843.585,-30.236},{716.613,844.801,-30.236},
{716.619,845.992,-30.235},{716.616,847.219,-30.234},{716.586,848.408,-30.234},{716.539,849.568,-30.233},{716.488,850.803,-30.231},{716.465,851.970,-30.231},
{716.464,853.160,-30.230},{716.517,854.360,-30.229},{716.689,855.529,-30.229},{716.714,856.769,-30.228},{716.427,857.925,-30.083},{716.134,859.046,-29.870},
{715.867,860.221,-29.645},{715.649,861.358,-29.426},{715.465,862.525,-29.199},{715.327,863.666,-28.975},{715.296,864.799,-28.749},{715.308,866.022,-28.503},
{715.321,867.175,-28.270},{715.332,868.321,-28.040},{715.319,869.496,-27.804},{715.288,870.663,-27.774},{715.253,871.920,-27.749},{715.221,873.082,-27.727},
{715.162,874.283,-27.708},{715.048,875.499,-27.696},{714.901,876.691,-27.676},{714.733,877.827,-27.658},{714.513,879.024,-27.531},{714.215,880.157,-27.400},
{713.869,881.312,-27.272},{713.813,882.468,-27.184},{713.858,883.622,-27.165},{713.883,884.851,-27.147},{713.823,886.030,-27.140},{713.643,887.210,-27.147},
{713.340,888.385,-27.170},{712.908,889.517,-27.210},{712.361,890.624,-27.271},{711.770,891.689,-27.353},{711.214,892.701,-27.433},{710.611,893.860,-27.541},
{710.042,894.964,-27.655},{709.464,896.085,-27.947},{708.928,897.126,-28.218},{708.391,898.167,-28.490},{707.804,899.305,-28.786},{707.270,900.342,-29.141},
{706.715,901.426,-29.527},{706.361,902.514,-29.906},{706.046,903.628,-30.292},{705.645,904.810,-30.615},{705.197,905.908,-30.575},{704.618,907.057,-30.538},
{704.013,908.167,-30.508},{703.432,909.288,-30.496},{702.892,910.458,-30.481},{702.396,911.554,-30.466},{701.812,912.683,-30.454},{701.164,913.691,-30.451},
{700.482,914.690,-30.458},{699.779,915.758,-30.438},{699.152,916.761,-30.400},{698.522,917.796,-30.361},{697.876,918.895,-30.319},{697.251,919.947,-30.280},
{696.551,921.023,-30.240},{695.891,922.012,-30.217},{695.334,923.069,-30.215},{694.874,924.239,-30.214},{694.359,925.338,-30.212},{693.800,926.414,-30.211},
{693.206,927.415,-30.212},{692.456,928.416,-30.212},{691.550,929.362,-30.210},{690.683,930.183,-30.209},{689.755,931.006,-30.207},{688.815,931.733,-30.205},
{687.805,932.447,-30.202},{686.767,933.057,-30.199},{685.666,933.451,-30.195},{684.620,933.935,-30.191},{683.525,934.557,-30.189},{682.461,935.183,-30.191},
{681.443,935.818,-30.193},{680.406,936.471,-30.195},{679.353,937.134,-30.197},{678.287,937.805,-30.200},{677.265,938.444,-30.202},{676.162,939.120,-30.204},
{675.159,939.720,-30.335},{674.139,940.317,-30.668},{673.076,940.917,-31.007},{671.995,941.455,-31.330},{670.853,941.889,-31.628},{669.739,942.269,-31.905},
{668.569,942.695,-32.205},{667.373,943.158,-32.602},{666.279,943.561,-32.969},{665.103,943.909,-33.314},{663.866,944.233,-33.676},{662.626,944.536,-34.040},
{661.421,944.982,-34.394},{660.416,945.547,-34.690},{659.244,946.145,-34.992},{658.150,946.524,-34.982},{656.899,946.785,-34.985},{655.561,947.043,-34.990},
{654.380,947.271,-34.995},{653.087,947.560,-34.997},{651.963,947.997,-34.983},{650.806,948.491,-34.940},{649.547,948.898,-34.903},{648.268,949.021,-34.888},
{646.957,949.142,-34.874},{645.764,949.291,-34.857},{644.544,949.484,-34.836},{643.249,949.804,-34.804},{642.035,950.035,-34.827},{640.738,950.194,-34.881},
{639.484,950.311,-34.932},{638.173,950.425,-34.974},{636.892,950.667,-34.994},{635.752,951.151,-34.988},{634.685,951.847,-34.961},{633.465,952.147,-34.973},
{632.356,951.734,-35.035},{631.269,951.157,-35.119},{630.184,950.608,-35.200},{629.027,950.116,-35.273},{627.864,949.722,-35.333},{626.656,949.512,-35.369},
{625.266,949.718,-35.350},{623.994,949.985,-35.287},{622.760,950.128,-35.058},{621.543,950.218,-34.841},{620.320,950.283,-34.626},{618.979,950.286,-34.401},
{617.762,950.266,-34.201},{616.507,950.238,-33.995},{615.303,950.069,-33.820},{614.066,949.791,-33.657},{612.791,949.441,-33.498},{611.532,949.088,-33.342},
{610.253,948.658,-33.195},{609.136,948.287,-33.109},{607.913,948.187,-33.060},{606.731,948.179,-33.015},{605.560,948.186,-32.972},{604.303,948.200,-32.926},
{603.165,948.222,-32.884},{601.936,948.250,-32.839},{600.645,948.245,-32.687},{599.402,948.167,-32.523},{598.116,948.072,-32.354},{596.863,947.980,-32.189},
{595.680,947.893,-32.033},{594.433,947.843,-31.870},{593.249,947.874,-31.726},{592.004,947.944,-31.590},{590.752,947.963,-31.450},{589.505,947.904,-31.306},
{588.213,947.787,-31.154},{586.948,947.725,-31.008},{585.628,947.691,-30.857},{584.356,947.660,-30.810},{583.086,947.619,-30.786},{581.815,947.431,-30.757},
{580.618,947.198,-30.727},{579.395,946.948,-30.696},{578.198,946.667,-30.665},{576.885,946.363,-30.619},{575.632,946.156,-30.573},{574.380,946.157,-30.531},
{573.092,946.235,-30.491},{571.841,946.314,-30.451},{570.567,946.393,-30.411},{569.321,946.466,-30.371},{568.104,946.497,-30.332},{566.854,946.389,-30.288},
{565.571,946.254,-30.242},{564.384,946.119,-30.035},{563.169,945.979,-29.764},{561.982,945.859,-29.502},{560.776,945.785,-29.240},{559.571,945.727,-28.980},
{558.392,945.606,-28.719},{557.176,945.366,-28.438},{556.005,945.094,-28.153},{554.774,944.806,-27.854},{553.674,944.549,-27.587},{552.513,944.287,-27.306},
{551.296,944.032,-27.013},{550.115,943.788,-26.729},{548.941,943.572,-26.449},{547.762,943.450,-26.177},{546.540,943.322,-25.895},{545.378,943.131,-25.620},
{544.227,942.880,-25.343},{543.117,942.536,-25.065},{541.950,942.168,-24.772},{540.800,941.888,-24.492},{539.604,941.937,-24.232},{538.439,942.206,-24.052},
{537.191,942.311,-24.057},{535.938,942.062,-24.124},{534.757,941.649,-24.223},{533.448,941.507,-24.347},{532.225,941.780,-24.480},{531.207,942.435,-24.610},
{530.703,943.358,-24.011},{530.346,944.238,-23.282},{529.931,945.281,-22.869},{529.527,946.410,-22.843},{529.251,947.600,-22.783},{529.257,948.827,-22.660},
{529.305,949.999,-22.534},{529.382,951.240,-22.480},{529.508,952.443,-22.434},{529.666,953.711,-22.381},{529.289,954.918,-22.424},{528.495,955.838,-22.546},
{527.723,956.798,-22.664},{527.532,957.980,-22.674},{527.030,958.991,-22.743},{525.856,959.325,-22.944},{524.647,959.126,-23.161},{523.565,958.657,-23.362},
{522.971,957.576,-23.488},{522.558,956.417,-23.584},{522.133,955.374,-23.678},{521.606,954.235,-23.789},{521.065,953.204,-23.954},{520.302,952.224,-24.212},
{519.550,951.361,-24.456},{518.888,950.387,-24.692},{518.388,949.328,-24.902},{517.925,948.235,-25.100},{517.476,947.152,-25.285},{516.940,946.132,-25.480},
{516.346,945.175,-25.681},{515.559,944.261,-25.913},{514.752,943.489,-26.135},{513.924,942.654,-26.368},{513.216,941.729,-26.586},{512.587,940.770,-26.793},
{511.981,939.678,-27.008},{511.417,938.623,-27.184},{510.863,937.612,-27.309},{510.283,936.556,-27.440},{509.720,935.531,-27.567},{509.140,934.474,-27.773},
{508.603,933.496,-27.983},{507.984,932.484,-28.214},{507.136,931.661,-28.478},{506.293,930.913,-28.733},{505.539,930.060,-28.979},{504.853,929.041,-29.225},
{504.363,927.977,-29.433},{503.965,926.858,-29.432},{503.556,925.771,-29.428},{502.866,924.752,-29.402},{501.947,923.974,-29.353},{500.989,923.292,-29.299},
{500.050,922.616,-29.245},{499.093,921.827,-29.426},{498.411,920.949,-29.697},{497.943,919.832,-29.990},{497.588,918.707,-30.153},{497.185,917.583,-30.312},
{496.665,916.460,-30.463},{496.118,915.441,-30.594},{495.517,914.429,-30.720},{494.868,913.453,-30.836},{494.205,912.515,-30.846},{493.521,911.494,-30.792},
{492.945,910.447,-30.753},{492.448,909.357,-30.725},{491.993,908.214,-30.705},{491.594,907.121,-30.690},{491.241,905.961,-30.697},{490.957,904.816,-30.736},
{490.660,903.606,-30.777},{490.207,902.383,-30.805},{489.620,901.297,-30.813},{488.984,900.153,-30.820},{488.553,898.954,-30.848},{488.255,897.779,-30.888},
{487.949,896.505,-30.932},{487.645,895.351,-30.934},{487.392,894.111,-30.895},{487.322,892.831,-30.867},{487.160,891.536,-30.833},{486.909,890.270,-30.820},
{486.567,889.081,-30.804},{486.129,887.953,-30.782},{485.645,886.794,-30.757},{485.198,885.729,-30.734},
}
BOT.routeB = {
{477.345,877.502,-30.208},{478.474,877.664,-30.335},{479.478,878.326,-30.442},{480.163,879.274,-30.517},{480.821,880.302,-30.479},{481.436,881.321,-30.488},
{481.997,882.383,-30.536},{482.518,883.514,-30.581},{482.984,884.572,-30.606},{483.457,885.693,-30.630},{483.910,886.813,-30.653},{484.337,887.918,-30.675},
{484.761,889.080,-30.696},{485.164,890.206,-30.716},{485.556,891.321,-30.735},{485.914,892.520,-30.775},{486.033,893.706,-30.804},{485.871,894.907,-30.817},
{485.752,896.044,-30.759},{485.983,897.211,-30.715},{486.916,897.957,-30.757},{487.940,898.562,-30.815},{488.813,899.351,-30.850},{489.664,900.207,-30.878},
{490.461,901.074,-30.901},{491.238,901.989,-30.920},{491.990,902.923,-30.935},{492.708,903.865,-30.947},{493.407,904.839,-30.999},{494.035,905.814,-31.048},
{494.634,906.866,-31.089},{495.227,907.956,-31.129},{495.793,908.951,-31.168},{496.421,909.994,-31.214},{497.043,911.008,-31.260},{497.653,911.987,-31.285},
{498.283,912.999,-31.161},{498.911,913.973,-31.043},{499.650,914.881,-30.944},{500.393,915.771,-30.713},{501.102,916.692,-30.430},{501.765,917.690,-30.133},
{502.329,918.717,-29.839},{502.875,919.728,-29.550},{503.567,920.742,-29.553},{504.238,921.678,-29.580},{504.854,922.716,-29.600},{505.445,923.755,-29.592},
{506.031,924.762,-29.369},{506.775,925.768,-29.111},{507.479,926.717,-28.867},{508.156,927.665,-28.629},{508.858,928.653,-28.382},{509.544,929.617,-28.141},
{510.244,930.601,-27.895},{510.872,931.583,-27.664},{511.447,932.596,-27.443},{512.050,933.707,-27.206},{512.626,934.692,-27.046},{513.330,935.731,-26.892},
{513.981,936.699,-26.750},{514.589,937.717,-26.615},{515.031,938.891,-26.506},{515.456,940.063,-26.327},{515.830,941.177,-26.153},{516.207,942.331,-25.974},
{516.616,943.429,-25.795},{517.067,944.560,-25.605},{517.514,945.649,-25.419},{518.142,946.661,-25.208},{518.805,947.703,-24.975},{519.339,948.683,-24.765},
{519.806,949.772,-24.559},{520.214,950.847,-24.366},{520.576,951.993,-24.177},{520.906,953.152,-23.992},{521.644,953.988,-23.786},{522.793,954.216,-23.582},
{523.994,954.030,-23.375},{525.107,953.662,-23.187},{526.129,952.914,-23.021},{526.873,951.995,-22.906},{527.460,950.945,-22.829},{528.020,949.772,-22.828},
{528.575,948.601,-22.827},{529.154,947.440,-22.820},{529.716,946.342,-22.810},{530.345,945.226,-22.788},{531.174,944.449,-23.256},{532.090,943.920,-23.808},
{533.137,943.389,-24.383},{534.221,942.950,-24.333},{535.385,942.589,-24.201},{536.565,942.316,-24.072},{537.705,942.109,-24.054},{538.873,941.912,-24.068},
{540.095,941.724,-24.320},{541.222,941.606,-24.558},{542.476,941.525,-24.827},{543.636,941.516,-25.082},{544.785,941.553,-25.339},{546.087,941.450,-25.617},
{547.310,941.302,-25.872},{548.622,941.154,-26.148},{549.742,941.057,-26.386},{550.897,940.974,-26.633},{552.070,940.897,-26.884},{553.292,941.044,-27.159},
{554.432,941.198,-27.415},{555.580,941.005,-27.636},{556.759,940.792,-27.861},{557.953,940.798,-28.113},{559.090,940.893,-28.363},{560.255,940.674,-28.584},
{561.445,940.480,-28.814},{562.628,940.536,-29.069},{563.850,940.604,-29.333},{565.082,940.523,-29.584},{566.262,940.487,-29.828},{567.525,940.558,-30.102},
{568.680,940.801,-30.218},{569.893,941.270,-30.269},{571.029,941.499,-30.312},{572.235,941.640,-30.355},{573.387,942.137,-30.405},{574.383,942.754,-30.450},
{575.453,943.316,-30.490},{576.560,943.788,-30.527},{577.639,944.261,-30.564},{578.795,944.746,-30.603},{579.937,944.975,-30.631},{581.104,945.174,-30.659},
{582.311,945.242,-30.683},{583.534,945.217,-30.703},{584.771,945.185,-30.724},{585.981,945.227,-30.746},{587.160,945.334,-30.885},{588.362,945.378,-31.023},
{589.553,945.331,-31.155},{590.711,945.257,-31.302},{591.940,945.481,-31.468},{593.034,945.815,-31.621},{594.250,945.946,-31.783},{595.433,945.770,-31.930},
{596.576,945.722,-32.076},{597.836,945.730,-32.239},{599.009,945.805,-32.393},{600.196,946.044,-32.555},{601.349,946.330,-32.714},{602.524,946.579,-32.805},
{603.733,946.833,-32.858},{604.883,947.080,-32.909},{606.040,947.267,-32.959},{607.280,947.424,-33.010},{608.464,947.440,-33.086},{609.618,947.440,-33.279},
{610.784,947.503,-33.464},{611.959,947.563,-33.651},{613.176,947.582,-33.852},{614.364,947.547,-34.056},{615.541,947.460,-34.267},{616.763,947.600,-34.449},
{617.724,948.299,-34.501},{618.742,949.011,-34.560},{619.779,949.514,-34.655},{620.960,949.739,-34.818},{622.233,949.886,-35.008},{623.423,949.919,-35.202},
{624.648,949.865,-35.334},{625.835,949.922,-35.319},{626.983,950.021,-35.299},{628.182,950.347,-35.247},{629.339,950.654,-35.199},{630.474,950.866,-35.163},
{631.682,950.735,-35.157},{632.780,950.373,-35.153},{633.979,949.973,-35.150},{635.163,949.838,-35.123},{636.409,949.762,-35.089},{637.654,949.972,-35.030},
{638.822,949.888,-34.997},{639.973,949.541,-34.966},{641.108,949.144,-34.937},{642.260,948.738,-34.907},{643.556,948.781,-34.885},{644.720,948.910,-34.881},
{645.889,948.912,-34.886},{647.111,948.845,-34.898},{648.265,948.718,-34.912},{649.448,948.464,-34.937},{650.624,948.254,-34.958},{651.811,948.268,-34.962},
{653.081,948.339,-34.934},{654.266,948.366,-34.909},{655.457,948.275,-34.893},{656.636,948.093,-34.885},{657.795,947.814,-34.887},{658.994,947.498,-34.896},
{660.158,947.483,-34.847},{661.307,947.460,-34.669},{662.489,947.235,-34.464},{663.535,946.758,-34.133},{664.577,946.228,-33.795},{665.625,945.807,-33.474},
{666.731,945.547,-33.168},{667.871,945.232,-32.844},{668.924,944.745,-32.553},{669.785,943.961,-32.377},{670.746,943.176,-32.051},{671.714,942.580,-31.726},
{672.781,942.007,-31.394},{673.820,941.488,-31.084},{674.895,941.026,-30.786},{675.904,940.424,-30.453},{676.794,939.655,-30.265},{677.545,938.784,-30.205},
{678.433,937.954,-30.201},{679.380,937.237,-30.198},{680.401,936.521,-30.195},{681.292,935.813,-30.192},{682.135,935.006,-30.188},{683.018,934.111,-30.184},
{683.847,933.266,-30.184},{684.734,932.464,-30.186},{685.659,931.670,-30.188},{686.479,930.783,-30.189},{687.305,929.809,-30.189},{688.032,928.868,-30.190},
{688.695,927.841,-30.189},{689.177,926.704,-30.187},{689.674,925.628,-30.186},{690.361,924.561,-30.186},{691.120,923.627,-30.194},{691.970,922.770,-30.230},
{692.802,921.859,-30.260},{693.397,920.887,-30.297},{693.943,919.816,-30.339},{694.470,918.780,-30.380},{695.090,917.798,-30.416},{695.779,916.743,-30.455},
{696.277,915.703,-30.497},{696.718,914.637,-30.540},{697.132,913.450,-30.590},{697.632,912.370,-30.618},{698.206,911.267,-30.637},{698.712,910.170,-30.674},
{699.364,909.181,-30.697},{700.201,908.309,-30.703},{700.901,907.315,-30.724},{701.545,906.314,-30.748},{702.149,905.227,-30.779},{702.681,904.214,-30.631},
{703.403,903.233,-30.272},{704.013,902.238,-29.939},{704.404,901.160,-29.686},{704.969,900.057,-29.399},{705.560,899.056,-29.125},{706.167,898.034,-28.845},
{706.697,896.998,-28.576},{707.035,895.908,-28.330},{707.283,894.732,-28.084},{707.611,893.629,-27.990},{707.985,892.553,-27.918},{708.384,891.371,-27.840},
{708.757,890.269,-27.767},{709.246,889.108,-27.680},{709.677,887.976,-27.626},{710.060,886.798,-27.593},{710.475,885.595,-27.557},{710.872,884.504,-27.522},
{710.981,883.303,-27.592},{711.037,882.113,-27.670},{711.258,880.890,-27.722},{711.539,879.684,-27.865},{711.849,878.523,-27.999},{712.130,877.413,-28.066},
{712.412,876.207,-28.070},{712.675,875.062,-28.059},{712.943,873.895,-28.047},{713.198,872.779,-28.035},{713.399,871.594,-28.033},{713.438,870.359,-28.056},
{713.784,869.218,-28.031},{714.326,868.165,-28.113},{714.556,867.052,-28.327},{714.396,865.921,-28.561},{714.063,864.731,-28.814},{714.049,863.613,-29.039},
{714.183,862.480,-29.262},{714.126,861.261,-29.509},{713.951,860.102,-29.749},{713.879,858.908,-29.992},{713.974,857.742,-30.217},{714.227,856.583,-30.219},
{714.388,855.352,-30.220},{714.483,854.164,-30.221},{714.564,852.978,-30.223},{714.590,851.757,-30.224},{714.419,850.604,-30.224},{714.283,849.367,-30.224},
{714.315,848.151,-30.225},{714.292,847.056,-30.226},{714.051,845.820,-30.226},{713.757,844.621,-30.225},{713.817,843.391,-30.226},{714.020,842.202,-30.228},
{714.068,840.994,-30.229},{713.853,839.736,-30.229},{713.565,838.559,-30.229},{713.406,837.358,-30.230},{713.188,836.149,-30.230},{712.851,835.043,-30.230},
{712.288,833.876,-30.230},{711.718,832.840,-30.229},{711.338,831.719,-30.229},{711.097,830.494,-30.230},{711.099,829.285,-30.231},{710.960,828.112,-30.231},
{710.615,826.955,-30.231},{710.111,825.835,-30.231},{709.490,824.784,-30.230},{708.825,823.862,-30.229},{708.257,822.864,-30.229},{707.659,821.796,-30.228},
{707.208,820.714,-30.228},{706.849,819.550,-30.228},{706.431,818.424,-30.227},{705.922,817.327,-30.227},{705.365,816.210,-30.226},{704.828,815.076,-30.227},
{703.969,814.333,-29.903},{702.941,813.652,-29.863},{702.002,812.894,-29.835},{701.068,812.078,-29.810},{700.168,811.370,-29.781},{699.148,810.634,-29.745},
{698.364,809.634,-29.743},{697.595,808.791,-29.732},{696.601,808.022,-29.696},{695.479,807.594,-29.624},{694.355,807.096,-29.600},{693.331,806.390,-29.853},
{692.513,805.579,-30.091},{691.612,804.751,-30.216},{690.683,803.931,-30.216},{689.907,803.078,-30.217},{688.976,802.256,-30.218},{688.060,801.549,-30.219},
{687.088,800.931,-30.219},{685.944,800.556,-30.218},{684.939,799.894,-30.217},{683.869,799.154,-30.216},{682.828,798.590,-30.214},{681.675,798.180,-30.213},
{680.509,797.891,-30.213},{679.406,797.476,-30.213},{678.227,797.114,-30.213},{677.026,796.810,-30.212},{675.837,796.553,-30.212},{674.642,796.282,-30.211},
{673.471,795.975,-30.209},{672.349,795.661,-30.207},{671.130,795.365,-30.204},{669.979,795.113,-30.201},{668.755,794.781,-30.198},{667.641,794.392,-30.198},
{666.532,793.898,-30.199},{665.377,793.530,-30.198},{664.255,793.289,-30.198},{663.165,792.797,-30.198},{662.127,792.206,-30.200},{661.140,791.580,-30.201},
{659.977,791.059,-30.202},{658.803,790.863,-30.202},{657.563,790.663,-30.202},{656.361,790.332,-30.202},{655.203,789.985,-30.202},{653.977,789.776,-30.203},
{652.836,789.654,-30.202},{651.661,789.522,-30.202},{650.503,789.052,-30.203},{649.412,788.573,-30.205},{648.320,788.196,-30.206},{647.094,788.039,-30.206},
{645.944,787.994,-30.206},{644.744,788.097,-30.205},{643.597,788.101,-30.205},{642.295,787.963,-30.205},{641.055,787.776,-30.264},{639.815,787.580,-30.362},
{638.611,787.245,-30.459},{637.490,786.929,-30.549},{636.321,786.686,-30.642},{635.125,786.704,-30.733},{633.859,786.819,-30.827},{632.669,786.782,-30.919},
{631.428,786.620,-31.016},{630.272,786.513,-31.105},{628.965,786.433,-31.217},{627.823,786.195,-31.319},{626.620,786.143,-31.425},{625.354,786.154,-31.536},
{624.144,786.117,-31.642},{622.903,786.051,-31.751},{621.740,786.072,-31.853},{620.557,786.118,-31.956},{619.291,786.197,-32.066},{618.122,786.350,-32.068},
{616.987,786.538,-32.069},{615.827,786.757,-32.069},{614.620,786.971,-32.070},{613.400,787.012,-32.072},{612.217,786.954,-32.074},{610.992,786.962,-32.075},
{609.790,787.030,-32.077},{608.710,787.182,-32.078},{607.512,787.466,-32.079},{606.365,787.772,-32.079},{605.172,788.097,-32.079},{603.946,788.452,-32.078},
{602.806,788.802,-32.078},{601.665,789.208,-32.077},{600.499,789.648,-32.047},{599.399,790.056,-31.917},{598.243,790.371,-31.781},{597.118,790.747,-31.649},
{596.015,791.166,-31.519},{594.889,791.605,-31.386},{593.850,792.051,-31.263},{592.767,792.543,-31.135},{591.652,793.055,-31.003},{590.577,793.529,-30.875},
{589.450,794.004,-30.742},{588.383,794.399,-30.616},{587.290,794.754,-30.488},{586.090,795.159,-30.347},{585.028,795.564,-30.221},{583.885,795.961,-30.087},
{582.733,796.260,-29.933},{581.588,796.625,-29.765},{580.460,797.027,-29.598},{579.337,797.419,-29.431},{578.214,797.771,-29.267},{577.064,798.114,-29.122},
{575.943,798.288,-29.032},{574.729,798.420,-28.936},{573.618,798.688,-28.845},{572.446,799.006,-28.747},{571.170,799.113,-28.648},{570.017,799.048,-28.562},
{568.863,798.971,-28.476},{567.644,798.896,-28.385},{566.465,798.797,-28.298},{565.322,798.438,-28.220},{564.175,798.129,-28.141},{562.973,797.958,-28.061},
{561.717,797.798,-28.069},{560.582,797.692,-28.081},{559.450,797.679,-27.836},{558.273,797.752,-27.540},{557.160,797.896,-27.263},{556.046,798.257,-26.991},
{554.950,798.748,-26.727},{553.881,799.250,-26.470},{552.829,799.810,-26.219},{551.810,800.271,-25.974},{550.764,800.553,-25.717},{549.638,800.725,-25.437},
{548.519,800.462,-25.147},{547.447,800.026,-24.865},{546.354,799.721,-24.580},{545.192,799.967,-24.293},{544.021,800.339,-24.007},{542.931,800.678,-23.931},
{541.770,800.548,-23.847},{540.957,799.815,-23.387},{540.338,798.938,-22.911},{540.180,797.823,-22.389},{540.261,796.690,-22.136},{540.478,795.664,-21.567},
{541.151,794.775,-20.825},{541.961,793.937,-20.606},{542.824,793.091,-20.383},{543.663,792.286,-20.168},{544.527,791.492,-19.952},{545.437,790.682,-19.725},
{546.300,789.916,-19.509},{547.048,789.014,-19.266},{547.821,788.061,-19.010},{548.791,787.388,-18.813},{549.815,786.742,-18.620},{550.819,786.065,-18.473},
{551.771,785.359,-18.351},{552.747,784.569,-18.241},{553.654,783.893,-18.154},{554.686,783.247,-18.057},{555.694,782.622,-17.962},{556.538,781.809,-17.883},
{557.040,780.682,-17.835},{557.549,779.616,-17.787},{558.257,778.699,-17.720},{558.746,777.628,-17.673},{557.896,776.963,-17.752},{556.668,777.143,-17.867},
{555.561,777.530,-17.971},{554.512,778.079,-18.069},{553.409,778.683,-18.173},{552.419,779.231,-18.266},{551.338,779.758,-18.367},{550.219,780.274,-18.472},
{549.181,780.820,-18.575},{548.080,781.416,-18.688},{547.065,781.923,-18.791},{545.976,782.409,-18.901},{544.810,782.857,-19.019},{543.718,783.312,-19.141},
{542.612,783.847,-19.274},{541.490,784.060,-19.399},{540.298,784.068,-19.526},{539.113,784.196,-19.655},{537.983,784.536,-19.785},{536.929,784.996,-19.910},
{535.862,785.514,-20.038},{534.846,786.112,-20.164},{533.746,786.665,-20.297},{532.714,787.140,-20.421},{531.829,788.006,-20.540},{531.346,789.170,-20.627},
{531.217,790.351,-20.667},{530.807,791.408,-20.700},{529.798,792.158,-20.749},{528.752,792.627,-20.808},{527.630,793.151,-20.920},{526.532,793.393,-21.005},
{525.304,793.490,-21.060},{524.086,793.562,-21.109},{522.886,793.615,-21.182},{521.655,793.649,-21.265},{520.421,793.662,-21.349},{519.159,793.604,-21.436},
{517.844,793.662,-21.524},{516.631,793.618,-21.608},{515.350,793.562,-21.697},{514.142,793.611,-21.778},{512.956,793.654,-21.858},{511.610,793.518,-21.953},
{510.427,793.364,-22.007},{509.214,793.309,-22.005},{507.933,793.552,-21.994},{506.744,793.532,-21.995},{505.479,793.584,-21.996},{504.435,794.243,-21.984},
{503.820,795.241,-21.964},{503.230,796.408,-21.959},{503.309,797.590,-21.956},{503.655,798.786,-21.953},{504.526,799.671,-21.949},{505.658,800.302,-21.945},
{506.938,800.395,-21.945},{508.083,800.731,-21.945},{508.853,801.689,-21.945},{509.542,802.714,-21.950},{510.597,803.253,-22.116},{511.842,803.467,-22.273},
{513.029,803.664,-22.422},{514.215,804.012,-22.584},{515.342,804.372,-22.741},{516.512,804.644,-22.895},{517.766,804.838,-23.051},{518.919,804.581,-23.154},
{520.089,804.205,-23.248},{521.237,804.125,-23.367},{522.257,804.707,-23.533},{522.836,805.772,-23.695},{523.149,806.859,-23.837},{523.499,807.833,-24.313},
{523.852,808.874,-24.841},{523.438,809.948,-25.101},{522.835,811.020,-25.018},{522.322,812.029,-24.946},{521.838,813.173,-24.904},{521.195,814.269,-24.843},
{520.468,815.261,-24.764},{519.906,816.458,-24.718},{519.571,817.555,-24.758},{519.337,818.709,-24.846},{518.822,819.862,-24.902},{518.267,820.699,-24.921},
{517.636,821.651,-24.943},{517.084,822.817,-24.996},{516.583,823.857,-25.042},{515.924,824.899,-25.070},{515.187,825.836,-25.078},{514.392,826.725,-25.075},
{513.635,827.675,-25.082},{512.944,828.647,-25.099},{512.459,829.737,-25.235},{512.018,830.859,-25.435},{511.531,831.875,-25.727},{510.925,832.874,-26.010},
{510.202,833.816,-26.272},{509.480,834.708,-26.519},{508.681,835.621,-26.770},{507.915,836.471,-27.054},{507.137,837.285,-27.440},{506.444,838.267,-27.725},
{505.862,839.217,-28.008},{505.166,840.190,-28.289},{504.462,841.059,-28.533},{503.743,841.936,-28.778},{503.037,842.879,-29.048},{502.420,843.896,-29.149},
{501.792,844.953,-29.252},{501.206,845.947,-29.350},{500.648,846.970,-29.486},{500.087,848.049,-29.658},{499.283,848.854,-29.772},{498.250,849.375,-29.827},
{497.181,850.009,-29.901},{496.309,850.742,-29.898},{495.478,851.646,-29.879},{494.730,852.543,-29.860},{494.027,853.464,-29.840},{493.440,854.584,-29.817},
{492.926,855.674,-29.847},{492.187,856.654,-29.878},{491.368,857.605,-29.910},{490.565,858.504,-29.940},{489.907,859.506,-29.971},{489.106,860.319,-29.999},
{488.173,861.097,-30.029},{487.190,861.842,-30.058},{486.423,862.712,-30.088},{486.336,863.927,-30.114},{486.524,865.057,-30.344},{486.497,866.252,-30.582},
{486.102,867.425,-30.781},{485.916,868.440,-30.903},{485.750,869.637,-30.837},{485.268,870.797,-30.748},{484.715,871.841,-30.728},{484.142,872.910,-30.707},
{483.588,873.942,-30.686},{483.018,875.005,-30.664},{482.433,876.096,-30.642},
}
BOT.oreTex = { cs_rockdetail2 = 1, ab_flakeywall = 2, metalic128 = 3, Strip_Gold = 4, gold128 = 5 }
BOT.font = nil
pcall(function() BOT.font = renderCreateFont('Arial', 10, 5) end)
local function d8(s) return u8:decode(s) end
local S_ORE   = d8('Месторождение ресурсов')
local S_BUSH  = d8('Куст на ферме')
local S_BUSY  = d8('Собирает сено')
local S_STORE = d8('%[ Сдать сено %]')

if sampev then
    local prevMat = sampev.onSetObjectMaterial
    function sampev.onSetObjectMaterial(id, data)
        pcall(function()
            local o = sampGetObjectHandleBySampId(id)
            if doesObjectExist(o) and getObjectModel(o) == 3930 and BOT.oreTex[data.textureName] then
                BOT.ore[id] = BOT.oreTex[data.textureName]
            end
        end)
        if prevMat then return prevMat(id, data) end
    end
    local prevDel = sampev.onDestroyObject
    function sampev.onDestroyObject(id)
        BOT.ore[id] = nil
        if prevDel then return prevDel(id) end
    end
    local prevDlg = sampev.onShowDialog
    function sampev.onShowDialog(id, style, title, b1, b2, text)
        if T.botMineStopDlg[0] and T.botMine[0] and id == 15039 then
            T.botMine[0] = false
            msg('Шахта: бот остановлен (открыт диалог)')
        end
        if prevDlg then return prevDlg(id, style, title, b1, b2, text) end
    end
end

local function sendFrontendClick(interfaceid, id, subid, json)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 63)
    raknetBitStreamWriteInt8(bs, interfaceid)
    raknetBitStreamWriteInt32(bs, id)
    raknetBitStreamWriteInt32(bs, subid)
    raknetBitStreamWriteInt32(bs, #json)
    raknetBitStreamWriteString(bs, json)
    raknetSendBitStreamEx(bs, 1, 10, 1)
    raknetDeleteBitStream(bs)
end

local function sendInterfaceLoaded(interfaceid, bool)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 66)
    raknetBitStreamWriteInt8(bs, interfaceid)
    raknetBitStreamWriteBool(bs, bool)
    raknetSendBitStreamEx(bs, 1, 10, 1)
    raknetDeleteBitStream(bs)
end

-- ---------- Шахта ----------
local function mineCollect()
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 63)
    raknetBitStreamWriteInt8(bs, 8)
    raknetBitStreamWriteInt32(bs, 7)
    raknetBitStreamWriteInt32(bs, -1)
    raknetBitStreamWriteInt32(bs, 0)
    raknetBitStreamWriteString(bs, '')
    raknetSendBitStreamEx(bs, 1, 7, 1)
    raknetDeleteBitStream(bs)
end

local function setAllCollision(state)
    for _, v in ipairs(getAllChars()) do
        if doesCharExist(v) and v ~= PLAYER_PED then setCharCollision(v, state) end
    end
    for _, v in ipairs(getAllVehicles()) do
        if doesVehicleExist(v) then setCarCollision(v, state) end
    end
    for _, v in ipairs(getAllObjects()) do
        if doesObjectExist(v) then setObjectCollision(v, state) end
    end
end

local function normAng(a)
    while a > math.pi do a = a - 2 * math.pi end
    while a < -math.pi do a = a + 2 * math.pi end
    return a
end
local lastCam = 0.0
local function smoothCam(target)
    target = normAng(target)
    local diff = normAng(target - lastCam)
    if math.abs(diff) > 0.01745 then
        local step = diff * 0.1
        if math.abs(step) < 0.008726 then step = diff > 0 and 0.008726 or -0.008726 end
        lastCam = normAng(lastCam + step)
    else
        lastCam = target
    end
    setCameraPositionUnfixed(0, lastCam)
end

local function circle3d(x, y, z, radius, color)
    local ox, oy
    for rot = 0, 360, 6 do
        local r = math.rad(rot)
        local lx, ly = radius * math.cos(r) + x, radius * math.sin(r) + y
        local sx, sy = convert3DCoordsToScreen(lx, ly, z)
        if sx and ox and isPointOnScreen(lx, ly, z, 1) then renderDrawLine(sx, sy, ox, oy, 3, color) end
        ox, oy = sx, sy
    end
end

local function playerNear(x, y, z, radius)
    for i = 0, sampGetMaxPlayerId() do
        if sampIsPlayerConnected(i) then
            local ok, ped = sampGetCharHandleBySampPlayerId(i)
            if ok and ped ~= PLAYER_PED then
                local px, py, pz = getCharCoordinates(ped)
                if getDistanceBetweenCoords3d(px, py, pz, x, y, z) <= radius then return true end
            end
        end
    end
    return false
end

local function scanOre()
    BOT.arr = {}
    local mx, my, mz = getCharCoordinates(PLAYER_PED)
    for i = 0, 2048 do
        if sampIs3dTextDefined(i) then
            local text, _, x, y, z = sampGet3dTextInfoById(i)
            if text and text:find(S_ORE) then
                local dist = getDistanceBetweenCoords3d(mx, my, mz, x, y, z)
                if dist <= 50 then table.insert(BOT.arr, { p = { x, y, z }, d = dist }) end
            end
        end
    end
    table.sort(BOT.arr, function(a, b) return a.d < b.d end)
end

local function mineWaypoint()
    local rt = BOT.rt
    if not rt or #rt == 0 then return end
    local px, py, pz = getCharCoordinates(PLAYER_PED)
    local wp = rt[BOT.wp or 1]
    local dist = getDistanceBetweenCoords3d(px, py, pz, wp[1], wp[2], wp[3])
    circle3d(wp[1], wp[2], wp[3] - 0.1, 1.5, 0xFF66CCFF)
    smoothCam(math.rad(getHeadingFromVector2d(wp[1] - px, wp[2] - py) - 90))
    setGameKeyState(1, -255)
    if dist <= 7 then
        BOT.wp = (BOT.wp or 1) + 1
        if BOT.wp > #rt then BOT.wp = 1 end
    end
end

local function mineGoOre(pos, dist)
    local px, py, pz = getCharCoordinates(PLAYER_PED)
    circle3d(pos[1], pos[2], pos[3] - 0.1, 1.5, 0xFF00FF00)
    smoothCam(math.rad(getHeadingFromVector2d(pos[1] - px, pos[2] - py) - 90))
    setGameKeyState(1, -255)
    if dist <= 3.0 then
        mineCollect()
        wait(1000)
        mineCollect()
    end
end

local function mineStep()
    setGameKeyState(16, 255) -- спринт
    if os.clock() >= BOT.jumpAt then
        BOT.jumpAt = os.clock() + math.random(2, 5)
        setGameKeyState(14, 255)
    end
    scanOre()
    local px, py, pz = getCharCoordinates(PLAYER_PED)
    for _, ore in ipairs(BOT.arr) do
        local p = ore.p
        if not playerNear(p[1], p[2], p[3], 3) then
            mineGoOre(p, getDistanceBetweenCoords3d(px, py, pz, p[1], p[2], p[3]))
            return
        end
    end
    mineWaypoint()
end

local mineWasOn, mineColPrev = false, false
lua_thread.create(function()
    while true do
        wait(0)
        pcall(function()
            if T.botMine[0] then
                if not mineWasOn then
                    mineWasOn = true
                    BOT.rt = (math.random(0, 1) == 1) and BOT.routeA or BOT.routeB
                    BOT.wp = 1
                    msg('Шахта: бот включён, маршрут ' .. ((BOT.rt == BOT.routeA) and 'A' or 'B'))
                end
                mineStep()
            elseif mineWasOn then
                mineWasOn = false
                setGameKeyState(1, 0)
                setGameKeyState(16, 0)
                msg('Шахта: бот выключен')
            end
            if T.botMineNoCol[0] ~= mineColPrev then
                mineColPrev = T.botMineNoCol[0]
                setAllCollision(not mineColPrev)
            end
        end)
    end
end)

lua_thread.create(function()
    while true do
        wait(0)
        if T.botMineEsp[0] and BOT.font then
            pcall(function()
                local x, y, z = getCharCoordinates(PLAYER_PED)
                for _, o in pairs(getAllObjects()) do
                    if getObjectModel(o) == 854 and isObjectOnScreen(o) then
                        local ok, x1, y1, z1 = getObjectCoordinates(o)
                        if ok then
                            local c1, c2 = convert3DCoordsToScreen(x, y, z)
                            local o1, o2 = convert3DCoordsToScreen(x1, y1, z1)
                            if c1 and o1 then
                                renderDrawLine(c1, c2, o1, o2, 2, 0xFF00FF00)
                                renderFontDrawText(BOT.font, '{EAFF00}' .. d8('Руда') .. '\n{00FF00}' ..
                                    math.floor(getDistanceBetweenCoords3d(x, y, z, x1, y1, z1)) .. 'm', o1, o2, -1)
                            end
                        end
                    end
                end
            end)
        end
    end
end)

-- ---------- Начальная ферма ----------
local function hasHay()
    if os.clock() < BOT.hay then return false end
    local px, py, pz = getCharCoordinates(PLAYER_PED)
    for _, obj in pairs(getAllObjects()) do
        if getObjectModel(obj) == 2901 then
            local res, ox, oy, oz = getObjectCoordinates(obj)
            if res and getDistanceBetweenCoords3d(px, py, pz, ox, oy, oz) <= 0.5 then return true end
        end
    end
    return false
end

local function find3d(pattern, notPattern)
    local px, py, pz = getCharCoordinates(PLAYER_PED)
    local best, bx, by, bz = math.huge, 0, 0, 0
    for i = 0, 2048 do
        if sampIs3dTextDefined(i) then
            local text, _, x, y, z = sampGet3dTextInfoById(i)
            if text and text:find(pattern) and not (notPattern and text:find(notPattern)) then
                local d = getDistanceBetweenCoords3d(px, py, pz, x, y, z)
                if d < best then best, bx, by, bz = d, x, y, z end
            end
        end
    end
    return best ~= math.huge, bx, by, bz
end

local function targetIs(pattern, notPattern)
    for i = 0, 2048 do
        if sampIs3dTextDefined(i) then
            local text, _, x, y, z = sampGet3dTextInfoById(i)
            if text and getDistanceBetweenCoords3d(x, y, z, BOT.tx, BOT.ty, BOT.tz) < 1.0 then
                if text:find(pattern) and not (notPattern and text:find(notPattern)) then return true end
            end
        end
    end
    return false
end

local function farmStep()
    local px, py, pz = getCharCoordinates(PLAYER_PED)
    local toStore = hasHay()
    if toStore then
        if not BOT.mv or not targetIs(S_STORE) then
            local f, x, y, z = find3d(S_STORE)
            if f then BOT.tx, BOT.ty, BOT.tz, BOT.mv = x, y, z, true end
        end
    else
        if not BOT.mv or not targetIs(S_BUSH, S_BUSY) then
            local f, x, y, z = find3d(S_BUSH, S_BUSY)
            if f then BOT.tx, BOT.ty, BOT.tz, BOT.mv = x, y, z, true end
        end
    end
    if BOT.mv then
        local dist = getDistanceBetweenCoords2d(px, py, BOT.tx, BOT.ty)
        if dist > 1.0 then
            smoothCam(math.rad(getHeadingFromVector2d(BOT.tx - px, BOT.ty - py) - 90))
            setGameKeyState(1, -255)
            setGameKeyState(16, 255)
        else
            setGameKeyState(1, 0)
            setGameKeyState(16, 0)
            BOT.mv = false
            wait(500)
            if targetIs(S_STORE) then BOT.hay = os.clock() + 5 end
        end
    end
end

local farmWasOn = false
lua_thread.create(function()
    while true do
        wait(5)
        pcall(function()
            if T.botFarm[0] then
                if not farmWasOn then
                    farmWasOn = true
                    BOT.mv = false
                    msg('НФерма: бот включён')
                end
                farmStep()
            elseif farmWasOn then
                farmWasOn = false
                BOT.mv = false
                setGameKeyState(1, 0)
                setGameKeyState(16, 0)
                msg('НФерма: бот выключен')
            end
        end)
    end
end)

lua_thread.create(function()
    while true do
        wait(0)
        if T.botFarm[0] and T.botFarmEsp[0] and BOT.font then
            pcall(function()
                local px, py, pz = getCharCoordinates(PLAYER_PED)
                local f, x, y, z = find3d(S_BUSH, S_BUSY)
                if f and isPointOnScreen(x, y, z, 1.0) then
                    local sx, sy = convert3DCoordsToScreen(x, y, z + 0.5)
                    local sx2, sy2 = convert3DCoordsToScreen(px, py, pz)
                    if sx and sx2 then
                        renderDrawLine(sx2, sy2, sx, sy, 1, 0xFFFFFFFF)
                        renderFontDrawText(BOT.font, string.format('{00C0FF}%s\n{FFFFFF}%dm', d8('СЕНО'),
                            math.floor(getDistanceBetweenCoords3d(px, py, pz, x, y, z))), sx, sy, -1)
                    end
                end
            end)
        end
    end
end)

pcall(addEventHandler, 'onReceivePacket', function(id, bs)
    if not (T.botFarm[0] and T.botFarmCaptcha[0]) then return end
    if id == 220 then
        raknetBitStreamIgnoreBits(bs, 8)
        local ptype = raknetBitStreamReadInt8(bs)
        if ptype == 84 then
            local interfaceid = raknetBitStreamReadInt8(bs)
            raknetBitStreamReadInt8(bs)
            if interfaceid == 81 then
                lua_thread.create(function()
                    local delay = math.random(1000, 2200)
                    wait(delay)
                    sendFrontendClick(81, 0, 0, '')
                    msg(string.format('[АвтоКапча] Ввёл капчу за %.2f сек', delay / 1000))
                end)
                return false
            end
        elseif ptype == 62 then
            local interfaceid = raknetBitStreamReadInt8(bs)
            local toggle = raknetBitStreamReadBool(bs)
            if interfaceid == 81 then
                sendInterfaceLoaded(81, toggle)
                return false
            end
        end
    end
end)

-- ---------- Ферма Лён / Хлопок ----------
T.botLih = imgui.new.bool(false)
BOT.lihFlax = true
local S_CAN, S_FLAX, S_COTTON = d8('Можно собрать'), d8('Лён'), d8('Хлопок')

local function lihFind()
    local mx, my, mz = getCharCoordinates(PLAYER_PED)
    local best, bp = math.huge, nil
    for i = 0, 2048 do
        if sampIs3dTextDefined(i) then
            local text, _, x, y, z = sampGet3dTextInfoById(i)
            if text and text:find(S_CAN) and text:find('10') and text:find(BOT.lihFlax and S_FLAX or S_COTTON) then
                local d = getDistanceBetweenCoords3d(mx, my, mz, x, y, z)
                if d < best then best, bp = d, { x, y, z } end
            end
        end
    end
    return bp
end

local function lihValid(p)
    for i = 0, 2048 do
        if sampIs3dTextDefined(i) then
            local text, _, x, y, z = sampGet3dTextInfoById(i)
            if text and getDistanceBetweenCoords3d(p[1], p[2], p[3], x, y, z) < 2.0 and text:find(S_CAN) then return true end
        end
    end
    return false
end

local function lihStep()
    local p = lihFind()
    if not p then return end
    if not lihValid(p) then wait(200) return end
    local px, py, pz = getCharCoordinates(PLAYER_PED)
    if getDistanceBetweenCoords3d(px, py, pz, p[1], p[2], p[3]) > 2 then
        local kind = BOT.lihFlax
        while T.botLih[0] and kind == BOT.lihFlax and getDistanceBetweenCoords2d(px, py, p[1], p[2]) > 1.5 do
            circle3d(p[1], p[2], p[3] - 0.1, 3, 0xFFFFFF00)
            setGameKeyState(1, -255)
            wait(1)
            px, py, pz = getCharCoordinates(PLAYER_PED)
            setCameraPositionUnfixed(0, math.rad(getHeadingFromVector2d(p[1] - px, p[2] - py) - 90))
        end
    else
        mineCollect()
        wait(200)
    end
end

local lihWasOn = false
lua_thread.create(function()
    while true do
        wait(0)
        pcall(function()
            if T.botLih[0] then
                if not lihWasOn then lihWasOn = true msg('Ферма лён/хлопок: бот включён') end
                lihStep()
            elseif lihWasOn then
                lihWasOn = false
                setGameKeyState(1, 0)
                msg('Ферма лён/хлопок: бот выключен')
            end
        end)
    end
end)

function secBotLih()
    Section('Бот на ферму лён / хлопок')
    Toggle('botLih', 'Включить бота фермы')
    Section('Что собирать')
    ButtonGrid('lihKind', { 'Лён', 'Хлопок' }, 2,
        function(i) return BOT.lihFlax == (i == 1) end,
        function(i) BOT.lihFlax = (i == 1) end)
    imgui.Dummy(V2(0, P(6)))
end

-- ---------- Автобус ----------
T.botBus = imgui.new.bool(false)
T.botBusInvis = imgui.new.bool(false)
if sampev then
    local prevRC = sampev.onSetRaceCheckpoint
    function sampev.onSetRaceCheckpoint(ctype, position, nextPosition, size)
        if T.botBus[0] and position then
            pcall(function()
                if isCharInAnyCar(PLAYER_PED) then
                    setCarCoordinates(storeCarCharIsInNoSave(PLAYER_PED), position.x, position.y, position.z)
                else
                    setCharCoordinates(PLAYER_PED, position.x, position.y, position.z)
                end
            end)
        end
        if prevRC then return prevRC(ctype, position, nextPosition, size) end
    end
    local prevPS = sampev.onSendPlayerSync
    function sampev.onSendPlayerSync(data)
        if T.botBusInvis[0] and data and data.position then data.position.z = data.position.z - 4 end
        if prevPS then return prevPS(data) end
    end
end

function secBotBus()
    Section('Бот на автобусника')
    Toggle('botBus', 'Включить бота (ТП на чекпоинт)')
    Toggle('botBusInvis', 'Инвиз')
    imgui.Dummy(V2(0, P(6)))
end

-- ---------- ТСР (Miku Reborn) ----------
for _, k in ipairs({ 'botTsrBox', 'botTsrCell', 'botTsrDoor', 'botTsrFence' }) do T[k] = imgui.new.bool(false) end
T.botTsrWait = imgui.new.int(1200)
BOT.boxStep, BOT.box = 0, 0

local function tsrDelete(models)
    for _, obj in pairs(getAllObjects()) do
        if models[getObjectModel(obj)] then deleteObject(obj) end
    end
end
local M_CELL, M_DOOR, M_FENCE = { [19303] = true }, { [19857] = true }, { [19912] = true, [19913] = true }
local function tsrTp(x, y, z) setCharCoordinates(PLAYER_PED, x, y, z) end

lua_thread.create(function()
    while true do
        wait(100)
        pcall(function()
            if T.botTsrCell[0] then tsrDelete(M_CELL) end
            if T.botTsrDoor[0] then tsrDelete(M_DOOR) end
            if T.botTsrFence[0] then tsrDelete(M_FENCE) end
        end)
    end
end)

local boxWasOn = false
lua_thread.create(function()
    while true do
        wait(0)
        pcall(function()
            if not T.botTsrBox[0] then boxWasOn = false return end
            if not boxWasOn then boxWasOn = true BOT.boxStep = 0 end
            local w = T.botTsrWait[0]
            if BOT.boxStep == 0 then
                tsrTp(257.86, 2012.86, 16.64)
                wait(500)
                mineCollect()
                BOT.boxStep = 1
            elseif BOT.boxStep == 1 then
                wait(w)
                tsrTp(244.37, 2015.84, 17.66)
                wait(100)
                tsrTp(239.16, 2026.78, 16.68)
                wait(500)
                mineCollect()
                BOT.boxStep = 2
            else
                wait(w)
                tsrTp(244.37, 2015.84, 17.66)
                wait(100)
                BOT.boxStep = 0
                BOT.box = BOT.box + 1
                printStringNow('Box: ' .. BOT.box, 500)
            end
        end)
    end
end)

local TSR_CELLS = {
    { '1', 1393.4752, 1353.7609, 10 }, { '2', 1393.4773, 1355.6962, 10 }, { '3', 1393.4667, 1357.8531, 10 },
    { '4', 1400.3271, 1353.6957, 10 }, { '5', 1400.3285, 1355.6793, 10 }, { '6', 1400.3372, 1357.8384, 10 },
    { 'Грязная одежда', 1396.1380, 1354.9414, 10 }, { 'Чистая одежда', 1397.8023, 1357.9216, 10.9390 },
}
local TSR_LOAD = {
    { 'ТП к началу', 257.86, 2012.86, 16.64 }, { 'ТП в центр', 244.3774, 2015.8484, 17.6670 },
    { 'ТП в конец', 239.1630, 2026.7818, 16.6870 },
}
local function tpGrid(id, list, cols)
    local labels = {}
    for i, v in ipairs(list) do labels[i] = v[1] end
    ButtonGrid(id, labels, cols, function() return false end, function(i)
        local v = list[i]
        tsrTp(v[2], v[3], v[4])
    end)
end

function secBotTsr()
    Section('Удаление объектов')
    Toggle('botTsrCell', 'Авто-удаление клеток')
    Toggle('botTsrDoor', 'Авто-удаление дверей')
    Toggle('botTsrFence', 'Авто-удаление заборов')
    ButtonGrid('tsrDel', { 'Удалить клетки', 'Удалить дверь', 'Удалить заборы' }, 3,
        function() return false end,
        function(i) tsrDelete(i == 1 and M_CELL or i == 2 and M_DOOR or M_FENCE) end)
    Section('Грузчик: бот коробки RAGE')
    Toggle('botTsrBox', 'Бот коробки RAGE')
    SliderRow('botTsrWait', 'Задержка (мс)', 100, 5000, '%d')
    tpGrid('tsrLoad', TSR_LOAD, 3)
    Section('Тюрьма: ТП')
    tpGrid('tsrCells', TSR_CELLS, 3)
    imgui.Dummy(V2(0, P(6)))
end

function secBotMine()
    Section('Бот на шахту')
    Toggle('botMine', 'Включить бота шахты')
    Toggle('botMineStopDlg', 'Стоп при диалоге админа')
    Section('Дополнительно')
    Toggle('botMineNoCol', 'Отключить коллизию')
    Toggle('botMineEsp', 'ESP руды')
    imgui.Dummy(V2(0, P(6)))
end

function secBotFarm()
    Section('Бот на начальную ферму')
    Toggle('botFarm', 'Включить бота фермы')
    Toggle('botFarmCaptcha', 'Авто-капча')
    Toggle('botFarmEsp', 'ESP куста с сеном')
    imgui.Dummy(V2(0, P(6)))
end

-- ---------- Завод ----------
T.botZavod = imgui.new.bool(false)
T.zavCaptcha = imgui.new.int(5000)
T.zavTake = imgui.new.int(2000)
T.zavPut = imgui.new.int(2000)
local ZAV = { state = 'waiting', ops = 0, paused = false,
    pts = { { 1972.12, 1356.50, 1181.89 }, { 1967.01, 1352.72, 1181.89 }, { 1984.21, 1354.51, 1181.89 } },
    ans = { '/b тут', '/b я тут', '/b тут я, что?', '/b я тут, что такое?', '/b я тут, что?' },
    kw = { 'тут', 'здесь', 'за компьютером', 'бот', 'ответ в чат', 'ответ в /b', 'ответ в /n', 'на месте', 'афк' } }

local function zavOn() return T.botZavod[0] and not ZAV.paused end

local function zavTP(i)
    local p = ZAV.pts[i]
    local x, y, z = getCharCoordinates(PLAYER_PED)
    local dist = getDistanceBetweenCoords3d(x, y, z, p[1], p[2], p[3])
    if dist <= 10 then setCharCoordinates(PLAYER_PED, p[1], p[2], p[3]) return end
    local steps = math.ceil(dist / 10)
    for s = 1, steps do
        if not T.botZavod[0] then break end
        if s == steps then
            setCharCoordinates(PLAYER_PED, p[1], p[2], p[3])
        else
            setCharCoordinates(PLAYER_PED, x + (p[1] - x) / steps * s, y + (p[2] - y) / steps * s, z + (p[3] - z) / steps * s)
            wait(1000)
        end
    end
end

local function zavGoTake()
    ZAV.state = 'taking'
    zavTP(1)
    wait(T.zavTake[0])
end

local function zavClick(interfaceid, id, subid, json)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 63)
    raknetBitStreamWriteInt8(bs, interfaceid)
    raknetBitStreamWriteInt32(bs, id)
    raknetBitStreamWriteInt32(bs, subid)
    raknetBitStreamWriteInt16(bs, #json)
    raknetBitStreamWriteString(bs, json)
    raknetSendBitStreamEx(bs, 1, 10, 1)
    raknetDeleteBitStream(bs)
end

-- ответ админу, бот на паузе
local function zavAdminReply()
    if ZAV.paused then return end
    ZAV.paused = true
    lua_thread.create(function()
        wait(math.random(500, 900))
        sampSendChat(d8(ZAV.ans[math.random(1, #ZAV.ans)]))
        wait(math.random(500, 900))
        ZAV.paused = false
    end)
end

-- включение / выключение
lua_thread.create(function()
    local prev = false
    while true do
        wait(200)
        local cur = T.botZavod[0]
        if cur ~= prev then
            prev = cur
            if cur then
                ZAV.ops = 0
                msg('Завод: бот включён, иду к точке взятия')
                pcall(zavGoTake)
            else
                ZAV.state = 'waiting'
                msg('Завод: бот выключен')
            end
        end
    end
end)

if sampev then
    local prevAtt = sampev.onSetPlayerAttachedObject
    function sampev.onSetPlayerAttachedObject(plID, index, create, obj)
        if zavOn() and ZAV.state == 'taking' and obj and obj.bone == 6 and obj.modelId == 3082 then
            local okId, myId = pcall(sampGetPlayerIdByCharHandle, PLAYER_PED)
            if not okId or plID == myId then
                ZAV.state = 'assembly'
                lua_thread.create(function() pcall(zavTP, 2) end)
                msg('Завод: предмет взят, иду на сборку')
            end
        end
        if prevAtt then return prevAtt(plID, index, create, obj) end
    end

    local prevMsg = sampev.onServerMessage
    function sampev.onServerMessage(color, text)
        if zavOn() and text then
            local clean = text:gsub('{%x%x%x%x%x%x}', '')
            if clean:find(d8('%[Завод%] Вы получили')) then
                ZAV.state = 'taking'
                ZAV.ops = ZAV.ops + 1
                lua_thread.create(function()
                    wait(2000)
                    if T.botZavod[0] then pcall(zavGoTake) end
                end)
                msg('Завод: предмет получен, цикл ' .. ZAV.ops)
            elseif text:find(d8('Администратор')) or text:find(d8('ответил вам:')) then
                for _, k in ipairs(ZAV.kw) do
                    if text:find(d8(k), 1, true) then zavAdminReply() break end
                end
            end
        end
        if prevMsg then return prevMsg(color, text) end
    end

    local prevDlgZ = sampev.onShowDialog
    function sampev.onShowDialog(id, style, title, b1, b2, text)
        if T.botZavod[0] then
            title, text = tostring(title or ''), tostring(text or '')
            if title:find('A:', 1, true) or title:find(d8('А:'), 1, true) or text:find('A:', 1, true) or text:find(d8('А:'), 1, true) then
                zavAdminReply()
            end
            if id == 27636 then
                if text:find(d8('Начать работу')) then sampSendDialogResponse(id, 1, 1, d8('Начать работу')) end
                return false
            elseif id == 27638 then
                if zavOn() and text:find('%[1%].*' .. d8('Стандартный')) then
                    sampSendDialogResponse(id, 1, 0, d8('[1] Стандартный'))
                end
                return false
            end
        end
        if prevDlgZ then return prevDlgZ(id, style, title, b1, b2, text) end
    end
end

pcall(addEventHandler, 'onReceivePacket', function(id, bs)
    if not zavOn() or id ~= 220 then return end
    pcall(raknetBitStreamResetReadPointer, bs)
    raknetBitStreamIgnoreBits(bs, 8)
    local ptype = raknetBitStreamReadInt8(bs)
    local function captcha()
        lua_thread.create(function()
            wait(T.zavCaptcha[0])
            if zavOn() then zavClick(98, 1, -1, '{}') end
        end)
    end
    if ptype == 84 then
        local interfaceid = raknetBitStreamReadInt8(bs)
        if interfaceid == 98 and ZAV.state == 'assembly' then captcha() end
    elseif ptype == 62 then
        local interfaceid = raknetBitStreamReadInt8(bs)
        local toggle = raknetBitStreamReadBool(bs)
        if interfaceid == 98 and ZAV.state == 'assembly' then captcha() end
        if interfaceid == 46 and toggle == false and ZAV.state == 'assembly' then
            ZAV.state = 'putitem'
            lua_thread.create(function()
                wait(T.zavPut[0])
                if T.botZavod[0] then pcall(zavTP, 3) end
            end)
            msg('Завод: сборка завершена, иду сдавать')
        end
    end
end)

function secBotZavod()
    Section('Бот на завод')
    Toggle('botZavod', 'Включить бота завода')
    SliderRow('zavCaptcha', 'Капча (мс)', 1000, 10000, '%d')
    SliderRow('zavTake', 'После взятия (мс)', 500, 5000, '%d')
    SliderRow('zavPut', 'Перед сдачей (мс)', 500, 5000, '%d')
    imgui.TextWrapped('Состояние: ' .. ZAV.state .. (ZAV.paused and ' (ответ админу)' or '') .. '  |  Циклов: ' .. ZAV.ops)
    imgui.Dummy(V2(0, P(6)))
end
end
__botSection()

local function TabContent()
    imgui.SetWindowFontScale(WS)
    if imgui.IsMouseClicked(0) then SCROLLED = false end
    SLIDER_ACT = false
    if curTab == 1 then
        if subTab[1] == 1 then secCharacter()
        else secCamera() end
    elseif curTab == 2 then
        if subTab[2] == 1 then secEspPlayers()
        elseif subTab[2] == 2 then secEspCars()
        else secEspRender() end
    elseif curTab == 3 then
        if subTab[3] == 1 then secCar() else secCarTrailer() end
    elseif curTab == 4 then
        if subTab[4] == 1 then secBotMine()
        elseif subTab[4] == 2 then secBotTsr()
        elseif subTab[4] == 3 then secBotFarm()
        elseif subTab[4] == 4 then secBotLih()
        elseif subTab[4] == 5 then secBotBus()
        elseif subTab[4] == 6 then secBotZavod() end
    elseif curTab == 5 then
        OSA.sec()
    elseif curTab == 6 then
        secChat()
    elseif curTab == 7 then
        local st = subTab[7]
        if st == 1 then secAppearance()
        elseif st == 2 then secAccent()
        elseif st == 3 then secWatermark()
        elseif st == 4 then secEffects()
        else UPD.sec() end
    end
    -- прокрутка перетаскиванием (пальцем / мышью)
    if imgui.IsWindowHovered() and imgui.IsMouseDragging(0, 8) and not SLIDER_ACT then
        SCROLLED = true
        imgui.SetScrollY(imgui.GetScrollY() - imgui.GetIO().MouseDelta.y)
    end
end

local function pushTheme()
    local c = imgui.Col
    local r, g, b = ACC.r, ACC.g, ACC.b
    local list = {
        { c.WindowBg,         V4(G(0.035), G(0.035), G(0.04), T.bgAlpha[0] / 100) },
        { c.ChildBg,          V4(0, 0, 0, 0) },
        { c.PopupBg,          V4(G(0.05), G(0.05), G(0.06), 0.98) },
        { c.Border,           V4(r, g, b, T.fxBorder[0] and 0.85 or 0.0) },
        { c.Text,             V4(G(0.96), G(0.96), G(0.96), 1) },
        { c.FrameBg,          V4(G(0.13), G(0.13), G(0.14), 1) },
        { c.FrameBgHovered,   V4(G(0.17), G(0.17), G(0.18), 1) },
        { c.FrameBgActive,    V4(G(0.21), G(0.21), G(0.22), 1) },
        { c.SliderGrab,       V4(r, g, b, 1) },
        { c.SliderGrabActive, V4(math.min(1, r + 0.18), math.min(1, g + 0.18), math.min(1, b + 0.18), 1) },
        { c.Button,           V4(G(0.14), G(0.14), G(0.15), 1) },
        { c.ButtonHovered,    V4(r, g, b, 0.35) },
        { c.ButtonActive,     V4(r, g, b, 0.70) },
        { c.ScrollbarBg,      V4(G(1), G(1), G(1), 0.07) },
        { c.ScrollbarGrab,    V4(r, g, b, 0.85) },
        { c.ScrollbarGrabHovered, V4(r, g, b, 0.80) },
        { c.ScrollbarGrabActive,  V4(r, g, b, 1.00) },
        { c.TextSelectedBg,   V4(r, g, b, 0.35) },
    }
    for _, it in ipairs(list) do imgui.PushStyleColor(it[1], it[2]) end
    return #list
end

imgui.OnFrame(function() return WinState[0] or menuA > 0.01 end, function(self)
    LIGHT = T.light[0]
    updateAccent()
    local sw, sh = getScreenResolution()
    local dt = imgui.GetIO().DeltaTime

    local target = WinState[0] and 1 or 0
    if T.fxAnim[0] then
        menuA = lerp(menuA, target, math.min(1, dt * 14))
        if math.abs(target - menuA) < 0.01 then menuA = target end
    else
        menuA = target
    end
    GA = menuA

    UI = K * T.scale[0] / 100
    WS = (T.scale[0] / 100) * (T.textScale[0] / 100)

    local k = T.fxAnim[0] and (0.94 + 0.06 * menuA) or 1
    local W = math.min(P(1100), sw * 0.97) * k
    local H = math.min(P(700), sh * 0.94) * k
    local Wf, Hf = W / k, H / k
    if not MP.x then MP.x, MP.y = (sw - Wf) / 2, (sh - Hf) / 2 end
    local ox, oy = MP.x + (Wf - W) / 2, MP.y + (Hf - H) / 2
    local R = P(T.rounding[0])
    UPD.rect.x, UPD.rect.y, UPD.rect.w, UPD.rect.h, UPD.rect.r = ox, oy, W, H, R
    if WinState[0] and UPD.available and UPD.state == 'found' and not UPD.shown then
        UPD.shown = true
        UPD.overlay = true
    end

    -- свечение за окном
    if T.fxGlow[0] then
        local bg = imgui.GetBackgroundDrawList()
        glow(bg, ox, oy, ox + W, oy + H, R, P(28), 0.04)
    end

    imgui.SetNextWindowPos(V2(ox, oy), imgui.Cond.Always)
    imgui.SetNextWindowSize(V2(W, H), imgui.Cond.Always)

    local nc = pushTheme()
    imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, menuA)
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, R)
    imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, P(10))
    imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, P(8))
    imgui.PushStyleVarFloat(imgui.StyleVar.GrabRounding, P(8))
    imgui.PushStyleVarFloat(imgui.StyleVar.ScrollbarRounding, P(8))
    imgui.PushStyleVarFloat(imgui.StyleVar.ScrollbarSize, P(18))
    imgui.PushStyleVarFloat(imgui.StyleVar.GrabMinSize, P(26))
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowBorderSize, P(1.5))
    imgui.PushStyleVarFloat(imgui.StyleVar.ChildBorderSize, 0)
    imgui.PushStyleVarFloat(imgui.StyleVar.FrameBorderSize, 0)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, V2(P(20), P(16)))
    imgui.PushStyleVarVec2(imgui.StyleVar.FramePadding, V2(P(10), P(7)))
    imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, V2(P(10), P(8)))
    local nv = 14

    imgui.Begin('##mir_main', nil,
        imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse +
        imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse + imgui.WindowFlags.NoMove)
    imgui.SetWindowFontScale(WS)

    local dl = imgui.GetWindowDrawList()
    local wp, wsz = imgui.GetWindowPos(), imgui.GetWindowSize()
    local th = imgui.GetTextLineHeight()

    -- акцентная линия
    if T.fxLine[0] then
        dl:AddRectFilledMultiColor(
            V2(wp.x + R, wp.y + P(1)), V2(wp.x + wsz.x - R, wp.y + P(4)),
            AC(1), AC(0), AC(0), AC(1))
    end

    -- шапка
    local cur = imgui.GetCursorScreenPos()
    local ih = P(88)
    drawIcon(dl, cur.x + ih / 2, cur.y + ih / 2, ih / 2 - P(2), T.wmPulse[0])

    -- крупная надпись (размер шрифта задаётся явно)
    local title = ffi.string(T.wmName)
    if title == '' then title = 'Menu' end
    local base = imgui.GetFontSize()
    local target = ih * 0.66
    local ratio = target / base
    local tsz = imgui.CalcTextSize(title)
    local tx = cur.x + ih + P(16)
    local bySize = P(19)
    local gap = P(2)
    local blockH = target + gap + bySize
    local ty = cur.y + (ih - blockH) / 2
    local drawn = pcall(function()
        dl:AddTextFontPtr(imgui.GetFont(), target, V2(tx, ty), U32(1, 1, 1, 1), title)
    end)
    if not drawn then
        imgui.SetWindowFontScale(WS * ratio)
        imgui.SetCursorScreenPos(V2(tx, ty))
        imgui.TextUnformatted(title)
        imgui.SetWindowFontScale(WS)
    end
    local byY = ty + target + gap
    local byDrawn = pcall(function()
        dl:AddTextFontPtr(imgui.GetFont(), bySize, V2(tx, byY), U32(0.82, 0.82, 0.86, 1.0), 'by MonetError')
    end)
    if not byDrawn then
        imgui.SetCursorScreenPos(V2(tx, byY))
        imgui.SetWindowFontScale(WS * (bySize / base))
        imgui.TextColored(V4(0.82, 0.82, 0.86, 1.0), 'by MonetError')
        imgui.SetWindowFontScale(WS)
    end

    local contentW = wsz.x - P(40)
    local closeSz = P(56)
    imgui.SetCursorScreenPos(cur)
    imgui.InvisibleButton('##drag', V2(contentW - closeSz - P(8), ih))
    if imgui.IsItemActive() and imgui.IsMouseDragging(0, 0) then
        local d = imgui.GetIO().MouseDelta
        MP.x = clamp(MP.x + d.x, -Wf + P(120), sw - P(120))
        MP.y = clamp(MP.y + d.y, 0, sh - P(60))
    end
    imgui.SetCursorScreenPos(V2(wp.x + wsz.x - closeSz - P(10), wp.y + P(10)))
    if CloseButton('##close', closeSz) then WinState[0] = false end

    imgui.SetCursorScreenPos(cur)
    imgui.Dummy(V2(1, ih))

    -- боковая панель + правая часть
    imgui.Dummy(V2(1, P(4)))
    local availAll = imgui.GetContentRegionAvail()
    local sideW = P(230)
    local gapS = P(14)

    imgui.BeginChild('##side', V2(sideW, availAll.y), false)
    Sidebar()
    imgui.EndChild()
    imgui.SameLine(0, gapS)

    imgui.BeginChild('##right', V2(availAll.x - sideW - gapS, availAll.y), false)
    imgui.SetWindowFontScale(WS)
    SubTabsBar()

    local av = imgui.GetContentRegionAvail()
    imgui.BeginChild('##content', V2(av.x, av.y), false)
    TabContent()
    imgui.EndChild()
    imgui.EndChild()

    imgui.End()
    imgui.PopStyleVar(nv)
    imgui.PopStyleColor(nc)
end)

local WMFPS = { frames = 0, t = os.clock(), val = 0 }

imgui.OnFrame(function() return T.wmShow[0] end, function(self)
    self.HideCursor = true
    LIGHT = false
    updateAccent()

    -- реальный FPS: считаем кадры и обновляем значение раз в 0.5 сек
    WMFPS.frames = WMFPS.frames + 1
    local nowT = os.clock()
    local dtF = nowT - WMFPS.t
    if dtF >= 0.5 then
        local f = WMFPS.frames / dtF
        WMFPS.val = (WMFPS.val == 0) and f or (WMFPS.val * 0.5 + f * 0.5)
        WMFPS.frames = 0
        WMFPS.t = nowT
    end
    GA = 1
    local sw, sh = getScreenResolution()
    T.wmScale[0] = math.max(1, math.min(100, T.wmScale[0]))
    local u = K * (T.wmScale[0] * 3) / 100
    local a = T.wmAlpha[0] / 100
    local G = 14 * u
    local m = T.wmMargin[0] * K
    local corner = T.wmCorner[0]
    local right = (corner == 1 or corner == 3)
    local bottom = (corner == 2 or corner == 3)

    local px = right and (sw - m + G) or (m - G)
    local py = bottom and (sh - m + G) or (m - G)
    imgui.SetNextWindowPos(V2(px, py), imgui.Cond.Always, V2(right and 1 or 0, bottom and 1 or 0))

    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, V2(0, 0))
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowBorderSize, 0)
    imgui.Begin('##mir_wm', nil,
        imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove +
        imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse + imgui.WindowFlags.NoBackground +
        imgui.WindowFlags.NoSavedSettings + imgui.WindowFlags.AlwaysAutoResize +
        imgui.WindowFlags.NoFocusOnAppearing + imgui.WindowFlags.NoNav)
    imgui.SetWindowFontScale(0.92 * (T.wmScale[0] * 3) / 100)

    local dl = imgui.GetWindowDrawList()
    local th = imgui.GetTextLineHeight()

    -- состав надписи
    local parts = {}
    local function add(txt, r, g, b, ex, fixedFps)
        if txt and txt ~= '' then parts[#parts + 1] = { t = txt, c = { r, g, b }, ex = ex, fps = fixedFps } end
    end
    add(ffi.string(T.wmName), 1, 1, 1)
    add(ffi.string(T.wmUser), 0.72, 0.72, 0.76)
    add(ffi.string(T.wmGame), ACC.r, ACC.g, ACC.b)
    if T.wmFps[0] then
        local fv = clamp(math.floor(WMFPS.val + 0.5), 0, 999)
        add(('%d FPS'):format(fv), 0.72, 0.72, 0.76, false, true)
    end
    if T.wmPing[0] then
        local ping = 0
        pcall(function()
            local okp, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
            if okp then ping = sampGetPlayerPing(id) end
        end)
        add(('%d ms'):format(ping), 0.72, 0.72, 0.76, true)
    end
    if T.wmTime[0] then
        local okt, ts = pcall(os.date, '%H:%M')
        add(okt and ts or '--:--', 0.72, 0.72, 0.76)
    end

    local padV, padH = 8 * u, 14 * u
    local pillH = th + padV * 2
    local iconD = pillH - 8 * u
    local gapI = 10 * u
    local sepGap = 10 * u
    local tw = 0
    for _, p in ipairs(parts) do
        -- Reserve a little extra width so changing FPS digits cannot be clipped.
        if p.fps then
            -- фиксированная ширина под FPS, чтобы ватермарка не дергалась и не пропадала
            p.w = imgui.CalcTextSize('000 FPS').x + 4 * u
        else
            p.w = imgui.CalcTextSize(p.t).x + (p.ex and 14 * u or 0)
        end
        tw = tw + p.w
    end
    local seps = math.max(0, #parts - 1)
    local pillW = 4 * u + iconD + gapI + tw + seps * (sepGap * 2 + 1) + padH

    local base = imgui.GetCursorScreenPos()
    local p1 = V2(base.x + G, base.y + G)
    local p2 = V2(p1.x + pillW, p1.y + pillH)

    imgui.SetCursorScreenPos(p1)
    imgui.InvisibleButton('##wm_btn', V2(pillW, pillH))
    if imgui.IsItemClicked(0) then WinState[0] = not WinState[0] end
    local hv = hoverAnim('wm', imgui.IsItemHovered() or imgui.IsItemActive())

    GA = a
    if T.wmGlow[0] then
        local pulse = 0.5 + 0.5 * math.sin(os.clock() * 2.2)
        glow(dl, p1.x, p1.y, p2.x, p2.y, pillH / 2, G * (0.75 + 0.25 * pulse), 0.05 + 0.03 * hv)
    end
    dl:AddRectFilled(p1, p2, U32(0.035, 0.035, 0.04, 0.92), pillH / 2)
    dl:AddRect(p1, p2, AC(0.65 + 0.35 * hv), pillH / 2)
    dl:AddRect(V2(p1.x + 1, p1.y + 1), V2(p2.x - 1, p2.y - 1), AC(0.25 + 0.2 * hv), pillH / 2)

    -- блик
    if T.wmShine[0] then
        local frac = ((os.clock() * 0.45) % 2.4) / 1.0
        if frac < 1 then
            local cx1, cx2 = p1.x + pillH * 0.5, p2.x - pillH * 0.5
            local x = lerp(cx1, cx2, frac)
            local bw = pillH * 1.5
            local c0, c1 = U32(1, 1, 1, 0), U32(1, 1, 1, 0.16)
            dl:PushClipRect(V2(cx1, p1.y), V2(cx2, p2.y), true)
            dl:AddRectFilledMultiColor(V2(x - bw / 2, p1.y), V2(x, p2.y), c0, c1, c1, c0)
            dl:AddRectFilledMultiColor(V2(x, p1.y), V2(x + bw / 2, p2.y), c1, c0, c0, c1)
            dl:PopClipRect()
        end
    end

    -- иконка
    drawIcon(dl, p1.x + 4 * u + iconD / 2, p1.y + pillH / 2, iconD / 2, T.wmPulse[0])

    -- текст
    local x = p1.x + 4 * u + iconD + gapI
    local ty = p1.y + (pillH - th) / 2
    for i, p in ipairs(parts) do
        dl:AddText(V2(x, ty), U32(p.c[1], p.c[2], p.c[3], 1), p.t)
        x = x + p.w
        if i < #parts then
            local lx = x + sepGap
            dl:AddLine(V2(lx, p1.y + pillH * 0.28), V2(lx, p2.y - pillH * 0.28), U32(1, 1, 1, 0.28), math.max(1, u))
            x = x + sepGap * 2 + 1
        end
    end
    GA = 1

    imgui.SetCursorScreenPos(base)
    imgui.Dummy(V2(pillW + G * 2, pillH + G * 2))

    imgui.End()
    imgui.PopStyleVar(2)
end)

imgui.OnFrame(function() return T.attachTrailer[0] and ATR_SHOW end, function(self)
    self.HideCursor = true
    local sw, sh = getScreenResolution()
    imgui.SetNextWindowPos(V2(sw / 2, sh - 24 * K), imgui.Cond.Always, V2(0.5, 1))
    imgui.Begin('##atr_btn', nil,
        imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove +
        imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoBackground + imgui.WindowFlags.NoSavedSettings +
        imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoFocusOnAppearing + imgui.WindowFlags.NoNav)
    imgui.SetWindowFontScale(K)
    if imgui.Button('Прицепить / Отцепить', V2(260 * K, 56 * K)) then ATR_CLICK = true end
    imgui.End()
end)

imgui.OnFrame(function() return T.clickWarp[0] end, function(self)
    self.HideCursor = true
    local sw, sh = getScreenResolution()
    imgui.SetNextWindowPos(V2(sw / 2, sh - 96 * K), imgui.Cond.Always, V2(0.5, 1))
    imgui.Begin('##cw_btn', nil,
        imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove +
        imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoBackground + imgui.WindowFlags.NoSavedSettings +
        imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoFocusOnAppearing + imgui.WindowFlags.NoNav)
    imgui.SetWindowFontScale(K)
    if imgui.Button(CW.active and 'ClickWarp: отмена' or 'ClickWarp: выбрать точку', V2(260 * K, 56 * K)) then CW.toggle() end
    imgui.End()
end)

imgui.OnFrame(function() return UPD.overlay and (WinState[0] or menuA > 0.5) end, function(self)
    LIGHT = T.light[0]
    GA = 1
    local R0 = UPD.rect
    local nc = pushTheme()
    imgui.PushStyleColor(imgui.Col.WindowBg, V4(0, 0, 0, 0.68))
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, R0.r)
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowBorderSize, 0)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, V2(0, 0))
    imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, P(10))
    imgui.SetNextWindowPos(V2(R0.x, R0.y), imgui.Cond.Always)
    imgui.SetNextWindowSize(V2(R0.w, R0.h), imgui.Cond.Always)
    if imgui.SetNextWindowFocus then imgui.SetNextWindowFocus() end
    imgui.Begin('##upd_ov', nil,
        imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove +
        imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse +
        imgui.WindowFlags.NoSavedSettings + imgui.WindowFlags.NoCollapse)
    imgui.SetWindowFontScale(WS)

    local dl = imgui.GetWindowDrawList()
    local wp = imgui.GetWindowPos()
    local W, H = R0.w, R0.h

    if UPD.state == 'checking' then
        local el = os.clock() - UPD.startT
        if UPD.res and el >= 1.3 then
            UPD.apply(false)
        elseif el > 20 then
            UPD.state = 'error'
            UPD.err = 'Время ожидания истекло'
        end
    end
    local st = UPD.state

    local pw = math.min(P(520), W * 0.9)
    local ph = P(210)
    if st == 'none' or st == 'error' then ph = P(250) end
    if st == 'found' then ph = math.min(P(480), H * 0.92) end
    local px, py = wp.x + (W - pw) / 2, wp.y + (H - ph) / 2

    glow(dl, px, py, px + pw, py + ph, P(16), P(22), 0.05)
    dl:AddRectFilled(V2(px, py), V2(px + pw, py + ph), U32(0.06, 0.06, 0.07, 1), P(16))
    dl:AddRect(V2(px, py), V2(px + pw, py + ph), AC(0.9), P(16), 0, P(1.5))
    dl:AddRectFilledMultiColor(V2(px + P(16), py + P(1)), V2(px + pw - P(16), py + P(4)), AC(1), AC(0), AC(0), AC(1))

    local function ctext(txt, y, col)
        local ts = imgui.CalcTextSize(txt)
        dl:AddText(V2(px + (pw - ts.x) / 2, y), col, txt)
    end
    local function big(txt, y, col, size)
        -- без AddTextFontPtr с произвольным размером (роняет нативный ImDrawList на NeoMLoader):
        -- крупный текст рисуем через масштаб шрифта окна
        local base = imgui.GetFontSize()
        if not base or base <= 0 then ctext(txt, y, col) return end
        imgui.SetWindowFontScale(WS * size / base)
        local ts = imgui.CalcTextSize(txt)
        dl:AddText(V2(px + (pw - ts.x) / 2, y), col, txt)
        imgui.SetWindowFontScale(WS)
    end
    local function spinner(cx, cy, r)
        local t = os.clock()
        for i = 0, 11 do
            local a = i * math.pi / 6
            local al = 1 - ((t * 1.6 - i / 12) % 1)
            dl:AddCircleFilled(V2(cx + math.cos(a) * r, cy + math.sin(a) * r),
                r * 0.17 * (0.6 + 0.4 * al), AC(0.15 + 0.85 * al), 10)
        end
    end
    local function button(id, label, x, y, w, h, primary)
        imgui.SetCursorScreenPos(V2(x, y))
        imgui.InvisibleButton('##ub' .. id, V2(w, h))
        local clicked = imgui.IsItemClicked(0)
        local hov = hoverAnim('ub' .. id, imgui.IsItemHovered())
        local p1, p2 = V2(x, y), V2(x + w, y + h)
        local ts = imgui.CalcTextSize(label)
        local tp = V2(x + (w - ts.x) / 2, y + (h - ts.y) / 2)
        if primary then
            dl:AddRectFilled(p1, p2, AC(0.85 + 0.15 * hov), P(10))
            dl:AddText(tp, ONC(1), label)
        else
            dl:AddRectFilled(p1, p2, U32(0.14, 0.14, 0.15, 1), P(10))
            dl:AddRect(p1, p2, AC(0.35 + 0.4 * hov), P(10))
            dl:AddText(tp, U32(0.95, 0.95, 0.95, 1), label)
        end
        return clicked
    end

    local white = U32(0.96, 0.96, 0.96, 1)
    local grey = U32(0.7, 0.7, 0.72, 1)
    local bx, bw = px + P(30), pw - P(60)

    if st == 'checking' or st == 'downloading' or st == 'done' then
        spinner(px + pw / 2, py + P(66), P(26))
        local line1, line2 = 'Подождите, пожалуйста', 'Проверка обновлений...'
        if st == 'downloading' then line2 = 'Скачивание обновления...' end
        if st == 'done' then line1, line2 = 'Готово!', 'Скрипт перезагружается...' end
        big(line1, py + P(120), white, P(26))
        ctext(line2, py + P(158), grey)
    elseif st == 'none' then
        big('Обновлений не найдено!', py + P(36), AC(1), P(26))
        ctext('Вы на последней версии :)', py + P(88), white)
        ctext('Версия: v' .. UPD.VERSION, py + P(120), grey)
        if button('close', 'Закрыть', bx, py + ph - P(74), bw, P(50), true) then UPD.overlay = false end
    elseif st == 'error' then
        big('Ошибка', py + P(36), U32(1, 0.35, 0.35, 1), P(26))
        ctext(UPD.err, py + P(92), white)
        ctext('Попробуйте позже', py + P(122), grey)
        if button('close', 'Закрыть', bx, py + ph - P(74), bw, P(50), true) then UPD.overlay = false end
    elseif st == 'found' then
        big('Обновление найдено!', py + P(24), AC(1), P(26))
        ctext('Версия ' .. UPD.ver, py + P(70), white)
        local y = py + P(98)
        if UPD.date ~= '' then
            ctext('Выход обновления: ' .. UPD.date, y, grey)
            y = y + P(30)
        end
        dl:AddText(V2(bx, y + P(6)), white, 'Что изменилось?')
        local listY = y + P(36)
        local listH = py + ph - P(84) - listY
        imgui.SetCursorScreenPos(V2(bx, listY))
        imgui.BeginChild('##upd_changes', V2(bw, listH), false)
        imgui.SetWindowFontScale(WS)
        if #UPD.changes == 0 then
            imgui.TextColored(V4(G(0.7), G(0.7), G(0.7), 1), 'Список изменений не указан')
        else
            for i, c in ipairs(UPD.changes) do
                imgui.TextWrapped(i .. ') ' .. c)
            end
        end
        if imgui.IsWindowHovered() and imgui.IsMouseDragging(0, 8) then
            imgui.SetScrollY(imgui.GetScrollY() - imgui.GetIO().MouseDelta.y)
        end
        imgui.EndChild()
        local hw = (bw - P(12)) / 2
        local by = py + ph - P(70)
        if button('later', 'Позже', bx, by, hw, P(50), false) then UPD.overlay = false end
        if button('upd', 'Обновить', bx + hw + P(12), by, hw, P(50), true) then UPD.start() end
    end

    imgui.SetCursorScreenPos(wp)
    imgui.Dummy(V2(1, 1))
    imgui.End()
    imgui.PopStyleVar(4)
    imgui.PopStyleColor(nc + 1)
end)

function main()
    if isSampLoaded and not isSampLoaded() then return end
    while isSampAvailable and not isSampAvailable() do wait(100) end

    sampRegisterChatCommand('osiris', function() WinState[0] = not WinState[0] end)
    msg('Меню: {FFFFFF}/osiris{FFFFFF} или нажми на ватермарку')
    pcall(UPD.check, true)

    local lastSave = os.clock()
    while true do
        wait(0)
        if os.clock() - lastSave > 1 then
            saveCfg(false)
            lastSave = os.clock()
        end
        pcall(tick)
        pcall(UPD.pump)
    end
end

function onScriptTerminate(scr, quitGame)
    if scr == thisScript() then
        pcall(restoreAirBrake)
        if cam and cam.active then pcall(camOff) end
        if flyLastCar and doesVehicleExist and doesVehicleExist(flyLastCar) then
            pcall(setCarProofs, flyLastCar, false, false, false, false, false)
            pcall(setCharCanBeKnockedOffBike, flyLastCar, true)
        end
        saveCfg(true)
    end
end
