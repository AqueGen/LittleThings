package.path = "./Modules/GroupChat/?.lua;" .. package.path

local Rules = require("ChatRules")

describe("Rules.Pick", function()
  it("picks instance chat in a finder group", function()
    assert.equals("INSTANCE_CHAT", Rules.Pick("SAY", { instance = true, raid = false, party = false }))
  end)
  it("keeps the group channel the player chose while in both a home party and a finder group", function()
    local group = { instance = true, raid = false, party = true }
    for _, current in ipairs({ "PARTY", "RAID", "INSTANCE_CHAT" }) do
      assert.is_nil(Rules.Pick(current, group))
    end
  end)
  it("still leaves say, guild and channels for instance chat in both groups", function()
    local group = { instance = true, raid = true, party = true }
    for _, current in ipairs({ "SAY", "GUILD", "CHANNEL" }) do
      assert.equals("INSTANCE_CHAT", Rules.Pick(current, group))
    end
  end)
  it("picks raid in a home raid", function()
    assert.equals("RAID", Rules.Pick("SAY", { instance = false, raid = true, party = true }))
  end)
  it("picks party in a home party", function()
    assert.equals("PARTY", Rules.Pick("SAY", { instance = false, raid = false, party = true }))
  end)
  it("picks say without a group", function()
    assert.equals("SAY", Rules.Pick("PARTY", { instance = false, raid = false, party = false }))
  end)
  it("goes back to the group after guild, channel, yell or emote", function()
    local group = { instance = false, raid = false, party = true }
    for _, current in ipairs({ "GUILD", "GUILD_DISCORD", "OFFICER", "CHANNEL", "YELL", "EMOTE", "RAID_WARNING" }) do
      assert.equals("PARTY", Rules.Pick(current, group))
    end
  end)
  it("leaves whispers and unknown types alone", function()
    local group = { instance = false, raid = false, party = true }
    for _, current in ipairs({ "WHISPER", "BN_WHISPER", "SMART_WHISPER", "VOICE_TEXT", "COMMUNITIES_CHANNEL" }) do
      assert.is_nil(Rules.Pick(current, group))
    end
  end)
  it("returns nil when the type is already right", function()
    assert.is_nil(Rules.Pick("PARTY", { instance = false, raid = false, party = true }))
  end)
end)
