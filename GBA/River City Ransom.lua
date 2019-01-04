--[[
	River City Ransom EX - Numeric Health
	Displays Stamina and Willpower as numbers, 
	Text colors match the in-game health bar colors

	Developed by @TraceBullet
--]]
	
while (true) do
	--cover up name, we know who we are
	gui.box(0, 0, 40, 15, "black");
	
	-- get color of health bar
	local b,g,r = gui.getpixel(48, 3)
	local stamWhite = bit.lshift( bit.lshift(r, 16) + bit.lshift(g,8) + b, 8) + 0xff;
	local b,g,r = gui.getpixel(48, 5)
	local stamColor = bit.lshift( bit.lshift(r, 16) + bit.lshift(g,8) + b, 8) + 0xff;
	local b,g,r = gui.getpixel(48, 7)
	local stamColorDark = bit.lshift( bit.lshift(r, 16) + bit.lshift(g,8) + b, 8) + 0xff;
	local b,g,r = gui.getpixel(48, 11)
	local willColor = bit.lshift( bit.lshift(r, 16) + bit.lshift(g,8) + b, 8) + 0xff;
	local b,g,r = gui.getpixel(48, 12)
	local willColorDark = bit.lshift( bit.lshift(r, 16) + bit.lshift(g,8) + b, 8) + 0xff;
	
	
	-- show stamina/max stamina/willpower as numeric value
	local stamina = memory.readword(0x200041e)
	local maxStamina = memory.readword(0x2000420)
	local willpower = memory.readword(0x200041c)
	gui.text(10, 1,string.format("%3d", stamina), stamColor, stamColorDark);
	gui.text(24, 1,string.format("/%3d", maxStamina), stamWhite, black);
	gui.text(28, 8,string.format("%3d", willpower), willColor, willColorDark);
	
--[[	--smooth stamina box
	local xOffset = 49;
	local scaleFactor=  4/16;
	gui.box(0+xOffset, 3, maxStamina+xOffset,7, "black", stamColorDark); -- max HP
	gui.box(0+xOffset, 3, stamina+xOffset,7, stamColor, stamColorDark); -- current HP
	gui.box(0+xOffset, 3, maxStamina+xOffset, 3, "white");
	]]--
	--continue emulation
	vba.frameadvance()
end