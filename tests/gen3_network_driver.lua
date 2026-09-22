return function(game)
 local U=dofile('tests/drivers/util.lua');local role=assert(os.getenv('QA_ROLE'));local dir=assert(os.getenv('SHOT_DIR'))
 game:_handleBootAction({action='new_game',start={map='FR_PALLET_TOWN',x=role=='host'and 10 or 9,y=12,facing='down'}})
 local space=require('src.core.game3.scripting.space');space.runOnFrame=function()end
 local vm=space.getVm();if vm then vm:halt(true)end;require('src.ui.game3.message').reset()
 local Party=require('src.core.game3.party');game.session.party={};assert(Party.giveMon(game.session,6,50))
 game.session.party[1].moves={19,57,33};game.session.party[1].pp={15,15,35}
 local flags=require('src.core.game3.scripting.flags');local moves=require('src.core.game3.field_moves')
 flags.setFlag(space.store,nil,moves.BADGE_FLAGS.FLY,true)
 local online=assert(game.mods.exports['gen1online-plus']).multiplayer
 local ride=assert(game.mods.exports.DRAMATIC_SKY_RIDE).gen3
 local P=require('src.core.game3.player');local Sprites=require('src.core.game3.ow_sprites')
 U.wait(250)
 if role=='host'then assert(online.hostLan(18831))else assert(online.joinLan('127.0.0.1:18831'))end
 local function until_(fn,label)
  for _=1,1800 do if fn()then return end;U.wait(1)end;error(label..': '..tostring(online.notice))
 end
 until_(function()return online.connected and online.peers.remote end,'pair')
 local function saw(text)for _,m in ipairs(online.chat)do if m.text==text then return true end end end
 local function peer()return game.mods.exports['gen1online-plus'].netNpcs()[1]end
 if role=='host'then
  local ok,why=ride.mount(1,'ground');assert(ok,why);assert(online.say('ground'))
  until_(function()return saw('ground-seen')end,'ground ack')
  assert(ride.dismount());P.reset(10,12,'down');U.wait(2)
  ok,why=ride.mount(1,'fly');assert(ok,why);U.hold(game,'down',10);U.wait(2);assert(online.say('flight'))
  until_(function()return saw('flight-seen')end,'flight ack')
  assert(ride.dismount(true));assert(online.say('landed'))
  until_(function()return saw('landed-seen')end,'landing ack')
  assert(online.say('done'));U.wait(120)
 else
  until_(function()return saw('ground')and peer()and peer().graphicsId>=830000 end,'mounted peer')
  local row=peer();assert(Sprites.getDraw(row.graphicsId),'remote mount sprite missing');assert(not ride.active,'peer mounted local player')
  assert(U.shot(game,dir..'/peer-ground.png'));assert(online.say('ground-seen'))
  until_(function()return saw('flight')and peer()and (peer().raiseY or 0)<-20 end,'airborne peer')
  row=peer();assert(row.graphicsId>=830000);assert(not ride.active);assert(online.peers.remote.busy,'airborne peer accepted activities')
  assert(U.shot(game,dir..'/peer-flight.png'));assert(online.say('flight-seen'))
  until_(function()return saw('landed')and peer()and peer().graphicsId<1024 and (peer().raiseY or 0)==0 end,'dismount peer')
  assert(online.say('landed-seen'));until_(function()return saw('done')end,'done')
 end
 print('[network ride] PASS',role,'remote mount/flight pose/height/dismount, local mount untouched')
 online.disconnect();U.wait(10);assert(#game.mods.exports['gen1online-plus'].netNpcs()==0,'ghost after disconnect');love.event.quit()
end
