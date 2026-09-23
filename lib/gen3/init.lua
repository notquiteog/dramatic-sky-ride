-- Native FRLG riding. The native player still owns ground movement, Surf,
-- scripts and field events; only airborne movement is replaced.
return function(mod)
 local function loadPart(path)return assert((loadstring or load)(assert(mod:read(path)),'@ride/'..path))()end
 local P=require('src.core.game3.player')
 local Map=require('src.core.game3.map')
 local Collision=require('src.core.game3.collision')
 local Sprites=require('src.core.game3.ow_sprites')
 local Pokemon=require('src.core.game3.pokemon')
 local Moves=require('src.core.game3.field_moves')
 local Compat=require('src.mods.Gen3Compat')
 local Runtime=require('src.core.game3.runtime')
 local Field=require('src.core.game3.field')
 local Space=require('src.core.game3.scripting.space')
 local Objects=require('src.core.game3.objects')
 local Audio=require('src.core.game3.audio')
 local S={active=false,mode=nil,slot=nil,height=0,menu=false,cursor=1,notice='',keys={},boost=0,stamina=1,hints={},last={}}
 local settings=loadPart('lib/gen3/settings.lua')(mod,Pokemon)
 local opt=settings.get
 local delta={up={0,-1},down={0,1},left={-1,0},right={1,0}}
 local opposite={up='down',down='up',left='right',right='left'}
 local cardinal={up='north',down='south',left='west',right='east'}
 local function clamp(n,a,b)return math.max(a,math.min(b,n))end
 local function game()return mod.world.game end
 local function party()local g=game();return g and g.session and g.session.party or {}end
 local function healthy(mon)return mon and not mon.isEgg and not mon.egg and (mon.hp or 0)>0 end
 local function exports(id)local m=mod.find and mod.find(id);return m and m.exports end
 local visual=loadPart('lib/gen3/visuals.lua')(mod,S,settings,Pokemon,Sprites,party)
 local function camera()
  for _,id in ipairs({'BATTLE_ART_VOXEL_FORK','DRAMALESS_SHAPE'})do
   local ex=exports(id);local c=ex and ex.gen3Camera
   if c and c.isActive and c.isActive()then return c end
  end
 end
 local function controlsBlocked()
  local g=game();local vm=Space.getVm()
  return not g or g.phase~='field' or Field.locked or Runtime.uiBusy()
   or require('src.core.game3.warp').isBusy()or(vm and vm:isRunning())
 end
 local function tell(text)
  S.notice=text or '';S.noticeTimer=2
 end
 local function feedback(cry)
  if cry and opt('mount_cries')then pcall(Audio.playCry,cry)end
  if not opt('flight_feedback')then return end
  pcall(Audio.playSe,require('src.core.game3.se_ids').SE_M_FLY)
  if love.joystick and love.joystick.getJoysticks then
   for _,j in ipairs(love.joystick.getJoysticks())do if j.setVibration then pcall(j.setVibration,j,.12,.20,.12)end end
  end
 end
 local function landable(x,y)
  return Collision.isWalkable(x,y)and not Collision.isWater(x,y)
   and not Collision.warpAt(x,y)and not Objects.blocks(x,y)
 end
 local function safePosition()return {map=Map.current,x=P.cellX,y=P.cellY,facing=P.facing}end
 local function activeEvent(def,x,y)
  if not opt('story_gates')then return false end
  local events=def and def.coordEvents
  if not events then local ev=Space.bundle and Space.bundle.events and Space.bundle.events[Map.current];events=ev and ev.coordEvents end
  for _,ev in ipairs(events or {})do if ev.x==x and ev.y==y and ev.scriptKey then
   if not tonumber(ev.var)or require('src.core.game3.scripting.flags').getVar(Space.store,nil,tonumber(ev.var))==(tonumber(ev.value)or 0)then return true end
  end end
  return false
 end
 local reached,overrides=nil,{}
 local function reachedMaps()
  if not reached then reached=mod.save and mod.save:get('legitimately_reached_maps',{})or{}end
  return reached
 end
 local function markReached(id)
  if not id or reachedMaps()[id]then return false end
  reachedMaps()[id]=true;if mod.save then mod.save:set('legitimately_reached_maps',reached)end;return true
 end
 local function discoveryGated(id,def)
  if overrides[id]~=nil then return overrides[id]end
  return type(id)=='string'and id:match('^FR_')~=nil and def and Moves.isOutdoors(def.mapType)
 end
 local function quiet()
  local g=game();local i=g and g.input;if i then i.state={};i.pressed={};i.pressQueue={}end
 end
 function S.dismount(force)
  if not S.active then return true end
  if S.mode=='fly'and not landable(P.cellX,P.cellY)then
   if not force then tell('Land on clear ground first.');return false,S.notice end
   if S.safe then
    if Map.current~=S.safe.map then
     Map.load(Runtime._mod,game(),S.safe.map,{x=S.safe.x,y=S.safe.y,facing=S.safe.facing})
    else P.reset(S.safe.x,S.safe.y,S.safe.facing)end
   end
  elseif S.mode=='surf'and Collision.isWater(P.cellX,P.cellY)and not force then
   tell('Return to shore before dismounting.');return false,S.notice
  end
  if S.mode=='fly'then P.px=P.cellX*16;P.py=P.cellY*16 end
  S.active=false;S.mode=nil;S.height=0;S.boost=0;S.suspended=false;P.freeFlying=false;P.spriteYOffset=0
  P.moving=false;P.targetX=P.cellX;P.targetY=P.cellY;P.progress=0
  feedback();return true
 end
 function S.mount(slot,mode)
  local g=game();local mon=party()[slot]
  if not opt('gen3_rides')then return false,'Enable riding in OPTIONS.'end
  if controlsBlocked()or Compat.worldBusy()or P.moving then return false,'Finish moving or talking first.'end
  if not healthy(mon)then return false,'Choose a healthy party Pokemon.'end
  if mode~='ground'and mode~='surf'and mode~='fly'then return false,'Unknown mount mode.'end
  local def=Map.currentDef()
  if not Moves.isOutdoors(def and def.mapType)then return false,'Ride outdoors.'end
  if mode=='ground'and P.surfing then return false,'Return to shore before ground riding.'end
  if mode~='ground'then
   local move=mode=='fly'and'FLY'or'SURF'
   if(mode=='surf'or opt('require_fly_move'))and not Moves.partyMoveUser({mon},move)then return false,'This Pokemon must know '..move..'.'end
   if opt('badge_checks')and not Moves.hasBadge({store=Space.store,session=g.session},move)then return false,'Earn the '..move..' field badge first.'end
  end
  if mode=='surf'and not P.surfing then
   local d=delta[P.facing];if not d or not Collision.isWater(P.cellX+d[1],P.cellY+d[2])then return false,'Face the water to surf.'end
  end
  if mode=='fly'and not landable(P.cellX,P.cellY)then return false,'Take off from clear ground.'end
  if S.active then local ok,why=S.dismount();if not ok then return false,why end end
  local gender=g.session and g.session.gender;local gid=(gender=='female'or gender=='F'or gender==1)and 7 or 0
  if not visual.resolve(visual.localId(mon.species,gid))then return false,'Mount sprite unavailable.'end
  markReached(Map.current)
  S.safe=safePosition();S.map=Map.current;S.active=true;S.mode=mode;S.slot=slot;S.species=mon.species;S.riderGid=gid
  S.stamina=1;S.boost=0;S.last[mode]=slot;S.altitudeTimer=2;P.biking=false
  if mode=='surf'and not P.surfing then P.startSurfing(g)end
  if mode=='fly'then P.freeFlying=true;P.surfing=false;S.height=opt('gen3_flight_height');P.spriteYOffset=-S.height end
  if opt('mount_hints')and not S.hints[mode]then
   S.hints[mode]=true;tell(mode=='fly'and'H: land  Page Up/Down: altitude  B: boost'or mode=='ground'and'G: dismount  B: gallop'or'Return to shore to dismount')
  end
  feedback(mon.species);return true
 end
 function S.show()
  if controlsBlocked()or Compat.worldBusy()or P.moving then return false end
  S.menu=true;S.cursor=1;S.notice='';quiet();return true
 end
 function S.shortcut(mode)
  if not opt('mount_shortcut')then return false end
  if controlsBlocked()then return false end
  if S.active and S.mode==mode then local ok,why=S.dismount();if why then tell(why)end;return ok end
  local preferred=S.last[mode];local why
  if preferred then local ok;ok,why=S.mount(preferred,mode);if ok then return true end end
  for i in ipairs(party())do if i~=preferred then local ok;ok,why=S.mount(i,mode);if ok then return true end end end
  tell(why or 'No available mount.');return false
 end
 local function held(input,key)return input and input.isDown and input:isDown(key)end
 local function crossConnection(dir)
  local g=game();local def=Map.currentDef();local conn=def and def.connections and(def.connections[dir]or def.connections[cardinal[dir]])
  local dest=conn and(conn.map or conn.mapId);local target=g.data and g.data.maps and g.data.maps[dest]
  if not target or not Moves.isOutdoors(target.mapType)then return false end
  if opt('discovery_gates')and discoveryGated(dest,target)and not reachedMaps()[dest]then tell('AREA NOT VISITED');return false end
  Map.ensureMidLayout(g,dest,target)
  local x,y=Collision.connectionLanding(target,conn,dir,P.cellX,P.cellY)
  if not x then return false end
  -- Preserve native connection barriers when story gates are enabled. Native
  -- crossing validates permissions/ghost barriers before changing the map.
  if opt('story_gates')then
   if not Collision.tryConnection(g,P.cellX,P.cellY,dir,false)then tell('ROUTE BLOCKED');return false end
   P.reset(x,y,dir)
  else Map.load(Runtime._mod,g,dest,{x=x,y=y,facing=dir,seamless=true,depth1Connections=true})end
  S.map=Map.current;P.freeFlying=true;P.surfing=false;P.spriteYOffset=-S.height
  if landable(P.cellX,P.cellY)then S.safe=safePosition()end
  return true
 end
 local function movement(input)
  local x=(held(input,'right')and 1 or 0)-(held(input,'left')and 1 or 0)
  local z=(held(input,'down')and 1 or 0)-(held(input,'up')and 1 or 0)
  local c=camera()
  if c and c.moveVector then x,z=c.moveVector(-z,x)end
  local len=math.sqrt(x*x+z*z);if len>1 then x,z=x/len,z/len end
  return x,z,c
 end
 local nativeUpdate=P.update
 P.update=function(g,input)
  if not S.active or S.suspended then return nativeUpdate(g,input)end
  if S.mode=='fly'and(S.menu or controlsBlocked())then P.moving=false;return end
  local dt=1/60
  local pressedB=held(input,'b')
  if S.mode~='fly'then
   nativeUpdate(g,S.menu and nil or input)
   if controlsBlocked()then return end
   local gallop=S.mode=='ground'and opt('ground_gallop')and pressedB and P.moving and S.stamina>0 and not S.exhausted
   S.stamina=clamp(S.stamina+(gallop and -.25 or .20)*dt,0,1)
   if S.stamina==0 then S.exhausted=true elseif S.stamina>.25 then S.exhausted=false end
   S.galloping=gallop
   local target=gallop and 1 or 0;S.boost=S.boost+clamp(target-S.boost,-5*dt,3.5*dt)
   if P.moving and not P.jumping then P.stepFrames=opt('gen3_ride_speed')/(clamp(opt('ground_speed'),50,200)/100*(1+.4*S.boost))end
   return
  end
  local x,z,c=movement(input);local moving=x~=0 or z~=0
  local target=opt('flight_boost')and pressedB and moving and 1 or 0
  S.boost=S.boost+clamp(target-S.boost,-5*dt,3.5*dt)
  local vertical=0
  if opt('manual_altitude')then vertical=(S.keys.pageup and 1 or 0)-(S.keys.pagedown and 1 or 0)+(S.triggerUp or 0)-(S.triggerDown or 0)end
  if vertical==0 and c and opt('camera_altitude')and math.abs(c.pitch or 0)>.12 then vertical=clamp(-(c.pitch or 0)*2,-1,1)end
  if vertical~=0 then
   local rate=({slow=24,normal=48,fast=72})[opt('vertical_speed')]or 48
   S.height=clamp(S.height+vertical*rate*dt,20,96);S.altitudeTimer=2
  end
  P.moving=moving
  if moving then
   local speed=16/opt('gen3_ride_speed')*clamp(opt('flight_speed'),50,200)/100*(1+S.boost)
   local nx,ny=P.px+x*speed,P.py+z*speed
   local def=Map.currentDef();local layout=def and def.midLayout
   local w,h=(layout and layout.width or def.width)*16,(layout and layout.height or def.height)*16
   local dir=math.abs(x)>math.abs(z)and(x<0 and'left'or'right')or(z<0 and'up'or'down')
   P.facing=dir
   local edge=nx<0 and'left'or nx>w-16 and'right'or ny<0 and'up'or ny>h-16 and'down'
   if edge and crossConnection(edge)then return end
   nx,ny=clamp(nx,0,w-16),clamp(ny,0,h-16)
   local cx,cy=math.floor((nx+8)/16),math.floor((ny+8)/16)
   if not(opt('story_safe')and Objects.blocks(cx,cy))and not activeEvent(def,cx,cy)then
    P.px,P.py=nx,ny;P.cellX,P.cellY=cx,cy
   else P.moving=false;tell('QUEST ROUTE BLOCKED')end
   P.animClock=(P.animClock or 0)+1;P.stepFrames=16
   if c and opt('camera_follow')then
    local yaw=math.atan2(x,-z);local diff=(yaw-(c.yaw or 0)+math.pi)%(math.pi*2)-math.pi
    c.yaw=(c.yaw or 0)+diff*math.min(1,3*dt)
   end
  end
  P.spriteYOffset=-S.height
  if landable(P.cellX,P.cellY)then S.safe=safePosition()end
 end
 -- Native ledge identity and landing collision are both retained. Reverse
 -- jumps apply only to authenticated low ledges, never arbitrary solid tiles.
 local nativeLedge=Collision.ledgeLanding
 Collision.ledgeLanding=function(g,x,y,dir)
  local tx,ty=nativeLedge(g,x,y,dir);if tx then return tx,ty end
  if not(S.active and S.mode=='ground'and opt('reverse_ledge_jumps'))then return end
  local d=delta[dir];if not d then return end
  local permissions=require('src.world.gen2.Permissions')
  local faces=permissions.ledgeFacings(Collision.cell(x+d[1],y+d[2]))
  if faces and faces[opposite[dir]]and Collision.canEnter(g,x+d[1]*2,y+d[2]*2,{})then return x+d[1]*2,y+d[2]*2 end
 end
 local sync=P.syncSavePosition
 P.syncSavePosition=function(g)
  if S.active and S.mode=='fly'and S.safe and g then
   for _,save in pairs({g.session,g.save})do
    save.map=S.safe.map;save.x=S.safe.x;save.y=S.safe.y;save.facing=S.safe.facing
    if save.position then save.position.map=S.safe.map;save.position.x=S.safe.x;save.position.y=S.safe.y;save.position.facing=S.safe.facing end
   end
   return
  end
  return sync(g)
 end
 -- Keep the 2D rider in view at high altitude; the voxel provider follows the
 -- exported height itself and owns its camera without this native pan.
 local View=require('src.core.game3.field_view');local draw=View.draw
 View.draw=function(g,w,h,opts)
  if not(S.active and S.mode=='fly'and not S.suspended)or camera()then return draw(g,w,h,opts)end
  local old=View.cameraPanY or 0;View.cameraPanY=old-S.height*.6
  local ok,res=pcall(draw,g,w,h,opts);View.cameraPanY=old;if not ok then error(res,0)end;return res
 end
 local function choices()
  if S.active then return {{label='DISMOUNT',act=function()return S.dismount()end}}end
  local rows={}
  for i,mon in ipairs(party())do if healthy(mon)then
   for _,mode in ipairs({'ground','surf','fly'})do
    local slot,kind=i,mode
    if mode=='ground'or(mode=='fly'and not opt('require_fly_move'))or Moves.partyMoveUser({mon},mode=='fly'and'FLY'or'SURF')then
     rows[#rows+1]={label=Pokemon.name(mon.species)..' / '..mode:upper(),act=function()return S.mount(slot,kind)end}
    end
   end
  end end
  return rows
 end
 mod.hooks:wrap('ui.start_menu.items',function(nextFn,g,items)
  local rows=nextFn(g,items)or items
  if opt('mount_menu')then rows[#rows+1]={label='RIDE',onSelect=function()require('src.ui.game3.start_menu').close();S.show()end}end
  return rows
 end)
 local function menuKey(key)
  local rows=choices()
  if key=='escape'or key=='x'then S.menu=false;quiet()
  elseif #rows>0 and key=='up'then S.cursor=(S.cursor-2)%#rows+1
  elseif #rows>0 and key=='down'then S.cursor=S.cursor%#rows+1
  elseif #rows>0 and(key=='return'or key=='z')then
   S.cursor=math.min(S.cursor,#rows);S.menu=false;local ok,why=rows[S.cursor].act();tell(why);S.menu=not ok;quiet()
  end
 end
 mod.hooks:wrap('input.key',function(nextFn,g,ev)
  if ev then
   if ev.key=='pageup'or ev.key=='pagedown'then S.keys[ev.key]=ev.phase=='pressed';if S.active and S.mode=='fly'then return end end
   if ev.phase=='pressed'then
    if ev.key=='f7'then if S.menu then S.menu=false;quiet()else S.show()end;return end
    if S.menu then menuKey(ev.key);return end
    if opt('mount_shortcut')and(ev.key=='h'or ev.key=='g')then S.shortcut(ev.key=='h'and'fly'or'ground');return end
   end
  end
  return nextFn(g,ev)
 end)
 mod.hooks:wrap('input.gamepad',function(nextFn,g,ev)
  if ev and ev.phase=='axis'then
   if ev.axis=='triggerright'then S.triggerUp=(ev.value or 0)>.35 and ev.value or 0 end
   if ev.axis=='triggerleft'then S.triggerDown=(ev.value or 0)>.35 and ev.value or 0 end
   if S.active and S.mode=='fly'and(ev.axis=='triggerright'or ev.axis=='triggerleft')then return end
  elseif ev and ev.phase=='pressed'then
   if S.menu then menuKey(({a='return',b='escape',dpup='up',dpdown='down'})[ev.button]);return end
   if opt('mount_shortcut')and(ev.button=='x'or ev.button=='y')then S.shortcut(ev.button=='x'and'fly'or'ground');return end
  end
  return nextFn(g,ev)
 end)
 mod.hooks:wrap('input.step',function(nextFn,g,dt)
  if g.phase~='field'then S.menu=false;S.keys={}end
  dt=tonumber(dt)or 1/60;S.altitudeTimer=math.max(0,(S.altitudeTimer or 0)-dt);S.noticeTimer=math.max(0,(S.noticeTimer or 0)-dt)
  if S.menu then quiet()end
  if S.active then
   local mon=party()[S.slot]
   if not healthy(mon)or mon.species~=S.species or not opt('gen3_rides')then S.dismount(true)
   elseif g.phase=='battle'then
    if not opt('remount_after_battle')then S.dismount(true)else S.suspended=true end
   elseif S.suspended and g.phase=='field'then
    S.suspended=false
    if S.map~=Map.current then S.dismount(true)elseif S.mode=='fly'then P.freeFlying=true;P.spriteYOffset=-S.height end
   elseif S.map~=Map.current then S.dismount(true)end
  end
  nextFn(g,dt)
  if not S.active then if Map.current then markReached(Map.current)end end
  if S.active and S.mode=='surf'and not P.surfing and not P.surfHopping then S.mode='ground'end
  -- Ordinary native SURF also adopts the eligible party mount automatically.
  if not S.active and P.surfing and not P.moving and opt('visible_surf_mounts')and not controlsBlocked()then
   for i,mon in ipairs(party())do if healthy(mon)and Moves.partyMoveUser({mon},'SURF')then S.mount(i,'surf');break end end
  end
 end)
 loadPart('lib/gen3/hud.lua')(mod,S,settings,choices,camera)
 loadPart('lib/gen3/music.lua')(mod,S,settings)
 loadPart('lib/InGameOptions.lua').install(mod,settings.rows,'DRAMATIC RIDE',settings.visible)
 mod.hooks:wrap('save.write',function(nextFn,g)if S.active and S.mode=='fly'then S.dismount(true);P.syncSavePosition(g)end;return nextFn(g)end)
 for _,name in ipairs({'save.loaded','save.created'})do mod.events:on(name,function()reached=nil;S.hints={};S.keys={}end)end
 mod.hooks:wrap('encounter.roll',function(nextFn,...)if S.active and S.mode=='fly'then return nil end;return nextFn(...)end)
 mod.hooks:wrap('core.quit_to_launcher',function(nextFn,...)S.dismount(true);S.menu=false;S.keys={};visual.clear();return nextFn(...)end)
 mod.exports.gen3=S;mod.exports.isMounted=function()return S.active and not S.suspended end
 mod.exports.isFlying=function()return S.active and S.mode=='fly'and not S.suspended end
 mod.exports.isGroundRiding=function()return S.active and S.mode=='ground'and not S.suspended end
 mod.exports.isWaterRiding=function()return S.active and S.mode=='surf'and not S.suspended end
 mod.exports.currentAltitude=function()return S.active and S.mode=='fly'and S.height or 0 end
 mod.exports.resolveGen3Graphics=visual.resolve
 mod.exports.mountVisualScale=visual.size
 mod.exports.gen3Pose=function()return {mounted=S.active,mode=S.mode,height=S.height,slot=S.slot,species=S.species,showRider=opt('show_rider'),scale=S.species and visual.size(S.species)or 1}end
 mod.exports.shouldShowFollowers=function()return not S.active or(S.mode=='ground'and opt('show_followers_while_mounted'))end
 mod.exports.allowAirEncounters=function()return mod.exports.isFlying()and opt('air_encounters')end
 mod.exports.flightRules={discoveryGates=function()return opt('discovery_gates')end,isMapReached=function(id)return reachedMaps()[id]==true end,markMapReached=markReached,
  registerDiscoveryGate=function(id,on)if type(id)~='string'then return false end;overrides[id]=on~=false;return true end,
  clearDiscoveryGateOverride=function(id)overrides[id]=nil end}
 mod.exports.supportsFeature=function(f)return f=='ground_ride'or f=='surf'or f=='flight'or f=='manual_altitude'or f=='mount_sizes'end
 mod.exports.optionSupport={schema=settings.rows,generation=3,retired={'landing_marker','dynamic_shadow'},unavailable={'flight_mount_renderer'}}
 loadPart('lib/gen3/skies.lua')(mod,S,settings,P,Map,controlsBlocked,tell)
 mod.log:info('Native FRLG ground, surf and flight parity runtime loaded')
end
