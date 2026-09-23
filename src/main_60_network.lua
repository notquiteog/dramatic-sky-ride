;(function()
-- Read-only integration: Online owns transport, Ride owns mount art and pose.
-- Remote visual lookup never mounts the local player or changes their party.
local cache,order={},{}
mod.exports.isMounted=function()
 return mod.exports.isFlying()or mod.exports.isGroundRiding()or mod.exports.isWaterRiding()
end
mod.exports.networkPose=function()
 local ex=mod.exports;local mode,species
 if ex.isFlying()then mode,species='fly',ex.mountSpecies()
 elseif ex.isGroundRiding()then mode,species='ground',ex.groundMountSpecies()
 elseif ex.isWaterRiding()then mode,species='surf',ex.waterMountSpecies()end
 if not mode then return nil end
 local world=ex._mountWorld(Game);local p=world and world.player
 local height=0
 if p and type(p.pose)=='function'then local _,_,py=p:pose();height=math.max(0,(p.py or 0)-(py or p.py or 0))end
 if mode=='fly' and height==0 then height=math.max(0,ex.currentAltitude()or 0)end
 local riderLift=8
 local entity=mode=='ground' and ground.riderEntity or mode=='fly' and flight.riderEntity
 if entity and type(entity.pose)=='function'then
  local _,_,py=entity:pose();if type(py)=='number' and p then riderLift=p.py-height-py end
 elseif mode=='surf' and ex._waterRideRiderPose and world then
  local _,_,py=ex._waterRideRiderPose(world);if type(py)=='number' and p then riderLift=p.py-height-py end
 end
 return {mode=mode,species=species,height=math.min(96,height),riderLift=math.max(-32,math.min(64,riderLift)),showRider=showRiderEnabled(),mountScale=math.max(.25,math.min(8,ex.mountVisualScale and ex.mountVisualScale(species)or 1))}
end
mod.exports.networkVisual=function(info)
 if type(info)~='table'or type(info.species)~='string' or #info.species>32 then return end
 local builder=mod.exports.networkSprites[info.mode];if not builder then return end
 local scale=tonumber(info.mountScale)or 1;if scale~=scale then return end;scale=math.max(.25,math.min(8,scale))
 local key=info.mode..':'..info.species..':'..string.format('%.4f',scale)..':'..tostring(info.showRider~=false)
 if not cache[key]then
  local sprite=builder(info.species);if not sprite then return end
  -- Providers may cache these renderers. Clone before attaching peer-owned
  -- scale metadata so local or other remote mounts retain their own settings.
  local copy={};for k,v in pairs(sprite)do copy[k]=v end;setmetatable(copy,getmetatable(sprite))
  copy.def={};for k,v in pairs(sprite.def or {})do copy.def[k]=v end
  copy.def.dramaticSkyRideNetworkScale=scale
  cache[key]={mount=copy};order[#order+1]=key
  if #order>32 then cache[table.remove(order,1)]=nil end
 end
 local world=mod.exports._mountWorld(Game)
 local p=world and world.player
 if info.showRider~=false and p and not cache[key].rider then cache[key].rider=select(1,buildRiderSprite(p))end
 return cache[key]
end
end)()
