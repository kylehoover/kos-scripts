@LAZYGLOBAL off.

local logLineNum is -1.

global function clearLine {
  parameter lineNum.

  print "":padright(terminal:width) at (0, lineNum).
}

global function logt {
  parameter s is " ".
  parameter replace is false.
  parameter clear is false.
  parameter additionalNewLines is 0.

  if not replace {
    set logLineNum to logLineNum + 1.
  }

  if clear {
    clearLine(logLineNum).
  }

  print s at (0, logLineNum).

  if additionalNewLines > 0 {
    set logLineNum to logLineNum + additionalNewLines.
  }
}

global function logtInc {
  parameter inc.
  set logLineNum to logLineNum + inc.
}

global function getNumberInput {
  parameter prompt is "Please enter a number: ".
  parameter lineNum is 0.

  local input is "".

  print prompt at (0, lineNum).

  until false {
    local c is terminal:input:getchar().

    if c = terminal:input:enter {
      break.
    }

    if c = terminal:input:backspace and input:length > 0 {
      set input to input:remove(input:length - 1, 1).
      print input:padright(input:length + 1) at (prompt:length, lineNum).
    }

    local charCode is unchar(c).

    if (charCode >= 48 and charCode <= 57) or (charCode = 45 and input:length = 0) {
      set input to input + c.
      print input at (prompt:length, lineNum).
    }
  }

  return input:tonumber().
}