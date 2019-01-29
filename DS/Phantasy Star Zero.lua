--[[
	Phantasy Star Zero HUD: Adds Meseta and XP/Next Level values to the bottom screen over the start button icon.
--]]

while (true) do
	local meseta = memory.readword(0x22415d0)
	local nextLevel  = memory.readword(0x21a2104)
	local curExp = memory.readword(0x22415c8)
	
	--frame around stats
	gui.box(0,169, 85, 200, 0x84b5deff)

	gui.text(8,172," $ "..meseta, "yellow")
	gui.text(8,182,"XP "..curExp.."/"..nextLevel)
	emu.frameadvance()
end