@LAZYGLOBAL off.

// import dependencies
runoncepath("util/terminal.ks").

local function calcDeltaV {
  parameter isp.
  parameter startingMass.
  parameter endingMass.

  return constant:g0 * isp * ln(startingMass / endingMass).
}

local function calcBurnTime {
  parameter dv. // delta-v
  parameter massParam. // mass
  parameter isp. // specific impulse
  parameter mt. // maxthrust

  local e is constant:e.
  local g is constant:g0. // gravitational acceleration constant (m/s^2)
  local m is massParam * 1000. // mass (kg)
  local p is isp. // specific impulse (s)
  local f is mt * 1000. // engine thrust (kg * m/s^2)
  
  return (g * m * p * (1 - e^(-dv / (g * p)))) / f.
}

local function calcTwoStageBurnTime {
  parameter dv. // delta-v

  local burnTime is 0.
  local remainingDv is 0.

  local engList is list().
  list engines in engList.

  for e in engList {
    if e:stage = stage:number {
      local res is stage:resourceslex.
      local endingMass is ship:mass - ((res:liquidfuel:amount / 200) + (res:oxidizer:amount / 200)).
      local firstStageDv is calcDeltaV(e:isp, ship:mass, endingMass).

      if firstStageDv > dv {
        return calcBurnTime(dv, ship:mass, e:isp, e:maxthrust).
      }

      if stage:nextdecoupler = "None" {
        return -1.
      }

      set burnTime to calcBurnTime(firstStageDv, ship:mass, e:isp, e:maxthrust).
      set remainingDv to dv - firstStageDv.

      break.
    }
  }

  local nextEng is stage:nextdecoupler:parent.
  local nextIsp is nextEng:ispat(ship:q).
  local nextMaxThrust is nextEng:possiblethrustat(ship:q).
  local nextMass is getMassBeforePart(ship:rootpart, stage:nextdecoupler).

  if nextMaxThrust = 0 {
    return 55.
  }

  return burnTime + calcBurnTime(remainingDv, nextMass, nextIsp, nextMaxThrust).
}

local function getMassBeforePart {
  parameter rootPart.
  parameter terminationPart.

  if rootPart = terminationPart {
    return 0.
  }

  local totalMass is 0.

  if not rootPart:children:empty {
    for child in rootPart:children {
      set totalMass to totalMass + getMassBeforePart(child, terminationPart).
    }
  }

  return totalMass + rootPart:mass.
}

local function next {
  set seqIndex to seqIndex + 1.
}

// parameters
parameter targetOrbit is 100000.
parameter targetInclination is 0.

// variables
local burnTime is 0. // calculated burn time to achieve desired orbit
local degreesFromNorth is targetInclination + 90.
local done is false.
local dvPreBurn is 0. // delta-v right before orbital burn
local nd is node(0, 0, 0, 0). // maneuver node
local seqIndex is 0.
local startingAlt is altitude.
local startBurnAt is 0. // number of seconds before eta:apoapsis at which to begin orbital burn
local steeringV is heading(0, 90).
local throttleV is 1.

// init
set ship:control:pilotmainthrottle to 0.
lock steering to steeringV.
lock throttle to throttleV.
sas off.

clearscreen.
logt().
logt("launch.ks", false, false, 1).
logt("TARGET ORBIT:           " + targetOrbit).
logt("TARGET INCLINATION:     " + targetInclination, false, false, 2).

// countdown
for i in range(3, 0, 1) {
  logt("Liftoff in " + i, true).
  wait 1.
}

local launchSequence is list(
  {
    if maxthrust > 0 {
      logt("Liftoff", true, true).
      next().
    }
  },
  {
    if altitude > startingAlt + 50 {
      // clear any launch structures before rolling
      logt("Rolling to " + degreesFromNorth + " degrees", false, false, 1).
      set steeringV to heading(degreesFromNorth, 90).
      next().
    }
  },
  {
    if ship:velocity:surface:mag > 100 {
      next().
    }
  },
  {
    local pitch is max(2, 90 * (1 - (altitude / 50000))).
    set steeringV to heading(degreesFromNorth, pitch).
    logt("Pitching over to " + round(pitch) + " degrees", true).

    // acount for apoapsis degrading as rocket coasts through atmosphere
    local adjustedTargetApoapsis is targetOrbit + (ship:q * 20000).

    if apoapsis >= adjustedTargetApoapsis {
      logt("Target apoapsis at cutoff:  " + round(adjustedTargetApoapsis)).
      set throttleV to 0.
      set warp to 1.
      next().
    }
  },
  {
    set steeringV to prograde.

    // setting a maneuver node too low in atmosphere will result in the node being behind the final apoapsis
    if altitude > 60000 {
      set warp to 0.
      wait until kuniverse:timewarp:issettled.

      set nd:eta to eta:apoapsis.
      set nd:prograde to 1000.
      add nd.

      local doneManeuvering is false.
      local adjustedTargetPeriapsis is targetOrbit * 0.99.
      local ti is abs(targetInclination).

      until doneManeuvering {
        local periapsisReached is nd:orbit:periapsis >= adjustedTargetPeriapsis.
        local inclinationReached is nd:orbit:inclination >= ti.

        if not periapsisReached {
          set nd:prograde to nd:prograde + 1.
        }

        if not inclinationReached {
          local dNormal is 0.

          if targetInclination < 0 {
            if nd:orbit:inclination < ti {
              set dNormal to 1.
            } else {
              set dNormal to -1.
            }
          } else {
            if nd:orbit:inclination < ti {
              set dNormal to -1.
            } else {
              set dNormal to 1.
            }
          }

          set nd:normal to nd:normal + dNormal.
        }

        set doneManeuvering to periapsisReached.
      }

      set burnTime to calcTwoStageBurnTime(nd:deltav:mag).
      set startBurnAt to (burnTime / 2) + 2. // start burn a little early

      logt("Orbital insertion delta-v:    " + round(nd:deltav:mag)).
      logt("Orbital insertion burn time:  " + round(burnTime), false, false, 1).

      if altitude < 70000 {
        when altitude > 70000 then {
          if warp > 0 {
            set warp to 0.
            wait until kuniverse:timewarp:issettled.
            set warp to 1.
          }
        }
      }

      set warp to 1.
      next().
    }
  },
  {
    set steeringV to prograde.

    if (nd:eta <= startBurnAt + 60) {
      // 1 minute or less out from burn, get ship into position
      set steeringV to nd:burnvector.
      next().
    }
  },
  {
    local timeUntilBurn is nd:eta - startBurnAt.
    logt("Orbital burn begins in " + round(timeUntilBurn), true, true).

    if (timeUntilBurn <= 10) {
      set warp to 0.
    }

    if (timeUntilBurn <= 0) {
      logt("Begin " + round(burnTime) + "s, " + round(nd:deltav:mag) + "m/s burn to reach orbit", true).
      set dvPreBurn to nd:deltav.
      set throttleV to 1.
      next().
    }
  },
  {
    if ship:maxthrust > 0 {
      local maxAcc is ship:maxthrust / ship:mass.
      local remainingBurnTime is nd:deltav:mag / maxAcc.
      set steeringV to nd:burnvector.
      set throttleV to min(1, remainingBurnTime).

      if vdot(dvPreBurn, nd:deltav) < 0 {
        set done to true.
      } else if nd:deltav:mag < 0.5 {
        wait until vdot(dvPreBurn, nd:deltav) < 0.5.
        set done to true.
      }
    }
  }
).

until done {
  launchSequence[seqIndex]().
  
  if maxthrust = 0 {
    stage.
  }

  wait 0.001.
}

// give everything a moment to settle
wait 2.

logt().
logt("APOAPSIS      " + round(apoapsis)).
logt("PERIAPSIS     " + round(periapsis)).
logt("INCLINATION   " + round(ship:orbit:inclination, 1)).

if apoapsis < 70000 or periapsis < 70000 {
  logt().
  logt("WARNING: Failed to reach orbit").
} else {
  remove nd.
}