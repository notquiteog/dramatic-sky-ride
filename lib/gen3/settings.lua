-- Native Gen3 uses the same persistent setting keys and defaults as GB Ride.
-- The three original Gen3 keys remain valid for existing saved preferences.
return function(mod, Pokemon)
 local rows,defaults={},{}
 local function add(key,label,kind,value,extra)
  local row={key=key,label=label,type=kind,default=value}
  for k,v in pairs(extra or {})do row[k]=v end
  rows[#rows+1]=row;defaults[key]=value
 end
 local function choice(key,label,value,choices)add(key,label,'choice',value,{choices=choices})end
 local function toggle(key,label,value)add(key,label,'toggle',value~=false)end
 local function number(key,label,value,min,max,step)add(key,label,'number',value,{min=min,max=max,step=step})end
 choice('settings_view','SETTINGS VIEW','advanced',{{'SIMPLE','simple'},{'ADVANCED','advanced'}})
 toggle('gen3_rides','RIDING')
 for _,row in ipairs({
  {'show_rider','SHOW RIDER'},{'mount_cries','MOUNT CRIES'},{'mount_hints','MOUNT HINTS'},
  {'mount_menu','MOUNTS MENU'},{'flight_feedback','SOUND & RUMBLE'},
  {'manual_altitude','MANUAL ALTITUDE'},{'flight_boost','FLIGHT BOOST'},
  {'camera_follow','CAMERA FOLLOW'},{'camera_altitude','CAMERA ALTITUDE'},
  {'mount_shortcut','MOUNT SHORTCUT'},{'ground_gallop','GROUND GALLOP'},
  {'ground_hud','GALLOP HUD'},{'ground_dust','GROUND DUST'},
  {'reverse_ledge_jumps','TWO-WAY LEDGES'},{'remount_after_battle','REMOUNT AFTER BATTLE'},
  {'visible_surf_mounts','VISIBLE SURF MOUNTS'},{'require_fly_move','REQUIRE FLY'},
  {'badge_checks','BADGE CHECKS'},{'story_gates','STORY GATES'},
  {'discovery_gates','DISCOVERY GATES'},{'story_safe','QUEST COLLISIONS'},
  {'pokedex_mount_sizes','REALISTIC MOUNT SIZES'},{'air_encounters','AIR ENCOUNTERS'},
 })do toggle(row[1],row[2])end
 toggle('show_followers_while_mounted','GROUND FOLLOWERS',false)
 number('flight_speed','FLIGHT SPEED',100,50,200,10)
 number('ground_speed','GROUND SPEED',100,50,200,10)
 choice('vertical_speed','VERTICAL SPEED','normal',{{'SLOW','slow'},{'NORMAL','normal'},{'FAST','fast'}})
 choice('altitude_display','ALTITUDE DISPLAY','temporary',{{'TEMPORARY','temporary'},{'ALWAYS','always'},{'OFF','off'}})
 choice('gen3_ride_speed','BASE RIDE SPEED',8,{{'WALK',16},{'RUN',8},{'FAST',6}})
 choice('gen3_flight_height','TAKEOFF HEIGHT',36,{{'LOW',24},{'NORMAL',36},{'HIGH',56}})
 choice('size_overrides','SIZE OVERRIDES','hidden',{{'HIDDEN','hidden'},{'EDIT','edit'}})
 local seen={}
 for species=1,411 do
  local name=Pokemon.keyName(species)
  if name and not seen[name]then
   seen[name]=true;number('mount_size_'..name:lower(),'SIZE '..name:gsub('_','-'),100,50,200,5)
  end
 end
 local simple={settings_view=true,gen3_rides=true,show_rider=true,flight_speed=true,ground_speed=true,
  manual_altitude=true,visible_surf_mounts=true,pokedex_mount_sizes=true,mount_hints=true,air_encounters=true,flying_music=true}
 local function get(key,fallback)
  local value=mod.options:get(key)
  if value==nil then value=defaults[key]end
  if value==nil then return fallback end
  return value
 end
 local function visible(row)
  if row.key:match('^mount_size_')then return get('size_overrides')=='edit'and get('settings_view')~='simple'end
  return get('settings_view')~='simple'or simple[row.key]==true
 end
 mod.options:define(rows)
 return {rows=rows,get=get,visible=visible,add=add}
end
