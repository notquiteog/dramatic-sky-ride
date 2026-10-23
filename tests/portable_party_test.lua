-- Real official API3 record conversion, then native identity resolution.
local sdk=assert(os.getenv('ENGINE_ROOT'),'set ENGINE_ROOT to official 0.3.96 engine')
package.path=sdk..'/?.lua;'..package.path
local Records=require('src.mods.UnifiedRecords')
local Party=dofile('lib/PortableParty.lua')
local checks=0
local function check(v,m)assert(v,m);checks=checks+1 end
for _,case in ipairs{{1,'FARFETCHD'},{2,'FARFETCH_D'}}do
 local gen,id=unpack(case)
 local a={species=id,level=20,hp=45,stats={hp=60,attack=30},moves={{id='FLY',pp=15}}}
 local b={species=id,level=20,hp=45,stats={hp=60,attack=30},moves={{id='FLY',pp=15}}}
 local menu={index=2};local game={save={party={a,b}},stack={top=function()return menu end}}
 local record=Records.mon(b,gen,{pokemon={[id]={}},moves={FLY={pp=15}}})
 check(record~=b and record.native~=b,'official record detached')
 check(record.species=='FARFETCHD','official canonical species alias')
 local mon,slot=Party.resolve(game,record);check(mon==b and slot==2,'duplicate party resolves actual selected native member')
 menu.index=nil;check(Party.resolve(game,record)==nil,'ambiguous detached records refused')
 b.hp=20;mon,slot=Party.resolve(game,record);check(mon==a and slot==1,'unique snapshot resolves original unchanged member')
 a.hp=19;check(Party.resolve(game,record)==nil,'stale snapshot refused')
 mon,slot=Party.resolve(game,b);check(mon==b and slot==2,'native compatibility identity retained')
 record.hp=100;check(b.hp==20,'detached writes never touch native party')
end
check(Party.species('MR__MIME')=='MR_MIME','Gen2 Mr Mime canonical script ID')
print('portable_party_test: '..checks..' official-record contracts passed')
