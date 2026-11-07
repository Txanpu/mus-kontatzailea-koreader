local WidgetContainer = require("ui/widget/container/widgetcontainer")
local VerticalGroup = require("ui/widget/container/verticalgroup")
local HorizontalGroup = require("ui/widget/container/horizontalgroup")
local CenterContainer = require("ui/widget/container/centercontainer")
local TextWidget = require("ui/widget/textwidget")
local Button = require("ui/widget/button")
local UIManager = require("ui/uimanager")
local Screen = require("device").screen
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
    self.chicos = {
        nosotros = 0,
        ellos = 0,
    }
    self.winner = nil
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
    if self.winner then
        return
    end

    self.scores[side] = math.max(0, math.min(self.target, self.scores[side] + amount))

    if self.scores[side] >= self.target then
        self.winner = side
        self.chicos[side] = self.chicos[side] + 1
    end

    self:show()
end

function Mus:_resetChico()
    -- Deshacer la anotación si se reinicia después de declarar la victoria.
    if self.winner then
        self.chicos[self.winner] = math.max(0, self.chicos[self.winner] - 1)
    end

    self.scores.nosotros = 0
    self.scores.ellos = 0
    self.winner = nil
    self:show()
end

function Mus:_newGame()
    self.scores.nosotros = 0
    self.scores.ellos = 0
    self.chicos.nosotros = 0
    self.chicos.ellos = 0
    self.winner = nil
    self:show()
end

function Mus:_nextChico()
    self.scores.nosotros = 0
    self.scores.ellos = 0
    self.winner = nil
    self:show()
end

function Mus:_toggleTarget()
    -- El objetivo solo se puede cambiar al empezar un chico.
    if self.scores.nosotros ~= 0 or self.scores.ellos ~= 0 or self.winner then
        return
    end

    self.target = self.target == 40 and 30 or 40
    self:show()
end

function Mus:_makeTeam(side, label, content_width, button_width, button_height)
    local score = self.scores[side]
    local amarracos = math.floor(score / 5)
    local piedras = score % 5

    local widgets = {
        align = "center",
        self:_makeText(label, content_width),
        self:_makeText(string.format(_("%d puntos"), score), content_width),
        self:_makeText(
            string.format(_("%d amarracos, %d piedras"), amarracos, piedras),
            content_width
        ),
    }

    if not self.winner then
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
            self:_makeButton(_("+5 Amarraco"), function()
                self:_changeScore(side, 5)
            end, button_width, button_height),
            self:_makeButton(_("-5 Amarraco"), function()
                self:_changeScore(side, -5)
            end, button_width, button_height),
        }))
    end

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
            string.format(_("Chicos — Nosotros: %d | Ellos: %d"),
                self.chicos.nosotros, self.chicos.ellos),
            content_width
        ),
    }

    if self.scores.nosotros == 0 and self.scores.ellos == 0 and not self.winner then
        table.insert(widgets, self:_makeButton(
            string.format(_("Chico a %d puntos — cambiar límite"), self.target),
            function()
                self:_toggleTarget()
            end,
            content_width,
            button_height
        ))
    else
        table.insert(widgets, self:_makeText(
            string.format(_("Chico a %d puntos"), self.target),
            content_width
        ))
    end

    if self.winner then
        local winner_name = self.winner == "nosotros" and _("Nosotros") or _("Ellos")
        table.insert(widgets, self:_makeText(
            string.format(_("¡%s gana el chico!"), winner_name),
            content_width
        ))
        table.insert(widgets, self:_makeButton(
            _("Empezar siguiente chico"),
            function()
                self:_nextChico()
            end,
            content_width,
            button_height
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
        self:_makeButton(_("Reiniciar chico"), function()
            self:_resetChico()
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
        child = VerticalGroup:new(widgets),
    })

    UIManager:show(self.window)
end

return Mus
