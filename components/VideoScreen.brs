sub Init()
    try
        m.videoPlayer = SafeFindNode(m.top, "videoPlayer")
        if m.videoPlayer = invalid
            SafeLog("WARN", "VideoScreen", "Video player node not found")
            return
        end if

        ' Use hardcoded FHD resolution. roDeviceInfo methods like GetWidth() and
        ' GetScreenSize() are unreliable across firmware versions (runtime error &hf4).
        m.videoPlayer.width = 1920
        m.videoPlayer.height = 1080

        ' Observe video state so we can auto-close when finished or on error
        m.videoPlayer.ObserveField("state", "onVideoStateChange")
    catch e
        SafeLog("ERROR", "VideoScreen", "Init failed: " + e.message)
    end try
end sub

sub onContentChange()
    try
        item = m.top.content
        if item = invalid
            SafeLog("WARN", "VideoScreen", "No content item provided")
            return
        end if

        ' Build a proper ContentNode for the Video node
        contentNode = CreateObject("roSGNode", "ContentNode")
        if contentNode = invalid
            SafeLog("ERROR", "VideoScreen", "Failed to create ContentNode")
            return
        end if

        streamUri = ""
        if item.url <> invalid and item.url <> ""
            streamUri = item.url
        else if item.streamUrl <> invalid and item.streamUrl <> ""
            streamUri = item.streamUrl
        end if

        streamFmt = ""
        if item.streamFormat <> invalid
            streamFmt = item.streamFormat
        end if
        if streamFmt = "" and InStr(streamUri, ".m3u8") > 0
            streamFmt = "hls"
        end if

        contentNode.url = streamUri
        contentNode.streamFormat = streamFmt

        if item.title <> invalid
            contentNode.title = item.title
        end if
        if item.length <> invalid
            contentNode.length = item.length
        end if
        if item.hdPosterUrl <> invalid
            contentNode.hdPosterUrl = item.hdPosterUrl
        end if

        ' Preserve ClipStart for resume from continue watching position
        if item.ClipStart <> invalid and item.ClipStart > 0
            contentNode.ClipStart = item.ClipStart
        end if

        m.videoPlayer.content = contentNode
        m.videoPlayer.control = "play"
        m.videoPlayer.setFocus(true)
    catch e
        SafeLog("ERROR", "VideoScreen", "onContentChange failed: " + e.message)
    end try
end sub

sub onVisibilityChange()
    try
        if m.top.visible
            m.videoPlayer.visible = true
            m.videoPlayer.control = "play"
            m.videoPlayer.setFocus(true)
        else
            m.videoPlayer.visible = false
            m.videoPlayer.control = "stop"
            m.videoPlayer.content = invalid
            m.top.close = true
        end if
    catch e
        SafeLog("ERROR", "VideoScreen", "onVisibilityChange failed: " + e.message)
    end try
end sub

sub onVideoStateChange()
    try
        state = m.videoPlayer.state
        if state = "finished" or state = "error"
            SafeLog("INFO", "VideoScreen", "Video state: " + state)

            ' Save final playback position for continue watching tracking
            currentItem = m.videoPlayer.content
            if currentItem <> invalid
                contentId = ""
                if currentItem.id <> invalid then contentId = currentItem.id
                position = 0
                duration = 0
                if currentItem.length <> invalid then duration = currentItem.length
                ' Try to get current playback position from video player
                try
                    position = m.videoPlayer.position
                    if position = invalid then position = 0
                catch e
                    SafeLog("WARN", "VideoScreen", "Could not read video position: " + e.message)
                end try

                if contentId <> "" and duration > 0
                    SavePlaybackPosition(contentId, position, duration)
                end if

                ' Remove from continue watching if fully watched (>= 95%)
                if not HasPartiallyWatched(contentId) then
                    SafeLog("INFO", "VideoScreen", "Video fully watched, removing from continue watching: " + contentId)
                    RemoveContinueWatchingItem(contentId)
                end if
            end if

            m.videoPlayer.control = "stop"
            m.videoPlayer.content = invalid
            m.top.close = true
        end if
    catch e
        SafeLog("ERROR", "VideoScreen", "onVideoStateChange failed: " + e.message)
    end try
end sub

function OnKeyEvent (key, press) as boolean
    result = false
    try
        if press
            if LCase(key) = "back"
                m.videoPlayer.control = "stop"
                m.videoPlayer.content = invalid
                m.top.close = true
                result = true
            else if LCase(key) = "play"
                if m.videoPlayer.state = "playing"
                    m.videoPlayer.control = "pause"
                else
                    m.videoPlayer.control = "play"
                end if
                result = true
            end if
        end if
    catch e
        SafeLog("ERROR", "VideoScreen", "OnKeyEvent failed: " + e.message)
    end try
    return result
end function

' OnExit handler - cleanup resources when screen exits
sub OnExit()
    try
        if m.videoPlayer <> invalid
            m.videoPlayer.control = "stop"
            m.videoPlayer.content = invalid
            m.videoPlayer.UnobserveField("state")
        end if
    catch e
        SafeLog("ERROR", "VideoScreen", "OnExit failed: " + e.message)
    end try
end sub
