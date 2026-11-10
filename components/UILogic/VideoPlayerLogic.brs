' VideoPlayerLogic.brs - Video playback with playlist support
' ********** Copyright 2020 Roku Corp.  All Rights Reserved. **********

sub ShowVideoScreen(content, itemIndex)
    m.videoPlayer = CreateObject("roSGNode", "Video")
    if m.videoPlayer = invalid then return

    ' Handle playlist behavior for non-first items
    if itemIndex <> 0
        numOfChildren = content.GetChildCount()
        ' Fixed: Use correct GetChildren(startIndex, count) parameters
        children = content.GetChildren(itemIndex, numOfChildren - itemIndex)
        childrenClone = []
        for each child in children
            childrenClone.Push(child.Clone(false))
        end for
        node = CreateObject("roSGNode", "ContentNode")
        node.Update({ children: childrenClone }, true)
        m.videoPlayer.content = node
    else
        m.videoPlayer.content = content.Clone(true)
    end if
    m.videoPlayer.contentIsPlaylist = true
    ShowScreen(m.videoPlayer)
    m.videoPlayer.control = "play"
    SafeObserveField(m.videoPlayer, "state", "OnVideoPlayerStateChange")
    SafeObserveField(m.videoPlayer, "visible", "OnVideoVisibleChange")

    ' Track video playback start
    try
        TrackPlaybackStateChange("play", "")
    catch e
        LogError("VideoPlayerLogic", "TrackPlaybackStateChange(play) failed: " + e.message)
    end try
end sub

sub OnVideoPlayerStateChange()
    if m.videoPlayer = invalid then return
    state = m.videoPlayer.state

    ' Track playback state change
    try
        TrackPlaybackStateChange(state, "")
    catch e
        LogError("VideoPlayerLogic", "TrackPlaybackStateChange(" + state + ") failed: " + e.message)
    end try

    ' close video screen in case of error or end of playback
    if state = "error"
        LogError("VideoPlayerLogic", "Video playback error")
        ReportError("video_error", "Video playback error", "state=error")
        CloseScreen(m.videoPlayer)
    else if state = "finished"
        CloseScreen(m.videoPlayer)
    end if
end sub

sub OnVideoVisibleChange()
    if m.videoPlayer = invalid then return
    if m.videoPlayer.visible = false and m.top.visible = true
        currentIndex = m.videoPlayer.contentIndex
        m.videoPlayer.control = "stop"
        m.videoPlayer.content = invalid
        SafeUnobserveField(m.videoPlayer, "state")
        SafeUnobserveField(m.videoPlayer, "visible")
        m.videoPlayer = invalid
        if m.GridScreen <> invalid
            m.GridScreen.SetFocus(true)
            if m.selectedIndex <> invalid
                m.GridScreen.jumpToRowItem = [m.selectedIndex[0], currentIndex + m.selectedIndex[1]]
            end if
        end if
    end if
end sub
