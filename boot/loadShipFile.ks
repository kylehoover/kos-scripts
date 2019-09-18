@LAZYGLOBAL off.

wait until ship:loaded.

// get kOS part and open terminal
local kosPart is ship:partsnamed("kOSMachine1m")[0].
kosPart:getmodule("kOSProcessor"):doevent("open terminal").

// get ship file name and it's path in the archive
local shipFileName is ship:name + ".ks".
local shipFilePath is path("0:/"):combine(shipFileName).

if exists(shipFilePath) {
  // copy ship file to ship volume and run
  copypath(shipFilePath, path()).
  runpath(shipFileName).
} else {
  print "ERROR loadShipFile.ks: " + shipFilePath + " does not exist".
}
