local hooks,frames,texts={},{},{};local depth,native=0,0
local function noop()end
love={graphics={push=function()depth=depth+1 end,pop=function()depth=depth-1 end,
 origin=noop,setShader=noop,translate=noop,scale=noop,setColor=noop}}
package.loaded['src.core.game3.player']={}
package.loaded['src.core.game3.field_effects']={drawBehind=noop}
package.loaded['src.ui.game3.window']={template=function(x,y,w,h)return{x=x,y=y,w=w,h=h}end,
 fill=noop,stdFrame=function(t)frames[#frames+1]=t end,cursorPx=noop}
local F={COLOR={NORMAL={}},draw=function(s,x,y,o)texts[#texts+1]={s,x,y,o}end}
package.loaded['src.ui.game3.font']=F
local S={menu=false,noticeTimer=0,cursor=1,notice=''}
local rows={};for i=1,18 do rows[i]={label='Mount '..i}end
local mod={exports={},hooks={wrap=function(_,key,fn)hooks[key]=fn end}}
dofile('lib/gen3/hud.lua')(mod,S,{get=function()return false end},function()return rows end,function()return false end)
local function draw()hooks['render.hud'](function()native=native+1 end,{}, {width=1280,height=720})end
draw();assert(native==1 and #frames==0 and depth==0,'inactive HUD must leave native frame alone')
S.menu=true;S.cursor=18;draw();assert(#frames==1 and depth==0)
assert(texts[2][1]=='Mount 15'and texts[5][1]=='Mount 18','selected mount must remain visible in scroll window')
for _,t in ipairs(texts)do assert(t[3]>=0 and t[3]<160 and t[4].colors==F.COLOR.NORMAL)end
S.menu=false;S.notice='Land first';S.noticeTimer=1;draw();assert(texts[#texts][1]=='Land first')
F.draw=function()error('native font error')end
assert(not pcall(draw)and depth==0,'failed draw must restore graphics state')
print('PASS native Ride HUD delegation, scrolling, idle ownership and graphics cleanup')
