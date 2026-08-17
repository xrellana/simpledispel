local addon = {
    db = {},
}

local playerClass = "PRIEST"
local knownSpells = {}
local spellNames = {
    [475] = "Remove Curse",
    [527] = "Purify",
}

Enum = {
    SpellBookSpellBank = {
        Player = 1,
    },
}

C_SpellBook = {
    IsSpellInSpellBook = function(spellID)
        return knownSpells[spellID] == true
    end,
}

C_Spell = {
    GetSpellName = function(spellID)
        return spellNames[spellID]
    end,
    GetSpellTexture = function(spellID)
        return spellID
    end,
}

function UnitClass()
    return playerClass, playerClass
end

local spellsChunk = assert(loadfile("DispelSpells.lua"))
spellsChunk("SimpleDispel", addon)

knownSpells[527] = true
local spell = addon.Spells:Resolve()
assert(spell and spell.id == 527, "known class dispel was not detected")
assert(spell.source == "auto", "detected class dispel must use the auto source")

knownSpells[475] = true
addon.db.manualSpellID = 475
spell = addon.Spells:Resolve()
assert(spell and spell.id == 475, "known manual override was not selected")
assert(spell.source == "manual", "known manual override must use the manual source")

knownSpells[475] = false
spell = addon.Spells:Resolve()
assert(spell and spell.id == 527, "unknown manual override must fall back to auto detection")
assert(spell.source == "auto", "manual fallback must report the auto source")

knownSpells[527] = false
playerClass = "WARRIOR"
spell = addon.Spells:Resolve()
assert(spell == nil, "class without a known friendly dispel must resolve to nil")

print("SimpleDispel spell detection: PASS")
