local WidgetContainer = require("ui/widget/container/widgetcontainer")
local VerticalGroup = require("ui/widget/verticalgroup")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local CenterContainer = require("ui/widget/container/centercontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local TextWidget = require("ui/widget/textwidget")
local Button = require("ui/widget/button")
local UIManager = require("ui/uimanager")
local Screen = require("device").screen
local Font = require("ui/font")
local Blitbuffer = require("ffi/blitbuffer")
local _ = require("gettext")

local Mus = WidgetContainer:extend({
    name = "mus",
})

function Mus:init()
    self.target = 40
    self.scores = {
        nosotros = 0,
        ellos = 0,
    }
    self.juegos = {
        nosotros = 0,
        ellos = 0,
    }
    self.last_winner = nil
    self.window = nil

    self.ui.menu:registerToMainMenu(self)
end

function Mus:addToMainMenu(menu_items)
    menu_items.mus = {
        text = _("Mus — Marcador"),
        sorting_hint = "tools",
        callback = function()
            self:show()
        end,
    }
end

function Mus:_getDimensions()
    local screen_width = Screen:getWidth()
    local screen_height = Screen:getHeight()
    local button_height = math.max(60, math.min(78, math.floor(screen_height / 12)))
    local content_width = math.max(240, screen_width - 32)
    return content_width, button_height
end

function Mus:_makeText(text, width)
    return TextWidget:new({
        text = text,
        face = Font:getFace("cfont", 20),
        width = width,
    })
end

function Mus:_makeButton(text, callback, width, height)
    return Button:new({
        text = text,
        callback = callback,
        width = width,
        height = height,
        bordersize = 2,
        radius = 0,
    })
end

function Mus:_closeWindow()
    if self.window then
        UIManager:close(self.window)
        self.window = nil
    end
end

function Mus:_changeScore(side, amount)
    self.scores[side] = math.max(0, math.min(self.target, self.scores[side] + amount))

    if self.scores[side] >= self.target then
        -- Al ganar el juego, se suma un juego al equipo y comienza
        -- automáticamente un nuevo tanteo para ambos equipos.
        self.juegos[side] = self.juegos[side] + 1
        self.scores.nosotros = 0
        self.scores.ellos = 0
        self.last_winner = side
    else
        self.last_winner = nil
    end

    self:show()
end

function Mus:_resetTantos()
    -- Reinicia solo los tantos de la partida; conserva los juegos ganados.
    self.scores.nosotros = 0
    self.scores.ellos = 0
    self.last_winner = nil
    self:show()
end

function Mus:_newGame()
    self.scores.nosotros = 0
    self.scores.ellos = 0
    self.juegos.nosotros = 0
    self.juegos.ellos = 0
    self.last_winner = nil
    self:show()
end

function Mus:_toggleTarget()
    -- El objetivo solo se puede cambiar si el tanteo está a cero.
    if self.scores.nosotros ~= 0 or self.scores.ellos ~= 0 then
        return
    end

    self.target = self.target == 40 and 30 or 40
    self.last_winner = nil
    self:show()
end

function Mus:_makeTeam(side, label, content_width, button_width, button_height)
    local score = self.scores[side]
    local amarracos = math.floor(score / 5)
    local piedras = score % 5

    local widgets = {
        align = "center",
        self:_makeText(label, content_width),
        self:_makeText(string.format(_("%d tantos"), score), content_width),
        self:_makeText(
            string.format(_("%d amarrakos, %d piedras"), amarracos, piedras),
            content_width
        ),
    }

    table.insert(widgets, HorizontalGroup:new({
        align = "center",
        self:_makeButton(_("+1 Piedra"), function()
            self:_changeScore(side, 1)
        end, button_width, button_height),
        self:_makeButton(_("-1 Piedra"), function()
            self:_changeScore(side, -1)
        end, button_width, button_height),
    }))

    table.insert(widgets, HorizontalGroup:new({
        align = "center",
        self:_makeButton(_("+5 Amarrako"), function()
            self:_changeScore(side, 5)
        end, button_width, button_height),
        self:_makeButton(_("-5 Amarrako"), function()
            self:_changeScore(side, -5)
        end, button_width, button_height),
    }))

    return VerticalGroup:new(widgets)
end

function Mus:show()
    self:_closeWindow()

    local content_width, button_height = self:_getDimensions()
    local button_width = math.floor((content_width - 8) / 2)

    local widgets = {
        align = "center",
        self:_makeText(_("Marcador de Mus"), content_width),
        self:_makeText(
            string.format(_("Juegos — Nosotros: %d | Ellos: %d"),
                self.juegos.nosotros, self.juegos.ellos),
            content_width
        ),
    }

    if self.scores.nosotros == 0 and self.scores.ellos == 0 then
        table.insert(widgets, self:_makeButton(
            string.format(_("Tantos a %d — cambiar límite"), self.target),
            function()
                self:_toggleTarget()
            end,
            content_width,
            button_height
        ))
    else
        table.insert(widgets, self:_makeText(
            string.format(_("Tantos a %d"), self.target),
            content_width
        ))
    end

    if self.last_winner then
        local winner_name = self.last_winner == "nosotros" and _("Nosotros") or _("Ellos")
        table.insert(widgets, self:_makeText(
            string.format(_("¡%s ha ganado un juego! Los tantos vuelven a cero."), winner_name),
            content_width
        ))
    end

    table.insert(widgets, self:_makeTeam(
        "nosotros", _("Nosotros"), content_width, button_width, button_height
    ))
    table.insert(widgets, self:_makeTeam(
        "ellos", _("Ellos"), content_width, button_width, button_height
    ))

    table.insert(widgets, HorizontalGroup:new({
        align = "center",
        self:_makeButton(_("Reiniciar tantos"), function()
            self:_resetTantos()
        end, button_width, button_height),
        self:_makeButton(_("Nueva partida"), function()
            self:_newGame()
        end, button_width, button_height),
    }))

    table.insert(widgets, self:_makeButton(_("Cerrar"), function()
        self:_closeWindow()
    end, content_width, button_height))

    self.window = CenterContainer:new({
        dimen = Screen:getSize(),
        FrameContainer:new({
            background = Blitbuffer.COLOR_WHITE,
            bordersize = 2,
            padding = 12,
            VerticalGroup:new(widgets),
        }),
    })

    UIManager:show(self.window)
end

return Mus
