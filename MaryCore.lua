----------------------------------------------------------------
-- MARY MEMORY CORE v1
-- This goes INSIDE MaryCore.lua
----------------------------------------------------------------

local HttpService = game:GetService("HttpService")

local Memory = {}

-- Path to memory.json (adjust if needed)
local MEMORY_FILE = "memory.json"

----------------------------------------------------------------
-- LOAD / SAVE
----------------------------------------------------------------

local function loadMemory()
    local raw = readfile(MEMORY_FILE)
    if raw then
        return HttpService:JSONDecode(raw)
    end

    -- default empty memory
    return {
        facts = {},
        log = {},
        meta = {
            createdAt = os.time(),
            lastUpdated = os.time(),
            version = 1
        }
    }
end

local function saveMemory(mem)
    mem.meta.lastUpdated = os.time()
    writefile(MEMORY_FILE, HttpService:JSONEncode(mem))
end

local memory = loadMemory()

----------------------------------------------------------------
-- UTILITIES
----------------------------------------------------------------

local function logEvent(eventType, data)
    table.insert(memory.log, {
        time = os.time(),
        type = eventType,
        data = data
    })
    saveMemory(memory)
end

local function clamp01(x)
    if x < 0 then return 0 end
    if x > 1 then return 1 end
    return x
end

----------------------------------------------------------------
-- PUBLIC API
----------------------------------------------------------------

function Memory.Remember(key, value, source, confidence, notes)
    confidence = confidence or 0.7
    notes = notes or ""

    local existing = memory.facts[key]

    if existing then
        existing.value = value
        existing.confidence = clamp01((existing.confidence + confidence) / 2)
        existing.source = source or existing.source
        if notes ~= "" then
            existing.notes = (existing.notes .. " | " .. notes)
        end
        logEvent("update_fact", { key = key, value = value })
    else
        memory.facts[key] = {
            value = value,
            confidence = clamp01(confidence),
            source = source or "unknown",
            notes = notes
        }
        logEvent("new_fact", { key = key, value = value })
    end

    saveMemory(memory)
end

function Memory.Correct(key, newValue, source, notes)
    local existing = memory.facts[key]

    if existing then
        existing.value = newValue
        existing.confidence = clamp01(existing.confidence * 0.5 + 0.5)
        existing.source = source or existing.source
        if notes then
            existing.notes = (existing.notes .. " | correction: " .. notes)
        end
        logEvent("correct_fact", { key = key, newValue = newValue })
    else
        Memory.Remember(key, newValue, source, 0.5, notes or "added via correction")
    end

    saveMemory(memory)
end

function Memory.Forget(key, reason)
    if memory.facts[key] then
        memory.facts[key] = nil
        logEvent("forget_fact", { key = key, reason = reason })
        saveMemory(memory)
    end
end

function Memory.Get(key)
    local fact = memory.facts[key]
    if fact then
        return fact.value, fact.confidence, fact.source, fact.notes
    end
    return nil
end

function Memory.Knows(key)
    return memory.facts[key] ~= nil
end

function Memory.Export()
    return memory
end

----------------------------------------------------------------
-- RETURN
----------------------------------------------------------------

return Memory
