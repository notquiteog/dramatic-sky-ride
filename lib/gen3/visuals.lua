-- Composite mount ids encode sender-selected presentation, so a receiver's
-- size/rider preferences never rewrite another player's appearance.
return function(mod,S,settings,Pokemon,Sprites,party)
 local originalGid,originalDraw=Sprites.playerGraphicsId,Sprites.getDraw
 local BASE=830000
 local cache,order={},{}
 local function clamp(n,a,b)return math.max(a,math.min(b,n))end
 local function exports(id)local m=mod.find and mod.find(id);return m and m.exports end
 local function size(species)
  local scale=1
  if settings.get('pokedex_mount_sizes')then
   local entry=require('src.core.game3.pokedex_data').getEntry(species)
   local meters=entry and (tonumber(entry.heightDm)or 0)/10 or 0
   if meters>0 then scale=clamp(meters/1.7,.5,4)end
  end
  local key=Pokemon.keyName(species)or tostring(species)
  return scale*clamp(tonumber(settings.get('mount_size_'..key:lower(),100))or 100,50,200)/100
 end
 local function code(species,gid,scale,show)
  local q=clamp(math.floor(scale*20+.5),5,160)
  return BASE+species*2+(gid==7 and 1 or 0)+(q*2+(show and 0 or 1))*1024
 end
 local function decode(id)
  if type(id)~='number'or id~=id or id%1~=0 or id<BASE+2 or id>BASE+322*1024 then return end
  local n=id-BASE;local presentation=math.floor(n/1024);local base=n%1024;local species=math.floor(base/2)
  if species<1 or species>411 or not Pokemon.keyName(species)then return end
  -- 0.3 ids carried no size field. Retain their 40px mount presentation.
  if presentation==0 then return species,base%2==1 and 7 or 0,1.25,true end
  local q=math.floor(presentation/2);if q<5 or q>160 then return end
  return species,base%2==1 and 7 or 0,q/20,presentation%2==0
 end
 local function composite(id)
  if cache[id]then return id end
  local species,gid,scale,show=decode(id);if not species then return end
  local wilds=exports('overworld_wild_spawns')
  local mountId=wilds and wilds.resolveGen3Sprite and wilds.resolveGen3Sprite(species)
  local mount=mountId and originalDraw(mountId)
  local owned
  if not mount then
   local dex=Pokemon.national(species)
   local bytes=dex and mod:read(('assets/hgss/%d-normal-9.png'):format(dex))
   if bytes then
    owned=love.graphics.newImage(love.filesystem.newFileData(bytes,'mount.png'));owned:setFilter('nearest','nearest')
    local q={};for i=0,8 do q[i]=love.graphics.newQuad(0,i*32,32,32,32,288)end
    mount={image=owned,quads=q,width=32,height=32}
   end
  end
  local pic=not mount and Pokemon.frontPic(species)
  local rider=show and originalDraw(gid)
  if not(mount or pic)or(show and not rider)then return end
  local mw,mh=mount and mount.width or 32,mount and mount.height or 32
  -- Feet stay at the bottom center. Canvas bounds expand with the mount;
  -- neither the mount nor its rider is cropped by a fixed 48x64 rectangle.
  local drawW,drawH=mw*scale,mh*scale
  local width=math.max(32,math.ceil(drawW+8));local height=math.max(40,math.ceil(drawH+28))
  local canvas=love.graphics.newCanvas(width,height*9);canvas:setFilter('nearest','nearest')
  love.graphics.push('all');love.graphics.origin();love.graphics.setShader();love.graphics.setScissor();love.graphics.setDepthMode();love.graphics.setBlendMode('alpha');love.graphics.setCanvas(canvas);love.graphics.clear(0,0,0,0);love.graphics.setColor(1,1,1,1)
  local quads={}
  for frame=0,8 do
   local y=(frame+1)*height
   if mount then love.graphics.draw(mount.image,mount.quads[frame]or mount.quads[0],(width-drawW)/2,y-drawH,0,scale,scale)
   else love.graphics.draw(pic.image,(width-drawW)/2,y-drawH,0,drawW/pic.w,drawH/pic.h)end
   if rider then
    local rs=.65;local seat=drawH*.60
    love.graphics.draw(rider.image,rider.quads[frame]or rider.quads[0],(width-rider.width*rs)/2,y-seat-rider.height*rs,0,rs,rs)
   end
   quads[frame]=love.graphics.newQuad(0,frame*height,width,height,width,height*9)
  end
  love.graphics.pop();if owned then owned:release()end
  cache[id]={image=canvas,quads=quads,width=width,height=height,frameCount=9,inanimate=false}
  order[#order+1]=id
  -- Bound hostile or rapidly changing remote visual variants.
  if #order>32 then local old=table.remove(order,1);if cache[old]then cache[old].image:release();cache[old]=nil end end
  return id
 end
 local function localId(species,gid)return code(species,gid,size(species),settings.get('show_rider'))end
 Sprites.getDraw=function(id)
  if decode(id)then composite(id);return cache[id]end
  return originalDraw(id)
 end
 Sprites.playerGraphicsId=function(g)
  if S.active and not S.suspended and (S.mode~='surf'or settings.get('visible_surf_mounts'))then
   local mon=party()[S.slot]
   if mon then return composite(localId(mon.species,S.riderGid))or originalGid(g)end
  end
  return originalGid(g)
 end
 local function clear()
  for id,v in pairs(cache)do v.image:release();cache[id]=nil end
  order={}
 end
 mod.events:on('mod.options_changed',function(ev)if ev and ev.mod=='overworld_wild_spawns'and ev.key=='sprite_style'then clear()end end)
 return {resolve=composite,localId=localId,size=size,decode=decode,clear=clear}
end
