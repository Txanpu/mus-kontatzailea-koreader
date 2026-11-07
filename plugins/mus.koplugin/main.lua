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
        azul = 0,
        rojo = 0,
    }
    self.juegos = {
        azul = 0,
        rojo = 0,
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

function Mus:_getLayoutMetrics()
    local screen_w = Screen:getWidth()
    local screen_h = Screen:getHeight()

    local panel_w = screen_w - 24
    local inner_w = panel_w - 24

    local btn_main_h = math.max(52, math.min(82, math.floor(screen_h * 0.08)))
    local btn_sub_h = math.max(42, math.min(64, math.floor(screen_h * 0.06)))
    local btn_ctrl_h = math.max(42, math.min(62, math.floor(screen_h * 0.058)))

    local btn_w_3 = math.floor((inner_w - 16) / 3)
    local btn_w_2 = math.floor((inner_w - 12) / 2)
    local btn_w_4 = math.floor((panel_w - 24) / 4)

    return {
        screen_w = screen_w,
        screen_h = screen_h,
        panel_w = panel_w,
        inner_w = inner_w,
        btn_main_h = btn_main_h,
        btn_sub_h = btn_sub_h,
        btn_ctrl_h = btn_ctrl_h,
        btn_w_3 = btn_w_3,
        btn_w_2 = btn_w_2,
        btn_w_4 = btn_w_4,
    }
end

function Mus:_makeText(text, font_size)
    return TextWidget:new({
        text = text,
        face = Font:getFace("cfont", font_size or 20),
    })
end

function Mus:_makeButton(text, callback, width, height, bordersize)
    return Button:new({
        text = text,
        callback = function()
            callback()
        end,
        width = width,
        height = height,
        bordersize = bordersize or 2,
        radius = 0,
        margin = 2,
        padding = 2,
    })
end

function Mus:_closeWindow(is_exiting)
    if self.window then
        UIManager:close(self.window)
        self.window = nil
        if is_exiting then
            UIManager:setDirty("all", "ui")
        end
    end
end

function Mus:_quitApp()
    self:_closeWindow(false)
    UIManager:quit()
end

function Mus:_changeScore(side, amount)
    local next_score = math.max(0, self.scores[side] + amount)

    if next_score >= self.target then
        self.juegos[side] = self.juegos[side] + 1
        self.scores.azul = 0
        self.scores.rojo = 0
        self.last_winner = side
    else
        self.scores[side] = next_score
        self.last_winner = nil
    end

    self:show()
end

function Mus:_resetTantos()
    self.scores.azul = 0
    self.scores.rojo = 0
    self.last_winner = nil
    self:show()
end

function Mus:_newGame()
    self.scores.azul = 0
    self.scores.rojo = 0
    self.juegos.azul = 0
    self.juegos.rojo = 0
    self.last_winner = nil
    self:show()
end

function Mus:_toggleTarget()
    if self.scores.azul ~= 0 or self.scores.rojo ~= 0 then
        return
    end

    self.target = self.target == 40 and 30 or 40
    self.last_winner = nil
    self:show()
end

function Mus:_makeTeamPanel(side, title, is_top_team, m)
    local score = self.scores[side]
    local hamarrekos = math.floor(score / 5)
    local piedras = score % 5
    local juegos = self.juegos[side]

    local header_text = self:_makeText(
        string.format(_("%s  —  Juegos: %d"), title, juegos),
        20
    )
    local score_text = self:_makeText(
        string.format(_("%d tantos"), score),
        30
    )
    local detail_text = self:_makeText(
        string.format(_("%d hamarrekos  ·  %d piedras"), hamarrekos, piedras),
        18
    )

    local add_row = HorizontalGroup:new({
        align = "center",
        self:_makeButton(_("+1"), function()
            self:_changeScore(side, 1)
        end, m.btn_w_3, m.btn_main_h, 3),
        self:_makeButton(_("+3"), function()
            self:_changeScore(side, 3)
        end, m.btn_w_3, m.btn_main_h, 3),
        self:_makeButton(_("+5 Hamarreko"), function()
            self:_changeScore(side, 5)
        end, m.btn_w_3, m.btn_main_h, 3),
    })

    local sub_row = HorizontalGroup:new({
        align = "center",
        self:_makeButton(_("-1 Piedra"), function()
            self:_changeScore(side, -1)
        end, m.btn_w_2, m.btn_sub_h, 1),
        self:_makeButton(_("-5 Hamarreko"), function()
            self:_changeScore(side, -5)
        end, m.btn_w_2, m.btn_sub_h, 1),
    })

    local content
    if is_top_team then
        -- Equipo Azul (arriba): botones pegados al borde superior de la mesa,
        -- marcador mirando hacia el centro.
        content = VerticalGroup:new({
            align = "center",
            sub_row,
            add_row,
            detail_text,
            score_text,
            header_text,
        })
    else
        -- Equipo Rojo (abajo): marcador mirando hacia el centro,
        -- botones pegados al borde inferior de la mesa.
        content = VerticalGroup:new({
            align = "center",
            header_text,
            score_text,
            detail_text,
            add_row,
            sub_row,
        })
    end

    return FrameContainer:new({
        background = Blitbuffer.COLOR_WHITE,
        bordersize = 2,
        padding = 8,
        margin = 4,
        content,
    })
end

function Mus:_makeCenterBar(m)
    local status_str
    if self.last_winner then
        local winner_name = self.last_winner == "azul" and _("EQUIPO AZUL") or _("EQUIPO ROJO")
        status_str = string.format(_("¡Juego para %s! Tantos a 0"), winner_name)
    elseif self.scores.azul == 0 and self.scores.rojo == 0 then
        status_str = string.format(_("Partida a %d tantos (pulsa 'A %d' para cambiar)"), self.target, self.target)
    else
        status_str = string.format(_("Partida en juego — Límite: %d tantos"), self.target)
    end

    local score_summary = self:_makeText(
        string.format(_("MARCADOR DE JUEGOS   |   AZUL %d  —  %d ROJO"), self.juegos.azul, self.juegos.rojo),
        19
    )
    local status_widget = self:_makeText(status_str, 16)

    local controls_row = HorizontalGroup:new({
        align = "center",
        self:_makeButton(
            string.format(_("A %d"), self.target),
            function()
                self:_toggleTarget()
            end,
            m.btn_w_4,
            m.btn_ctrl_h,
            2
        ),
        self:_makeButton(_("Cero"), function()
            self:_resetTantos()
        end, m.btn_w_4, m.btn_ctrl_h, 2),
        self:_makeButton(_("Nueva"), function()
            self:_newGame()
        end, m.btn_w_4, m.btn_ctrl_h, 2),
        self:_makeButton(_("Salir"), function()
            self:_quitApp()
        end, m.btn_w_4, m.btn_ctrl_h, 2),
    })

    return FrameContainer:new({
        background = Blitbuffer.COLOR_WHITE,
        bordersize = 3,
        padding = 6,
        margin = 6,
        VerticalGroup:new({
            align = "center",
            score_summary,
            status_widget,
            controls_row,
        }),
    })
end

function Mus:show()
    self:_closeWindow(false)

    local m = self:_getLayoutMetrics()

    local layout = VerticalGroup:new({
        align = "center",
        self:_makeTeamPanel("azul", _("EQUIPO AZUL"), true, m),
        self:_makeCenterBar(m),
        self:_makeTeamPanel("rojo", _("EQUIPO ROJO"), false, m),
    })

    self.window = FrameContainer:new({
        background = Blitbuffer.COLOR_WHITE,
        bordersize = 0,
        padding = 0,
        margin = 0,
        CenterContainer:new({
            dimen = Screen:getSize(),
            layout,
        }),
    })

    UIManager:show(self.window)
    UIManager:setDirty(self.window, "ui")
    UIManager:setDirty("all", "ui")
end

return Mus
