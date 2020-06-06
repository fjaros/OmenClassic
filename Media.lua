local MINOR_VERSION = tonumber(("$Revision: 66520 $"):match("%d+"))
if MINOR_VERSION > Omen.MINOR_VERSION then Omen.MINOR_VERSION = MINOR_VERSION end

local media = LibStub("LibSharedMedia-3.0")

media:Register("sound", "Bell Toll Alliance", [[sound\doodad\belltollalliance.ogg]])
media:Register("sound", "Bell Toll Horde", [[sound\doodad\belltollhorde.ogg]])
media:Register("sound", "Curse", [[sound\spells\curse.ogg]])
media:Register("sound", "Furious Howl 1", [[sound\spells\furioushowl1.ogg]])
media:Register("sound", "Furious Howl 2", [[sound\spells\furioushowl2.ogg]])
media:Register("sound", "Furious Howl 3", [[sound\spells\furioushowl3.ogg]])
media:Register("sound", "Pet Call", [[sound\spells\petcall.ogg]])
media:Register("sound", "Purge", [[sound\spells\purge.ogg]])
media:Register("sound", "Screech", [[sound\spells\screech.ogg]])
media:Register("sound", "Shield Wall", [[sound\spells\shieldwalltarget.ogg]])

media:Register("sound", "Aoogah!", [[Interface\AddOns\Omen\Media\Sounds\aoogah.ogg]])
