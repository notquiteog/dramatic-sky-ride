-- Native FRLG mounts. Ground/surf retain the native movement and field rules;
-- flight is transient and saves only its last safe landing position.
return function(mod)
 local P=require('src.core.game3.player')
 local Map=require('src.core.game3.map')
 local Collision=require('src.core.game3.collision')
 local Sprites=require('src.core.game3.ow_sprites')
 local Pokemon=require('src.core.game3.pokemon')
 local Moves=require('src.core.game3.field_moves')
 local Compat=require('src.mods.Gen3Compat')
 local Runtime=require('src.core.game3.runtime')
 local S={active=false,mode=nil,slot=nil,height=0,menu=false,cursor=1,notice='',cache={}}
 local delta={up={0,-1},down={0,1},left={-1,0},right={1,0}}
 local function game()return mod.world.game end
 local function party()local g=game();return g and g.session and g.session.party or {}end
 local function healthy(mon)return mon and not mon.isEgg and not mon.egg and (mon.hp or 0)>0 end
 local function exports(id)local m=mod.find and mod.find(id);return m and m.exports end
 local schema=mod.options:define({
  {key='gen3_rides',label='RIDING',type='toggle',default=true},
  {key='gen3_ride_speed',label='RIDE SPEED',type='choice',default=8,choices={{'WALK',16},{'RUN',8},{'FAST',6}}},
  {key='gen3_flight_height',label='FLIGHT HEIGHT',type='choice',default=36,choices={{'LOW',24},{'NORMAL',36},{'HIGH',56}}},
 })
 assert((loadstring or load)(assert(mod:read('lib/InGameOptions.lua')),'@ride/options'))().install(mod,schema,'DRAMATIC RIDE')
 local originalGid,originalDraw=Sprites.playerGraphicsId,Sprites.getDraw
 local BASE=830000
 -- A deterministic id encodes only a species and native trainer graphic. It
 -- lets an optional online provider request the same public mount picture.
 local function composite(species,gid)
  local id=BASE+species*2+(gid==7 and 1 or 0)
  if S.cache[id]then return id end
  local wilds=exports('overworld_wild_spawns')
  local mountId=wilds and wilds.resolveGen3Sprite and wilds.resolveGen3Sprite(species)
  local mount=mountId and originalDraw(mountId)
  local pic=not mount and Pokemon.frontPic(species)
  local rider=originalDraw(gid)
  if not rider or not(mount or pic)then return end
  local canvas=love.graphics.newCanvas(48,64*9);canvas:setFilter('nearest','nearest')
  love.graphics.push('all');love.graphics.origin();love.graphics.setShader();love.graphics.setScissor();love.graphics.setDepthMode();love.graphics.setBlendMode('alpha');love.graphics.setCanvas(canvas);love.graphics.clear(0,0,0,0);love.graphics.setColor(1,1,1,1)
  local quads={}
  for frame=0,8 do
   local y=frame*64
   if mount then
    local q=mount.quads[frame]or mount.quads[0];local scale=math.min(40/mount.width,40/mount.height)
    love.graphics.draw(mount.image,q,24-mount.width*scale/2,y+64-mount.height*scale,0,scale,scale)
   else love.graphics.draw(pic.image,4,y+24,0,40/pic.w,40/pic.h)end
   local q=rider.quads[frame]or rider.quads[0];local scale=.65
   love.graphics.draw(rider.image,q,24-rider.width*scale/2,y+39-rider.height*scale,0,scale,scale)
   quads[frame]=love.graphics.newQuad(0,y,48,64,48,64*9)
  end
  love.graphics.pop()
  S.cache[id]={image=canvas,quads=quads,width=48,height=64,frameCount=9,inanimate=false}
  return id
 end
 function S.resolveGraphics(id)
  if type(id)~='number' or id%1~=0 or id<BASE+2 or id>BASE+2*512+1 then return end
  local code=id-BASE;local species=math.floor(code/2)
  if not Pokemon.name(species)then return end
  return composite(species,code%2==1 and 7 or 0)
 end
 Sprites.getDraw=function(id)
  if S.cache[id]then return S.cache[id]end
  return originalDraw(id)
 end
 Sprites.playerGraphicsId=function(g)
  if S.active then
   local mon=party()[S.slot]
   if mon then return composite(mon.species,S.riderGid)or originalGid(g)end
  end
  return originalGid(g)
 end
 local function landable(x,y)
  return Collision.isWalkable(x,y) and not Collision.isWater(x,y)
   and not Collision.warpAt(x,y) and not require('src.core.game3.objects').blocks(x,y)
 end
 local function safePosition()return {map=Map.current,x=P.cellX,y=P.cellY,facing=P.facing}end
 function S.dismount(force)
  if not S.active then return true end
  if S.mode=='fly' and not landable(P.cellX,P.cellY)then
   if not force then return false,'Land on clear ground first.'end
   if S.safe and Map.current==S.safe.map then P.reset(S.safe.x,S.safe.y,S.safe.facing)end
  elseif S.mode=='surf' and Collision.isWater(P.cellX,P.cellY) and not force then
   return false,'Return to shore before dismounting.'
  end
  if S.mode=='fly'then P.px=P.cellX*16;P.py=P.cellY*16 end
  S.active=false;S.mode=nil;S.height=0;P.freeFlying=false;P.spriteYOffset=0
  P.moving=false;P.targetX=P.cellX;P.targetY=P.cellY;P.progress=0
  return true
 end
 function S.mount(slot,mode)
  local g=game();local mon=party()[slot]
  if not mod.options:get('gen3_rides')then return false,'Enable riding in OPTIONS.'end
  if not g or g.phase~='field' or Compat.worldBusy()or P.moving then return false,'Finish moving or talking first.'end
  if not healthy(mon)then return false,'Choose a healthy party Pokemon.'end
  if mode~='ground'and mode~='surf'and mode~='fly'then return false,'Unknown mount mode.'end
  if S.active then local ok,why=S.dismount();if not ok then return false,why end end
  local def=Map.currentDef()
  if not Moves.isOutdoors(def and def.mapType)then return false,'Ride outdoors.'end
  if mode~='ground'then
   local move=mode=='fly'and'FLY'or'SURF'
   if not Moves.partyMoveUser({mon},move)then return false,'This Pokemon must know '..move..'.'end
   if not Moves.hasBadge({store=require('src.core.game3.scripting.space').store,session=g.session},move)then return false,'Earn the '..move..' field badge first.'end
  end
  if mode=='surf'and not P.surfing then
   local d=delta[P.facing];if not Collision.isWater(P.cellX+d[1],P.cellY+d[2])then return false,'Face the water to surf.'end
  end
  if mode=='fly' and not landable(P.cellX,P.cellY)then return false,'Take off from clear ground.'end
  local gender=g.session and g.session.gender;S.riderGid=(gender=='female'or gender=='F'or gender==1)and 7 or 0;if not composite(mon.species,S.riderGid)then return false,'Mount sprite unavailable.'end
  S.safe=safePosition();S.map=Map.current;S.active=true;S.mode=mode;S.slot=slot;S.species=mon.species
  P.biking=false
  if mode=='surf' and not P.surfing then P.startSurfing(g)end
  if mode=='fly'then P.freeFlying=true;P.surfing=false;S.height=mod.options:get('gen3_flight_height')or 36;P.spriteYOffset=-S.height end
  return true
 end
 local function controlsBlocked()
  local g=game();local field=require("src.core.game3.field");local space=require("src.core.game3.scripting.space")
  return not g or g.phase~="field" or field.locked or Runtime.uiBusy()
   or require("src.core.game3.warp").isBusy() or (space.getVm() and space.getVm():isRunning())
 end
 local nativeUpdate=P.update
 P.update=function(g,input)
  if not S.active or S.mode~='fly'then
   nativeUpdate(g,input)
   if S.active and P.moving and not P.jumping then P.stepFrames=mod.options:get('gen3_ride_speed')or 8 end
   return
  end
  -- Native field processing remains active; only the airborne avatar's
  -- movement is replaced. Do not trigger ground steps, warps or encounters.
  if S.menu or controlsBlocked()then P.moving=false;return end
  local dir
  for _,key in ipairs({'up','down','left','right'})do if input and input:isDown(key)then dir=key;break end end
  P.moving=dir~=nil
  if dir then
   local d=delta[dir];local def=Map.currentDef();local speed=16/(mod.options:get('gen3_ride_speed')or 8)
   local x,y=P.px+d[1]*speed,P.py+d[2]*speed
   local layout=def.midLayout;local w,h=(layout and layout.width or def.width)*16,(layout and layout.height or def.height)*16
   P.px=math.max(0,math.min(w-16,x));P.py=math.max(0,math.min(h-16,y));P.facing=dir
   P.cellX=math.floor((P.px+8)/16);P.cellY=math.floor((P.py+8)/16)
   P.animClock=(P.animClock or 0)+1;P.stepFrames=16
  end
  P.spriteYOffset=-S.height
  if landable(P.cellX,P.cellY)then S.safe=safePosition()end
 end
 local sync=P.syncSavePosition
 P.syncSavePosition=function(g)
  if S.active and S.mode=='fly'and S.safe and g and g.save and g.save.position then
   g.save.position.map=S.safe.map;g.save.position.x=S.safe.x;g.save.position.y=S.safe.y;g.save.position.facing=S.safe.facing;return
  end
  return sync(g)
 end
 local function quiet()
  local g=game();local i=g and g.input;if i then i.state={};i.pressed={};i.pressQueue={}end
 end
 function S.show()
  if Compat.worldBusy() or P.moving then return false end
  S.menu=true;S.cursor=1;S.notice='';quiet();return true
 end
 local function choices()
  if S.active then return {{label='DISMOUNT',act=function()return S.dismount()end}}end
  local rows={}
  for i,mon in ipairs(party())do if healthy(mon)then
   for _,mode in ipairs({'ground','surf','fly'})do
    local slot,kind=i,mode
    if mode=='ground'or Moves.partyMoveUser({mon},mode=='fly'and'FLY'or'SURF')then
     rows[#rows+1]={label=(Pokemon.name(mon.species)or 'Pokemon')..' / '..mode:upper(),act=function()return S.mount(slot,kind)end}
    end
   end
  end end
  return rows
 end
 mod.hooks:wrap('ui.start_menu.items',function(nextFn,g,items)
  local rows=nextFn(g,items)or items;rows[#rows+1]={label='RIDE',onSelect=function()
   require('src.ui.game3.start_menu').close();S.show()
  end};return rows
 end)
 mod.hooks:wrap('input.key',function(nextFn,g,ev)
  if ev and ev.phase=='pressed'then
   if ev.key=='f7'then if S.menu then S.menu=false;quiet()else S.show()end;return end
   if S.menu then
    local rows=choices()
    if ev.key=='escape'or ev.key=='x'then S.menu=false;quiet()
    elseif #rows>0 and ev.key=='up'then S.cursor=(S.cursor-2)%#rows+1
    elseif #rows>0 and ev.key=='down'then S.cursor=S.cursor%#rows+1
    elseif #rows>0 and (ev.key=='return'or ev.key=='z')then
     S.menu=false;local ok,why=rows[S.cursor].act();S.notice=why or '';S.menu=not ok;quiet()
    end
    return
   end
  end
  return nextFn(g,ev)
 end)
 mod.hooks:wrap('input.step',function(nextFn,g,dt)
  if S.menu then quiet()end
  if S.active and (S.map~=Map.current or not healthy(party()[S.slot]) or party()[S.slot].species~=S.species or not mod.options:get('gen3_rides'))then S.dismount(true)end
  nextFn(g,dt)
  if S.active and S.mode=='surf' and not P.surfing and not P.surfHopping then S.mode='ground'end
 end)
 local font
 mod.hooks:wrap('render.hud',function(nextFn,g,v)
  nextFn(g,v);if not S.menu then return end
  font=font or love.graphics.newFont(18);local rows=choices();local w=math.min(v.width-24,440);local h=math.min(v.height-24,110+#rows*25);local x,y=(v.width-w)/2,(v.height-h)/2
  love.graphics.push('all');love.graphics.setFont(font);love.graphics.setColor(.07,.09,.13,.97);love.graphics.rectangle('fill',x,y,w,h,8)
  love.graphics.setColor(1,1,1,1);love.graphics.print('DRAMATIC RIDE',x+16,y+12)
  local first=math.max(1,S.cursor-math.floor((h-100)/25)+1)
  for i=first,math.min(#rows,first+math.floor((h-100)/25))do love.graphics.print((i==S.cursor and '> 'or '  ')..rows[i].label,x+16,y+42+(i-first)*25)end
  love.graphics.printf(S.notice~=''and S.notice or (#rows==0 and 'No healthy Pokemon.'or'Enter: mount   Esc: close'),x+16,y+h-40,w-32)
  love.graphics.pop()
 end)
 mod.events:on('save.writing',function()if S.active and S.mode=='fly'then S.dismount(true)end end)
 mod.hooks:wrap('encounter.roll',function(nextFn,...)if S.active and S.mode=='fly'then return nil end;return nextFn(...)end)
 mod.hooks:wrap('core.quit_to_launcher',function(nextFn,...)S.dismount(true);S.menu=false;return nextFn(...)end)
 mod.exports.gen3=S;mod.exports.isMounted=function()return S.active end
 mod.exports.isFlying=function()return S.active and S.mode=='fly'end
 mod.exports.resolveGen3Graphics=S.resolveGraphics
 mod.exports.gen3Pose=function()return {mounted=S.active,height=S.height,mode=S.mode}end
 mod.exports.supportsFeature=function(f)return f=='ground_ride'or f=='surf'or f=='flight'end
 mod.log:info('Native FRLG ground, surf and flight mounts loaded')
end
