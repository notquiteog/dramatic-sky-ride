;(function()
-- Read-only integration: Online owns transport, Ride owns mount art and pose.
-- Remote visual lookup never mounts the local player or changes their party.
local cache={}
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
 return {mode=mode,species=species,height=math.min(96,height),riderLift=math.max(-32,math.min(64,riderLift))}
end
mod.exports.networkVisual=function(info)
 if type(info)~='table'or type(info.species)~='string' or #info.species>32 then return end
 local builder=mod.exports.networkSprites[info.mode];if not builder then return end
 local key=info.mode..':'..info.species
 if not cache[key]then
  local sprite=builder(info.species);if not sprite then return end
  cache[key]={mount=sprite}
 end
 local world=mod.exports._mountWorld(Game)
 local p=world and world.player
 if p and not cache[key].rider then cache[key].rider=select(1,buildRiderSprite(p))end
 return cache[key]
end
end)()
