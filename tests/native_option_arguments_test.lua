-- API3 dispatches native options through a public hook and registered screen.
package.loaded['src.core.GameVersion']={generation=function()return 3 end}
package.loaded['src.mods.Runtime']={emit=function()end}
local native={id='textSpeed',label='NATIVE TEXT SPEED'}
local marker={};local calls=0;local callbacks={};local screens={}
local mod={id='TEST',options={get=function()end},read=function(_,path)local f=assert(io.open(path));local s=f:read('*a');f:close();return s end,
 content={screens={register=function(_,id,screen)screens[id]=screen end}},hooks={wrap=function(_,key,fn)callbacks[key]=fn end}}
local nativeRows={build=function()end,group=function()end};package.loaded['src.ui.game3.option_rows']=nativeRows
local build,group=nativeRows.build,nativeRows.group
local Adapter=dofile('lib/InGameOptions.lua');Adapter.install(mod,{},'TEST')
local game={options={modOptions={}},mods={modOptions={}}}
local function nextRows(g,base,extra)
 assert(g==game and base[1]==native and extra==marker,'public adapter discarded native page arguments');calls=calls+1;return base
end
local rows=callbacks['ui.options.rows'](nextRows,game,{native},marker)
assert(rows[1]==native and rows[2].id=='TEST:settings')
assert(screens['TEST:options'] and nativeRows.build==build and nativeRows.group==group,'native rows/group must never be patched')
callbacks['core.quit_to_launcher'](function()end)
rows=callbacks['ui.options.rows'](nextRows,game,{native},marker)
assert(#rows==1 and rows[1]==native and calls==2)
print('PASS public options hook preserves native rows/future arguments and registered-screen lifecycle')
