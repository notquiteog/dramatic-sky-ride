-- Exercise the actual bridge without booting the mount/asset subsystems.
local f=assert(io.open('src/main_63_gen2_free_flight.lua'));local source=f:read('*a');f:close()
local first=assert(source:find('local function installFirstPersonGoldTopBridge()',1,true))
local last=assert(source:find('\nlocal function resetPosition()',first,true))
local bridge=source:sub(first,last-1)..'\nreturn installFirstPersonGoldTopBridge'
local function exercise(nativeSupport,gold)
 local nativeCalls,legacyCalls=0,0
 local provider={supportsGen2World=nativeSupport,onTop=function()nativeCalls=nativeCalls+1;return true end}
 local env={dramaticFirstPerson=provider,type=type,isGold=function()return gold end,
 freeRoam=function()legacyCalls=legacyCalls+1;return false end,liveWorld=function()return {} end}
 local chunk=assert(loadstring(bridge));setfenv(chunk,env);local install=chunk();install();install()
 local result=provider.onTop()
 if nativeSupport or not gold then assert(result and nativeCalls==1 and legacyCalls==0)
 else assert(not result and nativeCalls==0 and legacyCalls==1) end
end
exercise(true,true);exercise(false,true);exercise(true,false);exercise(false,false)
print('Sky Ride camera owner delegation and legacy fallback passed')
