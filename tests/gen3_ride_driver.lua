return function(game)
 local U=dofile('tests/drivers/util.lua');local dir=assert(os.getenv('SHOT_DIR'))
 assert(require('src.core.Version').engine=='0.3.1')
 game:_handleBootAction({action='new_game',start={map='FR_PALLET_TOWN',x=10,y=12,facing='down'}})
 local space=require('src.core.game3.scripting.space');space.runOnFrame=function()end
 local vm=space.getVm();if vm then vm:halt(true)end;require('src.ui.game3.message').reset()
 local Party=require('src.core.game3.party');game.session.party={};assert(Party.giveMon(game.session,6,50))
 game.session.party[1].moves={19,57,33};game.session.party[1].pp={15,15,35}
 game.session.repelSteps=10000
 if game.mods.exports.overworld_wild_spawns then game.mods.modOptions.overworld_wild_spawns=game.mods.modOptions.overworld_wild_spawns or {};game.mods.modOptions.overworld_wild_spawns.gen3_visible_wilds=false;game.mods.exports.overworld_wild_spawns.gen3.map=nil end
 local Flags=require('src.core.game3.scripting.flags');local Moves=require('src.core.game3.field_moves')
 Flags.setFlag(space.store,nil,Moves.BADGE_FLAGS.FLY,true);Flags.setFlag(space.store,nil,Moves.BADGE_FLAGS.SURF,true)
 local ride=assert(game.mods.exports.DRAMATIC_SKY_RIDE).gen3;local P=require('src.core.game3.player')
 local C=require('src.core.game3.collision');local Map=require('src.core.game3.map')
 U.wait(90)
 local ok,why=ride.mount(1,'ground');assert(ok,why);U.hold(game,'right',16);U.wait(20)
 assert(P.cellX>10,'ground mount did not move');assert(game.mods.exports.DRAMATIC_SKY_RIDE.isMounted())
 if game.mods.exports.overworld_wild_spawns then assert(not game.mods.exports.overworld_wild_spawns.gen3.follower,'mounted follower not suppressed')end
 assert(U.shot(game,dir..'/ground.png'));assert(ride.dismount())
 P.reset(10,12,'down');U.wait(2);ok,why=ride.mount(1,'fly');assert(ok,why)
 local y=P.py;U.hold(game,'down',12);U.wait(2);assert(P.py>y+8,'flight did not move continuously')
 assert(P.spriteYOffset<0,'flight lost height')
 assert(U.shot(game,dir..'/flight.png'))
 assert(ride.dismount(true));assert(not P.freeFlying and P.spriteYOffset==0)
 assert(ride.show());assert(U.shot(game,dir..'/menu.png'));ride.menu=false
 local x,y,facing
 for cy=2,Map.currentDef().height-2 do for cx=2,Map.currentDef().width-2 do
  if C.isWalkable(cx,cy) and not C.isWater(cx,cy)and C.isWater(cx,cy+1) then x,y,facing=cx,cy,'down';break end
 end;if x then break end end
 assert(x,'surf fixture shore unavailable');P.reset(x,y,facing);U.wait(2)
 ok,why=ride.mount(1,'surf');assert(ok,why);U.wait(50);assert(P.surfing,'native surf failed')
 assert(U.shot(game,dir..'/surf.png'));assert(not ride.dismount(),'unsafe water dismount allowed')
 U.hold(game,'up',32);U.wait(25);assert(not C.isWater(P.cellX,P.cellY),'could not return to shore')
 assert(ride.dismount());assert(not ride.active)
 local wilds=game.mods.exports.overworld_wild_spawns
 if wilds then
  P.reset(10,12,'down');U.wait(3)
  local old
  for _,direction in ipairs({'down','left','up','right'})do
   for i=1,24 do
    game.input.pressQueue[#game.input.pressQueue+1]=direction;game.input.state[direction]=true;U.wait(1)
    local f=wilds.gen3.follower
    if f then
     if old and old.ref==f then
      local dx,dy=math.abs(f.px-old.x),math.abs(f.py-old.y)
      assert(dx+dy<=2.1,'follower teleported');assert(dx<.01 or dy<.01,'follower cut a corner')
     end
     assert(C.isWalkable(f.cellX,f.cellY),'follower crossed wall');old={ref=f,x=f.px,y=f.py}
    end
   end
   game.input.state[direction]=false
  end
  assert(old,'follower never appeared')
 end
 print('[ride] PASS native ground/flight/surf/menu, follower suppression and dismount')
 love.event.quit()
end
