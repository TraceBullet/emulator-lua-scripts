--[[
	Phantasy Star Zero HUD: Adds Meseta and XP/Next Level values to the bottom screen over the start button icon.
--]]

local c_lightLine = "#d6e7f7"
local c_darkLine = "#525263"
local c_background = "#84b5de"

local displayMeseta = 0
local displayExp = 0;
local stepsize = 3;
	
function rollDisplayValue(actual, display)
	stepsize = math.max(3, math.floor(math.abs(actual-display)/30));
	if (display > actual) then
		display = display - stepsize;
	elseif (display < actual) then
		display = display + stepsize;
	end
	
	-- stop rolling health once it's close to the actual value
	if (math.abs(display - actual) < 5) then
		display = actual;
	end;
	return display;
end
	
while (true) do
	--frame around stats
	gui.box(0,168, 99, 200, c_background)
	-- fancy line
	gui.line(0, 169, 91, 169, c_lightLine)
	gui.line(91, 169, 98, 176, c_lightLine)
	gui.line(98, 176, 98, 200, c_lightLine)
	-- more fancy lines
	gui.line(0, 167, 92, 167, c_darkLine)
	gui.line(92, 167, 100, 175, c_darkLine)
	gui.line(100, 175, 100, 200, c_darkLine)
	-- even fancier antialiasing lines
	gui.line(92, 168, 99, 175, "#8491a4")
	gui.line(92, 169, 98, 175, "#c0c2e1")

	-- read some stats from memory
	local meseta = memory.readword(0x22415d0)
	local nextLevel  = memory.readword(0x21a2104)
	local curExp = memory.readword(0x22415c8)
		
	displayMeseta = rollDisplayValue(meseta, displayMeseta)
	displayExp = rollDisplayValue(curExp, displayExp)
	
	gui.text(8,172," $ "..displayMeseta, "yellow")
	gui.text(8,182,"XP "..displayExp.."/"..nextLevel)
	emu.frameadvance()
end