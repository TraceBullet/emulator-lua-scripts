--[[
	LuaLibra: Enemy HP display for Final Fantasy V Advance
	For use with VBA-ReRecording's Lua Scripting

	Developed by @TraceBullet for the FFV Four Job Fiesta

	Special thanks to samurai goroh for game state flags and enemy positioning:
		http://www.erick.guillen.com.mx/FFV_LUA.htm
		http://www.erick.guillen.com.mx/Codes/GBA%20Final%20Fantasy%20V%20Advance.txt
--]]

-- Solid text colors
borderColor = 0x000000ff;
colorNormal  = "white"
colorHurt 	= "red"
colorHeal 	= "cyan"
colorTotal 	= 0xffcc00ff

-- Transparent HUD colors
t_borderColor = 0x00000080;
t_colorHurt 	= 0xaa000080;
t_colorYellow = 0xffff0080;
colorZeroes  = 0x00000000;

--[[
	Rolls the display value up/down towards the actual value.

	@param actual the actual value to roll towards
	@param display the current display value
	@return new display value
--]]
function rollDisplayValue(actual, display)
	stepsize = math.max(3, math.floor(math.abs(actual-display)/30));
	local returnValue = display;
	if (display > actual) then
		returnValue = display - stepsize; --math.max(3, stepsize);
	elseif (display < actual) then
		returnValue = display + stepsize; --math.max(3, stepsize);
	end

	-- stop rolling health once it's close to the actual value
	if (math.abs(display - actual) < 5) then
		returnValue = actual;
	end;
	return returnValue;
end

--[[
	Display the party's total gil in the corner
	Useful for gil farming or gil-tossing Samurai
--]]
displayGil = 0;
function printGil(x, y)
	local curGil = memory.readdword(0x200e0d4);
	displayGil = rollDisplayValue(curGil, displayGil);

	gui.text(x, y, "$"..string.format("%07d", displayGil), colorZeroes, t_borderColor); -- leading zeroes
	gui.text(x, y, "$"..string.format("%7d", displayGil), colorTotal, borderColor);	-- total
end

-- enemyIndex = value from 1 to 8
function GetEnemyInfo(enemyIndex)
	local enemyInfo = {
		EnemyIndex  = enemyIndex,
		CurrentHP 	= memory.readword(0x201efc0 + 0x94*enemyIndex),
		TotalHP 	= memory.readword(0x201efc2 + 0x94*enemyIndex),
		DisplayHP   = 0,
		PositionY   = bit.lshift(bit.band(memory.readbyte(0x0201FD35 + enemyIndex),0x0F),3) + 1 ,   -- low nibble
        PositionX   = bit.rshift(bit.band(memory.readbyte(0x0201FD35 + enemyIndex),0xF0),1) + 5 ,   -- high nibble
	}
	return enemyInfo
end

-- Updates current and display HP for enemy
function UpdateEnemyInfo(enemyInfo)
	enemyInfo.CurrentHP = memory.readword(0x201efc0 + 0x94*enemyInfo.EnemyIndex)
	enemyInfo.DisplayHP = rollDisplayValue(enemyInfo.CurrentHP, enemyInfo.DisplayHP)
end

-- Converts number into a table of 1's and 0's
local function GetBitFlags(number)
    local bitTable = {}
    local pos = 0

    for i=1,8 do
        bitTable[i] = 0
    end

    while number > 0 do
        pos = pos+1

        bitTable[pos] = number % 2
        number = math.floor(number / 2)
    end

    return bitTable
end

function GetHPColor(current, display)
	local textColor = colorNormal;
	if (current < display) then
		textColor = colorHurt;
	elseif (current > display) then
		textColor = colorHeal;
	end
	return textColor
end

-- Draw HP bar with rolling display values.
function DrawHPBar(x, y, current, total, display)
	local maxWidth = 30;
	local curWidth = maxWidth * (current / total);
	local dispWidth = maxWidth * (display / total);
	gui.box(x, y, x+maxWidth, y+2, t_colorHurt); -- background
	if (curWidth > dispWidth and dispWidth > 0) then -- healing / start battle
		gui.box(x, y, x+curWidth, y+2, "green"); -- scrolling green healing
		gui.box(x, y, x+dispWidth, y+2, colorNormal); -- current HP
	elseif (dispWidth > 0) then -- enemy took damage
		gui.box(x, y, x+dispWidth, y+2, "red"); -- scrolling red damage
		if (curWidth > 0) then
			gui.box(x, y, x+curWidth, y+2, colorNormal); -- current HP
		end
	end
end

local enemy = {}

-- Called when battle starts to initialize enemy table.
function ResetEnemyInfo()
	enemy = {}
	for i = 1,8 do
		enemy[i] = GetEnemyInfo(i);
	end
end

-- Called every frame during battle to update enemy table and display HP values above each enemy
function DrawEnemyInfo()
	for i = 1,8 do
		UpdateEnemyInfo(enemy[i])
		local x = enemy[i].PositionX
		local y = enemy[i].PositionY

		-- flip x position for back attacks
		local backAttack = memory.readbyte(0x2020a50)
		if (backAttack == 1) then
			x = 240 - x
		end

		-- adjust x&y for health bar placement
		x = x - 30
		y = y - 26

		local display = enemy[i].DisplayHP
		local current = enemy[i].CurrentHP
		local total = enemy[i].TotalHP

		local textColor = GetHPColor(current, display)
		local visibleTable = GetBitFlags(memory.readbyte(0x0201FD6E))

		if (display > 0 and total > 0 and visibleTable[9-i] == 1) then
			gui.text(x, y, string.format("%5d", enemy[i].DisplayHP), textColor)
			DrawHPBar(x+21, y+3, current, total, display)
		end
	end
end

framesToWait = 10;
waitTimer = 0;

-- Main loop: draw custom HUD and advance to next frame
while (true) do
	printGil(207, 1);

	--[[
		Check game state and only show HUD during battles
		0x020096E0 - current game state

		05 - Main World
		07 - Menu
		0A - Enemy Fight
		0B - Enemy-in-a-box Fight
		11 - loading battle FX

		source: http://www.erick.guillen.com.mx/Codes/GBA%20Final%20Fantasy%20V%20Advance.txt
	--]]
	local gameState = memory.readbyte(0x20096e0)
	local inBattle = (gameState == 0x0A) or (gameState == 0x0B)

	-- Wait a few frames after battle starts for monster data to load
	if (inBattle) then
		if (waitTimer < framesToWait) then
			waitTimer=waitTimer+1;
		elseif(waitTimer == framesToWait) then
			waitTimer=waitTimer+1;
			ResetEnemyInfo()
		else
			DrawEnemyInfo()
		end
	else
		waitTimer = 0; -- reset for next battle
	end

	--continue emulation
	vba.frameadvance()
end