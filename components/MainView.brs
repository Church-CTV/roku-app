' MainView.brs - Performance-optimized detail panel
' Optimizations: deferred poster loading, efficient metadata building, proper cleanup

sub Init()
    try
        m.overlay = SafeFindNode(m.top, "overlay")
        m.closeButton = SafeFindNode(m.top, "closeButton")
        m.detailPoster = SafeFindNode(m.top, "detailPoster")
        m.detailTitle = SafeFindNode(m.top, "detailTitle")
        m.detailDesc = SafeFindNode(m.top, "detailDesc")
        m.detailMeta = SafeFindNode(m.top, "detailMeta")
        m.playButton = SafeFindNode(m.top, "playButton")
        m.moreInfoButton = SafeFindNode(m.top, "moreInfoButton")

        ' Set initial focus to close button
        if m.closeButton <> invalid then m.closeButton.SetFocus(true)

        ' Observe field changes
        SafeObserveField(m.top, "close", "OnClose")
        SafeObserveField(m.top, "play", "OnPlay")
        SafeObserveField(m.top, "moreInfo", "OnMoreInfo")

        ' Observe button presses
        if m.closeButton <> invalid then SafeObserveField(m.closeButton, "select", "OnCloseButtonSelect")
        if m.playButton <> invalid then SafeObserveField(m.playButton, "select", "OnPlayButtonSelect")
        if m.moreInfoButton <> invalid then SafeObserveField(m.moreInfoButton, "select", "OnMoreInfoButtonSelect")

        ' Track content state for deferred loading
        m.contentLoaded = false
    catch e
        LogError("MainView", "Init: " + e.message)
    end try
end sub

sub OnContentSet()
    try
        content = m.top.itemContent
        if content <> invalid
            ' Set title immediately (fast text update)
            if m.detailTitle <> invalid and content.title <> invalid
                m.detailTitle.text = content.title
            end if
            ' Set description immediately (fast text update)
            if m.detailDesc <> invalid and content.description <> invalid
                m.detailDesc.text = content.description
            end if

            ' Set metadata efficiently
            if m.detailMeta <> invalid
                metaParts = []
                if content.length <> invalid
                    metaParts.Push(GetTime(content.length))
                end if
                if content.category <> invalid
                    metaParts.Push(content.category)
                end if
                if metaParts.Count() > 0
                    m.detailMeta.text = metaParts.Join("  o  ")
                end if
            end if

            ' Defer poster loading until needed (optimization for faster panel open)
            m.pendingContent = content
            m.contentLoaded = true
        end if
    catch e
        LogError("MainView", "OnContentSet: " + e.message)
    end try
end sub

sub OnClose()
    ' Close was triggered from parent
    CloseView()
end sub

sub OnCloseButtonSelect()
    CloseView()
end sub

sub OnPlayButtonSelect()
    m.top.postMessage("play", {})
end sub

sub OnMoreInfoButtonSelect()
    m.top.postMessage("moreInfo", {})
end sub

sub OnPlay()
    m.top.postMessage("play", {})
end sub

sub OnMoreInfo()
    m.top.postMessage("moreInfo", {})
end sub

sub CloseView()
    ' Clean up pending content reference
    m.pendingContent = invalid
    m.top.postMessage("close", {})
end sub

' Convert seconds to mm:ss format
function GetTime (length) as string
    minutes = (length \ 60).ToStr()
    seconds = length mod 60
    if seconds < 10
        seconds = "0" + seconds.ToStr()
    else
        seconds = seconds.ToStr()
    end if
    return minutes + ":" + seconds
end function

' OnExit handler - cleanup resources when view exits
sub OnExit()
    LogInfo("MainView", "OnExit: Cleaning up resources")

    ' Clean up top-level field observers
    SafeUnobserveField(m.top, "close")
    SafeUnobserveField(m.top, "play")
    SafeUnobserveField(m.top, "moreInfo")

    ' Clean up button observers
    if m.closeButton <> invalid then SafeUnobserveField(m.closeButton, "select")
    if m.playButton <> invalid then SafeUnobserveField(m.playButton, "select")
    if m.moreInfoButton <> invalid then SafeUnobserveField(m.moreInfoButton, "select")

    ' Clean up pending content reference
    m.pendingContent = invalid
    m.contentLoaded = false

    LogInfo("MainView", "OnExit: Cleanup complete")
end sub
