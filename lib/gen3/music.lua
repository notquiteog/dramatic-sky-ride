-- User-provided tracks and optional installed music packs remain optional.
-- Audio bytes are consumed in place; native map music is restored on landing.
return function(mod,S,settings)
 local Audio=require('src.core.game3.audio')
 local tracks,choices={},{{'NONE','none'}}
 local function add(row,read)
  if type(row)~='table'or not row.key or not(row.file or row.intro)then return end
  local loopFile=row.loop or row.loopFile or row.loop_file
  local intro=read(row.file or row.intro);local loop=loopFile and read(loopFile)
  if not intro or(loopFile and not loop)then return end
  tracks[row.key]={intro=intro,loop=loop,label=row.label or row.key}
  choices[#choices+1]={row.label or row.key,row.key}
 end
 local catalog=mod:read('audio/flying/tracks.lua')
 if catalog then
  local fn=(loadstring or load)(catalog,'@ride/music-catalog')
  local ok,rows=pcall(fn or function()return{}end)
  if ok and type(rows)=='table'then for _,row in ipairs(rows)do add(row,function(p)return mod:read(p)end)end end
 end
 local fs=love.filesystem
 local public=assert((loadstring or load)(assert(mod:read('lib/RegisteredFlightMusic.lua')),'@ride/registered-music'))()(mod)
 for _,row in ipairs(public)do
  if not tracks[row.key]then
   tracks[row.key]={intro=row.intro,loop=row.loop,label=row.label,publicPath=true}
   choices[#choices+1]={row.label,row.key}
  end
 end
 settings.add('flying_music','FLYING MUSIC','choice','none',{choices=choices})
 mod.options:define(settings.rows)
 local playing,source,loopPhase
 local function stop()
  if source then source:stop();source:release();source=nil end
  if playing then playing=nil;Audio.restoreMapSong()end
 end
 local function start(bytes,loop,publicPath)
  local ok,value=pcall(love.audio.newSource,publicPath and bytes or fs.newFileData(bytes,'flight.ogg'),publicPath and'stream'or'static')
  if not ok then return false end
  source=value;source:setLooping(loop);source:play();return true
 end
 mod.hooks:wrap('input.step',function(nextFn,g,dt)
  local result=nextFn(g,dt)
  local key=S.active and S.mode=='fly'and not S.suspended and settings.get('flying_music')or'none'
  local track=tracks[key]
  if not track then stop()
  elseif playing~=key then
   stop();loopPhase=not track.loop
   if start(track.intro,loopPhase,track.publicPath)then Audio.playSong(0);playing=key else tracks[key]=nil end
  elseif source and not source:isPlaying()and not loopPhase and track.loop then
   source:release();source=nil;loopPhase=true
   if not start(track.loop,true,track.publicPath)then tracks[key]=nil;stop()end
  end
  return result
 end)
 mod.hooks:wrap('core.quit_to_launcher',function(nextFn,...)stop();return nextFn(...)end)
 mod.exports.flyingMusicTracks=function()
  local out={};for key,t in pairs(tracks)do out[#out+1]={key=key,label=t.label}end;return out
 end
end
