return function(game)
 io.stdout:setvbuf("no")
 game.mods.modOptions.DRAMATIC_SKY_RIDE=game.mods.modOptions.DRAMATIC_SKY_RIDE or {};game.mods.modOptions.DRAMATIC_SKY_RIDE.mount_hints=false
 local U=dofile('tests/drivers/util.lua');local role=os.getenv('QA_ROLE');local gen=require('src.core.GameVersion').generation()
 local P=require(gen==2 and 'src.battle.gen2.Mon'or'src.pokemon.Pokemon')
 local function world()return game.world or game.overworld end
 local map=gen==2 and 'NEW_BARK_TOWN'or'PALLET_TOWN'
 if gen==2 then game.phase='play';game.world.trySceneScript=function()return false end;game.world.noWildEncounters=true;assert(game.world:setMap(map,role=='host'and 9 or 10,7,'down'));game.stack:clear()
 else U.teleport(game,map,role=='host'and 8 or 9,15,'down')end
 game.save.party={P.new(game.data,'ARCANINE',40)}
 local online=game.mods.exports['gen1online-plus'].multiplayer
 local ride=game.mods.exports.DRAMATIC_SKY_RIDE
 local port=gen==2 and 18837 or 18836
 U.wait(150);if gen==2 then game.stack:clear()else U.teleport(game,map,role=='host'and 8 or 9,15,'down')end
 if role=='host'then assert(online.hostLan(port))else assert(online.joinLan('127.0.0.1:'..port))end
 local function until_(fn,label)for _=1,1800 do if fn()then return end;U.wait(1)end;error(label)end
 until_(function()return online.connected and online.peers.remote end,'pair');online.ui.close();U.wait(15)
 local function saw(text)for _,m in ipairs(online.chat)do if m.text==text then return true end end end
 local function peer()for _,e in ipairs(world().npcs or {})do if e.id=='gen1online_room_peer'then return e end end end
 if role=='host'then
  assert(ride.requestGroundMount(game.save.party[1]),'ground mount');U.wait(15);assert(ride.networkPose().mode=='ground');online.say('mounted')
  until_(function()return saw('seen')end,'mount ack')
  U.hold(game,'down',16);online.say('moved');until_(function()return saw('moved-seen')end,'move ack')
  assert(ride.requestGroundDismount());online.say('dismounted');until_(function()return saw('done')end,'dismount ack')
 else
  until_(function()return saw('mounted')and peer()and peer().mountSprite end,'mount visible')
  assert(not ride.isMounted(),'remote changed local mount')
  local spr=peer():pose();assert(spr,'no mount sprite');assert(U.shot(game,os.getenv('SHOT_DIR')..'/mounted.png'))
  local y=peer().py;online.say('seen');until_(function()return saw('moved') and peer().py>y+2 end,'movement')
  online.say('moved-seen');until_(function()return saw('dismounted')and peer()and not peer().mountSprite end,'dismount')
  assert(not ride.isMounted());online.say('done')
 end
 U.wait(60);online.disconnect();U.wait(10);assert(not peer(),'ghost peer')
 print('[GB ride] PASS',gen,role,'mount/rider, movement, dismount, disconnect');love.event.quit()
end
