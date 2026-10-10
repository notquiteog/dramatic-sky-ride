local mapped,reads,clones=0,0,0
love={filesystem={newFileData=function(b)return b end},image={newImageData=function()
 return {mapPixel=function(_,fn)
  local r,g,b,a=fn(0,0,1,.4,0,1);assert(r==g and g==b and r<.83 and a==1,'opaque orange must not become OBJ transparency')
  r,g,b,a=fn(0,0,0,0,0,0);assert(a==0,'transparent padding stays transparent');mapped=mapped+1
 end,clone=function()clones=clones+1;return 'grayscale clone'end}
end}}
local Assets={imageData=function(p)return 'native:'..p end}
local mod={read=function(_,p)reads=reads+1;if p=='assets/hgss/6-normal-6.png'then return 'bytes'end end,assets={path=function(_,p)return 'mod/'..p end}}
local resolve=assert(loadfile('lib/owned_followers.lua'))()(mod,Assets,{data={pokemon={CHARIZARD={dex=6}}}})
local path=assert(resolve('CHARIZARD'));assert(resolve('CHARIZARD')==path and reads==1)
assert(Assets.imageData(path)=='grayscale clone');assert(Assets.imageData(path)=='grayscale clone');assert(mapped==1 and clones==2)
assert(Assets.imageData('native')=='native:native','native assets unchanged')
assert(resolve('MISSING')==nil);assert(resolve('MISSING',{dex=999})==nil)
print('owned_followers_test: cached owned art, native alpha/palette and missing assets passed')
