-- Public merged music records only. A pack may replace Surf/Bike music;
-- unregistered files inside another mod remain that mod's private assets.
return function(mod)
 local registry=mod.content and mod.content.music
 local out={}
 if not(registry and registry.get)then return out end
 for _,kind in ipairs({
  {key='installed_surf',label='Installed - Surf',ids={'Music_Surfing','Music_Surf'}},
  {key='installed_bike',label='Installed - Bike',ids={'Music_BikeRiding','Music_Bicycle'}},
 })do
  for _,id in ipairs(kind.ids)do
   local def=registry:get(id)
   if type(def)=='table'and type(def.file)=='string'and def.file~=''
    and(def.loopFile==nil or type(def.loopFile)=='string'and def.loopFile~='')then
    out[#out+1]={key=kind.key,label=kind.label,songId=id,intro=def.file,loop=def.loopFile}
    break
   end
  end
 end
 return out
end
