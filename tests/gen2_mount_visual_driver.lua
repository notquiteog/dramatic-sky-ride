return function(game)
 local U=dofile('/home/admin/Apps/Gen1Recomp/source/tests/drivers/util.lua')
 local w=game.world;w.trySceneScript=function()return false end;w.noWildEncounters=true
 assert(w:setMap('NEW_BARK_TOWN',7,8,'down'));U.wait(180);game.stack:clear()
 local D=assert(game.mods.exports.DRAMATIC_SKY_RIDE)
 local V=game.mods.exports.BATTLE_ART_VOXEL_FORK.lib
 local P=require('src.render.Pipelines');local Mon=require('src.battle.gen2.Mon')
 love.window.setMode(2560,1440,{resizable=true});V.require('DayNight').setting:sync('day')
 local mon=Mon.new(game.data,'RAIKOU',50);game.save.party={mon};U.wait(10)
 assert(D.requestGroundMount(mon),'mount rejected');U.wait(30)
 local p=w.player
 for _,mode in ipairs({3,6,7}) do
  P.setLevel('voxel',mode);U.wait(100)
  assert(D.gen2PlayerBridge.ownsPlayerSprite(),'mount visual not owned')
  assert(p.sprite.def.id=='GROUND_RIDE_RAIKOU','trainer replaced mount')
  local n=0
  for _,e in ipairs(w.entities) do if e.groundRideRider then
   n=n+1;assert(e.sprite.def.id=='SKY_RIDE_RIDER_SPRITE_CHRIS','uncropped trainer fallback')
   assert(e.sprite:resolveImage(),'runtime rider image unreadable')
  end end
  assert(n==(mode==6 and 0 or 1),'duplicate/first-person rider')
  assert(U.shot(game,assert(os.getenv('SHOT_DIR'))..'/raikou_'..mode..'.png'))
 end
 assert(D.requestGroundDismount());U.wait(30)
 assert(not D.gen2PlayerBridge.active() and p.sprite.def.id=='SPRITE_CHRIS','native player not restored')
 for _,e in ipairs(w.entities) do assert(not e.groundRideRider,'rider left after dismount') end
 print('[mount] PASS follower-backed Raikou, cropped rider, three camera modes, dismount restoration')
 love.event.quit()
end
