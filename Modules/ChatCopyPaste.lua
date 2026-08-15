-- Copy chat text, and make URLs in chat clickable.
--
-- Ported from ChatCopyPaste 1.38 (Novaspark-Arugal / Venomisto-Frostmourne). The copy
-- window is rebuilt on Blizzard's own templates rather than the original's hand-drawn
-- chrome; the chat-frame hover button, the URL linkifying and the 12.x secret-value
-- handling come across as they were.

local addonName, addon = ...

-- A stock icon rather than the original addon's bundled texture: no shipped art to go
-- missing, and a sheet of parchment reads as "copy this text" at 20px.
local COPY_ICON = "Interface\\Icons\\INV_Misc_Note_01"

-- Height of the strip below the inset, and where a 22px button sits centred in it.
local FOOTER_HEIGHT = 34
local FOOTER_BUTTON_Y = 7

local copyWindow, copyEditBox

--------------------------------------------------------------------------------
-- Message clean-up
--------------------------------------------------------------------------------

-- Blizzard's pluralisation escapes ("3 |4hour:hours;") aren't parsed by EditBox:Insert,
-- so they're resolved here. The original repeated this block once per unit; one loop
-- over the units does the same job.
local PLURAL_UNITS = { "year", "day", "hour", "minute", "second" }

local function CleanMessage(message)
    if not message then return "" end

    for _, unit in ipairs(PLURAL_UNITS) do
        local pattern = "(%d+) |4" .. unit .. ":" .. unit .. "s;"
        local count = message:match(pattern)
        if count then
            local word = (tonumber(count) == 1) and unit or (unit .. "s")
            message = message:gsub(pattern, "%1 " .. word)
        end
    end

    -- Inline textures don't survive the trip into an edit box.
    return (message:gsub("|T.-|t", ""))
end

-- Battle.net whispers carry an escape sequence that can't be inserted into an edit box,
-- and the client won't hand out display names, so the battletag stands in for the name.
local function ResolveBattleNetName(presenceID, message)
    presenceID = tonumber(presenceID)

    for index = 1, BNGetNumFriends() do
        local accountID, tag
        if C_BattleNet and C_BattleNet.GetFriendAccountInfo then
            local data = C_BattleNet.GetFriendAccountInfo(index)
            if data then
                accountID, tag = data.bnetAccountID, data.battleTag
            end
        end
        if tag and accountID == presenceID then
            tag = strsplit("#", tag)
            return (message:gsub("|HBNplayer:.*:.*:.*:BN_WHISPER:.*:", "[" .. tag .. "]:"))
        end
    end

    return message
end

--------------------------------------------------------------------------------
-- Copy window
--------------------------------------------------------------------------------

local function BuildCopyWindow()
    if copyWindow then return copyWindow end

    local frame = CreateFrame("Frame", addonName .. "ChatCopyFrame", UIParent, "ButtonFrameTemplate")
    frame:SetSize(660, 440)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()
    tinsert(UISpecialFrames, frame:GetName())

    if frame.SetTitle then
        frame:SetTitle("Copy Chat")
    end
    if ButtonFrameTemplate_HidePortrait then
        ButtonFrameTemplate_HidePortrait(frame)
    end

    -- Blizzard's scrolling input frame does the heavy lifting, sat inside the template's
    -- own inset: anchoring it to the frame's edges instead left it straddling the inset's
    -- border art.
    -- The template's inset runs almost to the bottom edge, leaving no real footer. Its
    -- bottom is pinned explicitly so the strip below it is a known height, which is what
    -- the buttons are centred in.
    local inset = frame.Inset or frame
    if frame.Inset then
        frame.Inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, FOOTER_HEIGHT)
    end

    local scroll = CreateFrame("ScrollFrame", nil, frame, "InputScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", inset, "TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -26, 6)
    scroll.maxLetters = 0
    if scroll.CharCount then scroll.CharCount:Hide() end

    local editBox = scroll.EditBox
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function() frame:Hide() end)

    -- The scroll frame has no width until its anchors resolve on first show, so the edit
    -- box is sized from what the frame actually measures, not at build time.
    local function FitEditBox()
        editBox:SetWidth(math.max(100, scroll:GetWidth() - 20))
    end

    -- Footer buttons sit centred as a pair in that strip.
    local selectAll = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    selectAll:SetSize(120, 22)
    selectAll:SetPoint("BOTTOM", frame, "BOTTOM", -64, FOOTER_BUTTON_Y)
    selectAll:SetText("Select All")
    selectAll:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)

    local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    close:SetSize(120, 22)
    close:SetPoint("BOTTOM", frame, "BOTTOM", 64, FOOTER_BUTTON_Y)
    close:SetText("Close")
    close:SetScript("OnClick", function() frame:Hide() end)

    frame:HookScript("OnSizeChanged", FitEditBox)
    frame:HookScript("OnShow", FitEditBox)

    copyWindow, copyEditBox = frame, editBox
    return frame
end

-- Fills the window with either a single URL or the tail of a chat frame's history.
local function OpenCopyWindow(chatFrameIndex, url)
    local window = BuildCopyWindow()
    local editBox = copyEditBox

    editBox:SetText("")

    if url then
        editBox:Insert(url)
        window:Show()
        editBox:SetFocus()
        editBox:HighlightText()
        return
    end

    local chatFrame = _G["ChatFrame" .. (chatFrameIndex or 1)]
    if not chatFrame then return end

    local maxLines = chatFrame:GetNumMessages() or 0
    local firstLine = math.max(1, maxLines - (Perskan.db.profile.chatCopyMaxLines or 500))
    local skippedSecret = false

    for i = firstLine, maxLines do
        local message, r, g, b = chatFrame:GetMessageInfo(i)

        -- 12.0 marks some lines secret; they can't be read, let alone copied.
        if issecretvalue and issecretvalue(message) then
            skippedSecret = true
        elseif message then
            message = CleanMessage(message)

            local presenceID = message:match("k:(%d+):%d+:BN_WHISPER:")
            if presenceID then
                message = ResolveBattleNetName(presenceID, message)
            end

            if r and g and b then
                -- Item links close the colour code entirely, so it's reopened after
                -- each one to keep the line the colour chat showed it in.
                local colorCode = RGBToColorCode(r, g, b)
                message = colorCode .. message:gsub("|r", "|r" .. colorCode)
            end

            editBox:Insert((i == firstLine and "" or "\n") .. message .. "|r")
        end
    end

    window:Show()
    editBox:SetFocus()

    if skippedSecret then
        Perskan:Print("Some chat lines held a protected value and couldn't be copied.")
    end
end

--------------------------------------------------------------------------------
-- Chat frame button
--------------------------------------------------------------------------------

local function AttachCopyButton(index)
    local chatFrame = _G["ChatFrame" .. index]
    if not chatFrame or chatFrame.perskanCopyButton then return end

    local button = CreateFrame("Button", nil, chatFrame)
    button:SetSize(20, 20)
    button:SetPoint("BOTTOMRIGHT", -2, -3)
    -- Relative to the chat frame, not a fixed level: a fixed 7 (as the original addon
    -- used) can land *behind* the chat frame's own art, leaving a button that still
    -- takes mouse-over but never draws and can be clicked through.
    button:SetFrameStrata(chatFrame:GetFrameStrata())
    button:SetFrameLevel(chatFrame:GetFrameLevel() + 10)
    button:RegisterForClicks("AnyUp")
    button:EnableMouse(true)
    button:Hide()

    local texture = button:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints(button)
    texture:SetTexture(COPY_ICON)
    texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(button)
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetBlendMode("ADD")

    button:SetScript("OnClick", function()
        if copyWindow and copyWindow:IsVisible() then
            copyWindow:Hide()
        else
            OpenCopyWindow(index)
        end
    end)

    local function ShowButton()
        if Perskan.db.profile.chatCopyButton then button:Show() end
    end

    -- Moving the mouse onto a child frame fires the parent's OnLeave, so hiding
    -- immediately makes the button hide the instant you reach for it - which is both the
    -- flicker and the reason a click never lands. Defer the hide a frame and only take it
    -- if the mouse has actually left both the chat frame and the button.
    local function HideButtonSoon()
        C_Timer.After(0.05, function()
            if button:IsMouseOver() or chatFrame:IsMouseOver() then return end
            button:Hide()
            if GameTooltip:GetOwner() == button then
                GameTooltip:Hide()
            end
        end)
    end

    button:SetScript("OnEnter", function(self)
        self:Show()
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Copy Chat")
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
        HideButtonSoon()
    end)

    chatFrame:HookScript("OnEnter", ShowButton)
    chatFrame:HookScript("OnLeave", HideButtonSoon)
    if chatFrame.ScrollToBottomButton then
        chatFrame.ScrollToBottomButton:HookScript("OnEnter", ShowButton)
        chatFrame.ScrollToBottomButton:HookScript("OnLeave", HideButtonSoon)
    end

    chatFrame.perskanCopyButton = button
end

local function AttachAllCopyButtons()
    for i = 1, NUM_CHAT_WINDOWS do
        AttachCopyButton(i)
    end
end

--------------------------------------------------------------------------------
-- Clickable URLs
--------------------------------------------------------------------------------

local URL_PATTERN = "[%w_.~!*:@&+$/?%%#-]-%w[-.%w]*%w%.%a%a+:?%d*/?"
local LINK_PREFIX = "perskanUrl"

-- Escapes, links and textures inside a "word" mean it isn't a bare URL.
local function HasEscapes(word)
    return word:match("|T.-|t") ~= nil or word:match("|H.-|h(.-)|h") ~= nil
end

local function UrlColorCode()
    local color = Perskan.db.profile.chatUrlColor or {}
    return ("|cff%02x%02x%02x"):format(
        (color.r or 0) * 255, (color.g or 0.68) * 255, (color.b or 1) * 255)
end

local function LinkifyMessage(message)
    local colorCode = UrlColorCode()
    local seen = {}

    for word in message:gmatch("%S+") do
        if word:match(URL_PATTERN) and not HasEscapes(word) and not seen[word] then
            local escaped = word:gsub("([%(%)%%%+%-%*%?%[%^%$])", "%%%1")
            message = message:gsub(escaped,
                colorCode .. "(|H" .. LINK_PREFIX .. ":url|h" .. word .. "|h)|r")
            seen[word] = true
        end
    end

    return message
end

local function UrlFilter(_, _, message, author, ...)
    if not Perskan.db.profile.chatUrlLinks then return end
    if issecretvalue and issecretvalue(message) then return end
    -- Addon payloads look enough like URLs to get mangled; leave them alone.
    if message:match("%[MDT_v2:") or message:match("%[WeakAuras:") then return end
    if not message:match(URL_PATTERN) then return end

    return false, LinkifyMessage(message), author, ...
end

local URL_EVENTS = {
    "CHAT_MSG_CHANNEL", "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER",
    "CHAT_MSG_BATTLEGROUND", "CHAT_MSG_BATTLEGROUND_LEADER", "CHAT_MSG_BN_WHISPER",
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
}

--------------------------------------------------------------------------------
-- Apply / setup
--------------------------------------------------------------------------------

-- Chat fade is a per-frame setting, so turning the option off puts fading back.
function Perskan:ApplyChatFade()
    local disabled = self.db.profile.chatDisableFade
    for i = 1, NUM_CHAT_WINDOWS do
        local chatFrame = _G["ChatFrame" .. i]
        if chatFrame then
            chatFrame:SetFading(not disabled)
        end
    end
end

function Perskan:ApplyChatCopyButton()
    if self.db.profile.chatCopyButton then
        AttachAllCopyButtons()
    else
        for i = 1, NUM_CHAT_WINDOWS do
            local chatFrame = _G["ChatFrame" .. i]
            if chatFrame and chatFrame.perskanCopyButton then
                chatFrame.perskanCopyButton:Hide()
            end
        end
    end
end

function Perskan:OpenChatCopyWindow()
    OpenCopyWindow(SELECTED_CHAT_FRAME and SELECTED_CHAT_FRAME:GetID() or 1)
end

Perskan:RegisterModule("ChatCopyPaste", function(self)
    for _, event in ipairs(URL_EVENTS) do
        ChatFrame_AddMessageEventFilter(event, UrlFilter)
    end

    -- Our link type has no tooltip data; without this the stock handler errors on it.
    local originalSetHyperlink = ItemRefTooltip.SetHyperlink
    function ItemRefTooltip:SetHyperlink(link, ...)
        if link and link:sub(1, #LINK_PREFIX) == LINK_PREFIX then return end
        return originalSetHyperlink(self, link, ...)
    end

    local function OnLinkClicked(link, text)
        if link == LINK_PREFIX .. ":url" then
            OpenCopyWindow(1, text)
        end
    end

    if type(ChatFrame_OnHyperlinkShow) == "function" then
        hooksecurefunc("ChatFrame_OnHyperlinkShow", function(_, link, text)
            OnLinkClicked(link, text)
        end)
    else
        -- 11.2.7+ routes clicks through SetItemRef instead.
        hooksecurefunc("SetItemRef", function(link, text)
            OnLinkClicked(link, text)
        end)
    end

    -- Chat frames created later (pop-out whispers, combat log tabs).
    if type(ChatFrame_OnLoad) == "function" then
        hooksecurefunc("ChatFrame_OnLoad", function(frame)
            local index = frame and frame.GetName and frame:GetName() and frame:GetName():match("ChatFrame(%d+)")
            if index then AttachCopyButton(tonumber(index)) end
        end)
    elseif ChatFrameUtil and type(ChatFrameUtil.OnLoad) == "function" then
        hooksecurefunc(ChatFrameUtil, "OnLoad", function(frame)
            local index = frame and frame.GetName and frame:GetName() and frame:GetName():match("ChatFrame(%d+)")
            if index then AttachCopyButton(tonumber(index)) end
        end)
    end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", function()
        self:ApplyChatCopyButton()
        self:ApplyChatFade()
    end)
end)
