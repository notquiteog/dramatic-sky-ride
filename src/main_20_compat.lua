-- alpha.15.3 compatibility guard.
-- Manual Surf is impossible during flight. Automatic water landing does not
-- call either native method below: it enters Surf through setSurfingState(),
-- so that transition remains intact.
do
  if not OverworldState.dramaticSkyRideSurfFlightGuard then
    local nativeUseSurfFieldMove = OverworldState.useSurfFieldMove
    local nativeTrySurf = OverworldState.trySurf

    if type(nativeUseSurfFieldMove) == "function" then
      function OverworldState:useSurfFieldMove(...)
        if flight.active and Game.overworld == self then
          notifyHud("LAND FIRST")
          feedback("blocked")
          return "no_water"
        end
        return nativeUseSurfFieldMove(self, ...)
      end
    end

    if type(nativeTrySurf) == "function" then
      function OverworldState:trySurf(...)
        if flight.active and Game.overworld == self then
          notifyHud("LAND FIRST")
          feedback("blocked")
          return nil
        end
        return nativeTrySurf(self, ...)
      end
    end

    OverworldState.dramaticSkyRideSurfFlightGuard = true
  end
end

log("alpha.15.3 Gen1Recomp 0.1.69+ / Dramatic Shape 1.7+ compatibility loaded")
