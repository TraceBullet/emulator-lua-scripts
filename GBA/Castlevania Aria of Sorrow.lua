--[[
	Castlevania: Aria of Sorrow
	
	Add MP value, exp to next level, and current exp to HUD
--]]
levelToTotalExp= 
{
0, 
84, 
204, 
400, 
690, 
1092, 
1624, 
2304, 
3150, 
4180, 
5412, 
6864, 
8554, 
10500, 
12720, 
15232, 
18054, 
21204, 
24700, 
28560, 
32802, 
37444, 
42504, 
48000, 
53950, 
60372, 
67284, 
74704, 
82650, 
91140, 
100192, 
109824, 
120054, 
130900, 
142380, 
154512, 
167314, 
180804, 
195000, 
209920, 
225582, 
242004, 
259204, 
259204, 
296010, 
315652, 
336144, 
357504, 
379750, 
402900, 
426972, 
451984, 
477954, 
504900, 
532840, 
561792, 
591774, 
622804, 
654900, 
688080, 
722362, 
757764, 
794304, 
832000, 
870870, 
910932, 
952204, 
994704, 
1038450, 
1083460, 
1129752, 
1177344, 
1226254, 
1276500, 
1328100, 
1381072, 
1435434, 
1491204, 
1548400, 
1607040, 
1667142, 
1728724, 
1791804, 
1856400, 
1922530, 
1990212, 
2059464, 
2130304, 
2202750, 
2276820, 
2352532, 
2429904, 
2508954, 
2589700, 
2672160, 
2756352, 
2842294, 
2930004, 
3019500
}

countdown = 0;
oldExp = 0;
diff = 0;

function drawExtraHUD()
	exp = memory.readdword(0x201328C);
	currentLevel = memory.readbyte(0x2013279);
	--memory.writeword(0x201328C, 2303);
	if (exp ~= oldExp) then
		countdown = 60*3;
		diff = exp-oldExp;
		oldExp=exp;
	end
	
	toNext = levelToTotalExp[currentLevel+1]-exp;
	gui.text(4, 24, "Next     "..toNext, 0x00aaccff, 0x00000080);
	
	-- exp from killed enemy display
	if (countdown > 0) then
		countdown=countdown-1;
		offset = countdown/5;
		gui.text(32+64-offset, 16, diff, 0x00aaccff, 0x00000080);
	end
	gui.text(32, 16, string.format("%7d", exp), 0xFFFFFFFF, 0x00000080);
	
	--MP display
	currentMP = memory.readword(0x2000406);
	gui.text(88, 10, currentMP, 0x00d008ff, 0xc06010ff);
end

function drawEnemyHealth()
	--health = memory.readword(0x2001304);
	--if (health > 0) then
	--	gui.text(12, 140, health, 0xcc0000cc, 0x110000ff);
	--end
	--
	--health = memory.readword(0x200140c);
	--if (health > 0) then
	--	gui.text(4, 142, health, 0xcc0000cc, 0x110000ff);
	--end	
    --
	--health = memory.readword(0x2001514);
	--if (health > 0) then
	--	gui.text(12, 148, health, 0xcc0000cc, 0x110000ff);
	--end
	--
	--health = memory.readword(0x2001490);
	--if (health > 0) then
	--	gui.text(4, 150, health, 0xcc0000cc, 0x110000ff);
	--end
	
	secondForm = memory.readword(0x2001304);
	firstForm = memory.readword(0x2001490);
	deathHealth = firstForm+secondForm;
	gui.text(4, 150, deathHealth, 0xcc0000cc, 0x110000ff);
	
	--fancy two segment health bar for Death
	leftPart = secondForm/4444 * 256;
	rightPart = firstForm/4444 * 256;
	gui.box(0,158, leftPart, 159, 0xff000080);
	gui.box(0,157, rightPart, 158, 0xcc004080);	
end

while (true) do
	stateByte = memory.readbyte(0x2000064);
	--gui.text(88, 10, stateByte, 0x00d008ff, 0xc06010ff);
	if (stateByte == 1) then
		drawExtraHUD()
	end
	--drawEnemyHealth()
	
	--continue emulation
	vba.frameadvance()	
end