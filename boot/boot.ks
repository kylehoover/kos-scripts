@LAZYGLOBAL off.

switch to 0.
runoncepath("/util/terminal.ks").

wait until ship:loaded.

// get kOS part and open terminal
local kosPart is ship:partsnamed("kOSMachine1m")[0].
kosPart:getmodule("kOSProcessor"):doevent("open terminal").

if altitude < 100 {
  // run launch script
  local launchFilePath is path():combine("launch.ks").

  if exists(launchFilePath) {
    clearscreen.
    print "Action: launch vessel".

    local targetOrbit is getNumberInput("Enter target orbit (in meters): ", 2).

    runpath(launchFilePath, targetOrbit).
  } else {
    print "boot.ks ERROR: " + launchFilePath + " does not exist".
  }
}
