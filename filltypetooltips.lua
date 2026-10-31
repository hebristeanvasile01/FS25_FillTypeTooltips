-- Fill Type Tooltips: hover the fill type icons in the shop (and anywhere else in the menus)
-- and a small tooltip shows the name of the fill type, in the game language.
-- Author: FS Modding
FillTypeTooltips = {}

FillTypeTooltips.TEXT_SIZE = 0.013
FillTypeTooltips.PADDING = 0.004

FillTypeTooltips.lookup = nil      -- built on first use
FillTypeTooltips.mouseX = 0
FillTypeTooltips.mouseY = 0
FillTypeTooltips.hovered = nil
FillTypeTooltips.tagged = 0

-- ---------------------------------------------------------------- fill type names

local function token(value)
    -- "data/.../hud_fill_wheat.png" -> "wheat", "fillTypes.wheat" -> "wheat"
    local s = string.lower(value)
    s = string.gsub(s, "%.png$", "")
    s = string.gsub(s, "%.dds$", "")
    s = string.match(s, "([^/%.]+)$") or s
    s = string.gsub(s, "^hud_fill_", "")
    s = string.gsub(s, "^filltype_", "")
    return s
end

function FillTypeTooltips:buildLookup()
    self.byName, self.byFile = {}, {}
    self.lookup = true
    if g_fillTypeManager == nil then return end
    local count = 0
    for _, fillType in ipairs(g_fillTypeManager:getFillTypes()) do
        local title = fillType.title
        if title ~= nil and title ~= "" and fillType.name ~= "UNKNOWN" then
            self.byName[string.lower(fillType.name)] = title
            local file = fillType.hudOverlayFilename
            if file ~= nil and file ~= "" then
                -- several fill types can share one icon: keep them all
                for _, key in ipairs({ string.lower(file), token(file) }) do
                    local list = self.byFile[key]
                    if list == nil then
                        list = {}
                        self.byFile[key] = list
                    end
                    table.insert(list, { name = string.lower(fillType.name), title = title })
                end
            end
            count = count + 1
        end
    end
    Logging.info("[FillTypeTooltips] %d fill types ready", count)
end

function FillTypeTooltips:titleFor(value)
    if type(value) ~= "string" or value == "" then return nil end
    if self.lookup == nil then self:buildLookup() end
    local t = token(value)
    -- 1) the icon is named after its fill type (hud_fill_fertilizer -> FERTILIZER): that one wins
    if self.byName[t] ~= nil then return self.byName[t] end
    -- 2) otherwise the fill types that use this icon file
    local list = self.byFile[string.lower(value)] or self.byFile[t]
    if list == nil then return nil end
    if #list == 1 then return list[1].title end
    for _, e in ipairs(list) do
        if e.name == t then return e.title end
    end
    -- shared icon: show every fill type that uses it
    local titles = {}
    for _, e in ipairs(list) do table.insert(titles, e.title) end
    return table.concat(titles, " / ")
end

-- ---------------------------------------------------------------- tag icons when the menu sets their image

local function tag(element, ...)
    for i = 1, select("#", ...) do
        local title = FillTypeTooltips:titleFor(select(i, ...))
        if title ~= nil then
            element.fillTypeTooltip = title
            FillTypeTooltips.tagged = FillTypeTooltips.tagged + 1
            if FillTypeTooltips.tagged == 1 then
                Logging.info("[FillTypeTooltips] first fill type icon found: %s", title)
            end
            return
        end
    end
end

if BitmapElement ~= nil then
    for _, name in ipairs({ "setImageFilename", "setImageSlice" }) do
        if BitmapElement[name] ~= nil then
            BitmapElement[name] = Utils.appendedFunction(BitmapElement[name], function(element, ...)
                element.fillTypeTooltip = nil
                tag(element, ...)
            end)
        end
    end

    -- remember the icon under the mouse while it is drawn
    if BitmapElement.draw ~= nil then
        BitmapElement.draw = Utils.appendedFunction(BitmapElement.draw, function(element)
            if element.fillTypeTooltip == nil then return end
            local pos, size = element.absPosition, element.absSize
            if pos == nil or size == nil then return end
            local mx, my = FillTypeTooltips.mouseX, FillTypeTooltips.mouseY
            if mx >= pos[1] and mx <= pos[1] + size[1] and my >= pos[2] and my <= pos[2] + size[2] then
                FillTypeTooltips.hovered = element
            end
        end)
    end
else
    Logging.warning("[FillTypeTooltips] BitmapElement not found")
end

-- ---------------------------------------------------------------- mouse position

if Gui ~= nil and Gui.mouseEvent ~= nil then
    Gui.mouseEvent = Utils.prependedFunction(Gui.mouseEvent, function(gui, posX, posY, ...)
        FillTypeTooltips.mouseX, FillTypeTooltips.mouseY = posX, posY
    end)
end

function FillTypeTooltips:mouseEvent(posX, posY, isDown, isUp, button)
    self.mouseX, self.mouseY = posX, posY
end

-- ---------------------------------------------------------------- the tooltip, drawn on top of the menu

function FillTypeTooltips:drawTooltip()
    local element = self.hovered
    self.hovered = nil
    if element == nil or element.fillTypeTooltip == nil then return end
    if element.getIsVisible ~= nil and not element:getIsVisible() then return end

    local text = element.fillTypeTooltip
    local size = self.TEXT_SIZE
    local pad = self.PADDING
    local w = getTextWidth(size, text) + pad * 2
    local h = size + pad * 2
    local x = self.mouseX + 0.012
    local y = self.mouseY - h - 0.006
    if x + w > 0.995 then x = self.mouseX - w - 0.006 end
    if y < 0.005 then y = self.mouseY + 0.02 end

    if drawFilledRect ~= nil then
        drawFilledRect(x, y, w, h, 0.02, 0.02, 0.02, 0.92)
        drawFilledRect(x, y, w, 0.0015, 0.35, 0.75, 0.2, 1)
    end
    setTextAlignment(RenderText.ALIGN_LEFT)
    if setTextVerticalAlignment ~= nil and RenderText.VERTICAL_ALIGN_BASELINE ~= nil then
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
    end
    setTextBold(false)
    setTextColor(1, 1, 1, 1)
    renderText(x + pad, y + pad + size * 0.22, size, text)
    setTextColor(1, 1, 1, 1)
end

if Gui ~= nil and Gui.draw ~= nil then
    Gui.draw = Utils.appendedFunction(Gui.draw, function(gui)
        FillTypeTooltips:drawTooltip()
    end)
else
    Logging.warning("[FillTypeTooltips] Gui.draw not found, tooltips cannot be drawn")
end

function FillTypeTooltips:loadMap()
    self:buildLookup()
end

addModEventListener(FillTypeTooltips)
