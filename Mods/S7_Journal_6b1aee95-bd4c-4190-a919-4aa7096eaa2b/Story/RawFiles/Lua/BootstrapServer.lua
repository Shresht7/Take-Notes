--  ======
--  IMPORT
--  ======

Ext.Require("Shared/Auxiliary.lua")
if Ext.IsDeveloperMode() then Ext.Require("Server/Development/DevMode.lua") end

--  =================
--  GAME START EVENTS
--  =================

Ext.RegisterOsirisListener("GameStarted", 2, "after", function(level, isEditorMode)
    if Osi.IsGameLevel(level) then
        if CENTRAL[IDENTIFIER].ModSettings.Uniques then
            local db = Osi.DB_IsPlayer:Get(nil)[1] or {}
            for _, player in pairs(db) do
                if Osi.ItemTemplateIsInCharacterInventory(player, JournalTemplate) < 1 then
                    Osi.ItemTemplateAddTo(JournalTemplate, player, 1, 1)
                end
            end
        end
    end
end)

--  ======
--  VARDEC
--  ======

Journal = {
    ["GMJournal"] = {
        ["Component"] = {
            ["Name"] = "S7_Notebook",
            ["Strings"] = {
                ["caption"] = "Notebook",
                ["addCategory"] = "Add New Category",
                ["addChapter"] = "Add New Chapter",
                ["addParagraph"] = "Add New Paragraph",
                ["editButtonCaption"] = "TOGGLE EDIT MODE",
                ["shareWithParty"] = "Share With Party"
            }
        },
        ["SubComponent"] = {
            ["ToggleEditButton"] = {
                ["Title"] = "ToggleEditButton",
                ["Visible"] = true
            }
        },
        ["JournalData"] = {}
    }
}

function Journal:New(object)
    local object = object or {}
    object = Integrate(self, object)
    return object
end

--  =====================
S7Journal = Journal:New()
--  =====================

--  ============
--  LOAD JOURNAL
--  ============

--- Load Journal
---@param fileName string
local function LoadJournal(fileName)
    S7Debug:Print("Loading Journal File: " .. fileName)
    local file = PersistentVars.Settings.Storage == "External" and LoadFile(fileName) or PersistentVars.JournalData[fileName] or ""
    file = UCL.Journalify(file)
    S7Journal = Journal:New(file)
    S7Debug:Print("Loaded Successfully")
end

--  ============
--  SAVE JOURNAL
--  ============

--- Save Journal
---@param channel string
---@param payload string
Ext.RegisterNetListener(IDENTIFIER, function (channel, payload)
    local journal = Ext.JsonParse(payload)
    if journal.ID == "SaveJournal" then
        S7Debug:Print("Saving Journal File: " .. journal.fileName)
        if PersistentVars.Settings.Storage == "External" then SaveFile(journal.fileName, journal.Data)
        elseif PersistentVars.Settings.Storage == "Internal" then PersistentVars.JournalData[journal.fileName] = Rematerialize(journal.Data) end
        S7Debug:Print("Saved Successfully")
    end
end)

--  ============
--  OPEN JOURNAL
--  ============

--- Character Opens Journal
---@param character string
---@param itemGuid string
Ext.RegisterOsirisListener("CharacterUsedItem", 2, "after", function(character, itemGuid)
    local item = Ext.GetItem(itemGuid)
    if item.RootTemplate.Id == JournalTemplate then
        if CENTRAL[IDENTIFIER].ModSettings.Uniques then item.StoryItem = true else item.StoryItem = false end
        S7Debug:Print(character .. " opened Journal")

        local fileName = PersistentVars.Settings.Storage == "External" and SubdirectoryPrefix or ""
        if PersistentVars.Settings.SyncTo == "CharacterGUID" then fileName = fileName .. tostring(character) .. ".md"
        elseif PersistentVars.Settings.SyncTo == "ItemGUID" then fileName = fileName .. tostring(itemGuid) .. ".md" end

        local file = PersistentVars.Settings.Storage == "External" and LoadFile(fileName) or PersistentVars.JournalData[fileName] or ""
        local len = string.len(file)
        item.GoldValueOverwrite = Ext.StatGetAttribute(item.StatsId, "Value") + math.floor(len/3)
        LoadJournal(fileName)
        item.CustomDisplayName = S7Journal.GMJournal.Component.Strings.caption
        local payload = {["ID"] = "CharacterOpenJournal", ["Data"] = {["fileName"] = fileName, ["content"] = S7Journal}}
        Ext.PostMessageToClient(character, IDENTIFIER, Ext.JsonStringify(Rematerialize(payload)))
    end
end)