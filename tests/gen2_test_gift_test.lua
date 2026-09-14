-- Exercise the real gift part against disposable party/PC and public SDK stubs.
local function loadHelper(gen2)
 local events,commands={},{}
 local world={maps={NEW_BARK_TOWN={objects={}}}}
 local game={save={party={},boxes={}},data={moves={FLY={pp=15},SURF={pp=15}}},world=world}
 local api={}
 function api:overworld()return world end
 function api:spawnNpc(id,obj)
  obj.owner='DRAMATIC_SKY_RIDE'
  table.insert(world.maps[id].objects,obj)
  return obj.name
 end
 local mod={id='DRAMATIC_SKY_RIDE',world=api,exports={runtimeGeneration={isGen2=function()return gen2 end}},
  content={commands={register=function(_,id,fn)commands[id]=fn end}},
  events={on=function(_,id,fn)events[id]=fn end}}
 local boxes={PARTY_SIZE=6,NUM_BOXES=2,MONS_PER_BOX=20}
 function boxes.isFull(save,i)return #(save.boxes[i] or {})>=20 end
 function boxes.box(save,i)save.boxes[i]=save.boxes[i] or {};return save.boxes[i]end
 local env=setmetatable({mod=mod,Game=game,log=function()end,require=function(id)
  if id=='src.battle.gen2.Mon' then return {
   new=function(_,species,level)return {species=species,level=level,moves={}}end,
   stampOT=function(_,mon)mon.ot='TEST'end}
  elseif id=='src.core.gen2.Boxes' then return boxes end
  error(id)
 end},{__index=_G})
 local file=assert(io.open('src/main_55_gen2_test_gift.lua'));local source=file:read('*a');file:close()
 local fn=assert(loadstring('do end\n'..source));setfenv(fn,env);fn()
 return game,events,commands,world
end
local game,events,commands,world=loadHelper(true)
assert(#game.save.party==0,'boot granted test Pokemon')
events['map.entered']({mapId='VIOLET_CITY'})
assert(#world.maps.NEW_BARK_TOWN.objects==0,'giver spawned outside New Bark')
events['map.entered']({mapId='NEW_BARK_TOWN'})
events['map.entered']({mapId='NEW_BARK_TOWN'})
assert(#world.maps.NEW_BARK_TOWN.objects==1,'missing or duplicated giver')
local npc=world.maps.NEW_BARK_TOWN.objects[1]
assert(npc.x==9 and npc.y==10 and npc.sprite=='SPRITE_SCIENTIST')
assert(#game.save.party==0,'map entry granted test Pokemon')
local talk=assert(commands[npc.scriptKey[2].verb])
talk({});assert(#game.save.party==4)
assert(game.save.party[1].species=='HO_OH' and game.save.party[1].level==50)
assert(game.save.party[1].moves[1].id=='FLY')
talk({});assert(#game.save.party==4,'repeat interaction duplicated gifts')
local g,e,c=loadHelper(false);assert(not next(e) and not next(c),'Gen 1 registered helper')
print('Gen 2 test giver: opt-in interaction, owned Ho-Oh/Fly, no boot gifts, no duplicates, Gen 1 excluded')
