local _, fPB = ...

local InCombatLockdown = InCombatLockdown

local ShouldAurasBeSecret = C_Secrets and C_Secrets.ShouldAurasBeSecret

local Client = fPB.Client

local Restrictions = {}
fPB.Restrictions = Restrictions

function Restrictions:Active()
  return Client.modern and (InCombatLockdown() or ShouldAurasBeSecret()) or false
end
