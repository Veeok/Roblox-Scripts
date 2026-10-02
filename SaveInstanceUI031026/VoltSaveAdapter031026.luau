-- Volt-native SaveInstance adapter
-- Designed for Volt 1.3+ and the SaveInstanceUI031026 callback interface.
-- Uses Volt's built-in binary serializer instead of UniversalSynSaveInstance.

local function notify(toast, kind, title, message, duration)
    if type(toast) == "function" then
        pcall(toast, kind, title, message, duration)
    end
end

local function status(setStatus, text, kind, message)
    if type(setStatus) == "function" then
        pcall(setStatus, text, kind, message)
    end
end

local function progress(setProgress, value, label)
    if type(setProgress) == "function" then
        pcall(setProgress, value, label)
    end
end

local function executorInfo()
    local identify = identifyexecutor or getexecutorname or whatexecutor
    if type(identify) ~= "function" then
        return "Unknown", ""
    end

    local ok, name, version = pcall(identify)
    if not ok then
        return "Unknown", ""
    end

    return tostring(name or "Unknown"), tostring(version or "")
end

local function getOptionsConstructor()
    local ok, constructor = pcall(function()
        return SaveInstanceOptions and SaveInstanceOptions.new
    end)

    if not ok or type(constructor) ~= "function" then
        return nil
    end

    return constructor
end

local function requireVoltSaveApi()
    if type(saveinstance) ~= "function" then
        error("Volt native saveinstance() is unavailable. Update Volt and make sure it is attached before running this script.")
    end

    local constructor = getOptionsConstructor()
    if not constructor then
        error("Volt SaveInstanceOptions.new() is unavailable. Volt 1.3+ is required.")
    end

    return constructor
end

local function normalizePath(rawPath)
    local path = tostring(rawPath or "")
    path = path:gsub("\\", "/")
    path = path:gsub("^%a:/", "")
    path = path:gsub("^/+", "")

    local parts = {}
    for part in path:gmatch("[^/]+") do
        if part ~= "." and part ~= ".." and part ~= "" then
            part = part:gsub("[%c<>:\"|%?%*]", "_")
            part = part:gsub("^%s+", ""):gsub("%s+$", "")
            part = part:gsub("[%.%s]+$", "")
            if part ~= "" then
                parts[#parts + 1] = part
            end
        end
    end

    if #parts == 0 then
        parts[1] = "SavedGame-" .. tostring(game.PlaceId) .. ".rbxl"
    end

    path = table.concat(parts, "/")
    path = path:gsub("%.rbxlx$", ".rbxl")

    if not path:lower():match("%.rbxl$") then
        path ..= ".rbxl"
    end

    return path
end

local function ensureParentFolder(path)
    if type(makefolder) ~= "function" then
        return
    end

    local folder = path:match("^(.*)/[^/]+$")
    if folder and folder ~= "" then
        pcall(makefolder, folder)
    end
end

local function splitExtension(path)
    local stem, extension = path:match("^(.*)(%.[^./]+)$")
    if not stem then
        return path, ""
    end
    return stem, extension
end

local function chooseOutputPath(path, avoidOverwrite)
    if not avoidOverwrite or type(isfile) ~= "function" then
        return path
    end

    local ok, exists = pcall(isfile, path)
    if not ok or not exists then
        return path
    end

    local stem, extension = splitExtension(path)
    for index = 1, 9999 do
        local candidate = string.format("%s (%d)%s", stem, index, extension)
        local checkOk, candidateExists = pcall(isfile, candidate)
        if checkOk and not candidateExists then
            return candidate
        end
    end

    error("Could not find an unused output filename after 9999 attempts.")
end

local function verifyOutput(path)
    if type(isfile) ~= "function" then
        return true, "Volt does not expose isfile() in this environment, so file existence could not be verified."
    end

    for _ = 1, 20 do
        local ok, exists = pcall(isfile, path)
        if ok and exists then
            return true
        end
        task.wait(0.1)
    end

    return false, "Volt saveinstance() returned but the expected output file was not found: " .. path
end

local function buildNativeOptions(options, outputPath, constructor)
    local native = constructor()

    native.FilePath = outputPath

    -- UniversalSynSaveInstance defaults to saving non-Archivable objects.
    native.IgnoreArchivable = true

    -- The UI exposes RemovePlayerCharacters, which is the inverse of
    -- UniversalSynSaveInstance's SavePlayerCharacters option.
    native.SavePlayerCharacters = options.RemovePlayerCharacters ~= true

    native.SavePlayers = false
    native.DisableCompression = false
    native.DecompileScripts = options.Decompile ~= false
    native.SaveNonCreatable = false
    native.SaveNilInstances = options.NilInstances == true
    native.CopyToClipboard = false

    return native
end

return function(options, setStatus, setProgress, toast)
    options = options or {}

    local constructor = requireVoltSaveApi()

    local executorName, executorVersion = executorInfo()
    local outputPath = normalizePath(options.FilePath)
    outputPath = chooseOutputPath(outputPath, options.AvoidFileOverwrite ~= false)

    ensureParentFolder(outputPath)

    if options.Binary == false then
        notify(
            toast,
            "warning",
            "Binary enforced",
            "Volt's native saver writes binary place files. The output was changed to .rbxl.",
            4
        )
    end

    if options.mode == "scripts" then
        error("Volt's native place saver does not provide UniversalSynSaveInstance's scripts-only mode. Choose Optimized or Full.")
    end

    if options.IsolateStarterPlayer == true then
        notify(
            toast,
            "warning",
            "Option not available",
            "Volt's native SaveInstanceOptions does not expose IsolateStarterPlayer, so that option was ignored.",
            5
        )
    end

    status(
        setStatus,
        "Saving",
        "busy",
        string.format("Using %s%s native serializer", executorName, executorVersion ~= "" and (" " .. executorVersion) or "")
    )
    progress(setProgress, 0.12, "Preparing Volt save... 12%")

    local nativeOptions = buildNativeOptions(options, outputPath, constructor)

    progress(setProgress, 0.24, "Serializing place... 24%")

    local ok, saveError = pcall(function()
        saveinstance(game, nativeOptions)
    end)

    if not ok then
        error("Volt native saveinstance failed: " .. tostring(saveError))
    end

    progress(setProgress, 0.94, "Verifying file... 94%")

    local verified, verifyMessage = verifyOutput(outputPath)
    if not verified then
        error(verifyMessage)
    end

    if verifyMessage then
        notify(toast, "warning", "Save completed", verifyMessage, 5)
    end

    status(setStatus, "Finished", "success", "Saved " .. outputPath)
    progress(setProgress, 1, "Saved successfully")

    notify(
        toast,
        "success",
        "Volt save complete",
        outputPath .. " was written to Volt's workspace.",
        4
    )

    return outputPath
end
