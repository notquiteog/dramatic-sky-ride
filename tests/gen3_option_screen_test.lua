local calls={};local Font={CHAR_SELECTOR_ARROW=1,measure=function(s)return#s*6 end,countChars=function(s)return#s end,truncate=function(s,n)return s:sub(1,n)end,
 draw=function(s,x,y)calls[#calls+1]={s,x,y}end,drawGlyph=function()end}
package.loaded['src.ui.game3.frlg_font']=Font
local frames=0
package.loaded['src.ui.game3.window']={template=function(...)return{...}end,stdFrame=function()frames=frames+1 end}
love={graphics={setColor=function()end,rectangle=function(_,x,y,w,h)assert(x==0 and y==0 and w==240 and h==160)end}}
local menu=dofile('lib/Gen3OptionScreen.lua').decorate({title='DRAMATIC RIDE',items={{label='VERY LONG NATIVE SETTING NAME',right='VERY LONG NATIVE CHOICE'}},index=1,scroll=0})
menu:draw();assert(menu.gbaCanvas and menu.rows==7 and frames==2)
for _,call in ipairs(calls)do assert(call[2]>=0 and call[2]+Font.measure(call[1])<=240,'native text left full GBA canvas')end
assert(calls[2][1]~='VERY LONG NATIVE SETTING NAME','long label is fitted before value column')
assert(calls[2][2]+Font.measure(calls[2][1])<calls[3][2],'label and value columns overlap')
print('PASS registered GBA screen native canvas/font/frames and bounded long columns')
