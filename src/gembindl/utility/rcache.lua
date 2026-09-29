global package, pairs, require, setmetatable, gemdos

local <const> RCache = {
  reqs = {},
  keep = {},
  keeping = false
}

setmetatable(RCache.reqs, {__mode = "kv"})

local reqs_hit, reqs_miss = 0, 0

-- set_on_require. Sets callback to be invoked bafore and
-- after require.
function RCache.set_on_require(on_require)
  RCache.on_require = on_require
end

-- require
-- Requires a module,  caches it in a weak table
-- and adds it to a regular keeping table, which
-- can be dropped using set_keep(false).
-- Input:
--   1) string: modname: the module to cache 
-- Returns:
--   1) value: the cached module value
function RCache.require(modname)
  local <const> reqs = RCache.reqs
  local t = reqs[modname]

  if t == nil then
    reqs_miss = reqs_miss + 1
    -- Package already loaded?
    local <const> loaded = package.loaded[modname]
    -- Require and cache
    local <const> on_require = RCache.on_require
    if on_require then
      on_require(true, modname)
    end
    t = require(modname)
    if on_require then
      on_require(false, modname)
    end
    reqs[modname] = t
    if loaded == nil then
      -- Restore original not loaded state
      package.loaded[modname] = nil
    end
    if RCache.keeping then
      RCache.keep[modname] = t
    end
  else
    reqs_hit = reqs_hit + 1
  end

  return t
end

-- stats. Returns cache statistics
-- Returns:
--   1) integer: number of modules in weak table
--   2) integer: number of cache hits
--   3) integer: number of cache misses
function RCache.stats()
  local cached = 0
  for k,v in pairs(RCache.reqs) do
    cached = cached + 1
  end
  return cached, reqs_hit, reqs_miss
end

-- set_keep. Enables and disables keeping. On disabling
-- keep table is replaced with empty table.
-- Input:
--   1) boolean: true to enable keeping otherwise false
function RCache.set_keep(enable)
  RCache.keeping = enable
  if not enable then
    RCache.keep = {}
  end
end

return RCache
