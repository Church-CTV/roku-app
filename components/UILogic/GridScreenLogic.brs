' GridScreenLogic.brs - Screen management with proper cleanup
' Optimizations: proper cleanup on screen transitions, deferred object creation

sub ShowGridScreen()
    ' Clean up any existing GridScreen
    if m.GridScreen <> invalid
        try
            m.GridScreen.UnobserveField("rowItemSelected")
            m.GridScreen.UnobserveField("close")
            m.GridScreen.UnobserveField("content")
        catch e
            LogError("GridScreenLogic", "UnobserveField failed: " + e.message)
        end try
        if m.GridScreen.parent <> invalid
            m.GridScreen.parent.RemoveChild(m.GridScreen)
        end if
        m.GridScreen = invalid
    end if

    m.GridScreen = CreateObject("roSGNode", "GridScreen")
    if m.GridScreen <> invalid
        SafeObserveField(m.GridScreen, "rowItemSelected", "OnGridScreenItemSelected")
        SafeObserveField(m.GridScreen, "close", "OnGridScreenClose")
        ' Observe content field so we can set focus when content arrives
        SafeObserveField(m.GridScreen, "content", "OnGridScreenContentReady")
        ShowScreen(m.GridScreen)
    end if
end sub

sub OnGridScreenClose()
    LogInfo("GridScreenLogic", "GridScreen close requested, exiting channel")
    if m.global <> invalid
        m.global.CloseChannel = true
    end if
end sub

sub OnGridScreenItemSelected(event)
    try
        grid = event.GetRoSGNode()
        if grid = invalid then return
        m.selectedIndex = event.GetData()
        if m.selectedIndex = invalid then return
        rowContent = grid.content.GetChild(m.selectedIndex[0])
        if rowContent = invalid then return
        itemIndex = m.selectedIndex[1]
        selectedItem = rowContent.GetChild(itemIndex)

        if selectedItem = invalid then return

        LogInfo("GridScreenLogic", "Item selected: " + selectedItem.title)

        ' Track content selection
        try
            TrackInteraction("select", "GridScreen", selectedItem.title)
        catch e
            LogError("GridScreenLogic", "TrackInteraction failed: " + e.message)
        end try

        ' Play the selected content directly (one-step)
        if selectedItem.url <> invalid
            PlayContent(selectedItem)
        end if
    catch e
        SafeLog("ERROR", "GridScreenLogic", "OnGridScreenItemSelected failed: " + e.message)
    end try
end sub

' Called when GridScreen receives content — set focus on RowList so keys work
sub OnGridScreenContentReady()
    try
        grid = m.GridScreen
        if grid = invalid or grid.content = invalid then return
        if grid.content.GetChildCount() = 0 then return
        rowList = grid.findNode("rowList")
        if rowList <> invalid and rowList.visible <> true then
            ' Ensure the grid screen is visible first
            grid.visible = true
        end if
        rowList.SetFocus(true)
        ' Force jump to first item in case focus didn't land properly
        Sleep(30)
        focused = SafeNodeGetFocus(rowList)
        if focused = invalid
            rowList.jumpToRowItem = [0, 0]
            rowList.SetFocus(true)
        end if
        LogInfo("GridScreenLogic", "Focus set on RowList after content loaded")
    catch e
        LogError("GridScreenLogic", "OnGridScreenContentReady: " + e.message)
    end try
end sub

sub ShowMainView(content, itemIndex)
    try
        ' Clean up any existing MainView
        if m.mainView <> invalid
            try
                m.mainView.UnobserveField("close")
                m.mainView.UnobserveField("play")
                m.mainView.UnobserveField("moreInfo")
            catch e
                LogError("GridScreenLogic", "MainView UnobserveField failed: " + e.message)
            end try
            m.mainView = invalid
        end if

        m.mainView = CreateObject("roSGNode", "MainView")
        if m.mainView <> invalid
            m.mainView.itemContent = content.GetChild(itemIndex)
            SafeObserveField(m.mainView, "close", "OnMainViewClose")
            SafeObserveField(m.mainView, "play", "OnMainViewPlay")
            SafeObserveField(m.mainView, "moreInfo", "OnMainViewMoreInfo")
            ShowScreen(m.mainView)
        end if
    catch e
        SafeLog("ERROR", "GridScreenLogic", "ShowMainView failed: " + e.message)
    end try
end sub

sub OnMainViewClose()
    LogInfo("GridScreenLogic", "MainView closed, returning to grid")
    if m.mainView <> invalid
        CloseScreen(m.mainView)
        m.mainView = invalid
    end if
end sub

sub OnMainViewPlay()
    LogInfo("GridScreenLogic", "Play button pressed, starting playback")
    if m.mainView <> invalid and m.mainView.itemContent <> invalid
        contentToPlay = m.mainView.itemContent
        CloseScreen(m.mainView)
        m.mainView = invalid
        try
            TrackContentPlay(contentToPlay, "MainView")
        catch e
            LogError("GridScreenLogic", "TrackContentPlay failed: " + e.message)
        end try
        PlayContent(contentToPlay)
    end if
end sub

sub OnMainViewMoreInfo()
    LogInfo("GridScreenLogic", "More Info button pressed")
    if m.mainView <> invalid and m.mainView.itemContent <> invalid
        content = m.mainView.itemContent
        metaParts = []
        if content.length <> invalid
            metaParts.Push(GetFormattedTime(content.length))
        end if
        if content.category <> invalid
            metaParts.Push(content.category)
        end if
        if content.rating <> invalid
            metaParts.Push(content.rating)
        end if
        if content.year <> invalid
            metaParts.Push(content.year.ToStr())
        end if
        metaText = ""
        if metaParts.Count() > 0
            metaText = metaParts.Join("  |  ")
        end if
        infoText = ""
        if content.title <> invalid
            infoText = content.title
        end if
        if content.description <> invalid and Len(content.description) > 0
            if Len(infoText) > 0
                infoText = infoText + Chr(13) + Chr(13)
            end if
            infoText = infoText + content.description
        end if
        if Len(metaText) > 0
            if Len(infoText) > 0
                infoText = infoText + Chr(13) + Chr(13)
            end if
            infoText = infoText + metaText
        end if
        if Len(infoText) > 0
            dialog = CreateObject("roSGNode", "Group")
            dialog.id = "moreInfoDialog"
            overlay = CreateObject("roSGNode", "Rectangle")
            overlay.width = "1920"
            overlay.height = "1080"
            overlay.color = "0x000000"
            overlay.opacity = "0.85"
            dialog.appendChild(overlay)
            panel = CreateObject("roSGNode", "Rectangle")
            panel.width = "1200"
            panel.height = "700"
            panel.translation = "[360, 190]"
            panel.color = "0x1A1A2E"
            panel.cornerRadius = "20"
            dialog.appendChild(panel)
            titleLabel = CreateObject("roSGNode", "Label")
            titleLabel.text = "More Info"
            titleLabel.font = "font:ExtraBoldSystemFont"
            titleLabel.color = "0xE8B931"
            titleLabel.translation = "[420, 230]"
            dialog.appendChild(titleLabel)
            bodyLabel = CreateObject("roSGNode", "Label")
            bodyLabel.text = infoText
            bodyLabel.font = "font:MediumSystemFont"
            bodyLabel.color = "0xFFFFFF"
            bodyLabel.translation = "[420, 310]"
            bodyLabel.width = "1060"
            bodyLabel.wrap = "true"
            bodyLabel.numLines = "10"
            dialog.appendChild(bodyLabel)
            okButton = CreateObject("roSGNode", "Button")
            okButton.id = "moreInfoOkButton"
            okButton.text = "OK"
            okButton.focusedColor = "0xE8B931"
            okButton.translation = "[860, 860]"
            okButton.width = "200"
            okButton.height = "60"
            dialog.appendChild(okButton)
            okButton.observeField("select", "OnMoreInfoAlertClosed")
            m.mainScene.appendChild(dialog)
            okButton.SetFocus(true)
        end if
    end if
end sub

sub OnMoreInfoAlertClosed()
    try
        dialog = m.mainScene.findNode("moreInfoDialog")
        if dialog <> invalid
            okButton = dialog.FindNode("moreInfoOkButton")
            if okButton <> invalid
                okButton.UnobserveField("select")
            end if
            if dialog.parent <> invalid
                dialog.parent.removeChild(dialog)
            end if
        end if
    catch e
        LogError("GridScreenLogic", "OnMoreInfoAlertClosed: " + e.message)
    end try
end sub

function GetFormattedTime (length) as string
    return FormatDuration(length)
end function
