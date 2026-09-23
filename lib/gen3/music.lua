-- User-provided tracks and optional installed music packs remain optional.
-- Audio bytes are consumed in place; native map music is restored on landing.
return function(mod,S,settings)
 local Audio=require('src.core.game3.audio')
 local tracks,choices={},{{'NONE','none'}}
 local function add(row,read)
  if type(row)~='table'or not row.key or not(row.file or row.intro)then return end
  local intro=read(row.file or row.intro);local loop=row.loop and read(row.loop)
  if not intro or(row.loop and not loop)then return end
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
 if fs.getDirectoryItems and fs.read then
  for _,folder in ipairs(fs.getDirectoryItems('mods')or{})do
   local root='mods/'..folder;local raw=fs.read(root..'/manifest.json')
   local id=raw and raw:match('"id"%s*:%s*"([^"]+)"')
   if(id=='Music_FRLG'or id=='Music_HGSS'or id=='Music_LGPE')and mod.find and mod.find(id)then
    local tag=id:sub(7)
    for _,kind in ipairs({{'surf','Surfing'},{'bike','BikeRiding'}})do
     add({key=tag:lower()..'_'..kind[1],label=tag..' - '..kind[1]:upper(),intro='assets/Music_'..kind[2]..'_intro.ogg',loop='assets/Music_'..kind[2]..'_loop.ogg'},function(p)return fs.read(root..'/'..p)end)
    end
   end
  end
 end
 settings.add('flying_music','FLYING MUSIC','choice','none',{choices=choices})
 mod.options:define(settings.rows)
 local playing,source,loopPhase
 local function stop()
  if source then source:stop();source:release();source=nil end
  if playing then playing=nil;Audio.restoreMapSong()end
 end
 local function start(bytes,loop)
  source=love.audio.newSource(fs.newFileData(bytes,'flight.ogg'),'static');source:setLooping(loop);source:play()
 end
 mod.hooks:wrap('input.step',function(nextFn,g,dt)
  local result=nextFn(g,dt)
  local key=S.active and S.mode=='fly'and not S.suspended and settings.get('flying_music')or'none'
  local track=tracks[key]
  if not track then stop()
  elseif playing~=key then
   stop();Audio.playSong(0);playing=key;loopPhase=not track.loop;start(track.intro,loopPhase)
  elseif source and not source:isPlaying()and not loopPhase and track.loop then
   source:release();loopPhase=true;start(track.loop,true)
  end
  return result
 end)
 mod.hooks:wrap('core.quit_to_launcher',function(nextFn,...)stop();return nextFn(...)end)
 mod.exports.flyingMusicTracks=function()
  local out={};for key,t in pairs(tracks)do out[#out+1]={key=key,label=t.label}end;return out
 end
end
