--[[
	Shadowrun SNES HUD
	Adds HP value, Karma, experience to next Karma, and nuyen as HUD elements
]]--

while (true) do
	local r,g,b = gui.getpixel(228, 14)
	local a = math.max(0, math.min(0xff, r*2)); -- alpha effects to match screen fades
	local c_border = bit.lshift( bit.lshift(r, 16) + bit.lshift(g,8) + b, 8) + 0xff;
	
	-- define colors
	local c_nuyen = 0xffcc0000+a;
	local c_karma = 0x0000ff00+a;
	local c_hp = 0xb0300000+a;
	local c_black = a;
		
	--gui.text(200, 42, string.format("%x", c_border, 0xffcc00ff))
	
	if (c_border ~= 0x30ff) then -- show HP when health bar is visible
		-- draw HP
		hp = memory.readbyte(0x7e33de)
		gui.text(240, 16, hp, c_hp, c_black)
	
		-- draw nuyen
		local nuyen = memory.readdword(0x7e3c0d)
		gui.text(10, 18, "Y "..nuyen, c_nuyen)
		gui.text(10, 18, "-", c_nuyen, c_black)
	
		-- draw karma exp bar
		local karmaBarScale = 3;
		local karmaExp = memory.readword(0x7e3c11)
		local karmaProgress = karmaBarScale * (karmaExp % 8) -- 8 exp = 1 karma
		local karma = bit.rshift(karmaExp, 3)
		gui.box(10, 10, 12+8*karmaBarScale, 14, c_black, c_border)
		if (karmaProgress > 0) then
			gui.box(11, 11, 10+karmaProgress, 13, c_karma, c_karma)
		end
		gui.text(13+8*karmaBarScale, 9, karma, c_karma, c_border)
	end
	
	
	
	emu.frameadvance()
end
