-- API3 party hooks/callbacks expose detached records. Riding keeps the actual
-- party member for health, reorder and battle return; never keep that view as
-- a live mon. There is no portable stable party handle/index in submenu ctx.
local M={}
function M.species(id)return({FARFETCH_D='FARFETCHD',MR__MIME='MR_MIME'})[id]or id end
local function matches(native,snapshot)
 if type(snapshot)~='table'then return native==snapshot end
 if type(native)~='table'then return false end
 for k,v in pairs(snapshot)do
  if type(v)~='function'and not matches(native[k],v)then return false end
 end
 return true
end
function M.resolve(game,record)
 local save=game and(game.session and game.session.party and game.session or game.save);local party=save and save.party
 if type(party)~='table'or type(record)~='table'then return nil,nil,'no party selection'end
 for i,mon in ipairs(party)do if mon==record then return mon,i end end
 local snapshot=record.native
 if type(snapshot)~='table'then return nil,nil,'detached selection has no native diagnostic snapshot'end
 -- Official Gen1/2 PartyMenu exposes its selected index on the live menu.
 -- Validate it against the detached native snapshot, including clone parties.
 local top=game.stack and game.stack.top and game.stack:top()
 local index=top and top.index
 if type(index)=='number'and index%1==0 and party[index]and matches(party[index],snapshot)then return party[index],index end
 local found,slot
 for i,mon in ipairs(party)do if matches(mon,snapshot)then
  if found then return nil,nil,'ambiguous party selection'end
  found,slot=mon,i
 end end
 return found,slot,not found and'party selection changed'or nil
end
return M
