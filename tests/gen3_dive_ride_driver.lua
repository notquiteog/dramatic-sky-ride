-- Isolated Hoenn native Dive roundtrip: Ride never takes underwater control.
return function(game)
 assert(love.filesystem.getIdentity():match('%-qa$'))
 local U=dofile('tests/drivers/util.lua')
 local version=require('src.core.GameVersion').get()
 local prefix=assert(({ruby='RU_',sapphire='SA_',emerald='EM_'})[version])
 local R=require('src.mods.Runtime');local old=game.update
 game.update=function(self,dt)return R.call('core.update',old,self,dt)end
 game:_handleBootAction({action='new_game',start={map=prefix..'ROUTE124',x=8,y=8,facing='down'}})
 local Space=require('src.core.game3.scripting.space');Space.runOnFrame=function()end
 local vm=Space.getVm();if vm then vm:halt(true)end;require('src.ui.game3.message').reset()
 local V=game.mods.exports.BATTLE_ART_VOXEL_FORK;if V then V.lib.require('Gen3Integration').setLevel(0,game)end
 local Party=require('src.core.game3.party');local Dex=require('src.core.game3.pokemon')
 game.session.party={};assert(Party.giveMon(game.session,Dex.speciesFromName('PELIPPER'),50))
 local mon=game.session.party[1];mon.moves={57,291};mon.pp={15,10};mon.maxPp={15,10}
 local Flags=require('src.core.game3.scripting.flags');local Moves=require('src.core.game3.field_moves')
 for _,move in ipairs({'SURF','DIVE'})do Flags.setFlag(Space.store,nil,Moves.badgeFlag(move),true)end
 local P=require('src.core.game3.player');local Map=require('src.core.game3.map')
 local C=require('src.core.game3.collision');local Dive=require('src.core.game3.dive')
 local S=assert(game.mods.exports.DRAMATIC_SKY_RIDE).gen3
 local function until_(fn,label)for _=1,1800 do if fn()then return end;U.wait(1)end;error(label)end
 U.wait(120)
 local x,y
 for cy=1,Map.currentDef().height-2 do for cx=1,Map.currentDef().width-2 do
  if Dive.isDiveable(C.behavior(cx,cy+1))and C.isWater(cx,cy)then
   P.reset(cx,cy+1,'down');local code,dest=Dive.trySetDiveWarp(game.session)
   if code==2 and dest then x,y=cx,cy;break end
  end
 end;if x then break end end
 assert(x,'no native Dive seam');S.dismount(true);P.reset(x,y,'down');P.surfing=false
 assert(S.mount(1,'surf'));until_(function()return P.surfing and not P.moving and not P.surfHopping end,'native Surf entry')
 local code,dest=Dive.trySetDiveWarp(game.session);assert(code==2 and dest,'Surf hop left Dive seam')
 assert(Dive.useDive(0,mon));until_(function()return P.underwater and Map.current==dest.map and not Dive.isActive() and not require('src.core.game3.warp').isBusy()end,'native Dive descent')
 U.wait(5);assert(not S.active,'Ride retained underwater ownership')
 assert(not S.mount(1,'ground'),'ground mount allowed underwater');assert(not S.mount(1,'fly'),'flight allowed underwater')
 U.hold(game,'down',20);U.wait(30)
 assert(P.underwater,'underwater traversal lost native state')
 assert(U.shot(game,assert(os.getenv('SHOT_DIR'))..'/underwater.png'))
 local up,back=Dive.trySetDiveWarp(game.session);assert(up==1 and back,'no native emergence at Dive destination')
 assert(Dive.useDive(0,mon));until_(function()return not P.underwater and Map.current==back.map and not Dive.isActive() and not require('src.core.game3.warp').isBusy()end,'native emergence')
 until_(function()return S.active and S.mode=='surf'end,'automatic surfaced Surf overlay')
 print('[PASS native Dive Ride ownership]',version,Map.current)
 love.event.quit()
end
