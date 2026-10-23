-- DSM4 bytes belong to Ride's public installation cache or its own package.
-- Another mod's old global cache is not an API3 asset handle.
return function(mod)
 local M={}
 local function valid(key)
  return type(key)=='string'and key:match('^stadium2/')and not key:find('..',1,true)and not key:find('\\',1,true)
 end
 function M.read(key)
  if not valid(key)then return nil end
  local bytes=mod.cache and mod.cache:read(key)
  if type(bytes)=='string'then return bytes end
  bytes=mod:read('assets/'..key)
  return type(bytes)=='string'and bytes or nil
 end
 function M.info(key)
  if not valid(key)then return nil end
  local info=mod.cache and mod.cache:info(key)
  if info then return info end
  return mod.assets and mod.assets:info('assets/'..key)
 end
 return M
end
