-- Resolve only explicitly exported canonical six-facing strips. Mounted ZIPs
-- and renamed mod directories need no filesystem discovery or private reads.
return function(mod)
 local ids={'overworld_wild_spawns','PokePCFollowers_VoxelMerge','pokepcfollowers','FOLLOWERS_EX','followers_ex'}
 return function(species,cfg,role)
  if type(mod.find)~='function' then return end
  for _,id in ipairs(ids)do
   local ok,handle=pcall(mod.find,mod,id)
   local api=ok and handle and handle.exports
   if api and type(api.resolveFollowerSprite)=='function' then
    local success,def=pcall(api.resolveFollowerSprite,{species=species,dex=cfg and cfg.dex,
     surface='land',style='followers',role=role or 'ride_mount',game=mod.game})
    if success and type(def)=='table' and type(def.image)=='string' and def.image~=''
     and tonumber(def.frames)==6 and def.trueColor~=false then return def.image end
   end
  end
 end
end
