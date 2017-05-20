--[[
	LuaLibra: Enemy HP display for Final Fantasy V Advance
	For use with VBA-ReRecording's Lua Scripting

	Developed by @TraceBullet for the FFV Four Job Fiesta
--]]

displayHealth = {-1,-1,-1,-1,-1,-1,-1,-1};
displayGil = {0};
xOffset = 0;

-- Solid text colors
borderColor = 0x000000ff;
colorNormal  = "white"
colorHurt 	= "red"
colorHeal 	= "cyan"
--colorZeroes  = "gray"
colorTotal 	= 0xffcc00ff

-- Transparent HUD colors
t_borderColor = 0x00000080;
-- colorNormal  = 0xffffff80;
t_colorHurt 	= 0xaa000080;
-- colorHeal 	= 0x00ffff80;
 colorZeroes  = 0x00000000;
 --colorZeroes  = 0x80808080;
-- colorTotal 	= 0xffcc0080;
t_colorYellow = 0xffff0080;

--[[
	Rolls the display value up/down towards the actual value.
	Uses tables so I can modify values by reference

	actual: the actual value being displayed
	displayTable: lua table containing the display value
	i: index of the display value 
--]]
function rollDisplayValue(actual, displayTable, i)
	stepsize = math.max(3, math.floor(math.abs(actual-displayTable[i])/30));
	if (displayTable[i] > actual) then
		displayTable[i] = displayTable[i] - stepsize; --math.max(3, stepsize);
	elseif (displayTable[i] < actual) then
		displayTable[i] = displayTable[i] + stepsize; --math.max(3, stepsize);
	end
	
	-- stop rolling health once it's close to the actual value
	if (math.abs(displayTable[i] - actual) < 5) then
		displayTable[i] = actual;
	end;
end

--[[
	Display the party's total gil in the corner
	Useful for gil farming or gil-tossing Samurai
--]]
function printGil()
	curGil = memory.readword(0x200e0d4);
	rollDisplayValue(curGil, displayGil, 1);
	
	gui.text(212, 0, "$"..string.format("%06d", displayGil[1]), colorZeroes, t_borderColor); -- leading zeroes
	gui.text(212, 0, "$"..string.format("%6d", displayGil[1]), colorTotal, borderColor);	-- total
end

function drawHealthBars(resetDisplay)
	aliveCount = 0;
	totalDisplayHealth = 0;
	totalCurHealth = 0;
	totalMaxHealth = 0;
	for i=1,8 do -- standard 8 enemy slots
	--for i=4,7 do -- neo exdeath slots
		curHpAddr = 0x201efc0 + 0x94*i
		maxHpAddr = 0x201efc2 + 0x94*i
		enemyCurHP = memory.readword(curHpAddr);
		enemyMaxHP = memory.readword(maxHpAddr);

		-- rolling health counter
		if (resetDisplay) then
			displayHealth[i] = 0;
		else 
			rollDisplayValue(enemyCurHP, displayHealth, i);
		end
		
		-- update totals
		totalDisplayHealth = totalDisplayHealth+displayHealth[i];
		totalCurHealth = totalCurHealth+enemyCurHP;
		totalMaxHealth = totalMaxHealth+enemyMaxHP;

		if (displayHealth[i] > 0 and enemyMaxHP > 0) then
			-- display individual HP counters in a column with no gaps
			aliveCount = aliveCount+1
			textColor = colorNormal;
			if (enemyCurHP <= 0) then
				textColor = colorHurt;
			elseif (enemyCurHP > displayHealth[i]) then
				textColor = colorHeal;
			end
			
			-- health bar
			maxWidth = 20;
			curWidth = maxWidth * (enemyCurHP / enemyMaxHP);
			dispWidth = maxWidth * (displayHealth[i] / enemyMaxHP);
			gui.box(33+xOffset, 114-8*aliveCount, 33+xOffset+maxWidth, 116-8*aliveCount, t_colorHurt); -- background
			if (curWidth > dispWidth and dispWidth > 0) then -- healing / start battle
				gui.box(33+xOffset, 114-8*aliveCount, 33+xOffset+curWidth, 116-8*aliveCount, "green"); -- scrolling green healing
				gui.box(33+xOffset, 114-8*aliveCount, 33+xOffset+dispWidth, 116-8*aliveCount, colorNormal); -- current HP
			elseif (dispWidth > 0) then -- enemy took damage
				gui.box(33+xOffset, 114-8*aliveCount, 33+xOffset+dispWidth, 116-8*aliveCount, "red"); -- scrolling red damage
				if (curWidth > 0) then
					gui.box(33+xOffset, 114-8*aliveCount, 33+xOffset+curWidth, 116-8*aliveCount, colorNormal); -- current HP
				end
			end

			-- gui.text(x, y, text, fillColor, borderColor);
			gui.text(12+xOffset, 112-8*aliveCount, string.format("%05d", displayHealth[i]), colorZeroes, t_borderColor); -- leading zeroes
			gui.text(12+xOffset, 112-8*aliveCount, string.format("%5d", displayHealth[i]), textColor, borderColor);
			
			-- show actual stats
			--gui.text(60+xOffset, 112-8*aliveCount, string.format("%5d/%5d", enemyCurHP, enemyMaxHP), "gray", "black");
		end
	end

	-- slide HUD in from side of screen
	-- if (totalDisplayHealth > 0 and xOffset < 0) then
		-- xOffset=xOffset+1
	-- elseif (totalDisplayHealth == 0 and xOffset > -40) then
		-- xOffset=xOffset-1;
	-- end
	
	-- just make the HUD vanish once everything is dead
	if (totalDisplayHealth > 0) then
		xOffset = 0;
	else
		xOffset = -40;
	end
	

	-- show sum of HP for all enemies
	gui.text(8+xOffset, 112, string.format("%06d", totalDisplayHealth), colorZeroes, t_borderColor); -- leading zeroes
	gui.text(8+xOffset, 112, string.format("%6d", totalDisplayHealth), colorTotal, borderColor);	-- total

	-- total health bar
	maxWidth = 60;
	curWidth = maxWidth * (totalCurHealth / totalMaxHealth);
	dispWidth = maxWidth * (totalDisplayHealth / totalMaxHealth);
	
	if (curWidth > dispWidth and dispWidth > 0) then -- overall healing / start battle
		gui.box(33+xOffset, 114, 33+xOffset+maxWidth, 116, t_colorHurt); -- background
		gui.box(33+xOffset, 114, 33+xOffset+curWidth, 116, "green"); -- display
		gui.box(33+xOffset, 114, 33+xOffset+dispWidth, 116, colorTotal); -- current
	elseif (dispWidth > 0) then -- overall took damage
		gui.box(33+xOffset, 114, 33+xOffset+maxWidth, 116, t_colorHurt); -- background
		gui.box(33+xOffset, 114, 33+xOffset+dispWidth, 116, "red"); -- display
		
		if (curWidth > 0) then
			gui.box(33+xOffset, 114, 33+xOffset+curWidth, 116, colorTotal); -- current
		end
	end
end

framesToWait = 10;
waitTimer = 0;

while (true) do
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
	gameState = memory.readbyte(0x20096e0)
	inBattle = (gameState == 0x0A) or (gameState == 0x0B)
	
	-- gui.text(10, 10, string.format("battle %s", tostring(inBattle)), "cyan");
	-- gui.text(10, 20, string.format("reset %s", tostring(resetDisplay)), "cyan");
	-- gui.text(10, 30, string.format("wait %s/%s", waitTimer, framesToWait), "cyan");
	
	-- Wait a few frames after battle starts for monster data to load
	if (inBattle) then
		if (waitTimer < framesToWait) then
			waitTimer=waitTimer+1;
		elseif(waitTimer == framesToWait) then
			waitTimer=waitTimer+1;
			drawHealthBars(true);
		else
			drawHealthBars(false);
		end
		
	else
		waitTimer = 0; -- reset for next battle
	end
	printGil();

	--continue emulation
	vba.frameadvance()
end