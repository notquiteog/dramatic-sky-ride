return function(mod,S,settings,choices,camera)
 local opt=settings.get
 local P=require('src.core.game3.player')
 local particles={};local clock=0
 mod.exports.groundParticles=function()return particles end
 mod.hooks:wrap('input.step',function(nextFn,g,dt)
  local result=nextFn(g,dt);dt=tonumber(dt)or 1/60
  for i=#particles,1,-1 do local p=particles[i];p.age=p.age+dt;if p.age>=p.life then table.remove(particles,i)end end
  clock=clock+dt
  if S.active and not S.suspended and S.mode=='ground'and P.moving and S.galloping and opt('ground_dust')and clock>.10 then
   clock=0;particles[#particles+1]={x=P.px+8,z=P.py+14,age=0,life=.35}
  end
  if not opt('ground_dust')then particles={}end
  return result
 end)
 local FX=require('src.core.game3.field_effects');local behind=FX.drawBehind
 FX.drawBehind=function(x,y,...)
  behind(x,y,...)
  if camera()then return end
  love.graphics.push('all')
  for _,p in ipairs(particles)do
   local t=p.age/p.life;love.graphics.setColor(.72,.63,.42,(1-t)*.65)
   love.graphics.circle('fill',p.x-x,p.z-y-t*4,1+t*2)
  end
  love.graphics.pop()
 end
 -- Use the engine's regional chrome and imported glyphs. These functions
 -- are also the normal skinning boundary for an optional UI presentation mod.
 local Window,Font
 mod.hooks:wrap('render.hud',function(nextFn,g,v)
  nextFn(g,v)
  local altitude=S.active and S.mode=='fly'and not S.suspended and opt('altitude_display')~='off'
   and(opt('altitude_display')=='always'or(S.altitudeTimer or 0)>0)
  local stamina=S.active and S.mode=='ground'and not S.suspended and opt('ground_hud')and(S.galloping or S.stamina<.999)
  if not S.menu and not altitude and not stamina and(S.noticeTimer or 0)<=0 then return end
  Window=Window or require('src.ui.game3.window');Font=Font or require('src.ui.game3.font')
  local gfx=love.graphics;gfx.push('all')
  local ok,err=pcall(function()
   gfx.origin();gfx.setShader()
   local scale=math.max(1,math.floor(math.min(v.width/240,v.height/160)))
   gfx.translate(math.floor((v.width-240*scale)/2),math.floor((v.height-160*scale)/2));gfx.scale(scale)
   gfx.setColor(1,1,1,1)
   local function panel(x,y,w,h)local t=Window.template(x,y,w,h);Window.fill(t);Window.stdFrame(t)end
   local function text(value,x,y,w)
    Font.draw(tostring(value or ''),x,y,{maxWidth=w or 208,colors=Font.COLOR.NORMAL})
   end
   if not S.menu then
    panel(2,15,26,4)
    text(altitude and('ALT '..math.floor(S.height)..' / 96')or stamina and('GALLOP '..math.floor(S.stamina*100)..'%')or S.notice,20,124,200)
    return
   end
   local rows=choices();local count=math.min(4,math.max(1,#rows));local first=math.max(1,S.cursor-count+1)
   local height=8+count*2;local top=math.floor((20-height)/2)
   panel(2,top,26,height);text('DRAMATIC RIDE',24,top*8+2,192)
   if #rows==0 then text('No healthy Pokemon.',32,top*8+26,176)end
   for i=first,math.min(#rows,first+count-1)do
    local y=top*8+26+(i-first)*16
    if i==S.cursor then Window.cursorPx(24,y)end
    text(rows[i].label,36,y,180)
   end
   text(S.notice~=''and S.notice or'A: mount   B: close',24,(top+height)*8-20,192)
  end)
  gfx.pop();if not ok then error(err,0)end
 end)
end
