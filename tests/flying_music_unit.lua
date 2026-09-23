-- Public music contract and native playback; no mod-directory access allowed.
local n=0
local function check(ok,why)n=n+1;assert(ok,why)end
local public=dofile('lib/RegisteredFlightMusic.lua')
check(#public({})==0,'independent without registry')
local defs={Music_Surfing={address=1,bank=2},Music_Bicycle={file='public/bike.ogg'}}
local registry={get=function(_,id)return defs[id]end}
local rows=public({content={music=registry}})
check(#rows==1 and rows[1].key=='installed_bike','only playable file records and Gen2 alias')
defs.Music_Surfing={file='public/surf-intro.ogg',loopFile='public/surf-loop.ogg'}
defs.Music_BikeRiding={file='public/current-bike.ogg'}
rows=public({content={music=registry}})
check(#rows==2 and rows[1].key=='installed_surf'and rows[2].key=='installed_bike','stable shared keys')
check(rows[1].songId=='Music_Surfing'and rows[1].loop=='public/surf-loop.ogg','owner song identity and loop retained')
check(rows[2].intro=='public/current-bike.ogg','effective primary record precedes alias')
defs.Music_Surfing={file='public/surf.ogg',loopFile=false}
check(#public({content={music=registry}})==1,'invalid loop record unavailable')
defs.Music_Surfing={file='public/surf-intro.ogg',loopFile='public/surf-loop.ogg'}
defs.Music_BikeRiding={file='public/bad.ogg'}
local selected='none';local stopped,restored=0,0;local sources={};local hooks={};local choice
package.loaded['src.core.game3.audio']={playSong=function(id)check(id==0,'native map song muted only for selected track');stopped=stopped+1 end,
 restoreMapSong=function()restored=restored+1 end}
love={filesystem=setmetatable({newFileData=function(bytes,name)return{bytes=bytes,name=name}end},{__index=function(_,k)error('private filesystem access: '..k)end}),audio={newSource=function(input,kind)
 if input=='public/bad.ogg'then error('invalid asset')end
 local src={input=input,kind=kind,playing=false};function src:setLooping(v)self.loop=v end
 function src:play()self.playing=true end;function src:stop()self.playing=false end
 function src:release()self.released=true end;function src:isPlaying()return self.playing end
 sources[#sources+1]=src;return src
end}}
local mod={content={music=registry},exports={},options={define=function()end},hooks={wrap=function(_,key,fn)hooks[key]=fn end}}
function mod:read(path)
 if path=='audio/flying/tracks.lua'then return "return {{key='local',label='Local',file='intro.ogg',loopFile='loop.ogg'}}"end
 if path=='intro.ogg'or path=='loop.ogg'then return 'bytes:'..path end
 local f=assert(io.open(path));local s=f:read('*a');f:close();return s
end
local S={active=true,mode='fly'}
dofile('lib/gen3/music.lua')(mod,S,{rows={},get=function()return selected end,add=function(_,_,_,_,extra)choice=extra.choices end})
check(#choice==4,'local plus two registered tracks exposed')
local function tick()hooks['input.step'](function()end,{},1/60)end
tick();check(#sources==0 and stopped==0,'default none preserves map music')
selected='installed_surf';tick();check(sources[1].input=='public/surf-intro.ogg'and sources[1].kind=='stream'and not sources[1].loop,'public intro streams')
sources[1].playing=false;tick();check(sources[1].released and sources[2].input=='public/surf-loop.ogg'and sources[2].loop,'public loop transition')
S.suspended=true;tick();check(sources[2].released and restored==1,'battle suspension restores native map music')
S.suspended=false;selected='local';tick();check(sources[3].input.bytes=='bytes:intro.ogg'and sources[3].kind=='static','own catalog bytes retained')
sources[3].playing=false;tick();check(sources[4].input.bytes=='bytes:loop.ogg'and sources[4].loop,'catalog loopFile alias')
hooks['core.quit_to_launcher'](function()end);check(sources[4].released and restored==2,'quit releases active audio')
selected='frlg_surf';tick();check(#sources==4,'old private asset key never plays a different public provider')
selected='installed_bike';tick();check(#sources==4 and stopped==2,'invalid public audio fails without silencing native map music')
local count=0;for _,row in ipairs(mod.exports.flyingMusicTracks())do if row.key=='installed_bike'then count=count+1 end end
check(count==0,'failed audio is no longer advertised')
print('flying_music_unit: '..n..' contracts passed')
