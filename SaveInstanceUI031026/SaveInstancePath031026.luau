-- SaveInstance executor-aware UI
-- Designed for workspace-relative save paths across executors.
-- Focused on Volt while remaining callback-driven for other executors.

return function(config)
    config = config or {}
    assert(type(config.onSave) == "function", "SaveInstancePath031026 requires config.onSave(options, setStatus, setProgress, toast)")

    local Players = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    local CoreGui = game:GetService("CoreGui")

    local player = Players.LocalPlayer
    local env = (type(getgenv) == "function" and getgenv()) or _G
    local singletonKey = "__VEEOK_SAVEINSTANCE_PATH_UI_031026"

    local previous = rawget(env, singletonKey)
    if type(previous) == "table" and type(previous.Destroy) == "function" then
        pcall(previous.Destroy, "reload")
    elseif typeof(previous) == "Instance" then
        pcall(function()
            previous:Destroy()
        end)
    end
    env[singletonKey] = nil

    local destroyed = false
    local busy = false
    local runId = 0
    local connections = {}
    local threads = {}
    local gui
    local controller
    local saveCallback = config.onSave
    local unloadCallback = config.onUnload

    local palette = {
        bg = Color3.fromRGB(15, 16, 21),
        header = Color3.fromRGB(20, 21, 28),
        card = Color3.fromRGB(27, 29, 38),
        field = Color3.fromRGB(34, 36, 47),
        border = Color3.fromRGB(53, 56, 70),
        text = Color3.fromRGB(240, 242, 248),
        muted = Color3.fromRGB(145, 150, 166),
        accent = Color3.fromRGB(91, 105, 255),
        accentHover = Color3.fromRGB(108, 121, 255),
        success = Color3.fromRGB(62, 181, 124),
        warning = Color3.fromRGB(219, 158, 64),
        danger = Color3.fromRGB(219, 78, 87),
        off = Color3.fromRGB(65, 68, 82),
    }

    local function new(className, props)
        local object = Instance.new(className)
        for key, value in pairs(props or {}) do
            object[key] = value
        end
        return object
    end

    local function corner(object, radius)
        new("UICorner", {
            CornerRadius = UDim.new(0, radius),
            Parent = object,
        })
    end

    local function stroke(object, transparency)
        new("UIStroke", {
            Color = palette.border,
            Transparency = transparency or 0,
            Thickness = 1,
            Parent = object,
        })
    end

    local function tween(object, duration, props)
        if destroyed or not object or not object.Parent then
            return nil
        end

        local animation = TweenService:Create(
            object,
            TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            props
        )
        animation:Play()
        return animation
    end

    local function bind(signal, callback)
        local connection = signal:Connect(function(...)
            if destroyed then
                return
            end
            callback(...)
        end)
        connections[#connections + 1] = connection
        return connection
    end

    local function spawnTracked(callback)
        local thread = task.spawn(function()
            if not destroyed then
                callback()
            end
        end)
        threads[#threads + 1] = thread
        return thread
    end

    local function delayTracked(seconds, callback)
        local thread = task.delay(seconds, function()
            if not destroyed then
                callback()
            end
        end)
        threads[#threads + 1] = thread
        return thread
    end

    local function detectExecutor()
        local identify = identifyexecutor or getexecutorname or whatexecutor
        if type(identify) ~= "function" then
            return "Unknown Executor", ""
        end

        local ok, name, version = pcall(identify)
        if not ok then
            return "Unknown Executor", ""
        end

        name = tostring(name or "Unknown Executor")
        version = tostring(version or "")
        return name, version
    end

    local executorName, executorVersion = detectExecutor()
    local executorLabel = executorName
    if executorVersion ~= "" then
        executorLabel ..= " " .. executorVersion
    end

    local executorLower = string.lower(executorName)
    local isVolt = string.find(executorLower, "volt", 1, true) ~= nil

    local function sanitizeName(value)
        value = tostring(value or "")
        value = value:gsub("%.rbxlx?$", "")
        value = value:gsub("[%c<>:\"/\\|%?%*]", "_")
        value = value:gsub("^%s+", ""):gsub("%s+$", "")
        value = value:gsub("[%.%s]+$", "")

        if value == "" then
            value = "SavedGame-" .. tostring(game.PlaceId)
        end

        return value:sub(1, 120)
    end

    local function sanitizeFolder(value)
        value = tostring(value or "")
        value = value:gsub("\\", "/")
        value = value:gsub("^%a:/", "")
        value = value:gsub("^/+", "")

        local parts = {}
        for part in value:gmatch("[^/]+") do
            if part ~= "." and part ~= ".." then
                part = part:gsub("[%c<>:\"|%?%*]", "_")
                part = part:gsub("^%s+", ""):gsub("%s+$", "")
                part = part:gsub("[%.%s]+$", "")

                if part ~= "" then
                    parts[#parts + 1] = part:sub(1, 80)
                end
            end
        end

        return table.concat(parts, "/")
    end

    local function resolveParent()
        if config.parent then
            return config.parent
        end

        if type(gethui) == "function" then
            local ok, result = pcall(gethui)
            if ok and result then
                return result
            end
        end

        local okCore, core = pcall(function()
            return CoreGui
        end)
        if okCore and core then
            return core
        end

        if player then
            local okGui, playerGui = pcall(function()
                return player:WaitForChild("PlayerGui", 5)
            end)
            if okGui and playerGui then
                return playerGui
            end
        end

        error("SaveInstance UI could not find a GUI parent")
    end

    local parent = resolveParent()

    local old = parent:FindFirstChild("SaveInstancePath031026")
    if old then
        pcall(function()
            old:Destroy()
        end)
    end

    local function destroy(reason)
        if destroyed then
            return
        end

        destroyed = true
        busy = false
        runId += 1

        for _, connection in ipairs(connections) do
            pcall(function()
                if connection.Connected then
                    connection:Disconnect()
                end
            end)
        end
        table.clear(connections)

        if type(task.cancel) == "function" then
            for _, thread in ipairs(threads) do
                pcall(task.cancel, thread)
            end
        end
        table.clear(threads)

        local unload = unloadCallback
        unloadCallback = nil
        saveCallback = nil

        if env[singletonKey] == controller then
            env[singletonKey] = nil
        end

        if gui and gui.Parent then
            pcall(function()
                gui:Destroy()
            end)
        end
        gui = nil

        if type(unload) == "function" then
            pcall(unload, reason or "destroy")
        end
    end

    gui = new("ScreenGui", {
        Name = "SaveInstancePath031026",
        ResetOnSpawn = false,
        IgnoreGuiInset = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = parent,
    })

    local protect = protectgui or (syn and syn.protect_gui)
    if type(protect) == "function" then
        pcall(protect, gui)
    end

    local toastHost = new("Frame", {
        Name = "Toasts",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -18, 0, 18),
        Size = UDim2.fromOffset(330, 420),
        BackgroundTransparency = 1,
        ZIndex = 50,
        Parent = gui,
    })

    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = toastHost,
    })

    local toastOrder = 0
    local function toast(kind, title, message, duration)
        if destroyed then
            return nil
        end

        kind = kind or "info"
        title = tostring(title or "Notice")
        message = tostring(message or "")
        duration = tonumber(duration) or 3.6
        toastOrder += 1

        local color = palette.accent
        if kind == "success" then
            color = palette.success
        elseif kind == "warning" then
            color = palette.warning
        elseif kind == "error" then
            color = palette.danger
        end

        local item = new("Frame", {
            LayoutOrder = toastOrder,
            Size = UDim2.fromOffset(0, 72),
            BackgroundColor3 = palette.card,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            ZIndex = 51,
            Parent = toastHost,
        })
        corner(item, 10)
        stroke(item, 0.25)

        new("Frame", {
            Size = UDim2.new(0, 4, 1, 0),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            ZIndex = 52,
            Parent = item,
        })

        new("TextLabel", {
            Position = UDim2.fromOffset(16, 10),
            Size = UDim2.new(1, -28, 0, 19),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            Text = title,
            TextColor3 = palette.text,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 52,
            Parent = item,
        })

        new("TextLabel", {
            Position = UDim2.fromOffset(16, 31),
            Size = UDim2.new(1, -28, 0, 29),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            Text = message,
            TextColor3 = palette.muted,
            TextSize = 10,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            ZIndex = 52,
            Parent = item,
        })

        tween(item, 0.22, {
            Size = UDim2.fromOffset(320, 72),
            BackgroundTransparency = 0,
        })

        delayTracked(duration, function()
            if item.Parent then
                tween(item, 0.2, {
                    Size = UDim2.fromOffset(0, 72),
                    BackgroundTransparency = 1,
                })
                delayTracked(0.22, function()
                    if item.Parent then
                        item:Destroy()
                    end
                end)
            end
        end)

        return item
    end

    local main = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(580, 650),
        BackgroundColor3 = palette.bg,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = gui,
    })
    corner(main, 14)
    stroke(main, 0.15)

    local header = new("Frame", {
        Size = UDim2.new(1, 0, 0, 70),
        BackgroundColor3 = palette.header,
        BorderSizePixel = 0,
        Parent = main,
    })

    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(18, 10),
        Size = UDim2.fromOffset(330, 23),
        Font = Enum.Font.GothamBold,
        Text = config.title or "Save Instance",
        TextSize = 19,
        TextColor3 = palette.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = header,
    })

    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(18, 35),
        Size = UDim2.fromOffset(390, 18),
        Font = Enum.Font.Gotham,
        Text = "Detected: " .. executorLabel,
        TextSize = 11,
        TextColor3 = palette.muted,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = header,
    })

    local status = new("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -54, 0.5, 0),
        Size = UDim2.fromOffset(92, 28),
        BackgroundColor3 = palette.success,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        Text = "READY",
        TextSize = 10,
        TextColor3 = Color3.new(1, 1, 1),
        Parent = header,
    })
    corner(status, 8)

    local close = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(30, 30),
        BackgroundColor3 = palette.card,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = Enum.Font.GothamBold,
        Text = "X",
        TextSize = 12,
        TextColor3 = palette.muted,
        Parent = header,
    })
    corner(close, 8)

    local scroll = new("ScrollingFrame", {
        Position = UDim2.fromOffset(0, 70),
        Size = UDim2.new(1, 0, 1, -70),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = palette.border,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = main,
    })

    new("UIPadding", {
        PaddingTop = UDim.new(0, 16),
        PaddingBottom = UDim.new(0, 18),
        PaddingLeft = UDim.new(0, 18),
        PaddingRight = UDim.new(0, 18),
        Parent = scroll,
    })

    new("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = scroll,
    })

    local order = 0
    local function nextOrder()
        order += 1
        return order
    end

    local function section(text)
        new("TextLabel", {
            LayoutOrder = nextOrder(),
            Size = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            Text = string.upper(text),
            TextSize = 10,
            TextColor3 = palette.muted,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = scroll,
        })
    end

    local function card(height)
        local frame = new("Frame", {
            LayoutOrder = nextOrder(),
            Size = UDim2.new(1, 0, 0, height),
            BackgroundColor3 = palette.card,
            BorderSizePixel = 0,
            Parent = scroll,
        })
        corner(frame, 11)
        stroke(frame, 0.42)
        return frame
    end

    local state = {
        binary = isVolt and true or config.binary ~= false,
        avoidOverwrite = config.avoidOverwrite ~= false,
        decompile = config.decompile ~= false,
        nilInstances = config.nilInstances == true,
        removePlayerCharacters = config.removePlayerCharacters == true,
        isolateStarterPlayer = config.isolateStarterPlayer == true,
        mode = config.mode or (isVolt and "full" or "optimized"),
    }

    section("Output")
    local outputCard = card(222)

    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 12),
        Size = UDim2.new(1, -28, 0, 17),
        Font = Enum.Font.GothamMedium,
        Text = executorName .. " workspace folder",
        TextSize = 12,
        TextColor3 = palette.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = outputCard,
    })

    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 31),
        Size = UDim2.new(1, -28, 0, 14),
        Font = Enum.Font.Gotham,
        Text = "Relative to the executor workspace. Leave blank for workspace root.",
        TextSize = 10,
        TextColor3 = palette.muted,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = outputCard,
    })

    local initialFolder = sanitizeFolder(config.defaultFolder or "Saves")
    local folderBox = new("TextBox", {
        Position = UDim2.fromOffset(14, 51),
        Size = UDim2.new(1, -28, 0, 43),
        BackgroundColor3 = palette.field,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Font = Enum.Font.Code,
        PlaceholderText = "Saves/MyGames",
        PlaceholderColor3 = palette.muted,
        Text = initialFolder,
        TextSize = 12,
        TextColor3 = palette.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = outputCard,
    })
    corner(folderBox, 9)
    stroke(folderBox, 0.35)
    new("UIPadding", {
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
        Parent = folderBox,
    })

    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 108),
        Size = UDim2.new(1, -28, 0, 17),
        Font = Enum.Font.GothamMedium,
        Text = "File name",
        TextSize = 12,
        TextColor3 = palette.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = outputCard,
    })

    local initialName = sanitizeName(config.defaultName or ((game.Name ~= "" and game.Name or "SavedGame") .. "-" .. tostring(game.PlaceId)))
    local fileBox = new("TextBox", {
        Position = UDim2.fromOffset(14, 133),
        Size = UDim2.new(1, -28, 0, 48),
        BackgroundColor3 = palette.field,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Font = Enum.Font.Gotham,
        PlaceholderText = "SavedGame-" .. tostring(game.PlaceId),
        PlaceholderColor3 = palette.muted,
        Text = initialName,
        TextSize = 13,
        TextColor3 = palette.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = outputCard,
    })
    corner(fileBox, 9)
    stroke(fileBox, 0.35)
    new("UIPadding", {
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
        Parent = fileBox,
    })

    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 190),
        Size = UDim2.new(1, -28, 0, 17),
        Font = Enum.Font.Gotham,
        Text = isVolt and "Volt only permits workspace-relative file paths." or "Save location is workspace-relative for compatibility.",
        TextSize = 10,
        TextColor3 = palette.muted,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = outputCard,
    })

    section("Mode")
    local modeCard = card(72)
    local modeHolder = new("Frame", {
        Position = UDim2.fromOffset(12, 12),
        Size = UDim2.new(1, -24, 1, -24),
        BackgroundColor3 = palette.field,
        BorderSizePixel = 0,
        Parent = modeCard,
    })
    corner(modeHolder, 9)

    new("UIPadding", {
        PaddingLeft = UDim.new(0, 6),
        PaddingRight = UDim.new(0, 6),
        PaddingTop = UDim.new(0, 6),
        PaddingBottom = UDim.new(0, 6),
        Parent = modeHolder,
    })

    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        Parent = modeHolder,
    })

    local modeButtons = {}
    local function refreshModes()
        for mode, button in pairs(modeButtons) do
            local selected = state.mode == mode
            tween(button, 0.15, {
                BackgroundColor3 = selected and palette.accent or palette.field,
                TextColor3 = selected and Color3.new(1, 1, 1) or palette.muted,
            })
        end
    end

    for _, info in ipairs({
        { "optimized", "Optimized" },
        { "full", "Full" },
        { "scripts", isVolt and "Scripts N/A" or "Scripts" },
    }) do
        local mode = info[1]
        local button = new("TextButton", {
            Size = UDim2.new(1 / 3, -8, 1, 0),
            BackgroundColor3 = mode == state.mode and palette.accent or palette.field,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = Enum.Font.GothamMedium,
            Text = info[2],
            TextSize = 12,
            TextColor3 = mode == state.mode and Color3.new(1, 1, 1) or palette.muted,
            Parent = modeHolder,
        })
        corner(button, 7)
        modeButtons[mode] = button

        bind(button.MouseButton1Click, function()
            if isVolt and mode == "scripts" then
                toast("warning", "Mode unavailable", "Volt's native saver does not expose scripts-only place serialization.", 4)
                return
            end

            state.mode = mode
            refreshModes()
        end)
    end

    local function listCard(height)
        local frame = card(height)
        new("UIPadding", {
            PaddingLeft = UDim.new(0, 14),
            PaddingRight = UDim.new(0, 14),
            PaddingTop = UDim.new(0, 8),
            PaddingBottom = UDim.new(0, 8),
            Parent = frame,
        })
        new("UIListLayout", {
            Padding = UDim.new(0, 2),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = frame,
        })
        return frame
    end

    local onToggleChanged = {}
    local function toggleRow(parentFrame, rowOrder, labelText, hintText, key, defaultValue, locked)
        state[key] = defaultValue

        local row = new("Frame", {
            LayoutOrder = rowOrder,
            Size = UDim2.new(1, 0, 0, 50),
            BackgroundTransparency = 1,
            Parent = parentFrame,
        })

        new("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, 5),
            Size = UDim2.new(1, -64, 0, 18),
            Font = Enum.Font.GothamMedium,
            Text = labelText,
            TextSize = 12,
            TextColor3 = locked and palette.muted or palette.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row,
        })

        new("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, 25),
            Size = UDim2.new(1, -64, 0, 15),
            Font = Enum.Font.Gotham,
            Text = hintText,
            TextSize = 10,
            TextColor3 = palette.muted,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = row,
        })

        local toggle = new("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(42, 24),
            BackgroundColor3 = defaultValue and palette.accent or palette.off,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            Parent = row,
        })
        corner(toggle, 12)

        local knob = new("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = defaultValue and UDim2.new(1, -21, 0.5, 0) or UDim2.fromOffset(3, 12),
            Size = UDim2.fromOffset(18, 18),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            Parent = toggle,
        })
        corner(knob, 9)

        bind(toggle.MouseButton1Click, function()
            if locked then
                toast("warning", "Option locked", hintText, 3.5)
                return
            end

            state[key] = not state[key]
            local enabled = state[key]
            tween(toggle, 0.15, { BackgroundColor3 = enabled and palette.accent or palette.off })
            tween(knob, 0.15, {
                Position = enabled and UDim2.new(1, -21, 0.5, 0) or UDim2.fromOffset(3, 12),
            })

            if onToggleChanged[key] then
                onToggleChanged[key](enabled)
            end
        end)
    end

    section("Format")
    local formatCard = listCard(116)
    toggleRow(
        formatCard,
        1,
        "Binary format",
        isVolt and "Volt native saveinstance writes binary place files." or "Use .rbxl instead of XML .rbxlx",
        "binary",
        state.binary,
        isVolt
    )
    toggleRow(formatCard, 2, "Avoid overwrite", "Choose a numbered filename when one already exists", "avoidOverwrite", state.avoidOverwrite, false)

    section("Content")
    local contentCard = listCard(220)
    toggleRow(contentCard, 1, "Decompile scripts", "Request script source when supported", "decompile", state.decompile, false)
    toggleRow(contentCard, 2, "Nil instances", "Include supported nil-parented instances", "nilInstances", state.nilInstances, false)
    toggleRow(contentCard, 3, "Remove player characters", "Exclude player character models", "removePlayerCharacters", state.removePlayerCharacters, false)
    toggleRow(contentCard, 4, "Isolate StarterPlayer", "May be ignored by native executor serializers", "isolateStarterPlayer", state.isolateStarterPlayer, false)

    section("Save")
    local actionCard = card(162)

    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 11),
        Size = UDim2.new(1, -28, 0, 17),
        Font = Enum.Font.GothamMedium,
        Text = "Output path",
        TextSize = 11,
        TextColor3 = palette.muted,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = actionCard,
    })

    local pathValue = new("TextLabel", {
        BackgroundColor3 = palette.field,
        Position = UDim2.fromOffset(14, 35),
        Size = UDim2.new(1, -28, 0, 42),
        BorderSizePixel = 0,
        Font = Enum.Font.Code,
        TextSize = 11,
        TextColor3 = palette.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = actionCard,
    })
    corner(pathValue, 8)
    new("UIPadding", {
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
        Parent = pathValue,
    })

    local detail = new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 84),
        Size = UDim2.new(1, -28, 0, 20),
        Font = Enum.Font.Gotham,
        Text = "Ready. Output is relative to " .. executorName .. "'s workspace.",
        TextSize = 10,
        TextColor3 = palette.muted,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = actionCard,
    })

    local saveButton = new("TextButton", {
        Position = UDim2.new(0, 14, 1, -46),
        Size = UDim2.new(1, -28, 0, 36),
        BackgroundColor3 = palette.accent,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        ClipsDescendants = true,
        Parent = actionCard,
    })
    corner(saveButton, 9)

    local progressFill = new("Frame", {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = palette.accent,
        BorderSizePixel = 0,
        ZIndex = saveButton.ZIndex + 1,
        Parent = saveButton,
    })

    local saveLabel = new("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = "Save instance",
        TextSize = 12,
        TextColor3 = Color3.new(1, 1, 1),
        ZIndex = saveButton.ZIndex + 2,
        Parent = saveButton,
    })

    local function currentPath()
        local folder = sanitizeFolder(folderBox.Text)
        local filename = sanitizeName(fileBox.Text) .. (state.binary and ".rbxl" or ".rbxlx")

        if folder == "" then
            return filename
        end

        return folder .. "/" .. filename
    end

    local function refreshPath()
        if destroyed then
            return
        end
        pathValue.Text = currentPath()
    end

    bind(folderBox.FocusLost, function()
        folderBox.Text = sanitizeFolder(folderBox.Text)
        refreshPath()
    end)

    bind(fileBox.FocusLost, function()
        fileBox.Text = sanitizeName(fileBox.Text)
        refreshPath()
    end)

    onToggleChanged.binary = refreshPath
    refreshPath()

    local function setStatus(text, kind, message)
        if destroyed then
            return
        end

        kind = kind or "success"
        local color = palette.success
        if kind == "warning" then
            color = palette.warning
        elseif kind == "error" then
            color = palette.danger
        elseif kind == "busy" then
            color = palette.accent
        end

        status.Text = string.upper(tostring(text or "READY"))
        tween(status, 0.15, { BackgroundColor3 = color })
        if message then
            detail.Text = tostring(message)
        end
    end

    local progress = 0
    local function setProgress(value, label, color)
        if destroyed then
            return
        end

        value = math.clamp(tonumber(value) or 0, 0, 1)
        progress = value

        if color then
            progressFill.BackgroundColor3 = color
        end

        tween(progressFill, 0.22, { Size = UDim2.fromScale(value, 1) })
        if label then
            saveLabel.Text = tostring(label)
        else
            saveLabel.Text = string.format("Saving... %d%%", math.floor(value * 100 + 0.5))
        end
    end

    local function resetButton()
        if destroyed then
            return
        end

        runId += 1
        progress = 0
        progressFill.Size = UDim2.fromScale(0, 1)
        progressFill.BackgroundColor3 = palette.accent
        saveButton.BackgroundColor3 = palette.accent
        saveLabel.Text = "Save instance"
    end

    local function buildOptions()
        return {
            FilePath = currentPath(),
            FolderPath = sanitizeFolder(folderBox.Text),
            ExecutorName = executorName,
            ExecutorVersion = executorVersion,
            Binary = state.binary,
            AvoidFileOverwrite = state.avoidOverwrite,
            Decompile = state.decompile,
            NilInstances = state.nilInstances,
            RemovePlayerCharacters = state.removePlayerCharacters,
            IsolateStarterPlayer = state.isolateStarterPlayer,
            ShowStatus = false,
            mode = state.mode,
        }
    end

    bind(saveButton.MouseButton1Click, function()
        if busy then
            toast("warning", "Save already running", "Wait for the current save operation to finish.", 2.5)
            return
        end

        if type(saveCallback) ~= "function" then
            toast("error", "Save unavailable", "The save callback is no longer available.", 4)
            return
        end

        folderBox.Text = sanitizeFolder(folderBox.Text)
        fileBox.Text = sanitizeName(fileBox.Text)
        refreshPath()

        local options = buildOptions()
        busy = true
        runId += 1
        local thisRun = runId

        saveButton.BackgroundColor3 = palette.field
        progressFill.BackgroundColor3 = palette.accent
        setProgress(0.04, "Preparing... 4%")
        setStatus("Saving", "busy", "Preparing " .. options.FilePath)

        spawnTracked(function()
            local target = 0.12
            while not destroyed and busy and runId == thisRun and progress < 0.88 do
                target = math.min(0.88, math.max(target, progress + 0.025))
                setProgress(target, string.format("Saving... %d%%", math.floor(target * 100 + 0.5)))
                task.wait(0.42)
            end
        end)

        spawnTracked(function()
            setProgress(0.09, "Preparing... 9%")
            task.wait()

            if destroyed or runId ~= thisRun then
                return
            end

            setProgress(0.14, "Serializing... 14%")

            local callback = saveCallback
            if type(callback) ~= "function" then
                busy = false
                setProgress(math.max(progress, 0.14), "Save failed", palette.danger)
                setStatus("Failed", "error", "Save callback was unloaded.")
                toast("error", "Save failed", "Save callback was unloaded.", 5)
                return
            end

            local ok, result = pcall(callback, options, setStatus, setProgress, toast)
            if destroyed or runId ~= thisRun then
                return
            end

            busy = false
            if ok then
                local savedPath = type(result) == "string" and result or options.FilePath
                setProgress(1, "Saved successfully", palette.success)
                setStatus("Finished", "success", "Saved " .. savedPath)
                toast("success", "Save complete", savedPath .. " was written successfully.", 4)

                delayTracked(1.4, function()
                    if runId == thisRun then
                        resetButton()
                        setStatus("Ready", "success", "Ready for another save.")
                    end
                end)
            else
                local errorText = tostring(result)
                progressFill.BackgroundColor3 = palette.danger
                setProgress(math.max(progress, 0.12), "Save failed", palette.danger)
                setStatus("Failed", "error", errorText:sub(1, 180))
                toast("error", "Save failed", errorText:sub(1, 220), 6)

                delayTracked(2.2, function()
                    if runId == thisRun then
                        resetButton()
                        setStatus("Ready", "success", "Fix the error and try again.")
                    end
                end)
            end
        end)
    end)

    bind(saveButton.MouseEnter, function()
        if not busy then
            tween(saveButton, 0.12, { BackgroundColor3 = palette.accentHover })
        end
    end)

    bind(saveButton.MouseLeave, function()
        if not busy then
            tween(saveButton, 0.12, { BackgroundColor3 = palette.accent })
        end
    end)

    bind(close.MouseButton1Click, function()
        destroy("close")
    end)

    bind(close.MouseEnter, function()
        tween(close, 0.12, {
            BackgroundColor3 = palette.danger,
            TextColor3 = Color3.new(1, 1, 1),
        })
    end)

    bind(close.MouseLeave, function()
        tween(close, 0.12, {
            BackgroundColor3 = palette.card,
            TextColor3 = palette.muted,
        })
    end)

    local dragging = false
    local dragInput
    local dragStart
    local startPosition

    bind(header.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = main.Position

            local endedConnection
            endedConnection = input.Changed:Connect(function()
                if destroyed or input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if endedConnection and endedConnection.Connected then
                        endedConnection:Disconnect()
                    end
                end
            end)
            connections[#connections + 1] = endedConnection
        end
    end)

    bind(header.InputChanged, function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    bind(UserInputService.InputChanged, function(input)
        if dragging and input == dragInput and dragStart and startPosition then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
        end
    end)

    main.BackgroundTransparency = 1
    main.Size = UDim2.fromOffset(560, 630)
    tween(main, 0.25, {
        BackgroundTransparency = 0,
        Size = UDim2.fromOffset(580, 650),
    })

    controller = {
        Gui = gui,
        SetStatus = setStatus,
        SetProgress = setProgress,
        Toast = toast,
        GetOptions = buildOptions,
        GetExecutor = function()
            return executorName, executorVersion
        end,
        GetFolder = function()
            return sanitizeFolder(folderBox.Text)
        end,
        SetFolder = function(value)
            if destroyed then
                return
            end
            folderBox.Text = sanitizeFolder(value)
            refreshPath()
        end,
        IsDestroyed = function()
            return destroyed
        end,
        Destroy = destroy,
    }

    env[singletonKey] = controller

    if isVolt then
        toast("success", "Volt detected", "Folder paths are relative to Volt's workspace.", 4)
    else
        toast("success", "Executor detected", executorLabel .. " workspace path mode enabled.", 4)
    end

    return controller
end
