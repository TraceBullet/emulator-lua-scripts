--[[
	Phantasy Star Zero HUD: Adds Meseta and XP/Next Level values to the bottom screen over the start button icon.
--]]

local c_lightLine = "#d6e7f7"
local c_darkLine = "#525263"
local c_background = "#84b5de"

local displayMeseta = 0
local displayExp = 0;
	
function rollDisplayValue(actual, display)
	local stepSize = math.max(3, math.floor(math.abs(actual-display)/30));
	if (display > actual) then
		display = display - stepSize;
	elseif (display < actual) then
		display = display + stepSize;
	end
	
	-- stop rolling health once it's close to the actual value
	if (math.abs(display - actual) < stepSize) then
		display = actual;
	end;
	return display;
end

accumulateTimer = 120;
prevExp = 0;
prevMeseta = 0;
expTimer = accumulateTimer;
mesetaTimer = accumulateTimer;

function drawExp()
	-- read some stats from memory
	local nextLevel  = memory.readword(0x21a2104)
	local curExp = memory.readword(0x22415c8)

	-- start the timer if current exp changes
	if (curExp ~= prevExp) then
		expTimer = accumulateTimer;
		prevExp = curExp
	end
	
	-- add a delay before rolling the display exp
	if (expTimer <= 0) then
		displayExp = rollDisplayValue(curExp, displayExp)
	else
		expTimer = expTimer - 1;
	end

	-- print display exp and next level exp
	local expColor = "white";
	local expString = "XP "..string.format("%6d", displayExp).."/"..string.format("%6d", nextLevel);
	local expBgString = "XP "..string.format("%06d", displayExp).."/"..string.format("%06d", nextLevel);
	gui.text(4, 182, expBgString, "gray")
	gui.text(4, 182, expString, expColor)
	
	--show recent change to exp
	local delta = curExp-displayExp;
	if (delta > 0) then
		gui.text(8+string.len(expString)*6, 182, "+"..delta, "cyan")
	end
end

function drawExpNext()
	-- read some stats from memory
	local toNext = memory.readword(0x21a2104)
	local curExp = memory.readword(0x22415c8)

	local nextLevel = toNext - curExp;

	-- start the timer if current exp changes
	if (nextLevel ~= prevExp) then
		expTimer = accumulateTimer;
		prevExp = nextLevel
	end
	
	-- add a delay before rolling the display exp
	if (expTimer <= 0) then
		displayExp = rollDisplayValue(nextLevel, displayExp)
	else
		expTimer = expTimer - 1;
	end

	-- print display exp and next level exp
	local expColor = "white";
	local expString = "Next "..string.format("%6d", displayExp);
	local expBgString = "Next "..string.format("%06d", displayExp);
	gui.text(4, 182, expBgString, "gray")
	gui.text(4, 182, expString, expColor)
	
	--show recent change to exp
	local delta = nextLevel-displayExp
	if (delta > 0) then
		gui.text(8+string.len(expString)*6, 182, math.abs(delta), "red")
	elseif (delta < 0) then
		gui.text(8+string.len(expString)*6, 182, math.abs(delta), "#c39bd3")
	end
end

function drawMeseta()
	-- read some stats from memory
	local meseta = memory.readdword(0x22415d0)

	if (meseta ~= prevMeseta) then
		mesetaTimer = accumulateTimer;
		prevMeseta = meseta;
	end
	
	if (mesetaTimer <= 0) then
		displayMeseta = rollDisplayValue(meseta, displayMeseta)
	else
		mesetaTimer = mesetaTimer - 1;
	end
	
	local mesetaColor = "yellow";
	local mesetaBgString = "$ "..string.format("%06d",displayMeseta);
	local mesetaString = "$ "..string.format("%6d",displayMeseta);
	gui.text(4,172, mesetaBgString, "gray")
	gui.text(4,172, mesetaString, mesetaColor)
		
	local delta = meseta-displayMeseta;
	if (delta > 0) then
		gui.text(4+string.len(mesetaString)*6, 172, "+"..delta, "green")
	elseif (delta < 0) then
		gui.text(4+string.len(mesetaString)*6, 172, delta, "red")
	end
end

local bossTimer = 0
local displayBoss = 0;
local prevBoss = 0;
function drawBossBar()
	-- Enemy shields analyzed!
	--local bossHealth  = memory.readword(0x237b774) -- Mother Trinity
	local bossHealth  = memory.readword(0x237d664) -- Dark Falz
	
	if (prevBoss ~= bossHealth) then
		bossTimer = accumulateTimer;
		prevBoss = bossHealth
	end
	
	if (bossTimer <= 0) then
		displayBoss = rollDisplayValue(bossHealth, displayBoss)
	else
		bossTimer = bossTimer - 1
	end
		
	local barWidth = 160*bossHealth/8600;
	local rollingWidth = 160*displayBoss/8600;
	gui.box(0, -20, 160, -18, "black")
	gui.box(0, -20, rollingWidth, -18, "red")
	gui.box(0, -20, barWidth, -18, "yellow")
	gui.drawtext(0, -22, displayBoss)
	
	local delta =  math.abs(displayBoss-bossHealth);
	if (delta > 0) then
		gui.drawtext(barWidth, -30, delta, "red")
	end
end
	
while (true) do
	--frame around stats
	--blue background
	gui.box(0,168, 96, 200, c_background)
	gui.box(96,173, 101, 200, c_background)
	-- fancy line
	gui.line(0, 169, 94, 169, c_lightLine)
	gui.line(94, 169, 101, 176, c_lightLine)
	gui.line(101, 176, 101, 200, c_lightLine)
	-- more fancy lines
	gui.line(0, 167, 95, 167, c_darkLine)
	gui.line(95, 167, 103, 175, c_darkLine)
	gui.line(102, 175, 102, 200, c_background)
	gui.line(103, 175, 103, 200, c_darkLine)
	-- even fancier antialiasing lines
	gui.line(95, 168, 102, 175, "#8491a4")
	gui.line(95, 169, 101, 175, "#c0c2e1")

	drawBossBar()

	--drawExp()
	drawExpNext()
	drawMeseta()
	
	emu.frameadvance()
end