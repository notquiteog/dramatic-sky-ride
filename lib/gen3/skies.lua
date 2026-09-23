-- Optional sky interception. Wild Skies owns flyer identity, ecology and
-- shared claims. Ride consumes only its public API; no companion is required.
return function(mod,S,settings,P,Map,blocked,tell)
 local M={cooldown=0,rest=0,intercepts=0}
 local function ex(id)local handle=mod.find and mod.find(id);return handle and handle.exports end
 local function flying()return S.active and S.mode=='fly'and not S.suspended end
 local function enabled()return flying()and settings.get('air_encounters')end
 local registered
 local function register()
  local db=ex('double_battles')
  if not(db and db.registerPartnerSource)or registered==db then return end
  if db.registerPartnerSource({id='dramatic_sky_ride_flock',priority=40,provide=function(_,battle)
   local lead=M.lastIntercept
   if not(M.interceptBuilding and lead and battle and battle.generation==3 and battle.enemy and battle.enemy.mon.species==lead.species and not lead.used)then return end
   lead.used=true
   local skies=ex('wild_skies');local take=skies and skies.takeFlockmate
   if not take then return end
   local mate=take(P.cellX,P.cellY,8,S.height,20)
   if mate then return mate.species,mate.level end
  end})~=false then registered=db end
 end
 function M.start(hit)
  if not(enabled()and not blocked()and hit and hit.species)then return false end
  local encounter={species=hit.species,level=tonumber(hit.level)or 5}
  local db=ex('double_battles');register()
  M.lastIntercept={species=hit.species,level=encounter.level,altitude=hit.altitude or S.height}
  if db and db.tagOrganic then db.tagOrganic(encounter,{map=Map.current,terrain='air',requirePartnerSource=true})end
  local Runtime=require('src.core.game3.runtime')
  M.interceptBuilding=true
  local result={pcall(require('src.core.game3.battle_bridge').startWild,Runtime._mod,mod.world.game,encounter,{})}
  M.interceptBuilding=false
  if not result[1]then error(result[2],0)end
  local started,why=result[2],result[3]
  if started then
   M.cooldown=2;M.rest=25;M.intercepts=M.intercepts+1
   mod.events:emit('mod.dramatic_sky_ride.flyer_intercepted',{species=hit.species,level=encounter.level,altitude=hit.altitude or S.height,mount=S.species})
   return true
  end
  M.lastIntercept=nil;M.cooldown=2
  tell('Sky encounter could not start: '..tostring(why or 'field busy'))
  return false
 end
 mod.exports.startSharedSkyEncounter=M.start
 mod.exports.wildSkiesIntegration=M
 mod.hooks:wrap('input.step',function(nextFn,g,dt)
  local result=nextFn(g,dt);dt=tonumber(dt)or 1/60
  M.cooldown=math.max(0,M.cooldown-dt);M.rest=math.max(0,M.rest-dt)
  if not(enabled()and not blocked())or M.cooldown>0 or M.rest>0 then return result end
  register()
  local skies=ex('wild_skies')
  if skies and skies.takeFlyer then
   local hit,status=skies.takeFlyer(P.cellX,P.cellY,1,S.height,20)
   if status=='pending'then M.cooldown=.5
   elseif hit and hit.species then
    if not M.start(hit)and skies.spawnFlyer then skies.spawnFlyer(hit.species,hit.level)end
   end
  end
  return result
 end)
 return M
end
