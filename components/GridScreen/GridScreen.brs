' GridScreen.brs - Performance-optimized grid with efficient focus management
' Optimizations: reduced field observations, efficient string building.
' Smart back navigation: back from a row jumps to its first item, back
' from (0, 0) opens an exit confirmation dialog. Back again dismisses
' the dialog, OK on the dialog button exits the app.

sub Init()
    m.rowList = SafeFindNode(m.top, "rowList")
    m.descriptionLabel = SafeFindNode(m.top, "descriptionLabel")
    SafeObserveField(m.top, "visible", "OnVisibleChange")
    m.titleLabel = SafeFindNode(m.top, "titleLabel")
    if m.rowList <> invalid
        SafeObserveField(m.rowList, "rowItemFocused", "OnItemFocused")
        SafeObserveField(m.rowList, "rowItemSelected", "OnRowItemSelected")
    end if

    SafeObserveField(m.top, "cardStyleChanged", "OnCardStyleChanged")

    ' Defer ConfigManager lookup until node is attached to scene (OnVisibleChange)
    m.configManager = invalid
    m.cardStyleSynced = false

    ' Exit confirmation dialog
    m.exitDialog = SafeFindNode(m.top, "exitDialog")
    m.exitButton = SafeFindNode(m.top, "exitButton")
    if m.exitButton <> invalid
        SafeObserveField(m.exitButton, "exitRequested", "OnExitRequested")
    end if
    m.dialogVisible = false
    m.preDialogFocusedIndex = invalid
    m.focusTimer = invalid
    m.exiting = false
end sub

sub OnVisibleChange()
    try
        if m.top.visible = true
            if m.rowList <> invalid
                ' Ensure rowList has content before setting focus
                if m.rowList.content <> invalid and m.rowList.content.GetChildCount() > 0
                    m.rowList.SetFocus(true)
                    ' Verify focus landed on the rowList (not some ancestor)
                    Sleep(30)
                    focused = SafeNodeGetFocus(m.rowList)
                    if focused = invalid
                        ' Focus didn't land on rowList — force jump to first item
                        m.rowList.jumpToRowItem = [0, 0]
                        m.rowList.SetFocus(true)
                    end if
                end if
            end if

            ' Defer ConfigManager lookup until node is attached to scene
            if m.configManager = invalid
                m.configManager = FindConfigManager()
            end if
            if m.configManager <> invalid and not m.cardStyleSynced
                ObserveConfigCardStyleFields()
                SyncCardStyleFromConfig()
                m.cardStyleSynced = true
            end if
        end if
    catch e
        LogError("GridScreen", "OnVisibleChange: " + e.message)
    end try
end sub

' Set up field observations on ConfigManager cardStyle fields
sub ObserveConfigCardStyleFields()
    try
        if m.configManager = invalid then return
        SafeObserveField(m.configManager, "cardShowTitle", "OnConfigCardStyleChanged")
        SafeObserveField(m.configManager, "cardShowDescription", "OnConfigCardStyleChanged")
        SafeObserveField(m.configManager, "cardTitleFont", "OnConfigCardStyleChanged")
        SafeObserveField(m.configManager, "cardDescriptionFont", "OnConfigCardStyleChanged")
        SafeObserveField(m.configManager, "cardTitleColor", "OnConfigCardStyleChanged")
        SafeObserveField(m.configManager, "cardDescriptionColor", "OnConfigCardStyleChanged")
        SafeObserveField(m.configManager, "cardTitleNumLines", "OnConfigCardStyleChanged")
        SafeObserveField(m.configManager, "cardDescriptionNumLines", "OnConfigCardStyleChanged")
        SafeObserveField(m.configManager, "detailShowTitle", "OnConfigCardStyleChanged")
        SafeObserveField(m.configManager, "detailShowDescription", "OnConfigCardStyleChanged")
        SafeObserveField(m.configManager, "detailTitleFont", "OnConfigCardStyleChanged")
        SafeObserveField(m.configManager, "detailDescriptionFont", "OnConfigCardStyleChanged")
        SafeObserveField(m.configManager, "detailTitleColor", "OnConfigCardStyleChanged")
        SafeObserveField(m.configManager, "detailDescriptionColor", "OnConfigCardStyleChanged")
        SafeObserveField(m.configManager, "detailTitleNumLines", "OnConfigCardStyleChanged")
        SafeObserveField(m.configManager, "detailDescriptionNumLines", "OnConfigCardStyleChanged")
    catch e
        LogError("GridScreen", "ObserveConfigCardStyleFields: " + e.message)
    end try
end sub

' Find ConfigManager in the scene
function FindConfigManager () as object
    scene = SafeGetScene(m.top)
    if scene = invalid then return invalid
    configManager = SafeFindNode(scene, "configManager")
    if configManager <> invalid then return configManager
    return invalid
end function

' Sync cardStyle from ConfigManager to global node for ContentCard access
sub SyncCardStyleFromConfig()
    try
        if m.configManager = invalid then return
        global = m.global
        if global = invalid then return

        ' Ensure fields exist on global before writing (addFields is idempotent)
        global.addFields({
            cardShowTitle: false, cardShowDescription: false,
            cardTitleFont: "", cardDescriptionFont: "",
            cardTitleColor: "0x000000", cardDescriptionColor: "0x000000",
            cardTitleNumLines: 1, cardDescriptionNumLines: 1,
            detailShowTitle: false, detailShowDescription: false,
            detailTitleFont: "", detailDescriptionFont: "",
            detailTitleColor: "0x000000", detailDescriptionColor: "0x000000",
            detailTitleNumLines: 1, detailDescriptionNumLines: 1
        })

        global.cardShowTitle = m.configManager.cardShowTitle
        global.cardShowDescription = m.configManager.cardShowDescription
        global.cardTitleFont = m.configManager.cardTitleFont
        global.cardDescriptionFont = m.configManager.cardDescriptionFont
        global.cardTitleColor = m.configManager.cardTitleColor
        global.cardDescriptionColor = m.configManager.cardDescriptionColor
        global.cardTitleNumLines = m.configManager.cardTitleNumLines
        global.cardDescriptionNumLines = m.configManager.cardDescriptionNumLines
        global.detailShowTitle = m.configManager.detailShowTitle
        global.detailShowDescription = m.configManager.detailShowDescription
        global.detailTitleFont = m.configManager.detailTitleFont
        global.detailDescriptionFont = m.configManager.detailDescriptionFont
        global.detailTitleColor = m.configManager.detailTitleColor
        global.detailDescriptionColor = m.configManager.detailDescriptionColor
        global.detailTitleNumLines = m.configManager.detailTitleNumLines
        global.detailDescriptionNumLines = m.configManager.detailDescriptionNumLines
        ApplyCardStyleToDetailLabels()
    catch e
        LogError("GridScreen", "SyncCardStyleFromConfig: " + e.message)
    end try
end sub

' Handle ConfigManager cardStyle field changes
sub OnConfigCardStyleChanged()
    SyncCardStyleFromConfig()
    m.top.cardStyleChanged = not m.top.cardStyleChanged
end sub

' Handle cardStyleChanged signal (for ContentCard re-apply)
sub OnCardStyleChanged()
    ' Re-apply detail labels in case content was already set
    ApplyCardStyleToDetailLabels()
end sub

' Apply cardStyle to GridScreen's detail labels
sub ApplyCardStyleToDetailLabels()
    try
        global = m.global
        if global = invalid then return
        if NodeHasField(global, "detailShowTitle")
            if global.detailShowTitle <> invalid and m.titleLabel <> invalid
                m.titleLabel.visible = global.detailShowTitle
            end if
            if global.detailShowDescription <> invalid and m.descriptionLabel <> invalid
                m.descriptionLabel.visible = global.detailShowDescription
            end if
            if global.detailTitleFont <> invalid and m.titleLabel <> invalid
                ApplySceneGraphFont(m.titleLabel, global.detailTitleFont)
            end if
            if global.detailDescriptionFont <> invalid and m.descriptionLabel <> invalid
                ApplySceneGraphFont(m.descriptionLabel, global.detailDescriptionFont)
            end if
            if global.detailTitleColor <> invalid and m.titleLabel <> invalid
                m.titleLabel.color = global.detailTitleColor
            end if
            if global.detailDescriptionColor <> invalid and m.descriptionLabel <> invalid
                m.descriptionLabel.color = global.detailDescriptionColor
            end if
            if global.detailTitleNumLines <> invalid and m.titleLabel <> invalid
                m.titleLabel.numLines = global.detailTitleNumLines
            end if
            if global.detailDescriptionNumLines <> invalid and m.descriptionLabel <> invalid
                m.descriptionLabel.numLines = global.detailDescriptionNumLines
            end if
        end if
    catch e
        LogError("GridScreen", "ApplyCardStyleToDetailLabels: " + e.message)
    end try
end sub

' Helper: apply font string to a SceneGraph label
sub ApplySceneGraphFont(label, fontName)
    if label = invalid or fontName = invalid or fontName = "" then return
    if GetInterface(fontName, "ifString") <> invalid
        label.font = fontName
    end if
end sub

' Intercept back for grid navigation and the exit dialog, and OK for the
' exit button. Returns true to consume the event.
' HARDENED: never returns false on back — always ensures focus is assigned.
function OnKeyEvent (key, press) as boolean
    try
        if not press then return false

        if LCase(key) = "back"
            ' If the dialog is open, back dismisses it (does NOT exit the app)
            if m.dialogVisible
                HideExitDialog()
                return true
            end if

            if m.rowList = invalid then return false

            focusedIndex = m.rowList.rowItemFocused

            ' HARDENED: If rowItemFocused is invalid or incomplete, force focus
            ' to a known valid position before processing back navigation.
            ' This prevents the case where the RowList has focus but no specific
            ' item is focused (e.g., after video exit restores visibility).
            if focusedIndex = invalid or focusedIndex.Count() < 2
                m.rowList.jumpToRowItem = [0, 0]
                m.rowList.SetFocus(true)
                return true
            end if

            rowIdx = focusedIndex[0]
            itemIdx = focusedIndex[1]

            if itemIdx > 0
                ' Back from any non-first item: jump to first item of current row
                m.rowList.jumpToRowItem = [rowIdx, 0]
                return true
            else if rowIdx > 0
                ' Back from first item of a non-first row: jump to (0, 0)
                m.rowList.jumpToRowItem = [0, 0]
                return true
            else
                ' Back from (0, 0): show the exit confirmation dialog
                ShowExitDialog()
                return true
            end if
        end if

        if LCase(key) = "ok" and m.dialogVisible
            ' OK while dialog is visible: close the channel via event.
            ' Do NOT call getParent().close() — crashes when GridScreen is
            ' nested inside LeftNavScreen contentPanel (Group has no close()).
            HideExitDialog()
            CloseChannel()
            return true
        end if
    catch e
        LogError("GridScreen", "OnKeyEvent: " + e.message)
    end try

    return false
end function

sub ShowExitDialog()
    try
        ' Remember the current focus so we can restore it on dismiss
        m.preDialogFocusedIndex = m.rowList.rowItemFocused

        ' Hide the rowList so its focus indicator is not visible behind the dialog
        m.rowList.visible = false

        ' Clear focus from rowList immediately so it doesn't consume key events
        ' (e.g., OK) while the dialog is visible. Without this, a hidden but
        ' still-focused rowList will swallow the OK press before it reaches
        ' GridScreen's OnKeyEvent.
        m.rowList.SetFocus(false)

        m.exitDialog.visible = true
        m.dialogVisible = true

        ' SetFocus is racy if called in the same tick as the visibility changes
        ' above — Roku's focus system may not have processed the rowList
        ' being hidden yet, and focus can fall back to the Overhang. Defer
        ' the focus call to the next tick so the exit button is the only
        ' visible focusable target when SetFocus runs.
        if m.focusTimer <> invalid
            m.focusTimer.control = "stop"
            m.focusTimer = invalid
        end if
        m.focusTimer = CreateObject("roSGNode", "Timer")
        m.focusTimer.duration = 0.05
        m.focusTimer.ObserveField("fire", "OnExitDialogFocusTimer")
        m.focusTimer.control = "start"

        LogInfo("GridScreen", "Exit dialog shown")
    catch e
        LogError("GridScreen", "ShowExitDialog: " + e.message)
    end try
end sub

sub OnExitDialogFocusTimer()
    try
        if m.focusTimer <> invalid
            m.focusTimer.control = "stop"
            m.focusTimer.UnobserveField("fire")
            m.focusTimer = invalid
        end if
        if m.exitButton <> invalid
            m.exitButton.SetFocus(true)
        else
            ' Fallback: if exitButton is invalid, restore focus to rowList
            ' to guarantee focus is never lost
            m.rowList.visible = true
            m.rowList.SetFocus(true)
            m.dialogVisible = false
            LogWarn("GridScreen", "OnExitDialogFocusTimer: exitButton invalid, restored rowList focus")
        end if
    catch e
        LogError("GridScreen", "OnExitDialogFocusTimer: " + e.message)
    end try
end sub

sub HideExitDialog()
    try
        m.exitDialog.visible = false
        m.dialogVisible = false

        ' Reset exiting flag so CloseChannel can be retried after a dismissed dialog
        m.exiting = false

        ' Restore rowList visibility and focus
        m.rowList.visible = true
        if m.preDialogFocusedIndex <> invalid
            m.rowList.jumpToRowItem = m.preDialogFocusedIndex
        end if
        m.rowList.SetFocus(true)

        ' Verify focus landed
        Sleep(50)
        if SafeNodeGetFocus(m.rowList) = invalid
            ' Fallback: force focus to first item
            m.rowList.jumpToRowItem = [0, 0]
            m.rowList.SetFocus(true)
        end if

        LogInfo("GridScreen", "Exit dialog dismissed")
    catch e
        LogError("GridScreen", "HideExitDialog: " + e.message)
    end try
end sub

' Handle exitRequested event from the exit button component
sub OnExitRequested()
    m.exitButton.exitRequested = false
    LogInfo("GridScreen", "Exit requested from exit button")
    HideExitDialog()
    CloseChannel()
end sub

' Close the channel by firing the close event on m.top, which MainScene
' observes and closes the roSGScreen.
sub CloseChannel()
    if m.exiting then return
    m.exiting = true
    LogInfo("GridScreen", "User confirmed exit, closing channel")
    m.top.close = true
end sub

' ExitApp: alias for CloseChannel, called when user confirms exit via OK key.
sub ExitApp()
    CloseChannel()
end sub

sub OnItemFocused()
    try
        focusedIndex = m.rowList.rowItemFocused
        if focusedIndex = invalid or focusedIndex.Count() < 2
            return
        end if

        row = m.rowList.content.GetChild(focusedIndex[0])
        if row = invalid then return

        item = row.GetChild(focusedIndex[1])
        if item = invalid then return

        ' Update title label efficiently
        if item.title <> invalid
            titleText = item.title
            if item.length <> invalid
                formattedTime = GetCachedTime(item.length)
                titleText += " | " + formattedTime
            end if
            m.titleLabel.text = titleText
        else
            m.titleLabel.text = ""
        end if

        ' Update description label
        if item.description <> invalid
            m.descriptionLabel.text = item.description
        else
            m.descriptionLabel.text = ""
        end if
    catch e
        LogError("GridScreen", "OnItemFocused: " + e.message)
    end try
end sub

' Format seconds to mm:ss, returning empty string for invalid input
function GetCachedTime (length) as string
    if length = invalid then return ""
    return FormatTime(length)
end function

' Convert seconds to mm:ss format
function FormatTime (length) as string
    return FormatDuration(length)
end function

' Handle row item selection - fire play to trigger playback
sub OnRowItemSelected()
    try
        m.top.play = true
    catch e
        LogError("GridScreen", "OnRowItemSelected: " + e.message)
    end try
end sub

' OnExit handler - cleanup resources when screen exits
sub OnExit()
    LogInfo("GridScreen", "OnExit: Cleaning up resources")

    ' Clean up rowList observers
    if m.rowList <> invalid
        try
            m.rowList.UnobserveField("rowItemFocused")
            m.rowList.UnobserveField("rowItemSelected")
        catch e
            LogError("GridScreen", "OnExit: rowList UnobserveField failed: " + e.message)
        end try
    end if

    ' Clean up top-level field observers
    try
        m.top.UnobserveField("visible")
        m.top.UnobserveField("cardStyleChanged")
    catch e
        LogError("GridScreen", "OnExit: top UnobserveField failed: " + e.message)
    end try

    ' Clean up exit button observer
    if m.exitButton <> invalid
        try
            m.exitButton.UnobserveField("exitRequested")
        catch e
            LogError("GridScreen", "OnExit: exitButton UnobserveField failed: " + e.message)
        end try
    end if

    ' Clean up configManager observers (unobserve from all 16 cardStyle fields)
    if m.configManager <> invalid
        try
            m.configManager.UnobserveField("cardShowTitle")
            m.configManager.UnobserveField("cardShowDescription")
            m.configManager.UnobserveField("cardTitleFont")
            m.configManager.UnobserveField("cardDescriptionFont")
            m.configManager.UnobserveField("cardTitleColor")
            m.configManager.UnobserveField("cardDescriptionColor")
            m.configManager.UnobserveField("cardTitleNumLines")
            m.configManager.UnobserveField("cardDescriptionNumLines")
            m.configManager.UnobserveField("detailShowTitle")
            m.configManager.UnobserveField("detailShowDescription")
            m.configManager.UnobserveField("detailTitleFont")
            m.configManager.UnobserveField("detailDescriptionFont")
            m.configManager.UnobserveField("detailTitleColor")
            m.configManager.UnobserveField("detailDescriptionColor")
            m.configManager.UnobserveField("detailTitleNumLines")
            m.configManager.UnobserveField("detailDescriptionNumLines")
        catch e
            LogError("GridScreen", "OnExit: configManager UnobserveField failed: " + e.message)
        end try
    end if

    ' Clean up focus timer (exit dialog)
    if m.focusTimer <> invalid
        m.focusTimer.control = "stop"
        m.focusTimer.UnobserveField("fire")
        m.focusTimer = invalid
    end if

    LogInfo("GridScreen", "OnExit: Cleanup complete")
end sub

