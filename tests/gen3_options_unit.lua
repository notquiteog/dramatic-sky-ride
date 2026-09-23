-- Isolated contract tests; no ROM, game profile, gameplay window or save writes.
-- Run: luajit tests/gen3_options_unit.lua (from mod root).
local function module(name,value)package.loaded[name]=value;return value end
local values,hooks,events,saved={},{},{},{}
local function noop()end
local counts={native=0,cries=0,sounds=0,riderDraws=0}
local graphics={}
for _,k in ipairs({'push','pop','origin','setShader','setScissor','setDepthMode','setBlendMode','setCanvas','clear','setColor'})do graphics[k]=noop end
local function image(w,h)return{setFilter=noop,release=noop,getDimensions=function()return w or 32,h or 288 end}end
graphics.newCanvas=function(w,h)return image(w,h)end;graphics.newImage=function()return image()end
local lastDraws={};graphics.draw=function(...)lastDraws[#lastDraws+1]={...}end
function graphics.newQuad(x,y,w,h,iw,ih)return {x=x,y=y,w=w,h=h,iw=iw,ih=ih}end
love={graphics=graphics,filesystem={newFileData=function(s)return s end,getDirectoryItems=function()return{}end,read=function()end},joystick={getJoysticks=function()return{}end}}
local P=module('src.core.game3.player',{cellX=5,cellY=5,px=80,py=80,facing='down',moving=false,animClock=0})
function P.reset(x,y,f)P.cellX=x;P.cellY=y;P.px=x*16;P.py=y*16;P.facing=f;P.moving=false;P.surfing=false end
function P.update(g,input)counts.native=counts.native+1;P.moving=input and(input:isDown('right')or input:isDown('b'))or false end
P.syncSavePosition=function(g)g.session.map='FR_PALLET_TOWN';g.session.x=P.cellX;g.session.y=P.cellY end
P.startSurfing=function()P.surfing=true end
local mapDef={mapType=1,width=20,height=20,midLayout={width=20,height=20},coordEvents={},connections={}}
local Map=module('src.core.game3.map',{current='FR_PALLET_TOWN',currentDef=function()return mapDef end,ensureMidLayout=noop})
local collision=module('src.core.game3.collision',{isWalkable=function(x,y)return x~=15 and y~=15 end,isWater=function(x,y)return x==15 or y==15 end,warpAt=function()return nil end,ledgeLanding=function()end,canEnter=function()return true end,cell=function()return 7 end,connectionLanding=function()return 1,1 end,tryConnection=function()return false end})
local rider=image(16,32)
local Sprites=module('src.core.game3.ow_sprites',{playerGraphicsId=function()return 0 end,getDraw=function(id)if id==0 or id==7 then return {image=rider,width=16,height=32,quads={[0]={}}}end end})
local Pokemon=module('src.core.game3.pokemon',{name=function()return'CHARIZARD'end,keyName=function(id)return id==6 and'CHARIZARD'or nil end,national=function(id)return id end,frontPic=function()return nil end})
module('src.core.game3.pokedex_data',{getEntry=function()return{heightDm=17}end})
local hasBadge=false
module('src.core.game3.field_moves',{isOutdoors=function()return true end,partyMoveUser=function(p,move)for _,m in ipairs(p[1].moves)do if m==move then return p[1]end end end,hasBadge=function()return hasBadge end})
module('src.mods.Gen3Compat',{worldBusy=function()return false end})
module('src.core.game3.runtime',{uiBusy=function()return false end})
module('src.core.game3.field',{locked=false})
module('src.core.game3.scripting.space',{getVm=function()return nil end,store={}})
module('src.core.game3.scripting.flags',{getVar=function()return 0 end})
local blocked=false;module('src.core.game3.objects',{blocks=function()return blocked end})
module('src.core.game3.audio',{playCry=function()counts.cries=counts.cries+1 end,playSe=function()counts.sounds=counts.sounds+1 end,restoreMapSong=noop,playSong=noop})
module('src.core.game3.se_ids',{SE_M_FLY=151})
module('src.core.game3.warp',{isBusy=function()return false end})
module('src.core.game3.field_view',{draw=noop})
module('src.core.game3.field_effects',{drawBehind=noop})
module('src.world.gen2.Permissions',{ledgeFacings=function()return{down=true}end})
module('src.core.GameVersion',{generation=function()return 3 end})
local Rows=module('src.ui.game3.option_rows',{build=function()return{}end,group=function(rows)return rows end})
module('src.mods.Runtime',{emit=function(name,ev)if name=='mod.options_changed'then values[ev.key]=ev.value end;for _,fn in ipairs(events[name]or{})do fn(ev)end end})
local input={state={}};function input:isDown(k)return self.state[k]==true end
local game={phase='field',input=input,save={options={}},session={gender='male',party={{species=6,hp=100,moves={}}}},mods={modOptions={}},writeOptions=noop,data={maps={FR_PALLET_TOWN=mapDef}}}
local camera={yaw=0,pitch=0,active=false,isActive=function()return false end,moveVector=function(f,r)return r,-f end}
local mod={id='DRAMATIC_SKY_RIDE',world={game=game},exports={},path='.',log={info=noop},find=function(id)if id=='BATTLE_ART_VOXEL_FORK'then return {exports={gen3Camera=camera}}end end}
mod.options={get=function(_,k)return values[k]end,define=function(_,rows)for _,r in ipairs(rows)do if values[r.key]==nil then values[r.key]=r.default end end;return rows end}
mod.hooks={wrap=function(_,key,fn)local previous=hooks[key]or noop;hooks[key]=function(...)return fn(previous,...)end end}
mod.events={on=function(_,key,fn)events[key]=events[key]or{};events[key][#events[key]+1]=fn end}
mod.save={get=function(_,k,f)return saved[k]or f end,set=function(_,k,v)saved[k]=v end}
function mod:read(path)if path:match('^assets/hgss/')then return'fake png'end;local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
assert(loadfile('lib/gen3/init.lua'))()(mod)
local S=mod.exports.gen3
local checks=0;local function check(ok,msg)assert(ok,msg);checks=checks+1 end
local function tick(n)for i=1,n or 1 do P.update(game,input)end end
check(values.show_rider==true and values.settings_view=='advanced','legacy defaults')
check(values.show_followers_while_mounted==false,'follower default')
local ok,why=S.mount(1,'fly');check(not ok and why:find('FLY'),'require-fly gate')
values.require_fly_move=false;ok,why=S.mount(1,'fly');check(not ok and why:find('badge'),'badge gate')
values.badge_checks=false;check(S.mount(1,'fly'),'disabled gates allow mount')
check(counts.cries==1 and counts.sounds>0,'mount cry and feedback')
input.state.right=true;local x=P.px;tick(1);local slow=P.px-x
values.flight_speed=200;x=P.px;tick(1);check(math.abs(P.px-x-slow*2)<.001,'flight percentage changes speed')
input.state.b=true;tick(12);check(S.boost>.5,'boost ramps up')
values.flight_boost=false;tick(15);check(S.boost==0,'disabled boost ramps down')
S.keys.pageup=true;local height=S.height;tick(10);check(S.height>height,'manual height')
values.manual_altitude=false;height=S.height;tick(10);check(S.height==height,'manual height disabled')
S.keys.pageup=false;camera.isActive=function()return true end;camera.pitch=-.5;values.camera_altitude=true;height=S.height;tick(5);check(S.height>height,'camera pitch altitude')
values.camera_altitude=false;height=S.height;tick(5);check(S.height==height,'camera altitude disabled')
camera.isActive=function()return false end;input.state={};P.reset(5,5,'down')
local id=Sprites.playerGraphicsId(game);check(id>830000,'virtual graphic available without Wilds/front sprite')
local first=Sprites.getDraw(id);values.mount_size_charizard=200
local bigId=Sprites.playerGraphicsId(game);local big=Sprites.getDraw(bigId)
check(bigId~=id and big.width>first.width,'size changes actual canvas and wire id')
values.show_rider=false;lastDraws={};local hiddenId=Sprites.playerGraphicsId(game);check(hiddenId~=bigId,'rider preference encoded')
local foundRider=false;for _,call in ipairs(lastDraws)do if call[1]==rider then foundRider=true end end
check(not foundRider,'hidden rider omitted from composite')
values.mount_size_charizard=50;values.show_rider=true
check(mod.exports.resolveGen3Graphics(bigId)==bigId and Sprites.getDraw(bigId).width==big.width,'receiver does not replace peer size with local preference')
check(mod.exports.resolveGen3Graphics(830012)==830012,'old wire id retained')
check(not mod.exports.resolveGen3Graphics(830001),'invalid species rejected')
blocked=true;input.state.right=true;x=P.px;tick();check(P.px==x,'quest collision retained')
values.story_safe=false;tick();check(P.px>x,'quest collision toggle')
blocked=false;values.story_safe=true;input.state={};P.reset(5,5,'down')
check(S.dismount(),'clear ground dismount')
check(S.mount(1,'ground'),'ground mount')
input.state.b=true;tick(20);check(S.stamina<1 and S.boost>0,'gallop consumes stamina')
values.ground_gallop=false;local stamina=S.stamina;tick(10);check(S.stamina>stamina,'disabled gallop regenerates')
local base=P.stepFrames;values.ground_speed=200;tick(10);check(P.stepFrames<base,'ground percentage functional')
check(not mod.exports.shouldShowFollowers(),'ground followers default hidden')
values.show_followers_while_mounted=true;check(mod.exports.shouldShowFollowers(),'ground followers opt-in')
local tx=collision.ledgeLanding(game,5,5,'up');check(tx==5,'reverse ledge enabled')
values.reverse_ledge_jumps=false;check(collision.ledgeLanding(game,5,5,'up')==nil,'reverse ledge disabled')
S.menu=true;game.phase='battle';hooks['input.step'](game,1/60);check(S.suspended and not S.menu,'battle suspension also closes owned mount menu')
game.phase='field';hooks['input.step'](game,1/60);check(not S.suspended and S.active,'battle remount')
values.remount_after_battle=false;game.phase='battle';hooks['input.step'](game,1/60);check(not S.active,'remount off dismounts')
game.phase='field';input.state={};P.reset(5,5,'down');check(S.mount(1,'fly'),'save fixture')
S.safe={map='FR_PALLET_TOWN',x=5,y=5,facing='down'};P.reset(15,15,'down')
hooks['save.write'](game);check(not S.active and P.cellX==5 and game.session.x==5,'pre-serialization safe landing')
-- Native settings page rebuilds in place and does not push duplicate pages.
local built=Rows.build({game=game});local pushes=0;local page
local groups=Rows.group(built,function(_,members)pushes=pushes+1;page=members end)
groups[#groups].activate();local before=#page
page[1].step({game=game},1)
check(pushes==1 and #page<before,'simple view refresh in place')
check(values.mount_size_charizard==50,'hidden size value retained')
print('PASS '..checks..' native Gen3 setting/runtime/network contracts (isolated stubs)')
