-- SaveInstance UI shell
-- UI only. Supply your own onSave callback.
-- Uses relative output names so the caller can keep writes inside its allowed workspace.

return function(config)
    config = config or {}
    assert(type(config.onSave) == "function", "SaveInstanceUI requires config.onSave(options, setStatus)")

    local Players = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")

    local player = Players.LocalPlayer
    local parent = config.parent or (player and player:WaitForChild("PlayerGui"))
    assert(parent, "No GUI parent available")

    local palette = {
        bg = Color3.fromRGB(16, 17, 22),
        bar = Color3.fromRGB(20, 21, 27),
        card = Color3.fromRGB(27, 29, 37),
        field = Color3.fromRGB(34, 36, 46),
        border = Color3.fromRGB(52, 55, 68),
        text = Color3.fromRGB(239, 241, 247),
        muted = Color3.fromRGB(145, 150, 166),
        accent = Color3.fromRGB(91, 105, 255),
        accentHover = Color3.fromRGB(108, 121, 255),
        success = Color3.fromRGB(62, 181, 124),
        warning = Color3.fromRGB(219, 158, 64),
        danger = Color3.fromRGB(219, 78, 87),
        off = Color3.fromRGB(66, 69, 82),
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

    local function animate(object, duration, props)
        local info = TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        local t = TweenService:Create(object, info, props)
        t:Play()
        return t
    end

    local function sanitize(value)
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

    local existing = parent:FindFirstChild("SaveInstanceUI031026")
    if existing then
        existing:Destroy()
    end

    local gui = new("ScreenGui", {
        Name = "SaveInstanceUI031026",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = parent,
    })

    local main = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(560, 610),
        BackgroundColor3 = palette.bg,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = gui,
    })
    corner(main, 14)
    stroke(main, 0.15)

    local bar = new("Frame", {
        Size = UDim2.new(1, 0, 0, 64),
        BackgroundColor3 = palette.bar,
        BorderSizePixel = 0,
        Parent = main,
    })

    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(18, 10),
        Size = UDim2.fromOffset(300, 23),
        Font = Enum.Font.GothamBold,
        Text = config.title or "Save Instance",
        TextSize = 19,
        TextColor3 = palette.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = bar,
    })

    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(18, 34),
        Size = UDim2.fromOffset(330, 17),
        Font = Enum.Font.Gotham,
        Text = "Clean save configuration panel",
        TextSize = 11,
        TextColor3 = palette.muted,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = bar,
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
        Parent = bar,
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
        Parent = bar,
    })
    corner(close, 8)

    local scroll = new("ScrollingFrame", {
        Position = UDim2.fromOffset(0, 64),
        Size = UDim2.new(1, 0, 1, -64),
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
        binary = true,
        avoidOverwrite = true,
        decompile = true,
        nilInstances = false,
        removePlayerCharacters = false,
        isolateStarterPlayer = false,
        mode = "optimized",
    }

    section("Output")
    local outputCard = card(108)

    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 12),
        Size = UDim2.new(1, -28, 0, 17),
        Font = Enum.Font.GothamMedium,
        Text = "File name",
        TextSize = 12,
        TextColor3 = palette.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = outputCard,
    })

    local initialName = sanitize(config.defaultName or ((game.Name ~= "" and game.Name or "SavedGame") .. "-" .. tostring(game.PlaceId)))
    local fileBox = new("TextBox", {
        Position = UDim2.fromOffset(14, 39),
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
            animate(button, 0.15, {
                BackgroundColor3 = selected and palette.accent or palette.field,
                TextColor3 = selected and Color3.new(1, 1, 1) or palette.muted,
            })
        end
    end

    for _, info in ipairs({
        { "optimized", "Optimized" },
        { "full", "Full" },
        { "scripts", "Scripts" },
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
        button.MouseButton1Click:Connect(function()
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
    local function toggleRow(parentFrame, rowOrder, labelText, hintText, key, defaultValue)
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
            TextColor3 = palette.text,
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

        toggle.MouseButton1Click:Connect(function()
            state[key] = not state[key]
            local enabled = state[key]
            animate(toggle, 0.15, { BackgroundColor3 = enabled and palette.accent or palette.off })
            animate(knob, 0.15, {
                Position = enabled and UDim2.new(1, -21, 0.5, 0) or UDim2.fromOffset(3, 12),
            })
            if onToggleChanged[key] then
                onToggleChanged[key](enabled)
            end
        end)
    end

    section("Format")
    local formatCard = listCard(116)
    toggleRow(formatCard, 1, "Binary format", "Use .rbxl instead of XML .rbxlx", "binary", true)
    toggleRow(formatCard, 2, "Avoid overwrite", "Ask the save callback not to replace an existing file", "avoidOverwrite", true)

    section("Content")
    local contentCard = listCard(220)
    toggleRow(contentCard, 1, "Decompile scripts", "Request script source when supported", "decompile", true)
    toggleRow(contentCard, 2, "Nil instances", "Include supported nil-parented instances", "nilInstances", false)
    toggleRow(contentCard, 3, "Remove player characters", "Exclude player character models", "removePlayerCharacters", false)
    toggleRow(contentCard, 4, "Isolate StarterPlayer", "Enable StarterPlayer isolation", "isolateStarterPlayer", false)

    section("Save")
    local actionCard = card(150)

    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 11),
        Size = UDim2.new(1, -28, 0, 17),
        Font = Enum.Font.GothamMedium,
        Text = "Relative output path",
        TextSize = 11,
        TextColor3 = palette.muted,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = actionCard,
    })

    local pathValue = new("TextLabel", {
        BackgroundColor3 = palette.field,
        Position = UDim2.fromOffset(14, 35),
        Size = UDim2.new(1, -28, 0, 37),
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
        Position = UDim2.fromOffset(14, 79),
        Size = UDim2.new(1, -28, 0, 18),
        Font = Enum.Font.Gotham,
        Text = "Ready to pass options to your save callback.",
        TextSize = 10,
        TextColor3 = palette.muted,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = actionCard,
    })

    local saveButton = new("TextButton", {
        Position = UDim2.new(0, 14, 1, -44),
        Size = UDim2.new(1, -28, 0, 34),
        BackgroundColor3 = palette.accent,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = Enum.Font.GothamBold,
        Text = "Save instance",
        TextSize = 12,
        TextColor3 = Color3.new(1, 1, 1),
        Parent = actionCard,
    })
    corner(saveButton, 9)

    local function currentPath()
        return sanitize(fileBox.Text) .. (state.binary and ".rbxl" or ".rbxlx")
    end

    local function refreshPath()
        pathValue.Text = currentPath()
    end

    fileBox.FocusLost:Connect(function()
        fileBox.Text = sanitize(fileBox.Text)
        refreshPath()
    end)
    onToggleChanged.binary = refreshPath
    refreshPath()

    local function setStatus(text, kind, message)
        local color = palette.success
        if kind == "warning" then
            color = palette.warning
        elseif kind == "error" then
            color = palette.danger
        elseif kind == "busy" then
            color = palette.accent
        end
        status.Text = string.upper(tostring(text or "READY"))
        animate(status, 0.15, { BackgroundColor3 = color })
        if message then
            detail.Text = tostring(message)
        end
    end

    local busy = false
    saveButton.MouseButton1Click:Connect(function()
        if busy then
            return
        end

        fileBox.Text = sanitize(fileBox.Text)
        refreshPath()

        local options = {
            FilePath = currentPath(),
            Binary = state.binary,
            AvoidFileOverwrite = state.avoidOverwrite,
            Decompile = state.decompile,
            NilInstances = state.nilInstances,
            RemovePlayerCharacters = state.removePlayerCharacters,
            IsolateStarterPlayer = state.isolateStarterPlayer,
            ShowStatus = false,
            mode = state.mode,
        }

        busy = true
        saveButton.Text = "Saving..."
        animate(saveButton, 0.15, { BackgroundColor3 = palette.off })
        setStatus("Saving", "busy", "The callback is processing " .. options.FilePath)

        task.spawn(function()
            local ok, err = pcall(config.onSave, options, setStatus)
            busy = false
            saveButton.Text = "Save instance"
            animate(saveButton, 0.15, { BackgroundColor3 = palette.accent })

            if not ok then
                setStatus("Failed", "error", tostring(err):sub(1, 160))
            elseif status.Text == "SAVING" then
                setStatus("Finished", "success", "The callback finished. Verify the output file in the configured workspace.")
            end
        end)
    end)

    saveButton.MouseEnter:Connect(function()
        if not busy then
            animate(saveButton, 0.12, { BackgroundColor3 = palette.accentHover })
        end
    end)

    saveButton.MouseLeave:Connect(function()
        if not busy then
            animate(saveButton, 0.12, { BackgroundColor3 = palette.accent })
        end
    end)

    close.MouseButton1Click:Connect(function()
        gui:Destroy()
    end)

    close.MouseEnter:Connect(function()
        animate(close, 0.12, { BackgroundColor3 = palette.danger, TextColor3 = Color3.new(1, 1, 1) })
    end)

    close.MouseLeave:Connect(function()
        animate(close, 0.12, { BackgroundColor3 = palette.card, TextColor3 = palette.muted })
    end)

    local dragging = false
    local dragInput
    local dragStart
    local startPosition

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    bar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
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
    main.Size = UDim2.fromOffset(540, 590)
    animate(main, 0.25, {
        BackgroundTransparency = 0,
        Size = UDim2.fromOffset(560, 610),
    })

    return {
        Gui = gui,
        SetStatus = setStatus,
        GetOptions = function()
            return {
                FilePath = currentPath(),
                Binary = state.binary,
                AvoidFileOverwrite = state.avoidOverwrite,
                Decompile = state.decompile,
                NilInstances = state.nilInstances,
                RemovePlayerCharacters = state.removePlayerCharacters,
                IsolateStarterPlayer = state.isolateStarterPlayer,
                ShowStatus = false,
                mode = state.mode,
            }
        end,
    }
end
