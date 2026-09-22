Cfg = {}

voiceTarget = 1

gameVersion = GetGameName()

-- these are just here to satisfy linting
if not IsDuplicityVersion() then
	LocalPlayer = LocalPlayer
	playerServerId = GetPlayerServerId(PlayerId())

	if gameVersion == "redm" then
		function CreateAudioSubmix(name)
			return Citizen.InvokeNative(0x658d2bc8, name, Citizen.ResultAsInteger())
		end

		function AddAudioSubmixOutput(submixId, outputSubmixId)
			Citizen.InvokeNative(0xAC6E290D, submixId, outputSubmixId)
		end

		function MumbleSetSubmixForServerId(serverId, submixId)
			Citizen.InvokeNative(0xFE3A3054, serverId, submixId)
		end

		function SetAudioSubmixEffectParamFloat(submixId, effectSlot, paramIndex, paramValue)
			Citizen.InvokeNative(0x9A209B3C, submixId, effectSlot, paramIndex, paramValue)
		end

		function SetAudioSubmixEffectParamInt(submixId, effectSlot, paramIndex, paramValue)
			Citizen.InvokeNative(0x77FAE2B8, submixId, effectSlot, paramIndex, paramValue)
		end

		function SetAudioSubmixEffectRadioFx(submixId, effectSlot)
			Citizen.InvokeNative(0xAAA94D53, submixId, effectSlot)
		end

		function SetAudioSubmixOutputVolumes(submixId, outputSlot, frontLeftVolume, frontRightVolume, rearLeftVolume,
											 rearRightVolume, channel5Volume, channel6Volume)
			Citizen.InvokeNative(0x825DC0D1, submixId, outputSlot, frontLeftVolume, frontRightVolume, rearLeftVolume,
				rearRightVolume, channel5Volume, channel6Volume)
		end
	end
end
Player = Player
Entity = Entity

if GetConvar('voice_useNativeAudio', 'false') == 'true' then
	-- Native audio multiplies by 3 internally for distance check
	Cfg.voiceModes = {
		{ 0.60, "Шепот" },   -- ~1.8m
		{ 2.00, "Обычный" }, -- ~6.0m
		{ 6.70, "Крик" }     -- ~20.0m
	}
else
	Cfg.voiceModes = {
		{ 1.8,  "Шепот" },
		{ 6.0,  "Обычный" },
		{ 20.0, "Крик" }
	}
end

-- Mumble's talker proximity is also applied by RedM on the receiving client.
-- Keep it open to the largest available mode; client/init/proximity.lua limits
-- the outgoing target channels using the speaker's selected state instead.
function GetPmaVoiceReceiveRange()
	local maximum = 0.0
    for i = 1, #Cfg.voiceModes do
        local distance = tonumber(Cfg.voiceModes[i][1]) or 0.0
        if distance > maximum then
            maximum = distance
        end
    end

    if GetConvar('voice_useNativeAudio', 'false') == 'true' then
        maximum = maximum * 3.0
    end

    return maximum
end

logger = {
	log = function(message, ...)
		print((message):format(...))
	end,
	info = function(message, ...)
		if GetConvarInt('voice_debugMode', 0) >= 1 then
			print(('[info] ' .. message):format(...))
		end
	end,
	warn = function(message, ...)
		print(('[^1WARNING^7] ' .. message):format(...))
	end,
	error = function(message, ...)
		error((message):format(...))
	end,
	verbose = function(message, ...)
		if GetConvarInt('voice_debugMode', 0) >= 4 then
			print(('[verbose] ' .. message):format(...))
		end
	end,
}

function tPrint(tbl, indent)
	indent = indent or 0
	for k, v in pairs(tbl) do
		local tblType = type(v)
		local formatting = string.rep("  ", indent) .. k .. ": "

		if tblType == "table" then
			print(formatting)
			tPrint(v, indent + 1)
		elseif tblType == 'boolean' then
			print(formatting .. tostring(v))
		elseif tblType == "function" then
			print(formatting .. tostring(v))
		else
			print(formatting .. v)
		end
	end
end

local function types(args)
	local argType = type(args[1])
	for i = 2, #args do
		local arg = args[i]
		if argType == arg then
			return true, argType
		end
	end
	return false, argType
end

function type_check(...)
	local vars = { ... }
	for i = 1, #vars do
		local var = vars[i]
		local matchesType, varType = types(var)
		if not matchesType then
			table.remove(var, 1)
			error(("Invalid type sent to argument #%s, expected %s, got %s"):format(i, table.concat(var, "|"), varType))
		end
	end
end
