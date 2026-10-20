global assert, collectgarbage, ipairs, require, gemdos

local <const> k_RCache = require("gembindl.utility.rcache")

-- Clear the cache
k_RCache.set_keep(false)
k_RCache.reset_stats()
collectgarbage()

-- Table to hold on_require events
local on_req_events = {}

-- Set on_require function to update on_req_events array
k_RCache.set_on_require(
  function(is_before, modname)
    -- Save on_require event
    on_req_events[#on_req_events + 1] = { is_before, modname }
  end)

-- Require the utility module
local utility = k_RCache.require("gembindl.utility")

-- Module will be required, as it's not in the cache
assert(#on_req_events == 2)
assert(on_req_events[1][1] == true)
assert(on_req_events[1][2] == "gembindl.utility")
assert(on_req_events[2][1] == false)
assert(on_req_events[2][2] == "gembindl.utility")

-- Stats show one module in cache, zero hits and one miss
local num, hits, misses = k_RCache.stats()
assert(num == 1)
assert(hits == 0)
assert(misses == 1)

-- Require it again, it will be taken from the cache
utility = k_RCache.require("gembindl.utility")
-- on_req_events still contains 2 events
assert(#on_req_events == 2)

-- Stats show one module in cache, one hit and one miss
num, hits, misses = k_RCache.stats()
assert(num == 1)
assert(hits == 1)
assert(misses == 1)

-- Clear the reference and garbage collect
utility = nil
collectgarbage()

-- Stats show zero modules in cache, one hit and one miss
num, hits, misses = k_RCache.stats()
assert(num == 0)
assert(hits == 1)
assert(misses == 1)

-- Turn on keeping
k_RCache.set_keep(true)

-- Require utility module again
on_req_events = {}
utility = k_RCache.require("gembindl.utility")
-- Module will be required, as it's not in the cache
-- on_req_events contains 2 events
assert(#on_req_events == 2)
assert(on_req_events[1][1] == true)
assert(on_req_events[1][2] == "gembindl.utility")
assert(on_req_events[2][1] == false)
assert(on_req_events[2][2] == "gembindl.utility")

-- Stats show one module in cache, one hit and two misses
num, hits, misses = k_RCache.stats()
assert(num == 1)
assert(hits == 1)
assert(misses == 2)

-- Clear the reference and garbage collect
utility = nil
collectgarbage()

-- Stats still show one module in cache, one hit and two misses
num, hits, misses = k_RCache.stats()
assert(num == 1)
assert(hits == 1)
assert(misses == 2)

-- Require utility module again
on_req_events = {}
utility = k_RCache.require("gembindl.utility")
-- Module was taken from the cache
-- on_req_events still contains no events
assert(#on_req_events == 0)

-- Stats show one module in cache, two hits and two misses
num, hits, misses = k_RCache.stats()
assert(num == 1)
assert(hits == 2)
assert(misses == 2)

-- Turn off keeping
k_RCache.set_keep(false)

-- Clear the reference and garbage collect
utility = nil
collectgarbage()

-- Stats show zero modules in cache, two hits and two misses
num, hits, misses = k_RCache.stats()
assert(num == 0)
assert(hits == 2)
assert(misses == 2)

-- Require two modules, with keep false
utility = k_RCache.require("gembindl.utility")
local aesdefs = k_RCache.require("gembindl.utility.defs.aesdefs")
-- on_req_events contains 4 events
assert(#on_req_events == 4)
-- Both modules will be required, as they are not in the cache
assert(on_req_events[1][1] == true)
assert(on_req_events[1][2] == "gembindl.utility")
assert(on_req_events[2][1] == false)
assert(on_req_events[2][2] == "gembindl.utility")
assert(on_req_events[3][1] == true)
assert(on_req_events[3][2] == "gembindl.utility.defs.aesdefs")
assert(on_req_events[4][1] == false)
assert(on_req_events[4][2] == "gembindl.utility.defs.aesdefs")

-- Stats show two modules in cache, two hits and four misses
num, hits, misses = k_RCache.stats()
assert(num == 2)
assert(hits == 2)
assert(misses == 4)

-- Now set keep to true.
k_RCache.set_keep(true)

-- Stats still show two modules in cache, two hits and four misses
num, hits, misses = k_RCache.stats()
assert(num == 2)
assert(hits == 2)
assert(misses == 4)

-- Clear the references and garbage collect
utility = nil
aesdefs = nil
collectgarbage()

-- Keep is true, so stats still show two modules in cache, two hits
-- and four misses
num, hits, misses = k_RCache.stats()
assert(num == 2)
assert(hits == 2)
assert(misses == 4)

-- on_req_events still contains 4 events
assert(#on_req_events == 4)

-- Require the utility module
utility = k_RCache.require("gembindl.utility")

-- Stats show two modules in cache, three hits and four misses
num, hits, misses = k_RCache.stats()
assert(num == 2)
assert(hits == 3)
assert(misses == 4)
