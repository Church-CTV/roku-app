' ContinueWatchingCard.brs — Poster card with progress bar for Continue Watching
' Uses Roku SceneGraph Poster/Grid item component pattern

sub Init()
    try
        m.poster = SafeFindNode(m.top, "poster")
        m.progressBg = SafeFindNode(m.top, "progressBg")
        m.progressFill = SafeFindNode(m.top, "progressFill")
        m.progressText = SafeFindNode(m.top, "progressText")

        ' Observe focus for visual highlight
        SafeObserveField(m.top, "focus", "OnFocusChanged")
        SafeObserveField(m.top, "unfocus", "OnUnfocusChanged")

        LogInfo("ContinueWatchingCard", "Card initialized")
    catch e
        LogError("ContinueWatchingCard", "Init failed: " + e.message)
    end try
end sub

' Handle content node change — update poster and progress bar
sub OnContentSet()
    try
        content = m.top.itemContent
        if content = invalid then return

        ' Set poster image
        posterUrl = ""
        if content.hdPosterUrl <> invalid then posterUrl = "" + content.hdPosterUrl
        if content.hdBackdropUrl <> invalid and posterUrl = "" then posterUrl = "" + content.hdBackdropUrl
        if content.hdThumbUrl <> invalid and posterUrl = "" then posterUrl = "" + content.hdThumbUrl
        if m.poster <> invalid and posterUrl <> "" then
            m.poster.uri = posterUrl
        end if

        ' Update progress bar from playback position
        UpdateProgressBar(content)
    catch e
        LogError("ContinueWatchingCard", "OnContentSet failed: " + e.message)
    end try
end sub

' Update progress bar display
sub UpdateProgressBar(content as object)
    if content = invalid or m.progressFill = invalid or m.progressText = invalid then return

    try
        ' Get playback position and duration from content node
        playbackPos = 0
        duration = 0

        if content.playbackPosition <> invalid
            playbackPos = content.playbackPosition
        end if

        if content.playbackDuration <> invalid
            duration = content.playbackDuration
        end if

        ' Calculate percentage
        percent = 0
        if duration > 0
            percent = (playbackPos / duration) * 100
            if percent > 100 then percent = 100
            if percent < 0 then percent = 0
        end if

        ' Update progress bar fill width (max 460px)
        maxBarWidth = 460
        fillWidth = (percent / 100) * maxBarWidth
        m.progressFill.width = fillWidth

        ' Format progress text
        timeLeft = duration - playbackPos
        if timeLeft <= 0
            timeLeft = 0
        end if

        text = ""
        if percent >= 100
            text = "✓ Completed"
        else if percent >= 75
            text = "Almost there (" + FormatTimeRemaining(timeLeft) + " left)"
        else if percent >= 50
            text = "Over halfway (" + FormatTimeRemaining(timeLeft) + " left)"
        else if percent >= 25
            text = "Quarter way (" + FormatTimeRemaining(timeLeft) + " left)"
        else
            text = FormatTimeRemaining(playbackPos) + " / " + FormatTimeRemaining(duration)
        end if

        m.progressText.text = text
    catch e
        LogError("ContinueWatchingCard", "UpdateProgressBar failed: " + e.message)
    end try
end sub

' Format seconds to MM:SS or HH:MM:SS
function FormatTimeRemaining (seconds as integer) as string
    if seconds = invalid or seconds < 0 then return "0:00"

    try
        secs = seconds
        hours = Int(secs / 3600)
        mins = Int((secs - hours * 3600) / 60)
        secs = secs - hours * 3600 - mins * 60

        if hours > 0
            return hours.ToStr() + ":" + PadLeft(mins.ToStr(), "0", 2) + ":" + PadLeft(secs.ToStr(), "0", 2)
        else
            return mins.ToStr() + ":" + PadLeft(secs.ToStr(), "0", 2)
        end if
    catch e
        SafeLog("ERROR", "ContinueWatchingCard", "FormatTimeRemaining failed: " + e.message)
        return "0:00"
    end try
end function

' Handle focus change — native focus ring handles the border
sub OnFocusChanged()
    ' Focus ring handled by RowList focusBitmapUri
    ' No overlay needed
end sub

' Handle unfocus
sub OnUnfocusChanged()
    ' Focus ring handled by RowList focusBitmapUri
    ' No overlay needed
end sub

' OnExit handler - cleanup resources when card exits
sub OnExit()
    try
        SafeUnobserveField(m.top, "focus")
        SafeUnobserveField(m.top, "unfocus")
    catch e
        LogError("ContinueWatchingCard", "OnExit: " + e.message)
    end try
end sub
