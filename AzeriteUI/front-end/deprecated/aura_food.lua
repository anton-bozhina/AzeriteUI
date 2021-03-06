local ADDON = ...
local Auras = CogWheel("LibDB"):GetDatabase(ADDON..": Auras")

-- Shortcuts for convenience
local auraList = Auras.auraList
local filterFlags = Auras.filterFlags

-- Bit filters
local ByPlayer = filterFlags.ByPlayer
local OnPlayer = filterFlags.OnPlayer
local OnTarget = filterFlags.OnTarget
local OnPet = filterFlags.OnPet
local OnToT = filterFlags.OnToT
local OnFocus = filterFlags.OnFocus
local OnParty = filterFlags.OnParty
local OnBoss = filterFlags.OnBoss
local OnArena = filterFlags.OnArena
local OnFriend = filterFlags.OnFriend
local OnEnemy = filterFlags.OnEnemy
local PlayerIsDPS = filterFlags.PlayerIsDPS
local PlayerIsHealer = filterFlags.PlayerIsHealer
local PlayerIsTank = filterFlags.PlayerIsTank
local IsCrowdControl = filterFlags.IsCrowdControl
local IsRoot = filterFlags.IsRoot
local IsSnare = filterFlags.IsSnare
local IsSilence = filterFlags.IsSilence
local IsImmune = filterFlags.IsImmune
local IsImmuneSpell = filterFlags.IsImmuneSpell
local IsImmunePhysical = filterFlags.IsImmunePhysical
local IsDisarm = filterFlags.IsDisarm
local IsFood = filterFlags.IsFood
local IsFlask = filterFlags.IsFlask
local Never = filterFlags.Never
local PrioLow = filterFlags.PrioLow
local PrioMedium = filterFlags.PrioMedium
local PrioHigh = filterFlags.PrioHigh
local PrioBoss = filterFlags.PrioBoss
local Always = filterFlags.Always

-- Halloween Lantern
auraList[ 44212] = OnPlayer -- Jack-o'-Lanterned!

------------------------------------------------------------------------
-- Well Fed!
------------------------------------------------------------------------
-- *missing most BfA ones
auraList[104277] = OnPlayer + IsFood 
auraList[ 65415] = OnPlayer + IsFood 
auraList[124215] = OnPlayer + IsFood 
auraList[130351] = OnPlayer + IsFood 
auraList[ 43764] = OnPlayer + IsFood 
auraList[ 87559] = OnPlayer + IsFood 
auraList[ 99305] = OnPlayer + IsFood 
auraList[160900] = OnPlayer + IsFood 
auraList[100373] = OnPlayer + IsFood 
auraList[262571] = OnPlayer + IsFood 
auraList[201350] = OnPlayer + IsFood 
auraList[201637] = OnPlayer + IsFood 
auraList[104278] = OnPlayer + IsFood 
auraList[ 24799] = OnPlayer + IsFood 
auraList[201223] = OnPlayer + IsFood 
auraList[124216] = OnPlayer + IsFood 
auraList[ 19711] = OnPlayer + IsFood 
auraList[225605] = OnPlayer + IsFood 
auraList[251234] = OnPlayer + IsFood 
auraList[ 87560] = OnPlayer + IsFood 
auraList[114733] = OnPlayer + IsFood 
auraList[159372] = OnPlayer + IsFood 
auraList[188534] = OnPlayer + IsFood 
auraList[124151] = OnPlayer + IsFood 
auraList[201638] = OnPlayer + IsFood 
auraList[160839] = OnPlayer + IsFood 
auraList[ 33254] = OnPlayer + IsFood 
auraList[201639] = OnPlayer + IsFood 
auraList[104279] = OnPlayer + IsFood 
auraList[ 87545] = OnPlayer + IsFood 
auraList[ 65416] = OnPlayer + IsFood 
auraList[124217] = OnPlayer + IsFood 
auraList[130353] = OnPlayer + IsFood 
auraList[ 87558] = OnPlayer + IsFood 
auraList[ 57288] = OnPlayer + IsFood 
auraList[201640] = OnPlayer + IsFood 
auraList[225604] = OnPlayer + IsFood 
auraList[201635] = OnPlayer + IsFood 
auraList[134094] = OnPlayer + IsFood 
auraList[100375] = OnPlayer + IsFood 
auraList[ 57327] = OnPlayer + IsFood 
auraList[104264] = OnPlayer + IsFood 
auraList[ 57097] = OnPlayer + IsFood 
auraList[201641] = OnPlayer + IsFood 
auraList[104280] = OnPlayer + IsFood 
auraList[160897] = OnPlayer + IsFood 
auraList[104276] = OnPlayer + IsFood 
auraList[ 46682] = OnPlayer + IsFood 
auraList[130354] = OnPlayer + IsFood 
auraList[160778] = OnPlayer + IsFood 
auraList[ 87546] = OnPlayer + IsFood 
auraList[ 87562] = OnPlayer + IsFood 
auraList[146808] = OnPlayer + IsFood 
auraList[185736] = OnPlayer + IsFood 
auraList[175218] = OnPlayer + IsFood 
auraList[225603] = OnPlayer + IsFood 
auraList[ 57334] = OnPlayer + IsFood 
auraList[175785] = OnPlayer + IsFood 
auraList[125108] = OnPlayer + IsFood 
auraList[ 33263] = OnPlayer + IsFood 
auraList[104281] = OnPlayer + IsFood 
auraList[ 62349] = OnPlayer + IsFood 
auraList[175219] = OnPlayer + IsFood 
auraList[124219] = OnPlayer + IsFood 
auraList[130355] = OnPlayer + IsFood 
auraList[160832] = OnPlayer + IsFood 
auraList[ 87547] = OnPlayer + IsFood 
auraList[ 87563] = OnPlayer + IsFood 
auraList[125113] = OnPlayer + IsFood 
auraList[ 87557] = OnPlayer + IsFood 
auraList[135440] = OnPlayer + IsFood 
auraList[ 57329] = OnPlayer + IsFood 
auraList[ 99478] = OnPlayer + IsFood 
auraList[177931] = OnPlayer + IsFood 
auraList[108028] = OnPlayer + IsFood 
auraList[124213] = OnPlayer + IsFood 
auraList[104282] = OnPlayer + IsFood 
auraList[225601] = OnPlayer + IsFood 
auraList[201695] = OnPlayer + IsFood 
auraList[ 19708] = OnPlayer + IsFood 
auraList[130356] = OnPlayer + IsFood 
auraList[215607] = OnPlayer + IsFood 
auraList[ 87548] = OnPlayer + IsFood 
auraList[ 87564] = OnPlayer + IsFood 
auraList[133593] = OnPlayer + IsFood 
auraList[ 33268] = OnPlayer + IsFood 
auraList[175222] = OnPlayer + IsFood 
auraList[ 35272] = OnPlayer + IsFood 
auraList[135076] = OnPlayer + IsFood 
auraList[ 33272] = OnPlayer + IsFood 
auraList[ 33256] = OnPlayer + IsFood 
auraList[104267] = OnPlayer + IsFood 
auraList[104283] = OnPlayer + IsFood 
auraList[ 65410] = OnPlayer + IsFood 
auraList[175223] = OnPlayer + IsFood 
auraList[124221] = OnPlayer + IsFood 
auraList[140410] = OnPlayer + IsFood 
auraList[ 66623] = OnPlayer + IsFood 
auraList[ 87549] = OnPlayer + IsFood 
auraList[ 87565] = OnPlayer + IsFood 
auraList[133595] = OnPlayer + IsFood 
auraList[130352] = OnPlayer + IsFood 
auraList[ 42293] = OnPlayer + IsFood 
auraList[251247] = OnPlayer + IsFood 
auraList[216343] = OnPlayer + IsFood 
auraList[201330] = OnPlayer + IsFood 
auraList[174077] = OnPlayer + IsFood 
auraList[ 57107] = OnPlayer + IsFood 
auraList[133596] = OnPlayer + IsFood 
auraList[ 57139] = OnPlayer + IsFood 
auraList[160722] = OnPlayer + IsFood 
auraList[130342] = OnPlayer + IsFood 
auraList[ 87556] = OnPlayer + IsFood 
auraList[ 87550] = OnPlayer + IsFood 
auraList[174078] = OnPlayer + IsFood 
auraList[146805] = OnPlayer + IsFood 
auraList[130348] = OnPlayer + IsFood 
auraList[ 19706] = OnPlayer + IsFood 
auraList[251248] = OnPlayer + IsFood 
auraList[125115] = OnPlayer + IsFood 
auraList[160893] = OnPlayer + IsFood 
auraList[201332] = OnPlayer + IsFood 
auraList[ 33257] = OnPlayer + IsFood 
auraList[ 33265] = OnPlayer + IsFood 
auraList[160883] = OnPlayer + IsFood 
auraList[104274] = OnPlayer + IsFood 
auraList[225599] = OnPlayer + IsFood 
auraList[130343] = OnPlayer + IsFood 
auraList[160724] = OnPlayer + IsFood 
auraList[174080] = OnPlayer + IsFood 
auraList[ 57291] = OnPlayer + IsFood 
auraList[ 57365] = OnPlayer + IsFood 
auraList[230061] = OnPlayer + IsFood 
auraList[134712] = OnPlayer + IsFood 
auraList[110645] = OnPlayer + IsFood 
auraList[105226] = OnPlayer + IsFood 
auraList[160726] = OnPlayer + IsFood 
auraList[201334] = OnPlayer + IsFood 
auraList[ 57100] = OnPlayer + IsFood 
auraList[ 57363] = OnPlayer + IsFood 
auraList[ 57371] = OnPlayer + IsFood 
auraList[225598] = OnPlayer + IsFood 
auraList[ 19705] = OnPlayer + IsFood 
auraList[ 19709] = OnPlayer + IsFood 
auraList[130344] = OnPlayer + IsFood 
auraList[ 57325] = OnPlayer + IsFood 
auraList[ 87552] = OnPlayer + IsFood 
auraList[ 64057] = OnPlayer + IsFood 
auraList[133428] = OnPlayer + IsFood 
auraList[133594] = OnPlayer + IsFood 
auraList[104273] = OnPlayer + IsFood 
auraList[108032] = OnPlayer + IsFood 
auraList[180745] = OnPlayer + IsFood 
auraList[201336] = OnPlayer + IsFood 
auraList[145304] = OnPlayer + IsFood 
auraList[104271] = OnPlayer + IsFood 
auraList[147312] = OnPlayer + IsFood 
auraList[ 65412] = OnPlayer + IsFood 
auraList[216828] = OnPlayer + IsFood 
auraList[130345] = OnPlayer + IsFood 
auraList[226805] = OnPlayer + IsFood 
auraList[104272] = OnPlayer + IsFood 
auraList[ 57356] = OnPlayer + IsFood 
auraList[180746] = OnPlayer + IsFood 
auraList[125070] = OnPlayer + IsFood 
auraList[100368] = OnPlayer + IsFood 
auraList[125102] = OnPlayer + IsFood 
auraList[ 57332] = OnPlayer + IsFood 
auraList[ 25694] = OnPlayer + IsFood 
auraList[160793] = OnPlayer + IsFood 
auraList[168475] = OnPlayer + IsFood 
auraList[ 53284] = OnPlayer + IsFood 
auraList[160889] = OnPlayer + IsFood 
auraList[207076] = OnPlayer + IsFood 
auraList[124210] = OnPlayer + IsFood 
auraList[130346] = OnPlayer + IsFood 
auraList[226807] = OnPlayer + IsFood 
auraList[225597] = OnPlayer + IsFood 
auraList[ 87554] = OnPlayer + IsFood 
auraList[180748] = OnPlayer + IsFood 
auraList[125071] = OnPlayer + IsFood 
auraList[ 87697] = OnPlayer + IsFood 
auraList[168349] = OnPlayer + IsFood 
auraList[ 87634] = OnPlayer + IsFood 
auraList[216353] = OnPlayer + IsFood 
auraList[180747] = OnPlayer + IsFood 
auraList[ 33259] = OnPlayer + IsFood 
auraList[180749] = OnPlayer + IsFood 
auraList[ 25941] = OnPlayer + IsFood 
auraList[160600] = OnPlayer + IsFood 
auraList[124211] = OnPlayer + IsFood 
auraList[130347] = OnPlayer + IsFood 
auraList[108031] = OnPlayer + IsFood 
auraList[185786] = OnPlayer + IsFood 
auraList[ 87555] = OnPlayer + IsFood 
auraList[180750] = OnPlayer + IsFood 
auraList[160885] = OnPlayer + IsFood 
auraList[100377] = OnPlayer + IsFood 
auraList[125104] = OnPlayer + IsFood 
auraList[ 87635] = OnPlayer + IsFood 
auraList[ 87551] = OnPlayer + IsFood 
auraList[ 45619] = OnPlayer + IsFood 
auraList[146804] = OnPlayer + IsFood 
auraList[ 87699] = OnPlayer + IsFood 
auraList[ 57373] = OnPlayer + IsFood 
auraList[ 57102] = OnPlayer + IsFood 
auraList[165802] = OnPlayer + IsFood 
auraList[ 46687] = OnPlayer + IsFood 
auraList[174079] = OnPlayer + IsFood 
auraList[124212] = OnPlayer + IsFood 
auraList[225600] = OnPlayer + IsFood 
auraList[ 19710] = OnPlayer + IsFood 
auraList[192004] = OnPlayer + IsFood 
auraList[ 59230] = OnPlayer + IsFood 
auraList[ 46899] = OnPlayer + IsFood 
auraList[146806] = OnPlayer + IsFood 
auraList[146807] = OnPlayer + IsFood 
auraList[201679] = OnPlayer + IsFood 
auraList[ 45245] = OnPlayer + IsFood 
auraList[104275] = OnPlayer + IsFood 
auraList[160895] = OnPlayer + IsFood 
auraList[ 65414] = OnPlayer + IsFood 
auraList[ 24870] = OnPlayer + IsFood 
auraList[251261] = OnPlayer + IsFood 
auraList[124220] = OnPlayer + IsFood 
auraList[ 57286] = OnPlayer + IsFood 
auraList[225602] = OnPlayer + IsFood 
auraList[175220] = OnPlayer + IsFood 
auraList[ 57294] = OnPlayer + IsFood 
auraList[146809] = OnPlayer + IsFood 
auraList[125106] = OnPlayer + IsFood 
auraList[ 57079] = OnPlayer + IsFood 
auraList[160902] = OnPlayer + IsFood 
auraList[124218] = OnPlayer + IsFood 
auraList[ 57358] = OnPlayer + IsFood 
auraList[ 57111] = OnPlayer + IsFood 
auraList[134887] = OnPlayer + IsFood 
auraList[ 57360] = OnPlayer + IsFood 
auraList[124214] = OnPlayer + IsFood 
auraList[130350] = OnPlayer + IsFood 
auraList[175784] = OnPlayer + IsFood 
auraList[174062] = OnPlayer + IsFood 
auraList[201634] = OnPlayer + IsFood 
auraList[ 87561] = OnPlayer + IsFood 
auraList[131828] = OnPlayer + IsFood 
auraList[ 57399] = OnPlayer + IsFood 
auraList[ 57367] = OnPlayer + IsFood 
auraList[134219] = OnPlayer + IsFood 
auraList[134506] = OnPlayer + IsFood 
auraList[225606] = OnPlayer + IsFood 
auraList[ 33261] = OnPlayer + IsFood 
auraList[201636] = OnPlayer + IsFood 

-- Toys

-- Fishing Bobbers. 
-- These are cosmetic, and stack, but only the latest is visible.
-- Need to make a grouped system where only the one with  
-- the longest time left is currently shown. 
--auraList[231291] = OnPlayer -- Can of Worms Bobber (Fishing Bobber)
--auraList[231319] = OnPlayer -- Toy Cat Head Bobber (Fishing Bobber)
--auraList[232613] = OnPlayer -- Wooden Pepe Bobber (Fishing Bobber)
