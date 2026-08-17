local _, addon = ...

local Spells = {}
addon.Spells = Spells

-- Ordered from the broadest specialization dispel to the narrower fallback.
-- Every entry is still checked against the player's spellbook at runtime.
Spells.Candidates = {
    DRUID = { 88423, 2782 },       -- Nature's Cure, Remove Corruption
    EVOKER = { 360823, 365585 },   -- Naturalize, Expunge
    MAGE = { 475 },                -- Remove Curse
    MONK = { 115450 },             -- Detox
    PALADIN = { 4987, 213644 },    -- Cleanse, Cleanse Toxins
    PRIEST = { 527, 213634 },      -- Purify, Purify Disease
    SHAMAN = { 77130, 51886 },     -- Purify Spirit, Cleanse Spirit
}

local function IsKnownBySpellBook(spellID)
    if not C_SpellBook or not C_SpellBook.IsSpellInSpellBook then
        return false
    end

    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    if bank == nil then
        return false
    end

    local ok, known = pcall(C_SpellBook.IsSpellInSpellBook, spellID, bank)
    return ok and known and true or false
end

function Spells:IsKnown(spellID)
    if IsKnownBySpellBook(spellID) then
        return true
    end

    if IsPlayerSpell then
        local ok, known = pcall(IsPlayerSpell, spellID)
        if ok and known then
            return true
        end
    end

    if IsSpellKnownOrOverridesKnown then
        local ok, known = pcall(IsSpellKnownOrOverridesKnown, spellID)
        if ok and known then
            return true
        end
    end

    if IsSpellKnown then
        local ok, known = pcall(IsSpellKnown, spellID)
        if ok and known then
            return true
        end
    end

    return false
end

function Spells:GetInfo(spellID)
    if not spellID or not C_Spell then
        return nil
    end

    local name = C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
    if not name then
        return nil
    end

    local icon = C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
    return {
        id = spellID,
        name = name,
        icon = icon,
        known = self:IsKnown(spellID),
    }
end

function Spells:Resolve()
    local manualSpellID = addon.db and addon.db.manualSpellID
    if manualSpellID then
        local manual = self:GetInfo(manualSpellID)
        -- SavedVariables are shared across characters. Ignore an override that
        -- the current character does not know, then continue with auto detect.
        if manual and manual.known then
            manual.source = "manual"
            return manual
        end
    end

    local _, class = UnitClass("player")
    local candidates = class and self.Candidates[class]
    if not candidates then
        return nil
    end

    for _, spellID in ipairs(candidates) do
        if self:IsKnown(spellID) then
            local spell = self:GetInfo(spellID)
            if spell then
                spell.source = "auto"
                return spell
            end
        end
    end

    return nil
end
