if ResearchAssistant == nil then ResearchAssistant = {} end
local RA = ResearchAssistant

local _

local currentlyLoggedInCharId = RA.currentlyLoggedInCharId or GetCurrentCharacterId()

local CAN_RESEARCH_TEXTURES = {
    ["Classic"] = {
        texturePath = [[/esoui/art/buttons/edit_disabled.dds]],
        textureSize = 30,
    },
    ["Modern"] =  {
        texturePath = [[/esoui/art/buttons/checkbox_indeterminate.dds]],
        textureSize = 16,
    },
    ["Circle"] = {
        texturePath = [[/esoui/art/miscellaneous/gamepad/pip_active.dds]],
        textureSize = 16,
    },
    ["Diamond"] = {
        texturePath = [[/esoui/art/miscellaneous/gamepad/scrollbox_elevator.dds]],
        textureSize = 16,
    },
    ["Triangle"] = {
        texturePath = [[/esoui/art/miscellaneous/slider_marker_up.dds]],
        textureSize = 16,
    },
    ["Magnifier"] = {
        texturePath = [[/esoui/art/miscellaneous/search_icon.dds]],
        textureSize = 32,
    },
}

local TEXTURE_OPTIONS = { "Classic", "Modern", "Circle", "Diamond", "Triangle", "Magnifier", }

-----------------------------
--UTIL FUNCTIONS
-----------------------------
local function RGBAToHex(r, g, b, a)
    r = (r>1 and 1) or (r<0 and 0) or r
    g = (g>1 and 1) or (g<0 and 0) or g
    b = (b>1 and 1) or (b<0 and 0) or b
    return string.format("%02x%02x%02x%02x", r * 255, g * 255, b * 255, a * 255)
end

local function HexToRGBA(hex)
    local rhex, ghex, bhex, ahex = string.sub(hex, 1, 2), string.sub(hex, 3, 4), string.sub(hex, 5, 6), string.sub(hex, 7, 8)
    return tonumber(rhex, 16)/255, tonumber(ghex, 16)/255, tonumber(bhex, 16)/255, tonumber(ahex, 16)/255
end

local function getClassIcon(classId)
    --* GetClassInfo(*luaindex* _index_)
    -- @return defId integer,lore string,normalIconKeyboard textureName,pressedIconKeyboard textureName,mouseoverIconKeyboard textureName,isSelectable bool,ingameIconKeyboard textureName,ingameIconGamepad textureName,normalIconGamepad textureName,pressedIconGamepad textureName
    local classLuaIndex = GetClassIndexById(classId)
    local _, _, textureName, _, _, _, ingameIconKeyboard, _, _, _= GetClassInfo(classLuaIndex)
    return ingameIconKeyboard or textureName or ""
end

local function decorateCharName(charName, classId, decorate)
    if not charName or charName == "" then return "" end
    if not classId then return charName end
    decorate = decorate or false
    if not decorate then return charName end
    local charNameDecorated
    --Get the class color
    local charColorDef = GetClassColor(classId)
    --Apply the class color to the charname
    if nil ~= charColorDef then charNameDecorated = charColorDef:Colorize(charName) end
    --Apply the class textures to the charname
    charNameDecorated = zo_iconTextFormatNoSpace(getClassIcon(classId), 20, 20, charNameDecorated)
    return charNameDecorated
end

--Build the table of all characters of the account
local function getCharactersOfAccount(keyIsCharName, decorate)
    decorate = decorate or false
    keyIsCharName = keyIsCharName or false
    local charactersOfAccount
    --Check all the characters of the account
    for i = 1, GetNumCharacters() do
        --GetCharacterInfo() -> *string* _name_, *[Gender|#Gender]* _gender_, *integer* _level_, *integer* _classId_, *integer* _raceId_, *[Alliance|#Alliance]* _alliance_, *string* _id_, *integer* _locationId_
        local name, gender, level, classId, raceId, alliance, characterId, location = GetCharacterInfo(i)
        local charName = zo_strformat(SI_UNIT_NAME, name)
        if characterId ~= nil and charName ~= "" then
            if charactersOfAccount == nil then charactersOfAccount = {} end
            charName = decorateCharName(charName, classId, decorate)
            if keyIsCharName then
                charactersOfAccount[charName]   = characterId
            else
                charactersOfAccount[characterId]= charName
            end
        end
    end
    return charactersOfAccount
end

------------------------------
--OBJECT FUNCTIONS
------------------------------
ResearchAssistantSettings = ZO_Object:Subclass()

function ResearchAssistantSettings:New()
    local obj = ZO_Object.New(self)
    obj:Initialize()
    return obj
end

function ResearchAssistantSettings:Initialize()
    --Constants
    self.CONST_CHARACTER_NOT_SCANNED_YET = -100
    self.CONST_OFF = "-"
    self.CONST_OFF_VALUE = 0

    local defaults = {
        debug = false,

        useAccountWideResearchChars = true,
        allowNoCharsForResearch = false,
        useLoggedInCharForResearch = false,

        textureName = "Modern",
        textureSize = 16,
        textureOffset = 0,
        showTooltips = false,
        showTooltipsType = false,
        showTooltipsArmorWeight = false,

        separateClothier = false,
        separateSmithing = false,

        canResearchColor = RGBAToHex(1, .25, 0, 1),
        duplicateUnresearchedColor = RGBAToHex(1, 1, 0, 1),
        alreadyResearchedColor = RGBAToHex(.5, .5, .5, 1),
        ornateColor = RGBAToHex(1, 1, 0, 1),
        intricateColor = RGBAToHex(0, 1, 1, 1),

        showResearched = true,
        showTraitless = true,
        showUntrackedOrnate = true,
        showUntrackedIntricate = true,

        blacksmithCharacter = {},
        weaponsmithCharacter = {},
        woodworkingCharacter = {},
        clothierCharacter = {},
        leatherworkerCharacter = {},
        jewelryCraftingCharacter = {},

        respectItemProtectionByZOs     = false,
        respectItemProtectionByFCOIS   = false,
        skipSets = false,
        skipSetsOnlyMaxLevel = false,

        alwaysShowResearchIcon = false,
        alwaysShowResearchIconExcludeNotTracked = true,

        --non settings variables
        acquiredTraits = {},

        hideVanillaUIResearchableTexture = false,
    }
    --Old non-server dependent character name settings
    --local settings = ZO_SavedVars:NewAccountWide("ResearchAssistant_Settings", 2, nil, defaults)
    --New server dependent character unique ID settings
    --ZO_SavedVars:NewAccountWide(savedVariableTable, version, namespace, defaults, profile, displayName)
    local settings = ZO_SavedVars:NewAccountWide("ResearchAssistant_Settings_Server", 2, nil, defaults, GetWorldName(), nil)

    if settings.isBlacksmith then settings.isBlacksmith = nil end
    if settings.isWoodworking then settings.isWoodworking = nil end
    if settings.isClothier then settings.isClothier = nil end
    if settings.isLeatherworker then settings.isLeatherworker = nil end
    if settings.isWeaponsmith then settings.isWeaponsmith = nil end
    if settings.useCrossCharacter then settings.useCrossCharacter = nil end
    if settings.showInGrid then settings.showInGrid = nil end

    if (not settings.showResearched) and settings.showTraitless == true then
        settings.showTraitless = false
    end

    settings.acquiredTraits[currentlyLoggedInCharId] = settings.acquiredTraits[currentlyLoggedInCharId] or { }

    --Use the same research characters for each of your characters
    if settings.useAccountWideResearchChars == true then
        --Use the value 0 (self.CONST_OFF_VALUE) as key for the account wide same chars
        settings.blacksmithCharacter[self.CONST_OFF_VALUE]       = settings.blacksmithCharacter[self.CONST_OFF_VALUE]         or self.CONST_OFF_VALUE
        settings.weaponsmithCharacter[self.CONST_OFF_VALUE]      = settings.weaponsmithCharacter[self.CONST_OFF_VALUE]        or self.CONST_OFF_VALUE
        settings.woodworkingCharacter[self.CONST_OFF_VALUE]      = settings.woodworkingCharacter[self.CONST_OFF_VALUE]        or self.CONST_OFF_VALUE
        settings.clothierCharacter[self.CONST_OFF_VALUE]         = settings.clothierCharacter[self.CONST_OFF_VALUE]           or self.CONST_OFF_VALUE
        settings.leatherworkerCharacter[self.CONST_OFF_VALUE]    = settings.leatherworkerCharacter[self.CONST_OFF_VALUE]      or self.CONST_OFF_VALUE
        settings.jewelryCraftingCharacter[self.CONST_OFF_VALUE]  = settings.jewelryCraftingCharacter[self.CONST_OFF_VALUE]    or self.CONST_OFF_VALUE
    else
        --Use different research characters for each of your characters
        -->Makes no sense imo but was the standard setting in older ResearchAssistant.
        -->Would only make sense if you level a small toon and whant it to research stuff. But even than changing it globally for
        -->all chars would be fine in order to collect the items for this small toon on all of your chars
        --Preset each selected research char with "none" for new added characters of the account
        settings.blacksmithCharacter[currentlyLoggedInCharId]       = settings.blacksmithCharacter[currentlyLoggedInCharId]         or self.CONST_OFF_VALUE
        settings.weaponsmithCharacter[currentlyLoggedInCharId]      = settings.weaponsmithCharacter[currentlyLoggedInCharId]        or self.CONST_OFF_VALUE
        settings.woodworkingCharacter[currentlyLoggedInCharId]      = settings.woodworkingCharacter[currentlyLoggedInCharId]        or self.CONST_OFF_VALUE
        settings.clothierCharacter[currentlyLoggedInCharId]         = settings.clothierCharacter[currentlyLoggedInCharId]           or self.CONST_OFF_VALUE
        settings.leatherworkerCharacter[currentlyLoggedInCharId]    = settings.leatherworkerCharacter[currentlyLoggedInCharId]      or self.CONST_OFF_VALUE
        settings.jewelryCraftingCharacter[currentlyLoggedInCharId]  = settings.jewelryCraftingCharacter[currentlyLoggedInCharId]    or self.CONST_OFF_VALUE
    end

    --Build a list of characters of the current acount
    --Key is the unique character Id, value is the name
    self.charId2Name = getCharactersOfAccount(false, true)
    --Key is the name, value the unique character Id
    self.charName2Id = getCharactersOfAccount(true, true)
    --The LAM settings character values table
    self.lamCharNamesTable = {}
    --Build the known characters table for the LAM dropdown controls
    self.lamCharIdTable = {}
    table.insert(self.lamCharNamesTable, 1, self.CONST_OFF)
    table.insert(self.lamCharIdTable, 1, self.CONST_OFF_VALUE)
    for l_charId, l_charName in pairs(self.charId2Name) do
        table.insert(self.lamCharNamesTable, l_charName)
        table.insert(self.lamCharIdTable, l_charId)
    end

    --Pass the SavedVariables to the settings object
    self.sv = settings
    --Create the LAM settings menu
    self:CreateOptionsMenu()
end

function ResearchAssistantSettings:GetCanResearchColor()
    local r, g, b, a = HexToRGBA(self.sv.canResearchColor)
    return {r, g, b, a}
end

function ResearchAssistantSettings:GetDuplicateUnresearchedColor()
    local r, g, b, a = HexToRGBA(self.sv.duplicateUnresearchedColor)
    return {r, g, b, a}
end

function ResearchAssistantSettings:GetAlreadyResearchedColor()
    local r, g, b, a = HexToRGBA(self.sv.alreadyResearchedColor)
    return {r, g, b, a}
end

function ResearchAssistantSettings:GetOrnateColor()
    local r, g, b, a = HexToRGBA(self.sv.ornateColor)
    return {r, g, b, a}
end

function ResearchAssistantSettings:GetIntricateColor()
    local r, g, b, a = HexToRGBA(self.sv.intricateColor)
    return {r, g, b, a}
end

function ResearchAssistantSettings:GetNotScannedColor()
    local r, g, b, a = 1, 1, 1, 1
    return {r, g, b, a}
end

function ResearchAssistantSettings:ShowResearched()
    return self.sv.showResearched
end

function ResearchAssistantSettings:ShowTraitless()
    return self.sv.showTraitless
end

function ResearchAssistantSettings:ShowUntrackedOrnate()
    return self.sv.showUntrackedOrnate
end

function ResearchAssistantSettings:ShowUntrackedIntricate()
    return self.sv.showUntrackedIntricate
end

function ResearchAssistantSettings:ShowTooltips()
    return self.sv.showTooltips
end

function ResearchAssistantSettings:ShowTooltipsType()
    return self.sv.showTooltipsType
end

function ResearchAssistantSettings:ShowTooltipsArmorWeight()
    return self.sv.showTooltipsArmorWeight
end

function ResearchAssistantSettings:GetResearchCharIdDependingOnSettings()
    if self.sv.useAccountWideResearchChars == true then
        return self.CONST_OFF_VALUE
    else
        return currentlyLoggedInCharId
    end
end

function ResearchAssistantSettings:IsItemProtectedByZOsSkipped()
    return self.sv.respectItemProtectionByZOs
end

function ResearchAssistantSettings:IsItemProtectedByFCOISSkipped()
    return self.sv.respectItemProtectionByFCOIS
end

function ResearchAssistantSettings:IsItemProtectedByAnySkipped()
    return (self:IsItemProtectedByZOsSkipped() and self:IsItemProtectedByFCOISSkipped()) or false
end

function ResearchAssistantSettings:SetKnownTraits(traitsTable)
    self.sv.acquiredTraits[currentlyLoggedInCharId] = traitsTable
end

function ResearchAssistantSettings:GetCharsWhoKnowTrait(traitKey)
    local knownCharIds = {}
    local knowers = ""
    for curCharId, traitList in pairs(self.sv.acquiredTraits) do
        if curCharId ~= self.CONST_OFF_VALUE then
            if traitList and traitList[traitKey] == true then
                local curCharName = self.charId2Name[curCharId]
                table.insert(knownCharIds, curCharName)
            end
        end
    end
    if #knownCharIds > 0 then
        table.sort(knownCharIds)
        for _, curCharName in ipairs(knownCharIds) do
            if knowers == "" then
                knowers = curCharName
            else
                knowers = knowers .. "\n" .. curCharName
            end
        end
    end
    return knowers
end

function ResearchAssistantSettings:GetTrackedCharForSkill(craftingSkillType, itemType, getCrafterName)
    getCrafterName = getCrafterName or false
    local crafter
    if(craftingSkillType == CRAFTING_TYPE_BLACKSMITHING and itemType > 7) then
        crafter = self.sv.blacksmithCharacter[self:GetResearchCharIdDependingOnSettings()]
    elseif(craftingSkillType == CRAFTING_TYPE_BLACKSMITHING and itemType <= 7) then
        crafter = self.sv.weaponsmithCharacter[self:GetResearchCharIdDependingOnSettings()]
    elseif(craftingSkillType == CRAFTING_TYPE_CLOTHIER and itemType <= 7) then
        crafter = self.sv.clothierCharacter[self:GetResearchCharIdDependingOnSettings()]
    elseif(craftingSkillType == CRAFTING_TYPE_CLOTHIER and itemType > 7) then
        crafter = self.sv.leatherworkerCharacter[self:GetResearchCharIdDependingOnSettings()]
    elseif(craftingSkillType == CRAFTING_TYPE_WOODWORKING) then
        crafter = self.sv.woodworkingCharacter[self:GetResearchCharIdDependingOnSettings()]
    elseif(craftingSkillType == CRAFTING_TYPE_JEWELRYCRAFTING) then
        crafter = self.sv.jewelryCraftingCharacter[self:GetResearchCharIdDependingOnSettings()]
    else
        crafter = self.CONST_OFF_VALUE
    end
    --Shall we return the name instead of the unique id?
    if getCrafterName == true and (crafter ~= nil and crafter ~= "" and crafter ~= self.CONST_OFF_VALUE) then
        local charNameDecorated = self.charId2Name[crafter]
        if charNameDecorated and charNameDecorated ~= "" then return charNameDecorated end
    end
    return crafter
end

function ResearchAssistantSettings:GetCraftingCharacterTraits(craftingSkillType, itemType)
    local crafter = self:GetTrackedCharForSkill(craftingSkillType, itemType)
    if crafter == self.CONST_OFF_VALUE then
      return
    else
        if self.sv.acquiredTraits and self.sv.acquiredTraits[crafter] then
            return self.sv.acquiredTraits[crafter]
        else
            return
        end
    end
end

--Check if any character is trackng this craftskill. If not the function will return true
function ResearchAssistantSettings:IsMultiCharSkillOff(craftingSkillType, itemType)
    local retVar = false
    local charIdForCraftSkill = self:GetTrackedCharForSkill(craftingSkillType, itemType, false)
    if charIdForCraftSkill == self.CONST_OFF_VALUE then
        retVar = true
    end
    return retVar
end

function ResearchAssistantSettings:GetPlayerTraits()
    return self.sv.acquiredTraits[currentlyLoggedInCharId]
end

function ResearchAssistantSettings:GetTraits()
    return self.sv.acquiredTraits
end

function ResearchAssistantSettings:GetPreferenceValueForTrait(traitKey)
    if (not traitKey) or (traitKey == 0) then return nil end
    local craft = zo_floor(traitKey / 10000)
    local item = zo_floor((traitKey - (craft * 10000)) / 100)
    local traits = self:GetCraftingCharacterTraits(craft, item)
    --if the traits are nil the selected character was not yet loggedIn!
    if traits == nil then
        --Char was not logged in yet. Return special value -100
        return self.CONST_CHARACTER_NOT_SCANNED_YET
    end
    return traits[traitKey]
end

function ResearchAssistantSettings:GetTexturePath()
    return CAN_RESEARCH_TEXTURES[self.sv.textureName].texturePath
end

function ResearchAssistantSettings:GetTextureSize()
    return self.sv.textureSize
end

function ResearchAssistantSettings:GetTextureOffset()
    return self.sv.textureOffset + 70
end

function ResearchAssistantSettings:IsDebug()
    return self.sv.debug
end

function ResearchAssistantSettings:GetHideVanillaUIResearchableTexture()
    return self.sv.hideVanillaUIResearchableTexture
end

function ResearchAssistantSettings:GetAlwaysShowResearchIcon()
    return self.sv.alwaysShowResearchIcon
end

function ResearchAssistantSettings:GetAlwaysShowResearchIconExcludeNonTracked()
    return self.sv.alwaysShowResearchIconExcludeNotTracked
end


function ResearchAssistantSettings:CreateOptionsMenu()
    local LAM = RA.lam
    local str = RA_Strings[self:GetLanguage()].SETTINGS

    local panel = {
        type            = "panel",
        name            = RA.name,
        author          = RA.author,
        version         = RA.version,
        website         = RA.website,
        donation        = RA.donation,
        feedback        = RA.feedback,
        slashCommand    = "/researchassistant",
        registerForRefresh = true
    }

    local icon = WINDOW_MANAGER:CreateControl("RA_Icon", ZO_OptionsWindowSettingsScrollChild, CT_TEXTURE)
    icon:SetColor(1, 1, 1, 1)
    icon:SetHandler("OnShow", function()
        self:SetTexture(CAN_RESEARCH_TEXTURES[self.sv.textureName].texturePath)
        icon:SetDimensions(self.sv.textureSize, self.sv.textureSize)
    end)

    local optionsData = { }
    table.insert(optionsData, {
        type = "header",
        name = str.CHARACTER_HEADER,
    })
    table.insert(optionsData, {
        type = "checkbox",
        name = str.USE_ACCOUNTWIDE_RESEARCH_CHARS,
        tooltip = str.USE_ACCOUNTWIDE_RESEARCH_CHARS_TT,
        getFunc = function() return self.sv.useAccountWideResearchChars end,
        setFunc = function(value)
            self.sv.useAccountWideResearchChars = value
            ReloadUI()
        end,
        requiresReload = true,
    })
    table.insert(optionsData, {
        type = "checkbox",
        name = str.USE_CURRENT_LOGGED_IN_CHAR_FOR_RESEARCH,
        tooltip = str.USE_CURRENT_LOGGED_IN_CHAR_FOR_RESEARCH_TT,
        getFunc = function() return self.sv.useLoggedInCharForResearch end,
        setFunc = function(value)
            self.sv.useLoggedInCharForResearch = value
            if value == true then
                if not self.sv.useAccountWideResearchChars then
                    --Use different research characters for each of your characters
                    self.sv.blacksmithCharacter[currentlyLoggedInCharId]       = currentlyLoggedInCharId
                    self.sv.weaponsmithCharacter[currentlyLoggedInCharId]      = currentlyLoggedInCharId
                    self.sv.woodworkingCharacter[currentlyLoggedInCharId]      = currentlyLoggedInCharId
                    self.sv.clothierCharacter[currentlyLoggedInCharId]         = currentlyLoggedInCharId
                    self.sv.leatherworkerCharacter[currentlyLoggedInCharId]    = currentlyLoggedInCharId
                    self.sv.jewelryCraftingCharacter[currentlyLoggedInCharId]  = currentlyLoggedInCharId
                end
            end
        end,
        disabled = function() return self.sv.useAccountWideResearchChars end
    })
    --[[
    table.insert(optionsData, {
        type = "checkbox",
        name = str.ALLOW_NO_CHARACTER_CHOSEN_FOR_RESEARCH,
        tooltip = str.ALLOW_NO_CHARACTER_CHOSEN_FOR_RESEARCH_TT,
        getFunc = function() return self.sv.allowNoCharsForResearch end,
        setFunc = function(value)
            self.sv.allowNoCharsForResearch = value
        end,
    })
    ]]
    table.insert(optionsData, {
        type = "checkbox",
        name = str.SEPARATE_SMITH_LABEL,
        tooltip = str.SEPARATE_SMITH_TOOLTIP,
        getFunc = function() return self.sv.separateSmithing end,
        setFunc = function(value)
            if not value then
                self.sv.weaponsmithCharacter[self:GetResearchCharIdDependingOnSettings()] = self.sv.blacksmithCharacter[self:GetResearchCharIdDependingOnSettings()]
            end
            self.sv.separateSmithing = value
            ResearchAssistant_InvUpdate()
        end,
    })
    table.insert(optionsData, {
        type = "dropdown",
        name = str.WS_CHAR_LABEL,
        tooltip = str.WS_CHAR_TOOLTIP,
        choices = self.lamCharNamesTable,
        choicesValues = self.lamCharIdTable,
        sort = "name-up",
        scrollable = true,
        getFunc = function() return self.sv.weaponsmithCharacter[self:GetResearchCharIdDependingOnSettings()] end,
        setFunc = function(value)
            self.sv.weaponsmithCharacter[self:GetResearchCharIdDependingOnSettings()] = value
            ResearchAssistant_InvUpdate()
        end,
        disabled = function() return not self.sv.separateSmithing end,
    })
    table.insert(optionsData, {
        type = "dropdown",
        name = str.BS_CHAR_LABEL,
        tooltip = str.BS_CHAR_TOOLTIP,
        choices = self.lamCharNamesTable,
        choicesValues = self.lamCharIdTable,
        sort = "name-up",
        scrollable = true,
        getFunc = function() return self.sv.blacksmithCharacter[self:GetResearchCharIdDependingOnSettings()] end,
        setFunc = function(value)
            self.sv.blacksmithCharacter[self:GetResearchCharIdDependingOnSettings()] = value
            if not self.sv.separateSmithing then
                self.sv.weaponsmithCharacter[self:GetResearchCharIdDependingOnSettings()] = value
            end
            ResearchAssistant_InvUpdate()
        end,
    })
    table.insert(optionsData, {
        type = "checkbox",
        name = str.SEPARATE_LW_LABEL,
        tooltip = str.SEPARATE_LW_TOOLTIP,
        getFunc = function() return self.sv.separateClothier end,
        setFunc = function(value)
            if not value then
                self.sv.leatherworkerCharacter[self:GetResearchCharIdDependingOnSettings()] = self.sv.clothierCharacter[self:GetResearchCharIdDependingOnSettings()]
            end
            self.sv.separateClothier = value
            ResearchAssistant_InvUpdate()
        end,
    })
    table.insert(optionsData, {
        type = "dropdown",
        name = str.LW_CHAR_LABEL,
        tooltip = str.LW_CHAR_TOOLTIP,
        choices = self.lamCharNamesTable,
        choicesValues = self.lamCharIdTable,
        sort = "name-up",
        scrollable = true,
        getFunc = function() return self.sv.leatherworkerCharacter[self:GetResearchCharIdDependingOnSettings()] end,
        setFunc = function(value)
            self.sv.leatherworkerCharacter[self:GetResearchCharIdDependingOnSettings()] = value
            ResearchAssistant_InvUpdate()
        end,
        disabled = function() return not self.sv.separateClothier end,
    })
    table.insert(optionsData, {
        type = "dropdown",
        name = str.CL_CHAR_LABEL,
        tooltip = str.CL_CHAR_TOOLTIP,
        choices = self.lamCharNamesTable,
        choicesValues = self.lamCharIdTable,
        sort = "name-up",
        scrollable = true,
        getFunc = function() return self.sv.clothierCharacter[self:GetResearchCharIdDependingOnSettings()] end,
        setFunc = function(value)
            self.sv.clothierCharacter[self:GetResearchCharIdDependingOnSettings()] = value
            if not self.sv.separateClothier then
                self.sv.leatherworkerCharacter[self:GetResearchCharIdDependingOnSettings()] = value
            end
            ResearchAssistant_InvUpdate()
        end,
    })
    table.insert(optionsData, {
        type = "dropdown",
        name = str.WW_CHAR_LABEL,
        tooltip = str.WW_CHAR_TOOLTIP,
        choices = self.lamCharNamesTable,
        choicesValues = self.lamCharIdTable,
        sort = "name-up",
        scrollable = true,
        getFunc = function() return self.sv.woodworkingCharacter[self:GetResearchCharIdDependingOnSettings()] end,
        setFunc = function(value)
            self.sv.woodworkingCharacter[self:GetResearchCharIdDependingOnSettings()] = value
            ResearchAssistant_InvUpdate()
        end,
    })
    table.insert(optionsData, {
        type = "dropdown",
        name = str.JC_CHAR_LABEL,
        tooltip = str.JC_CHAR_TOOLTIP,
        choices = self.lamCharNamesTable,
        choicesValues = self.lamCharIdTable,
        sort = "name-up",
        scrollable = true,
        getFunc = function() return self.sv.jewelryCraftingCharacter[self:GetResearchCharIdDependingOnSettings()] end,
        setFunc = function(value)
            self.sv.jewelryCraftingCharacter[self:GetResearchCharIdDependingOnSettings()] = value
            ResearchAssistant_InvUpdate()
        end,
    })
    table.insert(optionsData, {
        type = "header",
        name = str.HIDDEN_HEADER,
    })
    table.insert(optionsData, {
        type = "checkbox",
        name = str.SHOW_RESEARCHED_LABEL,
        tooltip = str.SHOW_RESEARCHED_TOOLTIP,
        getFunc = function() return self.sv.showResearched end,
        setFunc = function(value)
            self.sv.showResearched = value
            if not value then self.sv.showTraitless = false end
            ResearchAssistant_InvUpdate()
        end,
    })
    table.insert(optionsData, {
        type = "checkbox",
        name = str.SHOW_ICON_EVEN_IF_PROTECTED,
        tooltip = str.SHOW_ICON_EVEN_IF_PROTECTED_TOOLTIP,
        getFunc = function() return self.sv.alwaysShowResearchIcon end,
        setFunc = function(value)
            self.sv.alwaysShowResearchIcon = value
            ResearchAssistant_InvUpdate()
        end,
    })
    table.insert(optionsData, {
        type = "checkbox",
        name = str.SHOW_ICON_EVEN_IF_PROTECTED_EXCLUDE_NON_TRACKED,
        tooltip = str.SHOW_ICON_EVEN_IF_PROTECTED_EXCLUDE_NON_TRACKED_TOOLTIP,
        getFunc = function() return self.sv.alwaysShowResearchIconExcludeNotTracked end,
        setFunc = function(value)
            self.sv.alwaysShowResearchIconExcludeNotTracked = value
            ResearchAssistant_InvUpdate()
        end,
        disabled = function() return not self.sv.alwaysShowResearchIcon end,
    })
    table.insert(optionsData, {
        type = "checkbox",
        name = str.SHOW_TRAITLESS_LABEL,
        tooltip = str.SHOW_TRAITLESS_TOOLTIP,
        getFunc = function() return self.sv.showTraitless end,
        setFunc = function(value)
            self.sv.showTraitless = value
            ResearchAssistant_InvUpdate()
        end,
        disabled = function() return not self.sv.showResearched end
    })
    table.insert(optionsData, {
        type = "checkbox",
        name = str.SHOW_ORNATE_LABEL,
        tooltip = str.SHOW_ORNATE_TOOLTIP,
        getFunc = function() return self.sv.showUntrackedOrnate end,
        setFunc = function(value)
            self.sv.showUntrackedOrnate = value
            ResearchAssistant_InvUpdate()
        end,
    })
    table.insert(optionsData, {
        type = "checkbox",
        name = str.SHOW_INTRICATE_LABEL,
        tooltip = str.SHOW_INTRICATE_TOOLTIP,
        getFunc = function() return self.sv.showUntrackedIntricate end,
        setFunc = function(value)
            self.sv.showUntrackedIntricate = value
            ResearchAssistant_InvUpdate()
        end,
    })
    table.insert(optionsData, {
        type = "header",
        name = str.GENERAL_HEADER,
    })
    table.insert(optionsData, {
        type = "dropdown",
        name = str.ICON_LABEL,
        tooltip = str.ICON_TOOLTIP,
        choices = TEXTURE_OPTIONS,
        getFunc = function() return self.sv.textureName end,
        setFunc = function(value)
            self.sv.textureName = value
            self.sv.textureSize = CAN_RESEARCH_TEXTURES[value].textureSize
            icon:SetTexture(CAN_RESEARCH_TEXTURES[value].texturePath)
            icon:SetDimensions(self.sv.textureSize, self.sv.textureSize)
            ResearchAssistant_InvUpdate()
        end,
        reference = "RA_Icon_Dropdown"
    })
    table.insert(optionsData, {
        type = "slider",
        name = str.ICON_SIZE,
        tooltip = str.ICON_SIZE_TOOLTIP,
        min = 8,
        max = 64,
        step = 4,
        getFunc = function() return self.sv.textureSize end,
        setFunc = function(size)
            self.sv.textureSize = size
            icon:SetDimensions(size, size)
            ResearchAssistant_InvUpdate()
        end,
        width="full",
        default = self.sv.textureSize,
    })
    table.insert(optionsData, {
        type = "slider",
        name = str.ICON_OFFSET,
        tooltip = str.ICON_OFFSET_TOOLTIP,
        min = -490,
        max = 60,
        step = 1,
        getFunc = function() return self.sv.textureOffset end,
        setFunc = function(offset)
            self.sv.textureOffset = offset
            ResearchAssistant_InvUpdate()
        end,
        width="full",
        default = self.sv.textureOffset,
    })
    table.insert(optionsData, {
        type = "header",
        name = str.SETTINGS_HEADER_TOOLTIPS,
    })
    table.insert(optionsData, {
        type = "checkbox",
        name = str.SHOW_TOOLTIPS_LABEL,
        tooltip = str.SHOW_TOOLTIPS_TOOLTIP,
        getFunc = function() return self.sv.showTooltips end,
        setFunc = function(value)
            self.sv.showTooltips = value
            ResearchAssistant_InvUpdate()
        end,
    })
    table.insert(optionsData, {
        type = "checkbox",
        name = str.SHOW_TYPE_IN_TOOLTIP,
        tooltip = str.SHOW_TYPE_IN_TOOLTIP_TOOLTIP,
        getFunc = function() return self.sv.showTooltipsType end,
        setFunc = function(value)
            self.sv.showTooltipsType = value
            ResearchAssistant_InvUpdate()
        end,
        disabled = function() return not self.sv.showTooltips end,
    })
    table.insert(optionsData, {
        type = "checkbox",
        name = str.SHOW_ARMORWEIGHT_IN_TOOLTIP,
        tooltip = str.SHOW_ARMORWEIGHT_IN_TOOLTIP_TOOLTIP,
        getFunc = function() return self.sv.showTooltipsArmorWeight end,
        setFunc = function(value)
            self.sv.showTooltipsArmorWeight = value
            ResearchAssistant_InvUpdate()
        end,
        disabled = function() return not self.sv.showTooltips end,
    })
    table.insert(optionsData, {
        type = "header",
        name = str.SETTINGS_HEADER_VANILLAUI,
    })
    table.insert(optionsData, {
        type = "checkbox",
        name = str.HIDE_VANILLA_UI_RESEARCHABLE_TEXTURE,
        tooltip = str.HIDE_VANILLA_UI_RESEARCHABLE_TEXTURE_TOOLTIP,
        getFunc = function()
            return self.sv.hideVanillaUIResearchableTexture
        end,
        setFunc = function(value)
            self.sv.hideVanillaUIResearchableTexture = value
        end,
    })
    table.insert(optionsData, {
        type = "header",
        name = str.COLORS_HEADER,
    })
    table.insert(optionsData, {
        type = "colorpicker",
        name = str.RESEARCHABLE_LABEL,
        tooltip = str.RESEARCHABLE_TOOLTIP,
        getFunc = function()
            local r, g, b, a = HexToRGBA(self.sv.canResearchColor)
            return r, g, b
        end,
        setFunc = function(r, g, b)
            self.sv.canResearchColor = RGBAToHex(r, g, b, 1)
            ResearchAssistant_InvUpdate()
        end,
    })
    table.insert(optionsData, {
        type = "colorpicker",
        name = str.DUPLICATE_LABEL,
        tooltip = str.DUPLICATE_TOOLTIP,
        getFunc = function()
            local r, g, b, a = HexToRGBA(self.sv.duplicateUnresearchedColor)
            return r, g, b
        end,
        setFunc = function(r, g, b)
            self.sv.duplicateUnresearchedColor = RGBAToHex(r, g, b, 1)
            ResearchAssistant_InvUpdate()
        end,
    })
    table.insert(optionsData, {
        type = "colorpicker",
        name = str.RESEARCHED_LABEL,
        tooltip = str.RESEARCHED_TOOLTIP,
        getFunc = function()
            local r, g, b, a = HexToRGBA(self.sv.alreadyResearchedColor)
            return r, g, b
        end,
        setFunc = function(r, g, b)
            self.sv.alreadyResearchedColor = RGBAToHex(r, g, b, 1)
            ResearchAssistant_InvUpdate()
        end,
    })
    table.insert(optionsData, {
        type = "colorpicker",
        name = str.ORNATE_LABEL,
        tooltip = str.ORNATE_TOOLTIP,
        getFunc = function()
            local r, g, b, a = HexToRGBA(self.sv.ornateColor)
            return r, g, b
        end,
        setFunc = function(r, g, b)
            self.sv.ornateColor = RGBAToHex(r, g, b, 1)
            ResearchAssistant_InvUpdate()
        end,
    })
    table.insert(optionsData, {
        type = "colorpicker",
        name = str.INTRICATE_LABEL,
        tooltip = str.INTRICATE_TOOLTIP,
        getFunc = function()
            local r, g, b, a = HexToRGBA(self.sv.intricateColor)
            return r, g, b
        end,
        setFunc = function(r, g, b)
            self.sv.intricateColor = RGBAToHex(r, g, b, 1)
            ResearchAssistant_InvUpdate()
        end,
    })
    table.insert(optionsData, {
        type = "header",
        name = str.PROTECTION,
    })
    table.insert(optionsData, {
        type = "checkbox",
        name = str.SKIP_SETS,
        tooltip = str.SKIP_SETS_TOOLTIP,
        getFunc = function() return self.sv.skipSets end,
        setFunc = function(value)
            self.sv.skipSets = value
            ResearchAssistant_InvUpdate()
        end,
    })
    table.insert(optionsData, {
        type = "checkbox",
        name = str.SKIP_SETS_ONLY_MAX_LEVEL,
        tooltip = str.SKIP_SETS_ONLY_MAX_LEVEL_TOOLTIP,
        getFunc = function() return self.sv.skipSetsOnlyMaxLevel end,
        setFunc = function(value)
            self.sv.skipSetsOnlyMaxLevel = value
            ResearchAssistant_InvUpdate()
        end,
        disabled = function() return not self.sv.skipSets end,
    })
    table.insert(optionsData, {
        type = "checkbox",
        name = str.SKIP_ZOS_MARKED,
        tooltip = str.SKIP_ZOS_MARKED_TOOLTIP,
        getFunc = function() return self.sv.respectItemProtectionByZOs end,
        setFunc = function(value)
            self.sv.respectItemProtectionByZOs = value
            ResearchAssistant_InvUpdate()
        end,
    })
    table.insert(optionsData, {
        type = "checkbox",
        name = str.SKIP_FCOIS_MARKED,
        tooltip = str.SKIP_FCOIS_MARKED_TOOLTIP,
        getFunc = function() return self.sv.respectItemProtectionByFCOIS end,
        setFunc = function(value)
            self.sv.respectItemProtectionByFCOIS = value
            ResearchAssistant_InvUpdate()
        end,
        disabled = function() return FCOIS == nil end,
    })
    table.insert(optionsData, {
        type = "header",
        name = "Debug",
    })
    table.insert(optionsData, {
        type = "checkbox",
        name = "Debug",
        tooltip = "Debug",
        getFunc = function() return self.sv.debug end,
        setFunc = function(value)
            self.sv.debug = value
            RA.scanner:SetDebug(value)
        end,
    })

    RA.settingsPanel = LAM:RegisterAddonPanel("ResearchAssistantSettingsPanel", panel)
    LAM:RegisterOptionControls("ResearchAssistantSettingsPanel", optionsData)

    CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", function()
        icon:SetParent(RA_Icon_Dropdown)
        icon:SetTexture(CAN_RESEARCH_TEXTURES[self.sv.textureName].texturePath)
        icon:SetDimensions(self.sv.textureSize, self.sv.textureSize)
        icon:SetAnchor(CENTER, RA_Icon_Dropdown, CENTER, 36, 0)
    end)
end

function ResearchAssistantSettings:GetLanguage()
    local lang = GetCVar("language.2")
    local supportedLanguages = {
        ["de"] = "de",
        ["en"] = "en",
        ["es"] = "es",
        ["fr"] = "fr",
        ["jp"] = "jp",
        ["ru"] = "ru",
    }
    --return english if not supported
    local langSupported = supportedLanguages[lang] or "en"
    return langSupported
end