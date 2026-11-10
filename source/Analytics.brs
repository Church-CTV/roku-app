' Push event to array with max-size cap to prevent memory leak on long sessions
' Oldest entries are dropped when cap is exceeded
sub PushBounded(history, event, maxItems)
    try
        if history.Count() >= maxItems
            history.Shift()
        end if
        history.Push(event)
    catch e
        SafeLog("ERROR", "PushBounded", "Error: " + e.message)
    end try
end sub

' Analytics.brs - Core analytics tracking for example Roku channel
' Tracks key user events: screen views, content play, deep links, errors
' All events are collected in memory and exported on app exit or at intervals

' Initialize analytics - called from MainScene
sub AnalyticsInit(glob)
    try
        m.global = glob
        ' This will create the analytics node if needed
        GetAnalyticsNode()
    catch e
        SafeLog("ERROR", "AnalyticsInit", "Error: " + e.message)
    end try
end sub

' Get the analytics node - checks multiple locations
function GetAnalyticsNode () as object
    try
        ' First try m.global.analytics
        if m.global <> invalid and m.global.analytics <> invalid
            return m.global.analytics
        end if
        ' Then try local storage
        if m.analyticsNode <> invalid
            return m.analyticsNode
        end if
        ' Create if needed
        if m.global <> invalid
            analyticsNode = CreateObject("roSGNode", "Analytics")
            if analyticsNode <> invalid
                analyticsNode.eventCount = 0
                analyticsNode.lastExportTime = ""
                analyticsNode.screenHistory = CreateObject("roArray", 50, true)
                analyticsNode.playHistory = CreateObject("roArray", 100, true)
                analyticsNode.deepLinkHistory = CreateObject("roArray", 50, true)
                analyticsNode.errorHistory = CreateObject("roArray", 50, true)
                analyticsNode.sessionStartTime = GetTimestamp()
                analyticsNode.sessionStartEpoch = CreateObject("roDateTime").AsSeconds()
                analyticsNode.activeScreen = "MainScene"
                m.analyticsNode = analyticsNode
                return analyticsNode
            end if
        end if
    catch e
        LogWarn("Analytics", "GetAnalyticsNode: " + e.message)
    end try
    return invalid
end function

' Track a screen view event
sub TrackScreenView(screenName, previousScreen)
    try
        analytics = GetAnalyticsNode()
        if analytics = invalid
            return
        end if

        event = CreateObject("roSGNode", "AnalyticsEvent")
        event.eventType = "screen_view"
        event.screenName = screenName
        event.previousScreen = previousScreen
        event.timestamp = GetTimestamp()
        event.sessionDuration = GetSessionDuration()
        event.appVersion = m.global.AppVersion

        ' Update active screen
        analytics.activeScreen = screenName

        ' Add to screen history
        PushBounded(analytics.screenHistory, event, 50)
        analytics.eventCount = analytics.eventCount + 1

        ' Track screen view with heartbeat (disabled - function not resolved by compiler)
        ' HeartbeatTrackScreen(screenName)

        LogInfo("Analytics", "Screen view: " + screenName + " (from: " + previousScreen + ")")
    catch e
        LogError("Analytics", "TrackScreenView: " + e.message)
    end try
end sub

' Track a content play event
sub TrackContentPlay(contentItem, sourceScreen)
    try
        analytics = GetAnalyticsNode()
        if analytics = invalid
            return
        end if

        event = CreateObject("roSGNode", "AnalyticsEvent")
        event.eventType = "content_play"
        event.contentId = ""
        event.contentTitle = ""
        event.sourceScreen = sourceScreen
        event.timestamp = GetTimestamp()
        event.sessionDuration = GetSessionDuration()
        event.appVersion = m.global.AppVersion

        if contentItem <> invalid
            if contentItem.content <> invalid
                event.contentId = contentItem.content.id
                event.contentTitle = contentItem.content.title
                if contentItem.content.duration <> invalid
                    event.contentDuration = contentItem.content.duration
                end if
            else
                event.contentId = contentItem.id
                event.contentTitle = contentItem.title
                if contentItem.length <> invalid
                    event.contentDuration = contentItem.length
                end if
            end if
        end if

        ' Add to play history
        PushBounded(analytics.playHistory, event, 100)
        analytics.eventCount = analytics.eventCount + 1

        LogInfo("Analytics", "Content play: " + event.contentTitle)
    catch e
        LogError("Analytics", "TrackContentPlay: " + e.message)
    end try
end sub

' Track a deep link event
sub TrackDeepLink(contentId, mediaType, source)
    try
        analytics = GetAnalyticsNode()
        if analytics = invalid
            return
        end if

        event = CreateObject("roSGNode", "AnalyticsEvent")
        event.eventType = "deep_link"
        event.contentId = contentId
        event.mediaType = mediaType
        event.source = source
        event.timestamp = GetTimestamp()
        event.sessionDuration = GetSessionDuration()
        event.appVersion = m.global.AppVersion

        ' Add to deep link history
        PushBounded(analytics.deepLinkHistory, event, 50)
        analytics.eventCount = analytics.eventCount + 1

        LogInfo("Analytics", "Deep link: " + contentId + " (type: " + mediaType + ")")
    catch e
        LogError("Analytics", "TrackDeepLink: " + e.message)
    end try
end sub

' Track a content error event
sub TrackError(errorType, errorMessage, context)
    try
        analytics = GetAnalyticsNode()
        if analytics = invalid
            return
        end if

        event = CreateObject("roSGNode", "AnalyticsEvent")
        event.eventType = "error"
        event.errorType = errorType
        event.errorMessage = errorMessage
        event.context = context
        event.timestamp = GetTimestamp()
        event.sessionDuration = GetSessionDuration()
        event.appVersion = m.global.AppVersion

        ' Add to error history
        PushBounded(analytics.errorHistory, event, 50)
        analytics.eventCount = analytics.eventCount + 1
        LogError("Analytics", "Error: " + errorType + ": " + errorMessage + " (context: " + context + ")")
    catch e
        LogError("Analytics", "TrackError: " + e.message)
    end try
end sub

' Track a user interaction event
sub TrackInteraction(action, target, details)
    try
        analytics = GetAnalyticsNode()
        if analytics = invalid
            return
        end if

        event = CreateObject("roSGNode", "AnalyticsEvent")
        event.eventType = "interaction"
        event.action = action
        event.target = target
        event.details = details
        event.timestamp = GetTimestamp()
        event.sessionDuration = GetSessionDuration()
        event.appVersion = m.global.AppVersion

        ' Add to screen history as a general event
        PushBounded(analytics.screenHistory, event, 50)
        analytics.eventCount = analytics.eventCount + 1

        LogInfo("Analytics", "Interaction: " + action + " on " + target)
    catch e
        LogError("Analytics", "TrackInteraction: " + e.message)
    end try
end sub

' Track a content pause/resume event
sub TrackPlaybackStateChange(state, contentId)
    try
        analytics = GetAnalyticsNode()
        if analytics = invalid
            return
        end if

        event = CreateObject("roSGNode", "AnalyticsEvent")
        event.eventType = "playback_state"
        event.state = state
        event.contentId = contentId
        event.timestamp = GetTimestamp()
        event.sessionDuration = GetSessionDuration()
        event.appVersion = m.global.AppVersion

        ' Add to play history
        PushBounded(analytics.playHistory, event, 100)
        analytics.eventCount = analytics.eventCount + 1

        LogInfo("Analytics", "Playback state: " + state + " (content: " + contentId + ")")
    catch e
        LogError("Analytics", "TrackPlaybackStateChange: " + e.message)
    end try
end sub

' Get the current session duration in seconds using epoch-based tracking
function GetSessionDuration () as integer
    try
        analytics = GetAnalyticsNode()
        if analytics = invalid
            return 0
        end if

        ' Use epoch seconds if available (accurate across midnight)
        if analytics.sessionStartEpoch <> invalid
            now = CreateObject("roDateTime")
            return now.AsSeconds() - analytics.sessionStartEpoch
        end if

        ' Fallback: parse HH:MM:SS timestamps
        startTime = analytics.sessionStartTime
        if startTime = ""
            return 0
        end if

        currentTime = GetTimestamp()
        startParts = SplitString(startTime, ":")
        currentParts = SplitString(currentTime, ":")

        if startParts.Count() = 3 and currentParts.Count() = 3
            startSeconds = Val(startParts[0]) * 3600 + Val(startParts[1]) * 60 + Val(startParts[2])
            currentSeconds = Val(currentParts[0]) * 3600 + Val(currentParts[1]) * 60 + Val(currentParts[2])
            duration = currentSeconds - startSeconds
            if duration < 0
                duration = duration + 86400
            end if
            return duration
        end if
    catch e
        LogError("Analytics", "GetSessionDuration: " + e.message)
    end try

    return 0
end function

' Get analytics summary as an associative array (for export)
function GetAnalyticsSummary () as object
    try
        analytics = GetAnalyticsNode()
        if analytics = invalid
            return {}
        end if

        summary = {
            sessionStartTime: analytics.sessionStartTime
            activeScreen: analytics.activeScreen
            appVersion: m.global.AppVersion
            eventCount: analytics.eventCount
            screenViews: analytics.screenHistory.Count()
            plays: analytics.playHistory.Count()
            deepLinks: analytics.deepLinkHistory.Count()
            errors: analytics.errorHistory.Count()
        }

        return summary
    catch e
        LogError("Analytics", "GetAnalyticsSummary: " + e.message)
        return {}
    end try
end function

' Reset analytics data (for testing or new session)
sub ResetAnalytics()
    try
        analytics = GetAnalyticsNode()
        if analytics = invalid
            return
        end if

        analytics.eventCount = 0
        analytics.lastExportTime = ""
        analytics.screenHistory.Clear()
        analytics.playHistory.Clear()
        analytics.deepLinkHistory.Clear()
        analytics.errorHistory.Clear()
        analytics.sessionStartTime = GetTimestamp()
        analytics.sessionStartEpoch = CreateObject("roDateTime").AsSeconds()
        analytics.activeScreen = "MainScene"

        LogInfo("Analytics", "Analytics data reset")
    catch e
        LogError("Analytics", "ResetAnalytics: " + e.message)
    end try
end sub

' Clear analytics arrays after export or at specified intervals
' This prevents memory accumulation during long sessions
' Also clears based on time elapsed (default: 1 hour) to prevent unbounded growth
sub ClearAnalyticsArrays(maxAgeSeconds)
    try
        analytics = GetAnalyticsNode()
        if analytics = invalid
            return
        end if

        ' Default max age: 1 hour (3600 seconds)
        if maxAgeSeconds = invalid or maxAgeSeconds <= 0
            maxAgeSeconds = 3600
        end if

        ' Check if enough time has passed since session start
        currentDuration = GetSessionDuration()
        if currentDuration > maxAgeSeconds
            ' Time-based cleanup: clear all arrays
            analytics.screenHistory.Clear()
            analytics.playHistory.Clear()
            analytics.deepLinkHistory.Clear()
            analytics.errorHistory.Clear()
            analytics.eventCount = 0
            analytics.lastExportTime = GetTimestamp()
            analytics.sessionStartTime = GetTimestamp()
            analytics.sessionStartEpoch = CreateObject("roDateTime").AsSeconds()
            LogInfo("Analytics", "Analytics arrays cleared after " + currentDuration.ToStr() + " seconds (time-based cleanup)")
            return
        end if

        ' Event count-based cleanup
        totalEvents = 0
        if analytics.screenHistory <> invalid
            totalEvents = totalEvents + analytics.screenHistory.Count()
        end if
        if analytics.playHistory <> invalid
            totalEvents = totalEvents + analytics.playHistory.Count()
        end if
        if analytics.deepLinkHistory <> invalid
            totalEvents = totalEvents + analytics.deepLinkHistory.Count()
        end if
        if analytics.errorHistory <> invalid
            totalEvents = totalEvents + analytics.errorHistory.Count()
        end if

        ' Clear if more than 50 events accumulated to prevent memory buildup
        if totalEvents > 50
            analytics.screenHistory.Clear()
            analytics.playHistory.Clear()
            analytics.deepLinkHistory.Clear()
            analytics.errorHistory.Clear()
            analytics.eventCount = 0
            analytics.lastExportTime = GetTimestamp()
            LogInfo("Analytics", "Analytics arrays cleared after " + totalEvents.ToStr() + " events")
        end if
    catch e
        LogError("Analytics", "ClearAnalyticsArrays: " + e.message)
    end try
end sub
