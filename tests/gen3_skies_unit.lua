-- Optional Ride/Skies/Doubles contracts without maps, profiles, or gameplay.
local n=0
local function check(v,m)n=n+1;assert(v,m)end
local hooks={};local values={air_encounters=true};local S={active=true,mode='fly',height=48,species=6}
local P={cellX=4,cellY=7};local Map={current='ROUTE1'};local started=0;local consumed=0;local respawned=0;local tag;local source;local taken;local fail
local scope
local db={withOrganicSource=function(species,level,context,begin)
 check(species=='PIDGEY' and context.requirePartnerSource,'canonical scoped source');scope=context;local ok,why=begin();scope=nil;return ok,why end,registerPartnerSource=function(s)source=s;return true end,tagOrganic=function(enc,ctx)tag={enc,ctx};return true end}
local skies={takeFlyer=function(x,y,r,h,t)check(x==4 and y==7 and r==1 and h==48 and t==20,'physical position and altitude forwarded');consumed=consumed+1;if taken=='pending'then return nil,'pending'end;return taken end,
 takeFlockmate=function()return{species=17,level=8}end,spawnFlyer=function()respawned=respawned+1 end}
local handles={double_battles={exports=db},wild_skies={exports=skies}}
local emitted
local mod={id='DRAMATIC_SKY_RIDE',exports={},game={},world={startWildBattle=function(_,species,level)
 started=started+1;check(species=='PIDGEY'and level==7,'canonical public battle call');if scope then check(scope.requirePartnerSource,'source scope survives fresh native encounter');local mate=source.provide(nil,{generation=3,enemy={mon={species=16,level=level}}});check(mate==17,'scoped native flock source')end;return not fail,fail and 'blocked' end},find=function(id)return handles[id]end,hooks={wrap=function(_,k,fn)hooks[k]=fn end},events={emit=function(_,name)
 local prefix='mod.DRAMATIC_SKY_RIDE.';assert(name:sub(1,#prefix)==prefix,'engine rejects event prefix');emitted=name
end}}
package.loaded['src.core.game3.pokemon']={keyName=function(n)return n==16 and'PIDGEY'end,speciesFromName=function(s)return s=='PIDGEY'and 16 end}
local blocked=false;local notice
local M=dofile('lib/gen3/skies.lua')(mod,S,{get=function(k)return values[k]end},P,Map,function()return blocked end,function(t)notice=t end)
local function step(dt)return hooks['input.step'](function()end,mod.game,dt or 1/60)end
handles.wild_skies=nil;step();check(started==0,'no companion required')
handles.wild_skies={exports=skies};values.air_encounters=false;step();check(consumed==0,'AIR ENCOUNTERS OFF does not consume')
values.air_encounters=true;taken='pending';step();check(started==0 and M.cooldown>0,'pending shared claim starts no local battle')
M.cooldown=0;taken={species=16,level=7};step();check(started==1 and M.intercepts==1 and M.rest==25,'physical contact enters native battle and rest')
check(emitted=='mod.DRAMATIC_SKY_RIDE.flyer_intercepted','successful entry emits the manifest-owned event and returns normally')
check(source.provide(nil,{generation=3,enemy={mon={species=16}}})==nil,'flock source cannot leak into later encounter')
M.rest=0;M.cooldown=0;fail=true;step();check(respawned==1 and notice,'failed local start restores consumed flyer through owner API')
handles.double_battles=nil;M.rest=0;M.cooldown=0;fail=false;step();check(started==3,'standalone battle needs no Doubles companion')
blocked=true;check(not mod.exports.startSharedSkyEncounter({species=16}),'shared grant respects field ownership')
print('gen3_skies_unit: '..n..' contracts passed')
