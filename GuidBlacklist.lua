
GuidBlacklist = {}

local db
local ReverseGuids = {}
local MAX_TABLE_SIZE = 2000

function GuidBlacklist:OnInitialize()
	db = Omen.db.profile.GuidBlacklist
	for i, v in ipairs(db.t) do
		ReverseGuids[v] = i
	end
end

function GuidBlacklist:Add(guid)
	if ReverseGuids[guid] then
		return
	end
	
	-- But really we should only blacklist creatures...
	if not string.find(guid, 1, 9) == "Creature-" then
		return
	end

	if db.i > MAX_TABLE_SIZE then
		db.i = 1
	end
	
	local oldGuid = db.t[db.i]
	if oldGuid then
		ReverseGuids[oldGuid] = nil
	end

	db.t[db.i] = guid
	ReverseGuids[guid] = db.i
	db.i = db.i + 1
end

function GuidBlacklist:Rem(guid)
	local guidIndex = ReverseGuids[guid]
	if not guidIndex then
		return
	end
	
	ReverseGuids[guid] = nil
	db.t[guidIndex] = nil
end

function GuidBlacklist:Has(guid)
	return ReverseGuids[guid] ~= nil
end
