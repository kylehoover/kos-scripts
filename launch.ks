@LAZYGLOBAL off.

// import dependencies
runoncepath("util/terminal.ks").

local function calcBurnTime {
  parameter dv. // delta-v

  local engList is list().
  list engines in engList.
  local eng is engList[0].
  local e is constant:e.
  local g is constant:g0. // gravitational acceleration constant (m/s^2)
  local m is ship:mass * 1000. // current mass (kg)
  local p is eng:isp. // specific impulse (s)
  local f is eng:maxthrust * 1000. // engine thrust (kg * m/s^2)
  
  return (g * m * p * (1 - e^(-dv / (g * p)))) / f.
}

local function next {
  set seqIndex to seqIndex + 1.
}

// parameters
parameter targetOrbit.

// variables
local burnTime is 0. // calculated burn time to achieve desired orbit
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
logt("TARGET ORBIT:      " + targetOrbit, false, false, 2).

// countdown
for i in range(5, 0, 1) {
  logt("Liftoff in " + i, true).
  wait 1.
}

local launchSequence is list(
  {
    if maxthrust = 0 {
      stage.
    } else {
      logt("Liftoff", true, true).
      next().
    }
  },
  {
    if altitude > startingAlt + 50 {
      // clear any launch structures before rolling
      logt("Rolling to 90 degrees", false, false, 1).
      set steeringV to heading(90, 90).
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
    set steeringV to heading(90, pitch).
    logt("Pitching over to " + round(pitch) + " degrees", true).

    // acount for apoapsis degrading as rocket coasts through atmosphere
    local adjustedTargetApoapsis is targetOrbit + (ship:q * 18000).

    if apoapsis >= adjustedTargetApoapsis {
      set throttleV to 0.
      set warp to 1.
      logt("Coasting").
      next().
    }
  },
  {
    set steeringV to prograde.

    // setting a maneuver node too low in atmosphere will result in the node being behind the final apoapsis
    if altitude > 60000 {
      logt("Adding maneuver node for orbital burn", false, false, 1).
      set warp to 0.
      wait 0.5.

      set nd:eta to eta:apoapsis.
      set nd:prograde to 1000.
      add nd.

      until nd:orbit:periapsis >= targetOrbit {
        set nd:prograde to nd:prograde + 1.
      }

      set burnTime to calcBurnTime(nd:deltav:mag).
      set startBurnAt to (burnTime / 2) + 2. // start burn a little early
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

    if (nd:eta <= startBurnAt) {
      logt("Begin " + round(burnTime) + "s, " + round(nd:deltav:mag) + "m/s burn to reach orbit", true).
      set dvPreBurn to nd:deltav.
      set throttleV to 1.
      next().
    }
  },
  {
    local max_acc is ship:maxthrust / ship:mass.
    local remaining_burn_time is nd:deltav:mag / max_acc.
    set steeringV to nd:burnvector.
    set throttleV to min(1, remaining_burn_time).

    if vdot(dvPreBurn, nd:deltav) < 0 {
      set done to true.
    } else if nd:deltav:mag < 0.5 {
      wait until vdot(dvPreBurn, nd:deltav) < 0.5.
      set done to true.
    }
  }
).

until done {
  launchSequence[seqIndex]().
  wait 0.001.
}

// give everything a moment to settle
wait 2.

logt().
logt("APOAPSIS      " + round(apoapsis)).
logt("PERIAPSIS     " + round(periapsis)).

if apoapsis < 70000 or periapsis < 70000 {
  logt().
  logt("WARNING: Failed to reach orbit").
} else {
  remove nd.
}