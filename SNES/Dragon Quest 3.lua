local currentHp = {}
local displayHp = {}
local maxHp = {}

local maxHpSet = false
local startBattleWaitFrames = 5
local endBattleWaitFrames = 180

--[[
    Rolls the display value up/down towards the actual value.

    @param actual the actual value to roll towards
    @param display the current display value
    @return new display value
--]]
function rollDisplayValue(actual, display)
    if (actual == nil or display == nil) then return 0 end

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

-- Solid text colors
borderColor = 0x000000ff;
colorNormal = "white"
colorHurt   = "red"
colorHeal   = "cyan"
colorTotal  = 0xffcc00ff

-- Draw HP bar with rolling display values.
function DrawHPBar(x, y, current, total, display)
    local maxWidth = 64;
    local curWidth = maxWidth * (current / total);
    local dispWidth = maxWidth * (display / total);

    -- draw bar background
    gui.box(x, y, x+maxWidth, y+2, "black");

    if (curWidth > dispWidth and dispWidth > 0) then
        -- draw green bar when battle starts or when enemy is healed
        gui.box(x, y, x+curWidth, y+2, colorTotal);
        gui.box(x, y, x+dispWidth, y+2, colorNormal);
    elseif (dispWidth > 0) then
        -- draw red bar when enemy is damaged
        gui.box(x, y, x+dispWidth, y+2, colorHurt);
        if (curWidth > 0) then
            gui.box(x, y, x+curWidth, y+2, colorNormal);
        end
    end
end

function DrawHPText(x, y, current, total)
    local color = "gray"
    if (current > 0) then
        color = "white"
    end
    gui.text(x, y, string.format("%04d/%04d", current, total), "gray")
    gui.text(x, y, string.format("%4d/%4d", current, total), color)
end

function DrawDebugText()
    -- Display game states in corner
    gui.text(0,0, "Battle:"..tostring(inBattle), 'Red')
    gui.text(0,8, "maxHpSet:"..tostring(maxHpSet), 'Green')
    gui.text(0,16, "startBattle:"..tostring(startBattleWaitFrames), 'Yellow')	
    gui.text(0,24, "endBattle:"..tostring(endBattleWaitFrames), 'Yellow')	
end

while (true) do
    -- enemy 1 cur hp 
    -- 7e20c4
    -- 7e20e9    
    
    -- Fetch enemy health and store in HP tables
    local inBattle = false;    
    local baseHpAddr = 0x7e20c4;
    for i = 0,7 do
        local slotHpAddr = baseHpAddr + (i*0x25)
        local hp = memory.readword(slotHpAddr)
        
        if (hp > 0) then 
            inBattle = true            
            endBattleWaitFrames = 180
        end        
        
        currentHp[i] = hp
        displayHp[i] = rollDisplayValue(hp, displayHp[i])
        if (not maxHpSet) then
            maxHp[i] = currentHp[i];
        end
    end
    
    if (inBattle or endBattleWaitFrames > 0) then
        if (not inBattle) then endBattleWaitFrames = endBattleWaitFrames - 1 end
        
        -- Wait a few frames since it takes a bit for all enemies to be initialized
        if (startBattleWaitFrames > 0) then 
            startBattleWaitFrames = startBattleWaitFrames - 1           
        else
            maxHpSet = true
        end
        
        -- Draw HP
        for i = 0,7 do
            if (maxHp[i] > 0) then
                DrawHPText(182, 12*i, displayHp[i], maxHp[i])
                DrawHPBar(182, 12*i+8, currentHp[i], maxHp[i], displayHp[i])
            end
        end        
    else
        maxHpSet = false
        startBattleWaitFrames = 5
    end
    
    DrawDebugText()
    
	emu.frameadvance()
end
