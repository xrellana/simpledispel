local _, addon = ...

local Theme = {}
addon.Theme = Theme

-- New installs and every database that predates the theme option start on the
-- original dark palette, so an upgrade never changes the look of a live UI.
Theme.DEFAULT = "dark"
Theme.Names = { "dark", "light" }

-- The "(drag)" hint is drawn with an inline colour code, so SetTextColor on the
-- title cannot reach it. One mid grey keeps it legible on both handle colours.
Theme.DRAG_HINT_COLOR = "8a8f96"

local PALETTES = {
    -- Dark palette: values are the pre-theme constants, kept byte for byte.
    dark = {
        rootBackground = { 0.015, 0.018, 0.024, 0.88 },
        handleBackground = { 0.055, 0.065, 0.08, 0.94 },
        title = { 1, 0.82, 0 },
        emptyTitle = { 1, 0.82, 0 },
        emptyHint = { 0.62, 0.65, 0.70 },
        buttonBackground = { 0.035, 0.04, 0.05, 0.92 },
        buttonBorder = { 0.12, 0.12, 0.12, 1 },
        spellTextureAlpha = 0.28,
        spellTextureDesaturated = false,
        labelReady = { 0.82, 1, 0.82 },
        labelMissing = { 1, 0.45, 0.45 },
        -- Unavailable states darken the button away from a light-on-dark UI.
        stateShade = { 0.01, 0.01, 0.015, 1 },
        outOfRangeShadeAlpha = 0.52,
        cooldownShadeAlpha = 0.32,
        outOfRangeBorder = { 0.95, 0.18, 0.12, 1 },
        outOfRangeMark = { 1, 0.24, 0.18, 1 },
        cooldownMark = { 1, 0.78, 0.20, 1 },
    },
    -- Light palette: the frame is deliberately washed out and achromatic so a
    -- dispellable debuff icon is the only saturated object inside it.
    light = {
        rootBackground = { 0.88, 0.89, 0.91, 0.35 },
        handleBackground = { 0.80, 0.81, 0.84, 0.55 },
        title = { 0.16, 0.17, 0.20 },
        emptyTitle = { 0.22, 0.23, 0.26 },
        emptyHint = { 0.45, 0.47, 0.51 },
        buttonBackground = { 0.93, 0.94, 0.96, 0.55 },
        -- On a light fill the border has to be darker than the plate, not lighter.
        buttonBorder = { 0.30, 0.32, 0.36, 0.55 },
        -- The dispel icon is identical on every button, so it carries no
        -- per-unit information and is reduced to a faint achromatic watermark.
        spellTextureAlpha = 0.08,
        spellTextureDesaturated = true,
        labelReady = { 0.16, 0.17, 0.20 },
        labelMissing = { 0.70, 0.12, 0.10 },
        -- Darkening a light plate reads louder than the dispel alert itself, so
        -- unavailable states wash toward the background instead of away from it.
        stateShade = { 1, 1, 1, 1 },
        outOfRangeShadeAlpha = 0.55,
        cooldownShadeAlpha = 0.35,
        outOfRangeBorder = { 0.85, 0.10, 0.05, 1 },
        outOfRangeMark = { 0.82, 0.09, 0.05, 1 },
        -- Blizzard's amber is invisible on a near-white plate.
        cooldownMark = { 0.60, 0.36, 0.02, 1 },
    },
}

function Theme:IsValid(name)
    return PALETTES[name] ~= nil
end

function Theme:GetActive()
    local name = addon.db and addon.db.theme
    if self:IsValid(name) then
        return name
    end
    return self.DEFAULT
end

function Theme:Colors()
    return PALETTES[self:GetActive()]
end
