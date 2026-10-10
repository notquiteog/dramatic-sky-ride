-- Sprite-mode flight must retain a species without a Stadium provider.
local api={isFlying=function()return true end,isGroundRiding=function()return false end,isWaterRiding=function()return false end,mountSpecies=function()return nil end,currentAltitude=function()return 24 end,_mountWorld=function()return {player={py=64}}end}
local env=setmetatable({mod={exports=api},flight={species="CHARIZARD"},ground={},Game={},showRiderEnabled=function()return true end},{__index=_G})
local f=assert(io.open('src/main_60_network.lua'));local source=f:read('*a');f:close()
local chunk=assert(loadstring('local _ = nil\n'..source));setfenv(chunk,env);chunk()
local p=api.networkPose();assert(p.mode=='fly' and p.species=='CHARIZARD' and p.height==24)
api.isFlying=function()return false end;assert(api.networkPose()==nil)
api.isGroundRiding=function()return true end;api.groundMountSpecies=function()return 'RAPIDASH'end
assert(api.networkPose().species=='RAPIDASH')
print('gb_network_pose_test: sprite flight, dismount and ground identity passed')
