-- Ride replaces locomotion only while freely flying. Removing an ordinary
-- ground/Surf overlay must not cancel a native hop, warp, Dive or ledge step.
local M={}
function M.release(player,wasFlying)
 if not wasFlying then return end
 player.px=player.cellX*16;player.py=player.cellY*16
 player.freeFlying=false;player.spriteYOffset=0
 player.moving=false;player.targetX=player.cellX;player.targetY=player.cellY;player.progress=0
end
return M
