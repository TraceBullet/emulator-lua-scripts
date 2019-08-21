--------------------------------------------------------------------------------
--
-- Metroid Lua script for FCEUX by Neill Corlett
--
-- With thanks to SnowBro/Kent Hansen, whose work made this a lot quicker
--
-- Gameplay-altering features:
--  - Equipment menu on pause screen:  You can now collect both the wave and
--     ice beam and toggle between them, a la Super Metroid.  They are both
--     saved in passwords as well.
--  - Maximum energy tanks increased from 6 to 7
--  - You now start with full health and missiles
--
-- Helpful features:
--  - Minimap and large map on pause screen, with mouse tooltips
--     (click on elevators to navigate between areas)
--  - Item % on pause screen
--  - Time counter
--  - Countdowns on broken blocks
--  - Max missiles display
--  - Popup boxes on powerups
--  - Mouse input on password screen
--  - Clear time and item % on ending
--
-- Bugs/notes:
--  - The list of visited rooms persists when dead/using Up+A/continuing, but
--     can't be encoded in the password.
--
-- Features to do:
--  - Show missile doors on map?
--  - Various cosmetic improvements to pause screens?
--  - Keyboard input on password screen (without triggering FCEUX hotkeys)?
--  - Can we fit all 8 energy tanks somehow?
--  - Support saving/loading of games via savestates?
--  - Diagonal shooting/other input improvements?
--

--------------------------------------------------------------------------------
--
-- User configuration options
--
local showUnvisitedRooms = false  -- true  = Display all unexplored map squares
                                  -- false = Only show explored map squares
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--
-- We'll need some WRAM space to ourselves to store state information.
--
local collectedGearAddress = 0x7F7F
local visitedMapAddress    = 0x7F80 -- 0x7FFF

--------------------------------------------------------------------------------
--
-- Create gd image out of an 8x8, 4-color tile in ROM
--
local function gdTile(ofs,c0,c1,c2,c3,hflip,double)
    local gd = "\255\254\0\008\0\008\001\255\255\255\255"
    if double then gd = "\255\254\0\016\0\016\001\255\255\255\255" end
    for y=0,7 do
        local v0 = rom.readbyte(ofs + y    )
        local v1 = rom.readbyte(ofs + y + 8)
        local line = ""
        if hflip then
            for x=0,7 do
                local px
                if AND(v1,1) ~= 0 then
                    if AND(v0,1) ~= 0 then
                        v0 = v0 - 128
                        px = c3
                    else
                        px = c2
                    end
                else
                    if AND(v0,1) ~= 0 then
                        px = c1
                    else
                        px = c0
                    end
                end
                line = line .. px
                if double then line = line .. px end
                v1 = math.floor(v1/2)
                v0 = math.floor(v0/2)
            end
        else
            for x=0,7 do
                if v1 >= 128 then
                    v1 = v1 - 128
                    if v0 >= 128 then
                        v0 = v0 - 128
                        px = c3
                    else
                        px = c2
                    end
                else
                    if v0 >= 128 then
                        v0 = v0 - 128
                        px = c1
                    else
                        px = c0
                    end
                end
                line = line .. px
                if double then line = line .. px end
                v1 = v1 * 2
                v0 = v0 * 2
            end
        end
        gd = gd .. line
        if double then gd = gd .. line end
    end
    return gd
end

--
-- Same thing, but black and white
--
local function gdMonoTile(ofs)
    return gdTile(ofs,"\127\0\0\0","\0\255\255\255","\0\255\255\255","\0\255\255\255")
end

--
-- Use a string manually
--
local function gdMonoTileStr(str)
    local gd = "\255\254\0\008\0\008\001\255\255\255\255"
    for y=0,7 do
        for x=0,7 do
            if string.byte(str,1+8*y+x) > 32 then
                gd = gd .. "\0\255\255\255"
            else
                gd = gd .. "\127\0\0\0"
            end
        end
    end
    return gd
end

--
-- Just create a solid 8x8 tile
--
local function gdSolidTile(color)
    return "\255\254\0\008\0\008\001\255\255\255\255" .. string.rep(color,64)
end

--
-- Create Metroid font
--
local MetroidFont = {
    --
    -- Characters that exist in ROM
    --
    [string.byte("?")] = gdMonoTile(0x1B8B0),
    [string.byte("-")] = gdMonoTile(0x1B8C0),
    [string.byte("!")] = gdMonoTile(0x1B8D0),
    [string.byte(",")] = gdMonoTile(0x04D70),
    [254] = gdMonoTile(0x19670), -- TI
    [255] = gdMonoTile(0x19680), -- ME
    --
    -- Characters we have to supply
    --
    [string.byte(":")] = gdMonoTileStr(
        "        " ..
        "   xx   " ..
        "   xx   " ..
        "        " ..
        "   xx   " ..
        "   xx   " ..
        "        " ..
        "        "
    ),
    [string.byte("/")] = gdMonoTileStr(
        "      x " ..
        "     xx " ..
        "    xx  " ..
        "   xx   " ..
        "  xx    " ..
        " xx     " ..
        "xx      " ..
        "        "
    ),
    [string.byte("(")] = gdMonoTileStr(
        "    xx  " ..
        "   xx   " ..
        "  xx    " ..
        "  xx    " ..
        "  xx    " ..
        "   xx   " ..
        "    xx  " ..
        "        "
    ),
    [string.byte(")")] = gdMonoTileStr(
        "  xx    " ..
        "   xx   " ..
        "    xx  " ..
        "    xx  " ..
        "    xx  " ..
        "   xx   " ..
        "  xx    " ..
        "        "
    ),
    [string.byte("%")] = gdMonoTileStr(
        "        " ..
        "xx   xx " ..
        "xx  xx  " ..
        "   xx   " ..
        "  xx    " ..
        " xx  xx " ..
        "xx   xx " ..
        "        "
    ),
}
for i=48, 57 do MetroidFont[i] = gdMonoTile(0x1B4D0 + 0x10 * (i-48)) end -- 0-9
for i=65, 90 do MetroidFont[i] = gdMonoTile(0x04E10 + 0x10 * (i-65)) end -- A-Z
for i=97,122 do MetroidFont[i] = gdMonoTile(0x1B710 + 0x10 * (i-97)) end -- a-z

--
-- Draw text on the screen in the Metroid font
--
local function DrawMetroidFont(x,y,str)
    local ox = x
    for i=1,#str do
        local b = string.byte(str,i)
        if b == 10 then
            y = y + 8
            x = ox
        else
            local tile = MetroidFont[b]
            if tile then gui.gdoverlay(x,y,tile) end
            x = x + 8
        end
    end
end

local function DrawMetroidFontCenter(y,str)
    DrawMetroidFont(128 - 4 * #str, y, str)
end

--------------------------------------------------------------------------------
--
-- Add ability to read words
--
function rom   .readword(a) return rom   .readbyte(a) + 256 * rom   .readbyte(a+1) end
function memory.readword(a) return memory.readbyte(a) + 256 * memory.readbyte(a+1) end

--------------------------------------------------------------------------------
--
-- Mini-map cell images
--
-- highlight cursor:  FF0000  FFB000
-- unvisited room:    FFFFFF  002080(?)
-- visited room:      FFFFFF  D83890

local mm_dottedgridcell  = "\255\254\0\009\0\009\001\255\255\255\255\0\192\192\192\0\0\0\0\0\192\192\192\0\0\0\0\0\192\192\192\0\0\0\0\0\192\192\192\0\0\0\0\0\192\192\192\0\0\0\0\127\0\0\0\0\0\0\0\127\0\0\0\0\0\0\0\127\0\0\0\0\0\0\0\127\0\0\0\0\0\0\0\0\192\192\192\0\0\0\0\127\0\0\0\0\0\0\0\127\0\0\0\0\0\0\0\127\0\0\0\0\0\0\0\0\192\192\192\0\0\0\0\127\0\0\0\0\0\0\0\127\0\0\0\0\0\0\0\127\0\0\0\0\0\0\0\127\0\0\0\0\0\0\0\0\192\192\192\0\0\0\0\127\0\0\0\0\0\0\0\127\0\0\0\0\0\0\0\127\0\0\0\0\0\0\0\0\192\192\192\0\0\0\0\127\0\0\0\0\0\0\0\127\0\0\0\0\0\0\0\127\0\0\0\0\0\0\0\127\0\0\0\0\0\0\0\0\192\192\192\0\0\0\0\127\0\0\0\0\0\0\0\127\0\0\0\0\0\0\0\127\0\0\0\0\0\0\0\0\192\192\192\0\0\0\0\127\0\0\0\0\0\0\0\127\0\0\0\0\0\0\0\127\0\0\0\0\0\0\0\127\0\0\0\0\0\0\0\0\192\192\192\0\0\0\0\0\192\192\192\0\0\0\0\0\192\192\192\0\0\0\0\0\192\192\192\0\0\0\0\0\192\192\192"
local mm_bluegridcell    = "\255\254\0\009\0\009\001\255\255\255\255" .. string.rep("\0\0\0\128",9) .. string.rep("\0\0\0\128\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\128",7) ..string.rep("\0\0\0\128",9)

local mm_solid_highlight = gdSolidTile("\0\255\176\0")
local mm_solid_unvisited = gdSolidTile("\0\0 \128")
local mm_solid_visited   = gdSolidTile("\0\2168\144")

--------------------------------------------------------------------------------
--
-- Powerup info
--
local Powerup = {
    [0x00] = { name = "Bomb"         , counts = true },
    [0x01] = { name = "Hi-Jump Boots", counts = true },
    [0x02] = { name = "Long Beam"    ,               },
    [0x03] = { name = "Screw Attack" , counts = true },
    [0x04] = { name = "Morphing Ball", counts = true },
    [0x05] = { name = "Varia Suit"   , counts = true },
    [0x06] = { name = "Wave Beam"    ,               },
    [0x07] = { name = "Ice Beam"     ,               },
    [0x08] = { name = "Energy Tank"  , counts = true },
    [0x09] = { name = "Missiles"     , counts = true },
}

--------------------------------------------------------------------------------
--
-- Size of records in item list, by type
--
local ItemRecord = {
    [0x01] = { size = 3 }, -- enemy
    [0x02] = { size = 3 }, -- powerup
    [0x03] = { size = 1 }, -- ??
    [0x04] = { size = 2 }, -- elevator
    [0x05] = { size = 2 }, -- ??
    [0x06] = { size = 1 }, -- ??
    [0x07] = { size = 1 }, -- ??
    [0x08] = { size = 1 }, -- ??
    [0x09] = { size = 2 }, -- door
    [0x0A] = { size = 1 }, -- ??
}

--
-- Count the number of items in an area, excluding beams
--
local function CountItems(area)
    local count = 0
    local ptr = area.base + rom.readword(area.base + 0x9598)
    --
    -- For each line:
    --
    while true do
        local nextline = rom.readword(ptr + 1)
        ptr = ptr + 3 -- skip y and next pointer
        --
        -- For each room:
        --
        while true do
            local roomlen = rom.readbyte(ptr + 1)
            local nextptr = ptr + roomlen

            ptr = ptr + 2 -- skip x and length
            --
            -- For each item in the room:
            --
            while true do
                local type = AND(rom.readbyte(ptr),0xF)
                if type == 0 then break end -- end of item list
                if type == 2 then -- powerup
                    local powerup = Powerup[rom.readbyte(ptr + 1)]
                    if powerup and powerup.counts then
                        count = count + 1
                    end
                end
                --
                -- Advance to next item
                --
                if not ItemRecord[type] then
                    error(string.format("Unknown item type %02X", type))
                end
                ptr = ptr + ItemRecord[type].size
            end
            --
            -- Advance to next room
            --
            if roomlen == 0xFF then break end
            ptr = nextptr
        end
        --
        -- Advance to next line
        --
        if nextline == 0xFFFF then break end
        ptr = area.base + nextline
    end
    --
    -- Done
    --
    return count
end

--------------------------------------------------------------------------------
--
-- Count the number of items we've actually collected
--
local function CountItemsTaken()
    local count = 0
    --
    -- Start with gear that is not represented in the taken list
    --
    local gear = OR(memory.readbyte(0x6878), memory.readbyte(collectedGearAddress))
    --
    -- If we have the long beam, add 1
    --
    if AND(gear, 0x04) ~= 0 then count = count + 1 end
    --
    -- If we have EITHER the ice or wave beam, add 1
    -- This counting method is fair for existing Metroid savestates/passwords
    --
    if AND(gear, 0xC0) ~= 0 then count = count + 1 end
    --
    -- For the rest of the items, search the WRAM table
    --
    local len = math.floor(memory.readbyte(0x6886)/2)
    for i=1,len do
        local sig = memory.readword(0x6885 + 2*i)
        local type = math.floor(sig / 0x400)
        local powerup = Powerup[type]
        if powerup and powerup.counts then
            count = count + 1
        end
    end
    return count
end

--------------------------------------------------------------------------------
--
-- Get information about an area
--
local function GetArea(bank, name)
    local base = 0x4000 * bank + 0x10 - 0x8000
    local area = {
        bank        = bank,
        name        = name,
        base        = base,
        roomtable   = base + rom.readword(base + 0x959A), -- pointer table to rooms
        structtable = base + rom.readword(base + 0x959C), -- pointer table to structures
        macrotable  = base + rom.readword(base + 0x959E),
        special     = {}
    }
    --
    -- Figure out which rooms are special (creepy music).
    -- This is important because the scroll type is forced to horizontal.
    --
    for sp=0,6 do
        area.special[rom.readbyte(base + 0x95D0 + sp)] = true
    end
    return area
end

--
-- Generate map of areas
--
local Area = {
    GetArea(0x01, "Brinstar"),
    GetArea(0x02, "Norfair" ),
    GetArea(0x03, "Tourian" ),
    GetArea(0x04, "Kraid"   ),
    GetArea(0x05, "Ridley"  ),
}
for i=1,#Area do Area[Area[i].name] = Area[i] end

--
-- Expand area boundaries
--
local function ExpandAreaBounds(area,x,y)
    if not area.x0 or x <  area.x0 then area.x0 = x   end
    if not area.x1 or x >= area.x1 then area.x1 = x+1 end
    if not area.y0 or y <  area.y0 then area.y0 = y   end
    if not area.y1 or y >= area.y1 then area.y1 = y+1 end
end

--
-- Count total number of items in the game
-- (This should total 36)
--
local TotalItems = 2 -- long beam, and either of the other beams
for i=1,#Area do TotalItems = TotalItems + CountItems(Area[i]) end

--------------------------------------------------------------------------------
--
-- Add an enemy (3 bytes) to a room
--
local function addenemy(room,e0,e1,e2)
    --
    -- (this info is not needed for now)
    --
end

--
-- Add a powerup (3 bytes) to a room
--
local function addpowerup(room,p0,p1,p2)
    room.powerup = true
    room.poweruptype = p1
end

--
-- Elevator destination based on bits 0-3 of the elevator type
-- (nil can mean end-of-game)
--
local ElevatorDestination = {
    [0x00] = Area.Brinstar,
    [0x01] = Area.Norfair,
    [0x02] = Area.Kraid,
    [0x03] = Area.Tourian,
    [0x04] = Area.Ridley,
}

--
-- Add an elevator (2 bytes) to a room
--
local function addelevator(room,e0,e1)
    room.elevator     = true
    room.elevatorup   = (e1 >= 128)
    room.elevatorarea = ElevatorDestination[AND(e1,0xF)]
    --
    -- Elevator rooms should always be vertical
    --
    room.vert      = true
    room.wallleft  = true
    room.wallright = true
end

--
-- Add a door (2 bytes) to a room
--
local function adddoor(room,e0,e1)
    --
    -- (this info is not needed for now)
    --
end

--------------------------------------------------------------------------------
--
-- See if we've picked up a certain powerup, by examining the list in WRAM
--
local function HavePowerup(mapX,mapY,type)
    --
    -- Generate the 2-byte signature used in WRAM
    --
    local sig = 0x400 * type + 0x20 * mapX + mapY
    --
    -- Search the WRAM table
    --
    local len = math.floor(memory.readbyte(0x6886)/2)
    for i=1,len do
        if memory.readword(0x6885 + 2*i) == sig then
            return true -- Found
        end
    end
    return false -- Didn't find
end

--------------------------------------------------------------------------------
--
-- Decode special items for a room
--
local function DecodeRoomItems(room)
    local area = room.area
    local ptr = area.base + rom.readword(area.base + 0x9598)
    --
    -- Check for Y hit
    --
    while true do
        local y = rom.readbyte(ptr)
        if y > room.y then
            --
            -- Done with list
            --
            return
        elseif y == room.y then
            --
            -- Y hit: check for X hit
            --
            ptr = ptr + 3
            while true do
                local x = rom.readbyte(ptr)
                if x > room.x then
                    --
                    -- Done with list
                    --
                    return
                elseif x == room.x then
                    --
                    -- X hit: Read all items
                    --
                    ptr = ptr + 2 -- skip x and len
                    while true do
                        local type = AND(rom.readbyte(ptr),0xF)
                            if type == 0 then -- end of item list
                            return
                        elseif type == 1 then -- enemy
                            addenemy(
                                room,
                                rom.readbyte(ptr + 0),
                                rom.readbyte(ptr + 1),
                                rom.readbyte(ptr + 2)
                            )
                        elseif type == 2 then -- powerup
                            addpowerup(
                                room,
                                rom.readbyte(ptr + 0),
                                rom.readbyte(ptr + 1),
                                rom.readbyte(ptr + 2)
                            )
                        elseif type == 4 then -- elevator
                            addelevator(
                                room,
                                rom.readbyte(ptr + 0),
                                rom.readbyte(ptr + 1)
                            )
                        elseif type == 9 then -- door
                            adddoor(
                                room,
                                rom.readbyte(ptr + 0),
                                rom.readbyte(ptr + 1)
                            )
                        end
                        --
                        -- Advance to next item
                        --
                        if not ItemRecord[type] then
                            error(string.format("Unknown item type %02X at room %d,%d", type, room.x, room.y))
                        end
                        ptr = ptr + ItemRecord[type].size
                    end

                else
                    --
                    -- Next item
                    --
                    x = rom.readbyte(ptr + 1) -- len
                    if x == 0xFF then
                        --
                        -- Done with list
                        --
                        return
                    end
                    ptr = ptr + x
                end
            end
        else
            --
            -- Next item
            --
            local newptr = rom.readword(ptr + 1)
            if newptr == 0xFFFF then return end
            ptr = area.base + newptr
        end

    end

end

--------------------------------------------------------------------------------
--
-- Detect walls from tile array
--
local function DetectWall(contents, start, delta, len)
    for i=1,len do
        local ta = AND(contents[start + 0x00],0xFF)
        local tb = AND(contents[start + 0x01],0xFF)
        local tc = AND(contents[start + 0x20],0xFF)
        local td = AND(contents[start + 0x21],0xFF)
        --
        -- If we find a 4x4 area of blastable or walkable tiles, then no wall
        --
        if ta >= 0x70 and tb >= 0x70 and tc >= 0x70 and td >= 0x70 then
            return false
        end
        start = start + delta
    end
    --
    -- Otherwise, wall
    --
    return true
end

--
-- Detect doors from tile array
--
local function DetectDoor(contents, start, delta, len, value)
    for i=1,len do
        local ta = AND(contents[start + 0x00],0xFF)
        local tb = AND(contents[start + 0x01],0xFF)
        local tc = AND(contents[start + 0x20],0xFF)
        local td = AND(contents[start + 0x21],0xFF)
        if ta == value or tb == value or tc == value or td == value then
            --
            -- Found door
            --
            return true
        end
        start = start + delta
    end
    --
    -- No door
    --
    return false
end

--
-- Decode room contents and set certain flags (doors, walls, etc.)
--
local function DecodeRoomContents(room)
    local contents = {}

    --
    -- Get initial palette # and initialize nametable data
    --
    local src = room.area.base + rom.readword(room.area.roomtable + 2 * room.roombyte)
    local init = 256 * rom.readbyte(src) + 255
    src = src + 1
    for y=0,29 do
        for x=0,31 do
            contents[32 * y + x] = init
        end
    end

    while rom.readbyte(src) < 0xFD do
        local x = rom.readbyte(src)
        local y = math.floor(x / 16)
        x = 2 * math.mod(x, 16)
        y = 2 * math.mod(y, 16)
        local s = rom.readbyte(src + 1)
        local p = 256 * rom.readbyte(src + 2)
        src = src + 3

        --
        -- Draw structure
        --
        local structsrc = room.area.base + rom.readword(room.area.structtable + 2 * s)

        while rom.readbyte(structsrc) ~= 0xFF do
            if y >= 30 then break end
            local ox = x

            local width = rom.readbyte(structsrc)
            for col=1,width do
                if x >= 32 then break end

                local macrosrc = room.area.macrotable + 4 * rom.readbyte(structsrc + col)
                if x >= 0 and x < 32 and y >= 0 and y < 32 then
                    contents[32 * y + x     ] = p + rom.readbyte(macrosrc + 0)
                    contents[32 * y + x +  1] = p + rom.readbyte(macrosrc + 1)
                    contents[32 * y + x + 32] = p + rom.readbyte(macrosrc + 2)
                    contents[32 * y + x + 33] = p + rom.readbyte(macrosrc + 3)
                end
                x = x + 2
            end

            x = ox
            y = y + 2
            structsrc = structsrc + width + 1
        end
    end

    if rom.readbyte(src) == 0xFD then
        --
        -- Decode enemies, etc.
        --
        src = src + 1

        while rom.readbyte(src) ~= 0xFF do
            local e0 = rom.readbyte(src)

            local type = AND(e0,0xF)
                if type == 1 then -- enemy
                addenemy(room,
                    rom.readbyte(src + 0),
                    rom.readbyte(src + 1),
                    rom.readbyte(src + 2)
                )
                src = src + 3
            elseif type == 2 then -- door
                adddoor(
                    room,
                    rom.readbyte(src + 0),
                    rom.readbyte(src + 1)
                )
                src = src + 2
            elseif type == 4 then -- elevator
                addelevator(
                    room,
                    rom.readbyte(src + 0),
                    rom.readbyte(src + 1)
                )
                src = src + 2
            elseif type == 6 then -- statues
                src = src + 1
            elseif type == 7 then -- ?? (takes 3 bytes)
                src = src + 3
            else
                error(string.format("Unknown object type %02X at room %d,%d", type, room.x, room.y))
            end
        end
    end

    --
    -- Detect doors on left and right
    --
    room.doorleft    = DetectDoor(contents, 0x000, 0x40, 0x0F, 0xA0)
    room.doorright   = DetectDoor(contents, 0x01E, 0x40, 0x0F, 0xA0)
    room.hdoorleft   = DetectDoor(contents, 0x000, 0x40, 0x0F, 0xA1)
    room.hdoorright  = DetectDoor(contents, 0x01E, 0x40, 0x0F, 0xA1)

    --
    -- Special case: Tourian room #4: Add a door to the left
    --
    if room.area == Area.Tourian and room.roombyte == 4 then room.doorleft = true end

    --
    -- Detect walls on all sides
    --
    room.wallleft   = room.wallleft   or room.doorleft  or room.hdoorleft  or     room.vert or room.elevator or DetectWall(contents, 0x000, 0x40, 0x0F)
    room.wallright  = room.wallright  or room.doorright or room.hdoorright or     room.vert or room.elevator or DetectWall(contents, 0x01E, 0x40, 0x0F)
    room.walltop    = room.walltop                                         or not room.vert                  or DetectWall(contents, 0x000, 0x02, 0x10)
    room.wallbottom = room.wallbottom                                      or not room.vert                  or DetectWall(contents, 0x380, 0x02, 0x10)
end

--------------------------------------------------------------------------------
--
-- Make room info out of x/y/area/vertical
--
local function MakeRoom(x,y,area,vert)
    --
    -- Get room byte from the global map
    --
    local roombyte = rom.readbyte(0x0254E + 32 * y + x)
    --
    -- Special case certain rooms
    --
    if roombyte == 0xFF then -- empty
        return {
            empty = true,
            wallleft = true,
            wallright = true,
            walltop = true,
            wallbottom = true,
        }
    elseif roombyte == 0x01 then -- elevator shaft
        return {
            shaft = true,
            wallleft = true,
            wallright = true,
            walltop = true,
            wallbottom = true,
        }
    end

    --
    -- Create and initialize room structure
    --
    local room = {}
    room.x = x
    room.y = y
    room.area = area
    room.vert = vert
    room.roombyte = roombyte
    room.special = area.special[room.roombyte]
    --
    -- Force horizontal scrolling in special rooms
    --
    if room.special then room.vert = false end

    --
    -- Decode room contents
    --
    DecodeRoomContents(room)
    --
    -- Decode global items
    --
    DecodeRoomItems(room)

    return room
end

--------------------------------------------------------------------------------
--
-- Map data
--
local MetroidMap = {}

--
-- Traverse a room in the map recursively, and collect all relevant data
--
local function TraverseMap(x,y,area,vert)
    if not MetroidMap[32 * y + x] then
        ExpandAreaBounds(area,x,y)
        --
        -- Load room
        --
        local room = MakeRoom(x,y,area,vert)
        MetroidMap[32 * y + x] = room
        --
        -- Reload vert, in case it's a special room
        --
        vert = room.vert
        --
        -- Incorporate walls from adjoining rooms, if any, or edge of map
        --
        room.walltop    = room.walltop    or y <=  0 or MakeRoom(x,y-1,area,vert).wallbottom
        room.wallbottom = room.wallbottom or y >= 31 or MakeRoom(x,y+1,area,vert).walltop
        room.wallleft   = room.wallleft   or x <=  0 or MakeRoom(x-1,y,area,vert).wallright
        room.wallright  = room.wallright  or x >= 31 or MakeRoom(x+1,y,area,vert).wallleft
        --
        -- See where we can go directly
        --
        if not room.walltop    then TraverseMap(x, y-1, area, vert) end
        if not room.wallbottom then TraverseMap(x, y+1, area, vert) end
        if not room.wallleft   then TraverseMap(x-1, y, area, vert) end
        if not room.wallright  then TraverseMap(x+1, y, area, vert) end
        --
        -- See where we can go through doors (swap scrolling type)
        --
        if x > 0  and room.doorleft   then TraverseMap(x-1, y, area, not vert) end
        if x < 31 and room.doorright  then TraverseMap(x+1, y, area, not vert) end
        --
        -- See where we can go through doors (force horizontal scrolling)
        --
        if x > 0  and room.hdoorleft  then TraverseMap(x-1, y, area, false) end
        if x < 31 and room.hdoorright then TraverseMap(x+1, y, area, false) end
        --
        -- See where we can go through elevators
        --
        if room.elevator then
            if room.elevatorup then
                if y >= 2 then
                    --
                    -- Room above must be a shaft
                    --
                    local above = MakeRoom(x,y-1,area,true)
                    if above.shaft then
                        ExpandAreaBounds(area,x,y-1)
                        MetroidMap[32 * (y-1) + x] = above
                        --
                        -- Traverse new area
                        --
                        if room.elevatorarea then
                            TraverseMap(x, y-2, room.elevatorarea, true)
                        end
                    end
                end
            else
                if y <= 29 then
                    --
                    -- Room below must be a shaft
                    --
                    local below = MakeRoom(x,y+1,area,true)
                    if below.shaft then
                        ExpandAreaBounds(area,x,y+1)
                        MetroidMap[32 * (y+1) + x] = below
                        --
                        -- Traverse new area
                        --
                        if room.elevatorarea then
                            TraverseMap(x, y+2, room.elevatorarea, true)
                        end
                    end
                end
            end
        end

    end
end

--
-- Initialize map
--
TraverseMap(
    rom.readbyte(0x055E7), -- initial X
    rom.readbyte(0x055E8), -- initial Y
    Area.Brinstar,
    false
)

--------------------------------------------------------------------------------
--
-- Get global coordinates of the screen top/left corner
--
local function GetScreenGX()
    local x   = memory.readbyte(0x50)
    if memory.readbyte(0x49) == 3 and memory.readbyte(0xFD) ~= 0 then x = x - 1 end
    return 256 * x + memory.readbyte(0xFD)
end

local function GetScreenGY()
    local y   = memory.readbyte(0x4F)
    if memory.readbyte(0x49) == 1 and memory.readbyte(0xFC) ~= 0 then y = y - 1 end
    return 240 * y + memory.readbyte(0xFC)
end

--
-- Get global coordinates of Samus
--
local function GetSamusGX() return GetScreenGX() + memory.readbyte(0x51) end
local function GetSamusGY() return GetScreenGY() + memory.readbyte(0x52) end

--
-- Get current room coordinates of Samus
--
local function GetSamusRX() return math.mod(math.floor(GetSamusGX() / 256), 32) end
local function GetSamusRY() return math.mod(math.floor(GetSamusGY() / 240), 32) end

--------------------------------------------------------------------------------
--
-- Get/set bits in the visited room map
--
local function WasRoomVisited(x,y)
    local ofs = 32 * y + x
    if ofs < 0 or ofs > 1023 then ofs = 0 end
    local addr = math.floor(ofs / 8) + visitedMapAddress
    local bit  = math.mod(ofs, 8)
    return AND(memory.readbyte(addr), BIT(bit)) ~= 0
end

local function SetRoomVisited(x,y)
    local ofs = 32 * y + x
    if ofs < 0 or ofs > 1023 then ofs = 0 end
    local addr = math.floor(ofs / 8) + visitedMapAddress
    local bit  = math.mod(ofs, 8)
    memory.writebyte(addr, OR(memory.readbyte(addr),BIT(bit)))
end

--
-- Visit the current room
--
local function UpdateVisited()
    SetRoomVisited(GetSamusRX(), GetSamusRY())
end

--------------------------------------------------------------------------------

local function GetCurrentArea()
    return Area[memory.readbyte(0x23)]
end

--------------------------------------------------------------------------------
--
-- Draw empty cells
--
local function DrawEmptyCells(x0,y0,cols,rows,ecell)
    for row=0,rows-1 do
        for col=0,cols-1 do
            gui.gdoverlay(x0 + 8*col, y0 +8*row, ecell)
        end
    end
end

--------------------------------------------------------------------------------
--
-- Draw map or mini-map
--
-- If we're hovering over an elevator, this returns the destination area
--
local function DrawMap(x0,y0,cols,rows,mapX,mapY,currentArea)
    local hoverarea

    local samusX = GetSamusRX()
    local samusY = GetSamusRY()

    --
    -- Get mouse x,y
    --
    local inp = input.get()
    local xmouse = inp.xmouse
    local ymouse = inp.ymouse

    --
    -- Draw actual map cells
    --
    for row=0,rows-1 do
        local mY = mapY + row
        local y = y0 + 8 * row

        for col=0,cols-1 do
            local mX = mapX + col
            local x = x0 + 8 * col
            --
            -- Hover?
            --
            local hover = (
                xmouse >= x and xmouse < (x+8) and
                ymouse >= y and ymouse < (y+8)
            )
            local hovertext

            local room = MetroidMap[32 * mY + mX]
            if
                mX >= 0 and mX <= 31 and
                mY >= 0 and mY <= 31 and
                room and
                not room.empty
            then
                --
                -- Only draw rooms that match the current area.
                -- Only draw shafts if they adjoin a room in the current area.
                --
                local roomabove = MetroidMap[32 * (mY - 1) + mX]
                local roombelow = MetroidMap[32 * (mY + 1) + mX]
                if
                    --true or -- TODO: remove: debug
                    room.area == currentArea or
                    room.shaft and (
                        roomabove.area == currentArea or
                        roombelow.area == currentArea
                    )
                then
                    if room.shaft then
                        local shaftcolor = "#FFC080"
                        --
                        -- Draw shaft
                        --
                        gui.drawbox(x+1,y+0, x+6,y+7,shaftcolor)
                        gui.drawbox(x+2,y+0, x+5,y+7,"#000000")
                        gui.drawbox(x+3,y+0, x+4,y+7,"#000000")

                        gui.drawpixel(x+2,y+1,shaftcolor)
                        gui.drawpixel(x+2,y+3,shaftcolor)
                        gui.drawpixel(x+2,y+5,shaftcolor)
                        gui.drawpixel(x+2,y+7,shaftcolor)
                        gui.drawpixel(x+5,y+1,shaftcolor)
                        gui.drawpixel(x+5,y+3,shaftcolor)
                        gui.drawpixel(x+5,y+5,shaftcolor)
                        gui.drawpixel(x+5,y+7,shaftcolor)

                        --
                        -- Get destination area
                        --
                        if hover then
                            if roomabove.area ~= currentArea then
                                hoverarea = roomabove.area
                            else
                                hoverarea = roombelow.area
                            end
                            hovertext = "To " .. hoverarea.name
                        end

                    else
                        -- Determine solid/border colors
                        local border = "#FFFFFF"
                        local solid = nil
                        if WasRoomVisited(mX, mY) then
                            solid = mm_solid_visited
                        elseif showUnvisitedRooms then
                            solid = mm_solid_unvisited
                        end
                        
                        -- Show blinking cursor for current position
                        if
                            (mX == samusX and mY == samusY) and
                            AND(memory.readbyte(0x2D),0x08) ~= 0
                        then
                            solid = mm_solid_highlight
                            border = "#FF0000"
                        end

                        -- Draw map square if room has been visited or showUnvisitedRooms is enabled
                        if solid ~= nil then
                            gui.gdoverlay(x,y,solid)
                            --
                            -- Room borders
                            --
                            if room.wallleft   then
                                if room.doorleft or room.hdoorleft then
                                    gui.drawbox(x  ,y  ,x  ,y+2,border)
                                    gui.drawbox(x  ,y+5,x  ,y+7,border)
                                else
                                    gui.drawbox(x  ,y  ,x  ,y+7,border)
                                end
                            end
                            if room.wallright  then
                                if room.doorright or room.hdoorright then
                                    gui.drawbox(x+7,y  ,x+7,y+2,border)
                                    gui.drawbox(x+7,y+5,x+7,y+7,border)
                                else
                                    gui.drawbox(x+7,y  ,x+7,y+7,border)
                                end
                            end
                            if room.walltop    then gui.drawbox(x  ,y  ,x+7,y  ,border) end
                            if room.wallbottom then gui.drawbox(x  ,y+7,x+7,y+7,border) end

                            --if room.elevator then DrawMetroidFont(x,y,"E") end

                            --
                            -- Dot rooms with powerups (that we haven't gotten yet)
                            --
                            if
                                room.powerup and
                                not HavePowerup(room.x, room.y, room.poweruptype)
                            then
                                gui.drawbox(x+3,y+3,x+4,y+4,border)

                                if hover then
                                    local powerup = Powerup[room.poweruptype]
                                    if powerup then hovertext = powerup.name end
                                end
                            end
                        end

                    end
                end
            end
            --
            -- Draw hovertext if desired
            --
            if hovertext then
                if AND(memory.readbyte(0x2D),0x08) ~= 0 then
                    gui.drawbox(x,y,x+7,y+7,"#FFFFFF")
                else
                    gui.drawbox(x,y,x+7,y+7,"#000000")
                end
                local hx = x-20
                local hy = y-10
                if hx < 0   then hx = 0   end
                if hx > 200 then hx = 200 end
                if hy < 0   then hy = 0   end
                if hy > 223 then hy = 223 end
                gui.text(hx,hy,hovertext)
            end
        end
    end
    return hoverarea
end

--------------------------------------------------------------------------------

local function GetAgeInFrames(active)
    local frames = (
        0x000100 * memory.readbyte(0x687D) +
        0x00D000 * memory.readbyte(0x687E) +
        0xD00000 * memory.readbyte(0x687F)
    )
    if active then
        frames = frames + memory.readbyte(0x2D)
        if memory.readbyte(0x2D) == 0 then
            frames = frames + 256
        end
    else
        -- fake it
        frames = frames + 128
    end
    return frames
end

local function DrawAge(active)
    local frames = GetAgeInFrames(active)

    local dotcolor = "#C0C0C0"
    if math.mod(frames, 60) < 30 then dotcolor = "#FFFFFF" end
    if not active then dotcolor = "#C0C0C0" end

    local seconds = math.floor(frames  / 60)
    local minutes = math.floor(seconds / 60)
    local hours   = math.floor(minutes / 60)

    seconds = math.mod(seconds, 60)
    minutes = math.mod(minutes, 60)

    --
    -- Lots of hours? Just peg it at 99:59:59 and turn the flashing off
    --
    if hours > 99 then
        hours = 99
        minutes = 59
        seconds = 59
        dotcolor = "#FFFFFF"
    end

    local x0 = 153
    local y0 =  12
    DrawMetroidFont(x0 - 19, y0,"\254\255")
    DrawMetroidFont(x0     , y0,string.format("%02d", hours))
    DrawMetroidFont(x0 + 20, y0,string.format("%02d", minutes))
    DrawMetroidFont(x0 + 40, y0,string.format("%02d", seconds))

    gui.drawbox(x0 + 17, y0 + 1, x0 + 18, y0 + 2, dotcolor)
    gui.drawbox(x0 + 17, y0 + 4, x0 + 18, y0 + 5, dotcolor)
    gui.drawbox(x0 + 37, y0 + 1, x0 + 38, y0 + 2, dotcolor)
    gui.drawbox(x0 + 37, y0 + 4, x0 + 38, y0 + 5, dotcolor)

end

--------------------------------------------------------------------------------

local function IsVert()
    return AND(memory.readbyte(0xFA), 0x8) ~= 0
end

local function GetScrollX()
    local x = memory.readbyte(0xFD)
    if AND(memory.readbyte(0xFF),0x01) ~= 0 and not IsVert() then x = x + 256 end
    return x
end

local function GetScrollY()
    local y = memory.readbyte(0xFC)
    if AND(memory.readbyte(0xFF),0x02) ~= 0 and     IsVert() then y = y + 240 end
    return y
end

--------------------------------------------------------------------------------
--
-- Convert WRAM addresses to screen coordinates
--
local function WRAMtoScreenX(wram)
    local wx = math.floor(wram / 2)
    local ws = math.floor(wram / 0x400)
    wx = math.mod(wx, 16)
    ws = math.mod(ws, 2)
    local scrx = 16 * wx
    if IsVert() then
        scrx = math.mod(512 +            scrx - GetScrollX(), 256)
    else
        scrx = math.mod(512 + 256 * ws + scrx - GetScrollX(), 512)
    end
    return scrx
end

local function WRAMtoScreenY(wram)
    local wy = math.floor(wram / 0x40)
    local ws = math.floor(wram / 0x400)
    wy = math.mod(wy, 16)
    ws = math.mod(ws, 2)
    local scry = 16 * wy
    if IsVert() then
        scry = math.mod(480 + 240 * ws + scry - GetScrollY(), 480)
    else
        scry = math.mod(480 +            scry - GetScrollY(), 240)
    end
    return scry
end

--------------------------------------------------------------------------------
--
-- Blastable block types that we shouldn't bother counting
--
local SkipBlastBlockType = {
    [6] = true, -- chozo orb
    [7] = true, -- hidden energy tank
}

--------------------------------------------------------------------------------
--
-- Helpful countdown on blasted tiles
--
local function DrawBlastedTiles()

    for t=0,0xC do
        local blast = 0x500 + 0x10 * t

        --
        -- Only for delayed blasts, and regular crumbly block
        --
        if memory.readbyte(blast) == 3 and not SkipBlastBlockType[memory.readbyte(blast + 0xA)] then
            --
            -- Determine how many tenths of a second are left
            --
            local frames = 4 * memory.readbyte(blast + 0x7)
            local tenths = math.floor(frames / 6)

            --
            -- Get WRAM location
            --
            local wram = memory.readword(blast + 0x8) - 0x6000

            --
            -- Draw countdown
            --
            local scrx = WRAMtoScreenX(wram)
            local scry = WRAMtoScreenY(wram)
            DrawMetroidFont(scrx,scry+4,string.format("%2d",tenths))

        end

    end

end

local function DrawMaxMissiles()
    local max = memory.readbyte(0x687A)
    if max ~= 0 then
        DrawMetroidFont(68, 44, string.format("%03d", max))
        gui.drawbox(66,45,66,46,"#FFFFFF")
        gui.drawbox(65,47,65,48,"#FFFFFF")
        gui.drawbox(64,49,64,50,"#FFFFFF")
    end
end

--------------------------------------------------------------------------------
--
-- Count the number of energy tanks we've REALLY collected, via the WRAM item
-- collection table.  This value can be up to 8.
--
local function GetRealTankCount()
    local count = 0
    --
    -- Search the WRAM table
    --
    local len = math.floor(memory.readbyte(0x6886)/2)
    for i=1,len do
        local s1 = memory.readbyte(0x6886 + 2*i)
        if s1 >= 32 and s1 < 36 then
            count = count + 1
        end
    end
    return count
end

--
-- Refresh TankCount with the actual number of collected tanks, up to a maximum
-- of 7.
--
local function UpdateRealTankCount()
    local count = GetRealTankCount()
    --
    -- For practical reasons, we still have to cap the tank count at 7.
    -- More than 7 tanks don't show up properly, and a health value of 0x8000 is
    -- actually considered negative (beep beep beep)
    --
    if count > 7 then count = 7 end
    --
    -- Write new count
    --
    memory.writebyte(0x6877, count)
end

--------------------------------------------------------------------------------
--
-- Continually watch the player's powerup inventory
--
local lastPowerUp = ""
local prevTank = 0
local prevMaxM = 0
local prevGear = 0

--
-- Initialize powerup tracking
-- (to be called at the beginning of a game)
--
local function InitPowerups()
    lastPowerUp = ""
    prevTank = 0
    prevMaxM = 0
    prevGear = 0
end

--
-- Update all powerups.  Should be called during every game frame.
--
local function UpdatePowerups()
    UpdateRealTankCount()
    --
    -- Read current energy tank and missile count
    --
    local tank = GetRealTankCount() -- may be up to 8
    local maxm = memory.readbyte(0x687A)
    --
    -- Add new bits to collected gear, if present
    --
    memory.writebyte(
        collectedGearAddress,
        OR(memory.readbyte(collectedGearAddress), memory.readbyte(0x6878))
    )

    if tank ~= prevTank then
        lastPowerUp = "ENERGY TANK"
    elseif maxm ~= prevMaxM then
        local diff = maxm - prevMaxM
        lastPowerUp = diff .. " MISSILES"
    elseif memory.readbyte(collectedGearAddress) ~= prevGear then
        --
        -- Determine which gear just got added
        --
        local newGear = AND(memory.readbyte(collectedGearAddress),255-prevGear)
        for i=0,7 do
            if AND(newGear,BIT(i)) ~= 0 then
                lastPowerUp = string.upper(Powerup[i].name)
            end
        end
    end

    --
    -- Update powerups we've seen before
    --
    prevTank = tank
    prevMaxM = maxm
    prevGear = memory.readbyte(collectedGearAddress)

    --
    -- Ensure only ice or wave beam selected
    --
    if memory.readbyte(0x6878) >= 0xC0 then
        memory.writebyte(0x6878, memory.readbyte(0x6878) - 0x40) -- default to ice
    end
end

--
-- Re-enable all collected gear before visiting the password screen
--
local function RestorePowerups()
    memory.writebyte(
        0x6878,
        OR(memory.readbyte(collectedGearAddress), memory.readbyte(0x6878))
    )
end

--------------------------------------------------------------------------------
--
-- Draw HUD features
--
local function DrawHUD()
    DrawBlastedTiles()

    DrawEmptyCells(212,12,5,3,mm_dottedgridcell)
    DrawMap       (212,12,5,3,GetSamusRX()-2,GetSamusRY()-1,GetCurrentArea())

    DrawAge(memory.readbyte(0x1E) == 0x03)
    --
    -- If NOT in the escape sequence, draw max missiles
    --
    if memory.readbyte(0x010B) == 0xFF then
        DrawMaxMissiles()
    end
end

--------------------------------------------------------------------------------
--
-- Which area to show on the map screen when we pause
--
local mapScreenArea

--------------------------------------------------------------------------------

local function GameEngine()
    --
    -- Reset map to the current area
    --
    mapScreenArea = GetCurrentArea()

    UpdateVisited()
    UpdatePowerups()
    DrawHUD()
end

--------------------------------------------------------------------------------

local function EndGame()
    --
    -- Restore powerups for password screen
    --
    RestorePowerups()
end

--------------------------------------------------------------------------------

local function DrawItemPercent()
    local count = CountItemsTaken()
    local str = string.format("ITEMS: %d/%d (%d%%)", count, TotalItems, math.floor(100 * count / TotalItems))
    DrawMetroidFont(8,200,str)
end

--------------------------------------------------------------------------------
--
-- Samus graphic for equipment menu
--
local SamusTile = {}
local function LoadSamus(base,ofs,varia,justin)
    local c0,c1,c2,c3
    if not justin then
        c0 = "\127\0\0\0"
        c1 = "\0\216(\0"
        c2 = "\0\0\148\0"
        c3 = "\0\252\1528"
        if varia then c3 = "\0\252\196\216" end
    else
        c0 = "\127\0\0\0"
        c1 = "\0\228\0X"
        c2 = "\0\252\196\252"
        c3 = "\0\200L\012"
        if varia then c3 = "\0\0\148\0" end
    end
    SamusTile[base+0] = gdTile(ofs+0x000, c0, c1, c2, c3, false, true)
    SamusTile[base+1] = gdTile(ofs+0x010, c0, c1, c2, c3, false, true)
    SamusTile[base+2] = gdTile(ofs+0x100, c0, c1, c2, c3, false, true)
    SamusTile[base+3] = gdTile(ofs+0x110, c0, c1, c2, c3, false, true)
    SamusTile[base+4] = gdTile(ofs+0x200, c0, c1, c2, c3, false, true)
    SamusTile[base+5] = gdTile(ofs+0x210, c0, c1, c2, c3, false, true)
    SamusTile[base+6] = gdTile(ofs+0x300, c0, c1, c2, c3, false, true)
    SamusTile[base+7] = gdTile(ofs+0x300, c0, c1, c2, c3, true , true)
end
LoadSamus(0x00,0x180A0,false,false)
LoadSamus(0x08,0x180A0,true ,false)
LoadSamus(0x10,0x19180,false,true )
LoadSamus(0x18,0x19180,true ,true )

--
-- Equipment menu data
--
local equipCursor = 0x04
local EquipmentInfo = {
    [0x04] = { x=0x04, y=0x48, w=0x5F,          down=0x80, right=0x20 },
    [0x80] = { x=0x04, y=0x50, w=0x5F, up=0x04, down=0x40, right=0x10 },
    [0x40] = { x=0x04, y=0x58, w=0x5F, up=0x80, down=0x08, right=0x01 },
    [0x08] = { x=0x04, y=0x90, w=0x5F, up=0x40,            right=0x02 },
    [0x20] = { x=0x94, y=0x48, w=0x67,          down=0x10, left =0x04 },
    [0x10] = { x=0x94, y=0x60, w=0x67, up=0x20, down=0x01, left =0x80 },
    [0x01] = { x=0x94, y=0x68, w=0x67, up=0x10, down=0x02, left =0x40 },
    [0x02] = { x=0x94, y=0x90, w=0x67, up=0x01,            left =0x08 },
}
for k,v in pairs(EquipmentInfo) do
    for i=0,7 do
        if k == BIT(i) then v.name = string.upper(Powerup[i].name) break end
    end
end

--
-- Currently on equipment screen?
--
local equipScreen = false;

--
-- Simulate a palette selection
--
local function SelectSamusPal()
    local p = 0x02
    if AND(memory.readbyte(0x6878),0x20) ~= 0 then p = p + 0x01 end -- varia suit
    if     memory.readbyte(0x010E)       ~= 0 then p = p + 0x02 end -- missiles selected
    if     memory.readbyte(0x69B3)       ~= 0 then p = p + 0x17 end -- justin bailey
    --
    -- Set palette data pending
    --
    memory.writebyte(0x001C, p)
end

local oldclick
local function PauseMode()
    UpdateVisited()
    UpdatePowerups()

    --
    -- Mouse x/y/click
    --
    local inp = input.get()
    local xmouse = inp.xmouse
    local ymouse = inp.ymouse
    local click = inp.leftclick and not oldclick
    oldclick = inp.leftclick

    --
    -- Input as reported by the game
    --
    local input = memory.readbyte(0x12)
    --
    -- Toggle screens, as appropriate
    --
    if AND(input,0x20) ~= 0 then
        equipScreen = not equipScreen
    end

    --
    -- Start with empty grid
    --
    DrawEmptyCells(0,8,32,28,mm_bluegridcell)

    if equipScreen then
        --
        -- Move around on equipment menu
        --
        if AND(input,0x08) ~= 0 and EquipmentInfo[equipCursor].up    then equipCursor = EquipmentInfo[equipCursor].up    end
        if AND(input,0x04) ~= 0 and EquipmentInfo[equipCursor].down  then equipCursor = EquipmentInfo[equipCursor].down  end
        if AND(input,0x02) ~= 0 and EquipmentInfo[equipCursor].left  then equipCursor = EquipmentInfo[equipCursor].left  end
        if AND(input,0x01) ~= 0 and EquipmentInfo[equipCursor].right then equipCursor = EquipmentInfo[equipCursor].right end
        local pointing = false
        for k,v in pairs(EquipmentInfo) do
            if
                xmouse >= v.x and xmouse < (v.x+v.w) and
                ymouse >= v.y and ymouse < (v.y+  8)
            then
                equipCursor = k
                pointing = true
                break
            end
        end

        if AND(input,0x80) ~= 0 or (pointing and click) then
            if AND(memory.readbyte(collectedGearAddress),equipCursor) ~= 0 then
                memory.writebyte(0x6878,XOR(memory.readbyte(0x6878),equipCursor))
                --
                -- Disallow both wave and ice
                --
                if equipCursor == 0x80 and AND(memory.readbyte(0x6878),0x40) ~= 0 then
                    memory.writebyte(0x6878,XOR(memory.readbyte(0x6878),0x40))
                end
                if equipCursor == 0x40 and AND(memory.readbyte(0x6878),0x80) ~= 0 then
                    memory.writebyte(0x6878,XOR(memory.readbyte(0x6878),0x80))
                end
                --
                -- If we just enabled/disabled varia, queue a palette change
                --
                if equipCursor == 0x20 then SelectSamusPal() end
                --
                -- Reset beam sound effect
                --
                memory.writebyte(0x061F,AND(memory.readbyte(0x061F),0x7E))
            end
        end
        --
        -- Draw Samus, in either normal or Varia palette
        --
        local n = 0
        if AND(memory.readbyte(0x6878),0x20) ~= 0 then n = n + 8 end
        if memory.readbyte(0x69B3) ~= 0 then n = n + 16 end
        gui.gdoverlay(0x6C,0x50,SamusTile[n + 0])
        gui.gdoverlay(0x7C,0x50,SamusTile[n + 1])
        gui.gdoverlay(0x6C,0x60,SamusTile[n + 2])
        gui.gdoverlay(0x7C,0x60,SamusTile[n + 3])
        gui.gdoverlay(0x6C,0x70,SamusTile[n + 4])
        gui.gdoverlay(0x7C,0x70,SamusTile[n + 5])
        gui.gdoverlay(0x6C,0x80,SamusTile[n + 6])
        gui.gdoverlay(0x7C,0x80,SamusTile[n + 7])
        --
        -- Draw equipment menu items
        --
        for k,v in pairs(EquipmentInfo) do
            local bg = "#808080"
            if AND(memory.readbyte(0x6878),k) ~= 0 then bg = "#C0C0C0" end
            gui.drawbox(v.x-1,v.y  ,v.x+v.w-1,v.y+1,bg)
            gui.drawbox(v.x-1,v.y+2,v.x+v.w-1,v.y+3,bg)
            gui.drawbox(v.x-1,v.y+4,v.x+v.w-1,v.y+5,bg)
            gui.drawbox(v.x-1,v.y+6,v.x+v.w-1,v.y+6,bg)
            if AND(memory.readbyte(collectedGearAddress),k) ~= 0 then
                DrawMetroidFont(v.x, v.y, v.name)
            end
            if k == equipCursor then
                local c = "#000000"
                if AND(memory.readbyte(0x2D),0x08) ~= 0 then c = "#FFFFFF" end
                gui.drawbox(v.x-1,v.y-1,v.x+v.w-1,v.y+7,c)
            end
        end
        DrawMetroidFontCenter(16, "EQUIPMENT")
        DrawMetroidFontCenter(200,"(A: ENABLE/DISABLE)")
        DrawMetroidFontCenter(216,"(SELECT: MAP)")
    else
        if not mapScreenArea then mapScreenArea = GetCurrentArea() end
        local areaw = mapScreenArea.x1 - mapScreenArea.x0
        local areah = mapScreenArea.y1 - mapScreenArea.y0
        local hoverarea = DrawMap(
            128 - 4 * areaw,
            112 - 4 * areah,
            areaw,
            areah,
            mapScreenArea.x0,
            mapScreenArea.y0,
            mapScreenArea
        )
        DrawMetroidFontCenter(16, "MAP: " .. string.upper(mapScreenArea.name))
        DrawItemPercent()
        DrawMetroidFontCenter(216,"(SELECT: EQUIPMENT)")
        --
        -- If we clicked on an elevator, go there next frame
        --
        if hoverarea and click then
            mapScreenArea = hoverarea
        end
    end

end

--------------------------------------------------------------------------------

local function GoPassword()
    --
    -- Restore powerups for password screen
    --
    RestorePowerups()
end

--------------------------------------------------------------------------------

local function FullHealth()
    UpdateRealTankCount()
    local tanks = memory.readbyte(0x6877)        -- TankCount
    memory.writebyte(0x0106,0x99               ) -- HealthLo
    memory.writebyte(0x0107,0x09 + 0x10 * tanks) -- HealthHi
end

local function FullMissiles()
    memory.writebyte(0x6879,memory.readbyte(0x687A))
end

--------------------------------------------------------------------------------

local function SamusIntro()
    --
    -- Beginning of game - initialize powerup tracking
    --
    InitPowerups()
    --
    -- Start with full health and missiles
    --
    FullHealth()
    FullMissiles()
end

--------------------------------------------------------------------------------
--
-- If the game is in WaitTimer state, this returns the number of seconds
-- remaining
--
local function WaitSecondsRemaining()
    local frames =
        9 * memory.readbyte(0x2C) +
        memory.readbyte(0x29)
    return frames / 60
end

--------------------------------------------------------------------------------

local function DrawPowerPopup()
    --
    -- Number of seconds to display the popup
    --
    local total = 3.75
    --
    -- Fade time
    --
    local fade = 0.25

    if
            memory.readbyte(0x001D) == 0x00  -- playing
        and memory.readbyte(0x001E) == 0x09  -- waiting for timer
        and memory.readbyte(0x068D) == 0x40  -- current music is power-up theme
    then
        local remain = WaitSecondsRemaining()

        local frac = 0

        if (total - remain) < fade then
            frac = (total - remain) / fade
        elseif remain < fade then
            frac = remain / fade
        else
            frac = 1
        end

        local cx = 128
        local cy = 120

        local bw = 128
        local bh = 23

        local x0 = math.floor(cx - (frac * bw / 2))
        local y0 = math.floor(cy - (frac * bh / 2))
        local x1 = math.floor(cx + (frac * bw / 2))
        local y1 = math.floor(cy + (frac * bh / 2))
        for y=y0,y1 do
            gui.drawbox(x0,y,x1,y,"#002080")
            y=y+1
        end
        gui.drawbox(x0, y0, x1, y1,"clear", "#FFFFFF")

        if frac >= 0.9 then
            local x = cx - 4 * #lastPowerUp
            local y = cy - 4
            DrawMetroidFont(x, y, lastPowerUp)
        end
        --
        -- If we just got an energy tank:
        --
        if lastPowerUp == "ENERGY TANK" then
            --
            -- Refill health, in case we have more than 6 tanks and the game
            -- didn't do it
            --
            FullHealth()
        end
    end
end

--------------------------------------------------------------------------------

local function WaitTimer()
    UpdatePowerups()
    DrawHUD()
    --
    -- We might be waiting because we just got a powerup
    --
    DrawPowerPopup()
end

--------------------------------------------------------------------------------

local MainStateTable = {
    [0x03] = GameEngine,
    [0x04] = EndGame,
    [0x05] = PauseMode,
    [0x06] = GoPassword,
    [0x08] = SamusIntro,
    [0x09] = WaitTimer,
}

--
-- Called when game is in playing state
--
local function Play()
    local f = MainStateTable[memory.readbyte(0x1E)]
    if f then f() end
end

--------------------------------------------------------------------------------
--
-- Password screen
--
local oldclick
local function PasswordScreen()

    -- 0x320 = top cursor position (0x00-0x17)
    -- 0x321 = alphabet y
    -- 0x322 = alphabet x

    local i = input.get()

    --
    -- Get x/y and draw mouse pointer
    --
    local x = i.xmouse
    local y = i.ymouse

    --
    -- Get alphabet row and column and, if it's in bounds, write it
    --
    local alphacol = math.floor((x -  28) / 16)
    local alpharow = math.floor((y - 116) / 16)
    if
        alphacol >= 0 and alphacol <= 12 and
        alpharow >= 0 and alpharow <= 4
    then
        memory.writebyte(0x321, alpharow)
        memory.writebyte(0x322, alphacol)
    end

    if i.leftclick and not oldclick then
        --
        -- clicked!
        --
        if
            alphacol >= 0 and alphacol <= 12 and
            alpharow >= 0 and alpharow <= 4
        then
            --
            -- Simulate an A press
            --
            joypad.set(1, { A = true })
        else
            --
            -- Otherwise, see if we clicked on a password position
            --
            if y >= 64 and y < 72 then
                if x >= 72 and x < 120 then
                    memory.writebyte(0x320,      math.floor((x -  72) / 8))
                elseif x >= 128 and x < 176 then
                    memory.writebyte(0x320,  6 + math.floor((x - 128) / 8))
                end
            elseif y >= 80 and y < 88 then
                if x >= 72 and x < 120 then
                    memory.writebyte(0x320, 12 + math.floor((x -  72) / 8))
                elseif x >= 128 and x < 176 then
                    memory.writebyte(0x320, 18 + math.floor((x - 128) / 8))
                end
            end
        end
    end

    oldclick = i.leftclick
end

--------------------------------------------------------------------------------
--
-- Fix annoying title music
--
local function FixTitleMusic()
    if
            memory.readbyte(0x068D) ==   0x10 -- title theme
        and memory.readword(0x0604) == 0x0AF9 -- has reached here
        and memory.readword(0x0624) == 0x1B1B -- with these counters...
        and memory.readword(0x0626) == 0x1B1B
        and memory.readbyte(0x0684) ==   0x00 -- nothing pending
    then
        memory.writebyte(0x0684,0x10) -- restart it
    end
end

--------------------------------------------------------------------------------
--
-- Ending sequence
--
local function Ending()
    --
    -- Clear our stuff out of WRAM, including collected gear and visited map
    --
    if memory.readbyte(collectedGearAddress) ~= 0 then
        --
        -- Merge gear
        --
        memory.writebyte(0x6878,
            OR(
                memory.readbyte(0x6878),
                memory.readbyte(collectedGearAddress)
            )
        )
        memory.writebyte(collectedGearAddress, 0)
        --
        -- Clear visited map
        --
        for i=0,127 do memory.writebyte(visitedMapAddress+i,0) end
    end
    --
    -- If we're on "The End", and not hitting START, show some stats
    --
    if
        memory.readword(0x0C) == 0x9A39 and AND(memory.readword(0x14),0x10) == 0
    then
        --
        -- Clear time
        --
        local frames = GetAgeInFrames(false)
        local seconds = math.floor(frames  / 60)
        local minutes = math.floor(seconds / 60)
        local hours   = math.floor(minutes / 60)
        seconds = math.mod(seconds, 60)
        minutes = math.mod(minutes, 60)
        --
        -- Lots of hours? Just peg it at 99:59:59
        --
        if hours > 99 then
            hours = 99
            minutes = 59
            seconds = 59
        end
        DrawMetroidFontCenter(0x90,string.format("CLEAR TIME: %02d:%02d:%02d", hours, minutes, seconds))

        --
        -- Items
        --
        local count = CountItemsTaken()
        DrawMetroidFontCenter(0xA0,string.format("ITEMS: %d/%d (%d%%)", count, TotalItems, math.floor(100 * count / TotalItems)))

        --
        -- And some parting words of wisdom
        --
        DrawMetroidFontCenter(0xC0,"SEE YOU NEXT MISSION?")
    end

end

--------------------------------------------------------------------------------

local TitleStateTable = {
    [0x18] = PasswordScreen,
    [0x1D] = Ending,
}

--
-- Called when game is at title/password screens
--
local function Title()
    FixTitleMusic()
    local f = TitleStateTable[memory.readbyte(0x1F)]
    if f then f() end
end

--------------------------------------------------------------------------------
--
-- GUI update
--
gui.register(function()
    --
    -- Dot on the screen so the GUI overlay always updates
    --
    gui.drawpixel(0,0,"#000000")

    if memory.readbyte(0x1D) == 0 then
        Play()
    else
        Title()
    end
end)

--------------------------------------------------------------------------------
--
-- Main loop
--
while true do
    FCEU.frameadvance()
end

--------------------------------------------------------------------------------
