-- Real native Waterfall ascent/descent with the optional Ride overlay enabled.
return function(game)
 assert(love.filesystem.getIdentity():match('%-qa$'))
 local U=dofile('tests/drivers/util.lua');local version=require('src.core.GameVersion').get()
 local prefix=({ruby='RU_',sapphire='SA_',emerald='EM_'})[version]
 local map=prefix and prefix..'EVER_GRANDE_CITY' or 'FR_FOUR_ISLAND_ICEFALL_CAVE_ENTRANCE'
 local R=require('src.mods.Runtime');local old=game.update
 game.update=function(self,dt)return R.call('core.update',old,self,dt)end
 game:_handleBootAction({action='new_game',start={map=map,x=4,y=4,facing='up'}})
 local Space=require('src.core.game3.scripting.space');Space.runOnFrame=function()end
 local vm=Space.getVm();if vm then vm:halt(true)end;require('src.ui.game3.message').reset()
 local V=game.mods.exports.BATTLE_ART_VOXEL_FORK;if V then V.lib.require('Gen3Integration').setLevel(0,game)end
 local Party=require('src.core.game3.party');local Dex=require('src.core.game3.pokemon')
 game.session.party={};assert(Party.giveMon(game.session,Dex.speciesFromName('GYARADOS'),50))
 local mon=game.session.party[1];mon.moves={57,127};mon.pp={15,15};mon.maxPp={15,15}
 local Flags=require('src.core.game3.scripting.flags');local Moves=require('src.core.game3.field_moves')
 for _,move in ipairs({'SURF','WATERFALL'})do Flags.setFlag(Space.store,nil,Moves.badgeFlag(move),true)end
 local P=require('src.core.game3.player');local Map=require('src.core.game3.map')
 local C=require('src.core.game3.collision');local Field=require('src.core.game3.field')
 local S=assert(game.mods.exports.DRAMATIC_SKY_RIDE).gen3
 local function until_(fn,label)for _=1,1800 do if fn()then return end;U.wait(1)end;error(label)end
 U.wait(120);local x,y,top
 for cy=2,Map.currentDef().height-2 do for cx=1,Map.currentDef().width-2 do
  if C.isWater(cx,cy) and not Moves.isWaterfallBehavior(C.behavior(cx,cy)) and Moves.isWaterfallBehavior(C.behavior(cx,cy-1))then
   local ty=cy-1;while ty>0 and Moves.isWaterfallBehavior(C.behavior(cx,ty))do ty=ty-1 end
   if C.isWater(cx,ty)then x,y,top=cx,cy,ty;break end
  end
 end;if x then break end end
 assert(x,'no native Waterfall seam');S.dismount(true);P.reset(x,y,'up');P.surfing=true
 until_(function()return S.active and S.mode=='surf'end,'Surf overlay adoption')
 local result=Moves.waterfallFromMenu({session=game.session,mon=mon,party=game.session.party,isSurfing=true,isFacingWaterfall=true,facing='up',store=Space.store})
 -- Native badge validation and actual field-effect chain, not a forced-step mock.
 assert(result.ok,'native Waterfall rejected');assert(Field.executeFieldMove(result)~=false)
 until_(function()return P.cellY==top and not P.moving and not Field._waterfall and not Field.locked end,'native ascent')
 assert(P.surfing and S.active and S.mode=='surf','lost Surf during ascent')
 assert(U.shot(game,assert(os.getenv('SHOT_DIR'))..'/summit.png'))
 U.hold(game,'down',20)
 until_(function()return P.cellY>=y and not P.moving end,'native descent')
 assert(P.surfing and S.active and S.mode=='surf','lost Surf during descent')
 print('[PASS native Waterfall Ride]',version,map,y,top,P.cellY)
 love.event.quit()
end
