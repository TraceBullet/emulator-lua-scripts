--[[
	Streets of Rage - Floating Lifebars
	For use with Gens Re-Recording -- https://segaretro.org/Gens_Re-Recording
	
	Adds a lifebar underneath each enemy
		> 24 HP = Purple bar 
		> 16 HP = Red bar
		>  8 HP = Yellow bar
		>  0 HP = Green bar
]]--
gui.register(function()
	-- Get the screen X position	
	scroll_x = memory.readword(0xffe002)
	
	-- Look at all enemy slots
	for n=0,16 do
		offset = 0x80*n;
		
		-- Read enemy's health and absolute position
		ehp = memory.readbytesigned(offset + 0xffb933)
		ex = memory.readword(offset + 0xffb910)
		ez = memory.readword(offset + 0xffb914)
		
		-- Subtract scroll position from enemy absolute position to get screen position
		e_sx = ex - scroll_x;
	
	   -- Draw stacked health bars
		if (ehp > 0) then
			dispHp = math.min(ehp, 8)
			gui.box(e_sx-8*3, ez/2+162, e_sx+8*3, ez/2+164, "black")
			gui.box(e_sx-dispHp*3, ez/2+162, e_sx+dispHp*3, ez/2+164, "#00ff00", "#00cc00")
		end	
		if(ehp-8 > 0) then
			dispHp = math.min(ehp-8, 8)
			gui.box(e_sx-dispHp*3, ez/2+162, e_sx+dispHp*3, ez/2+164, "#ffff00", "#cccc00")
		end	
		if(ehp-16 > 0) then
			dispHp = math.min(ehp-16, 8)
			gui.box(e_sx-dispHp*3, ez/2+162, e_sx+dispHp*3, ez/2+164, "#ff0000", "#cc0000")
		end	
		if(ehp-24 > 0) then
			dispHp = ehp-24
			gui.box(e_sx-dispHp*3, ez/2+162, e_sx+dispHp*3, ez/2+164, "#ff00ff", "#cc00cc")
		end	
	end
end)
-- grunts 4 hp, die when hp < 0