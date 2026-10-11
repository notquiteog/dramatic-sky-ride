local L=dofile('lib/gen3/native_locomotion.lua')
for _,phase in ipairs({'ground step','Surf hop','ledge jump','Dive warp','waterfall'})do
 local p={cellX=5,cellY=6,px=82,py=99,targetX=5,targetY=7,progress=.4,moving=true,
  spriteYOffset=-3,underwater=phase=='Dive warp',surfHopping=phase=='Surf hop',surfing=true,
  jumping=phase=='ledge jump',freeFlying=false,action=phase}
 local old={};for k,v in pairs(p)do old[k]=v end
 L.release(p,false)
 for k,v in pairs(old)do assert(p[k]==v,phase..' clobbered native '..k)end
end
local p={cellX=5,cellY=6,px=80,py=96,targetX=5,targetY=7,progress=.4,moving=true,spriteYOffset=-32,freeFlying=true}
L.release(p,true)
assert(not p.freeFlying and not p.moving and p.spriteYOffset==0 and p.progress==0)
assert(p.px==80 and p.py==96 and p.targetX==5 and p.targetY==6)
print('PASS native ground/Surf/ledge/Dive/waterfall ownership and free-flight release')
