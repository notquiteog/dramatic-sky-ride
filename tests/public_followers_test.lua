local requested,mode
local mod={game={},world={},find=function(self,id)
 assert(self.world)
 if id~='overworld_wild_spawns' then return end
 if mode=='missing' then return {exports={}}end
 return {exports={resolveFollowerSprite=function(opts)
  requested=opts
  if mode=='error'then error('provider unavailable')end
  return {image='mounted/custom/six.png',frames=mode=='nine'and 9 or 6,trueColor=mode~='palette'}
 end}}
end}
local resolve=dofile('lib/public_followers.lua')(mod)
assert(resolve('LAPRAS',{dex=131},'ground_mount')=='mounted/custom/six.png')
assert(requested.species=='LAPRAS'and requested.dex==131 and requested.style=='followers'and requested.role=='ground_mount'and requested.game==mod.game)
for _,v in ipairs({'missing','error','nine','palette'})do mode=v;assert(resolve('LAPRAS',{dex=131})==nil)end
assert(dofile('lib/public_followers.lua')({})('LAPRAS')==nil)
print('PASS public follower provider path, canonical layout, missing/failed provider and owned-fallback signal')
