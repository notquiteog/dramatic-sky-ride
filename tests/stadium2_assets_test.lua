local calls={cacheRead=0,cacheInfo=0,ownRead=0,ownInfo=0}
local cached,packaged={},{}
local mod={cache={read=function(_,key)calls.cacheRead=calls.cacheRead+1;return cached[key]end,
 info=function(_,key)calls.cacheInfo=calls.cacheInfo+1;if cached[key]then return{type='file',size=#cached[key]}end end},
 read=function(_,path)calls.ownRead=calls.ownRead+1;return packaged[path]end,
 assets={info=function(_,path)calls.ownInfo=calls.ownInfo+1;if packaged[path]then return{type='file',size=#packaged[path]}end end}}
-- Any legacy filesystem use fails this fixture immediately.
love={filesystem=setmetatable({},{__index=function(_,key)error('removed filesystem access: '..key)end})}
local assets=dofile('lib/Stadium2Assets.lua')(mod)
assert(assets.read('stadium2/pack.info')==nil)
assert(calls.cacheRead==1 and calls.ownRead==1)
packaged['assets/stadium2/normal/006.dsm']='packaged DSM4'
assert(assets.read('stadium2/normal/006.dsm')=='packaged DSM4')
assert(assets.info('stadium2/normal/006.dsm').size==13)
cached['stadium2/normal/006.dsm']='cached DSM4'
assert(assets.read('stadium2/normal/006.dsm')=='cached DSM4')
assert(assets.info('stadium2/normal/006.dsm').size==11)
local reads=calls.cacheRead+calls.ownRead
for _,path in ipairs{'crystal_251/stadium2/pack.info','../stadium2/pack.info','stadium2/../secret','stadium2/normal\\006.dsm'}do
 assert(assets.read(path)==nil and assets.info(path)==nil)
end
assert(calls.cacheRead+calls.ownRead==reads,'cross-owner paths must never be retried')
print('PASS Stadium2 public cache/package bytes, metadata, missing files and owner boundary')
-- Missing owner pack must not change the supported public provider hierarchy.
local companion
local env=setmetatable({OPTION_SCHEMA={},ELIGIBLE={CHARIZARD={dex=6}},GROUND_ELIGIBLE={},
 flight={active=true,species='CHARIZARD'},ground={},Game={data={pokemon={}}},
 optionValue=function()return'stadium'end,voxelLevel=function()return 3 end,log=function()end}, {__index=_G})
env.mod={exports={runtimeGeneration={isGen2=function()return true end},stadium3DNative={installed=function()return false end}},options={define=function()end},find=function(_,id)
 if id=='STADIUM2_OVERWORLD_MODELS'then return companion end
end}
setfenv(assert(loadfile('src/main_28_stadium_compat.lua')),env)()
assert(env.mod.exports.flightRendering.effective()=='2d','no owner pack/provider falls back to owned 2D art')
companion={exports={voxelPipelineState={active=true},supportsSpecies=function(species,dex)return species=='CHARIZARD'and dex==6 end}}
assert(env.mod.exports.flightRendering.provider()=='gen2_stadium2_voxel')
assert(env.mod.exports.flightRendering.effective()=='stadium','registered public companion remains renderer owner')
assert(env.mod.exports.stadiumCompatibility.supportsSpecies('CHARIZARD'))
-- Cache deletion refusal (nil/error or false) must not clear runtime state.
local function guardResult(result)
 local cleared=0
 local stub={exports={stadium3DNative={cacheStatus=function()return{compatible=true}end,modelInfo=function()return{animations=1}end,clearCache=function()cleared=cleared+1 end}},
  cache={delete=function(_,key)assert(key=='stadium2/pack.info');return result,'denied'end}}
 local e=setmetatable({mod=stub,log=function()end},{__index=_G})
 setfenv(assert(loadfile('src/main_46a_stadium2_animation_cache_guard.lua')),e)()
 local ok=stub.exports.stadium3DAnimationCacheGuard.invalidateMarker()
 assert(ok==(result==true));assert(cleared==(result==true and 1 or 0))
end
guardResult(nil);guardResult(false);guardResult(true)
print('PASS missing owner pack, public optional renderer and refused cache deletion')
