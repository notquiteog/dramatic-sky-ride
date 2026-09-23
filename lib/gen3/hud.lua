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
 local font
 mod.hooks:wrap('render.hud',function(nextFn,g,v)
  nextFn(g,v)
  local altitude=S.active and S.mode=='fly'and not S.suspended and opt('altitude_display')~='off'
   and(opt('altitude_display')=='always'or(S.altitudeTimer or 0)>0)
  local stamina=S.active and S.mode=='ground'and not S.suspended and opt('ground_hud')and(S.galloping or S.stamina<.999)
  if not S.menu and not altitude and not stamina and(S.noticeTimer or 0)<=0 then return end
  font=font or love.graphics.newFont(16)
  love.graphics.push('all');love.graphics.setFont(font)
  if not S.menu then
   local x,y=12,v.height-38
   local text=altitude and('ALT '..math.floor(S.height)..' / 96')or stamina and('GALLOP '..math.floor(S.stamina*100)..'%')or S.notice
   love.graphics.setColor(.07,.09,.13,.92);love.graphics.rectangle('fill',x,y,math.min(v.width-24,font:getWidth(text)+20),27,4)
   love.graphics.setColor(1,1,1,1);love.graphics.print(text,x+10,y+4);love.graphics.pop();return
  end
  local rows=choices();local w=math.min(v.width-24,440);local h=math.min(v.height-24,110+#rows*25);local x,y=(v.width-w)/2,(v.height-h)/2
  love.graphics.setColor(.07,.09,.13,.97);love.graphics.rectangle('fill',x,y,w,h,8)
  love.graphics.setColor(1,1,1,1);love.graphics.print('DRAMATIC RIDE',x+16,y+12)
  local count=math.max(1,math.floor((h-100)/25));local first=math.max(1,S.cursor-count+1)
  for i=first,math.min(#rows,first+count-1)do love.graphics.print((i==S.cursor and '> 'or '  ')..rows[i].label,x+16,y+42+(i-first)*25)end
  love.graphics.printf(S.notice~=''and S.notice or(#rows==0 and'No healthy Pokemon.'or'Enter / A: mount   Esc / B: close'),x+16,y+h-40,w-32)
  love.graphics.pop()
 end)
end
