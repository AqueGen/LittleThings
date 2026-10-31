-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local addonName, ns = ...

local GroupChat = {}

local hooked = false

local function OnOpenChat()
    if not ns.IsOn("groupChat") then
        return
    end
    local editBox = ChatFrameUtil.GetActiveWindow()
    if not editBox or not editBox:HasFocus() then
        return
    end
    local chatType = ns.ChatRules.Pick(editBox:GetChatType(), {
        instance = IsInGroup(LE_PARTY_CATEGORY_INSTANCE),
        raid = IsInRaid(LE_PARTY_CATEGORY_HOME),
        party = IsInGroup(LE_PARTY_CATEGORY_HOME),
    })
    if chatType then
        editBox:SetChatType(chatType)
        editBox:UpdateHeader()
    end
end

function GroupChat.Enable()
    if not hooked then
        hooked = true
        hooksecurefunc(ChatFrameUtil, "OpenChat", OnOpenChat)
    end
end

function GroupChat.OnSwitch(enabled)
    if enabled then
        GroupChat.Enable()
    end
end

GroupChat.key = "groupChat"
ns.RegisterModule("GroupChat", GroupChat)
