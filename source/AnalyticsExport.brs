' AnalyticsExport.brs - Analytics export and transmission for Roku channel template
' Added: retry logic with exponential backoff, local queue persistence, rate limiting support
' Note: SplitString function is required (BrightScript standard library alias)

sub AnalyticsExportInit(globalNode)
    try
        ' Initialize analytics export
        if globalNode = invalid
            return
        end if
        LogInfo("AnalyticsExport", "Analytics export initialized")
    catch e
        LogError("AnalyticsExport", "AnalyticsExportInit: " + e.message)
    end try
end sub

' Export all analytics data and send to configured endpoint
sub ExportAndSend(globalNode)
    try
        if globalNode = invalid or globalNode.analytics = invalid
            return
        end if

        ' Use global config cache - avoid redundant file I/O
        config = invalid
        if globalNode <> invalid and globalNode.config <> invalid
            config = globalNode.config
        end if
    catch e
        LogError("AnalyticsExport", "ExportAndSend init: " + e.message)
        return
    end try
    analyticsEnabled = true
    if config <> invalid and config.DoesExist("features")
        if config.features.DoesExist("analytics")
            analyticsEnabled = config.features.analytics
        end if
    end if

    if not analyticsEnabled
        LogInfo("AnalyticsExport", "Analytics disabled - skipping export")
        return
    end if

    ' Periodic memory cleanup - check every time we attempt export
    ClearAnalyticsArrays(3600) ' Clear if session > 1 hour

    ' Build export payload
    payload = BuildExportPayload(globalNode)
    if payload = invalid
        LogInfo("AnalyticsExport", "No payload to export")
        return
    end if

    ' Get export URL from config
    exportUrl = ""
    if config <> invalid and config.DoesExist("analytics")
        if config.analytics.DoesExist("exportUrl")
            exportUrl = config.analytics.exportUrl
        end if
    end if

    if exportUrl = ""
        LogInfo("AnalyticsExport", "No export URL configured - skipping")
        return
    end if

    ' Check rate limit before sending
    if not IsExportAllowed(globalNode)
        LogInfo("AnalyticsExport", "Rate limited - skipping export")
        return
    end if

    ' Attempt to send analytics data with retry logic
    success = SendAnalyticsWithRetry(payload, exportUrl)
    if success
        LogInfo("AnalyticsExport", "Analytics sent successfully")
        ClearAnalyticsHistory(globalNode)
        MarkExportSent(globalNode)
    else
        ' All retries failed - queue events locally for later delivery
        LogError("AnalyticsExport", "Analytics send failed after all retries - queuing events locally")

        ' Convert payload to an event for queue storage
        queuedEvent = CreateObject("roSGNode", "AnalyticsEvent")
        queuedEvent.eventType = "analytics_export"
        queuedEvent.timestamp = GetTimestamp()
        queuedEvent.sessionDuration = ""
        if globalNode.analytics <> invalid and globalNode.analytics.sessionStartTime <> invalid
            queuedEvent.sessionDuration = globalNode.analytics.sessionStartTime
        end if

        ' Copy payload fields to the event
        if globalNode.DoesExist("AppVersion")
            queuedEvent.appVersion = globalNode.AppVersion
        end if
        if globalNode.analytics.DoesExist("screenHistory")
            queuedEvent.screenViews = globalNode.analytics.screenHistory.Count()
        end if
        if globalNode.analytics.DoesExist("playHistory")
            queuedEvent.plays = globalNode.analytics.playHistory.Count()
        end if
        if globalNode.analytics.DoesExist("deepLinkHistory")
            queuedEvent.deepLinks = globalNode.analytics.deepLinkHistory.Count()
        end if
        if globalNode.analytics.DoesExist("errorHistory")
            queuedEvent.errors = globalNode.analytics.errorHistory.Count()
        end if

        ' Add to local event queue
        QueueEvent(globalNode, queuedEvent)

        ' Save queue to persistent storage
        SaveEventQueue(globalNode)
    end if
end sub

' Best-effort single-shot analytics send for app exit path
' Uses short timeout (1s) and no retries to avoid blocking shutdown
function SendAnalyticsBestEffort (payload, exportUrl) as boolean
    if payload = invalid or exportUrl = ""
        return false
    end if

    xfer = CreateObject("roURLTransfer")
    xfer.SetURL(exportUrl)
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.SetHeader("Content-Type", "application/json")
    xfer.SetRequest("POST")

    try
        jsonStr = FormatJson(payload)
    catch e
        SafeLog("ERROR", "AnalyticsExport", "SendAnalyticsBestEffort: FormatJson failed: " + e.message)
        xfer = invalid
        return false
    end try
    if jsonStr = invalid or jsonStr = ""
        xfer = invalid
        return false
    end if

    xfer.AsyncPostFromString(jsonStr)

    port = xfer.GetPort()
    msg = wait(1000, port) ' 1 second max to avoid blocking app exit

    if Type(msg) = "roUrlEvent"
        statusCode = msg.GetInt()
        if statusCode = 200 or statusCode = 201 or statusCode = 204
            xfer = invalid
            return true
        end if
    end if
    xfer = invalid
    return false
end function

' Send analytics data with retry logic (exponential backoff)
' Retries up to 3 times with delays: 1s, 2s, 4s
function SendAnalyticsWithRetry (payload, exportUrl) as boolean
    if payload = invalid or exportUrl = ""
        return false
    end if

    maxRetries = 3
    baseDelayMs = 1000 ' 1 second base delay

    for attempt = 1 to maxRetries
        LogInfo("AnalyticsExport", "Send attempt " + attempt.ToStr() + "/" + maxRetries.ToStr() + " to " + exportUrl)

        success = SendAnalytics(payload, exportUrl)
        if success
            LogInfo("AnalyticsExport", "Send succeeded on attempt " + attempt.ToStr())
            return true
        end if

        if attempt < maxRetries
            delayMs = (baseDelayMs * (2 ^ (attempt - 1))) + 0.5
            delayMs = Int(delayMs)
            LogWarn("AnalyticsExport", "Attempt " + attempt.ToStr() + " failed, retrying in " + delayMs.ToStr() + "ms")
            Sleep(delayMs)
        end if
    next

    LogError("AnalyticsExport", "All " + maxRetries.ToStr() + " send attempts failed")
    return false
end function

' Send analytics data to the configured endpoint (single attempt)
function SendAnalytics (payload, exportUrl) as boolean
    if payload = invalid or exportUrl = ""
        return false
    end if

    xfer = CreateObject("roURLTransfer")
    xfer.SetURL(exportUrl)
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.SetHeader("Content-Type", "application/json")
    xfer.SetRequest("POST")

    try
        jsonStr = FormatJson(payload)
    catch e
        LogError("AnalyticsExport", "SendAnalytics: FormatJson failed: " + e.message)
        xfer = invalid
        return false
    end try
    if jsonStr = invalid or jsonStr = ""
        LogError("AnalyticsExport", "Failed to serialize payload")
        xfer = invalid
        return false
    end if

    xfer.AsyncPostFromString(jsonStr)

    port = xfer.GetPort()
    msg = wait(5000, port)

    if Type(msg) = "roUrlEvent"
        statusCode = msg.GetInt()
        if statusCode = 200 or statusCode = 201 or statusCode = 204
            xfer = invalid
            return true
        else
            LogWarn("AnalyticsExport", "HTTP status " + statusCode.ToStr() + " on send attempt")
        end if
    else
        LogError("AnalyticsExport", "No response from server (timeout or connection error)")
    end if
    xfer = invalid
    return false
end function

' Clear all analytics event history after successful export
sub ClearAnalyticsHistory(globalNode)
    try
        if globalNode = invalid or globalNode.analytics = invalid
            return
        end if

        globalNode.analytics.screenHistory.Clear()
        globalNode.analytics.playHistory.Clear()
        globalNode.analytics.deepLinkHistory.Clear()
        globalNode.analytics.errorHistory.Clear()
        globalNode.analytics.eventCount = 0
        LogInfo("AnalyticsExport", "Analytics history cleared")
    catch e
        LogError("AnalyticsExport", "ClearAnalyticsHistory: " + e.message)
    end try
end sub

' Called when the app is exiting - final export attempt with queue flush
sub AnalyticsOnAppExit(globalNode)
    try
        if globalNode = invalid
            return
        end if

        ' Check global cache first to avoid redundant file I/O
        config = invalid
        if globalNode.config <> invalid
            config = globalNode.config
        end if
        analyticsEnabled = true
        if config <> invalid and config.DoesExist("features")
            if config.features.DoesExist("analytics")
                analyticsEnabled = config.features.analytics
            end if
        end if

        if not analyticsEnabled
            LogInfo("AnalyticsExport", "Analytics disabled - skipping exit export")
            return
        end if

        exportUrl = ""
        if config <> invalid and config.DoesExist("analytics")
            if config.analytics.DoesExist("exportUrl")
                exportUrl = config.analytics.exportUrl
            end if
        end if

        ' First, try to flush any queued events before sending current batch
        if exportUrl <> ""
            LogInfo("AnalyticsExport", "Flushing event queue before app exit")
            FlushEventQueue(exportUrl)
        end if

        ' Now send current analytics data with retry logic
        payload = BuildExportPayload(globalNode)
        if payload <> invalid and exportUrl <> ""
            success = SendAnalyticsBestEffort(payload, exportUrl)
            if success
                LogInfo("AnalyticsExport", "Final analytics export succeeded")
                ClearAnalyticsHistory(globalNode)
                MarkExportSent(globalNode)
            else
                LogError("AnalyticsExport", "Final analytics export failed - events queued locally")
                ' Queue the final payload for later delivery
                queuedEvent = CreateObject("roSGNode", "AnalyticsEvent")
                queuedEvent.eventType = "analytics_export_final"
                queuedEvent.timestamp = GetTimestamp()
                if globalNode.DoesExist("AppVersion")
                    queuedEvent.appVersion = globalNode.AppVersion
                end if
                QueueEvent(globalNode, queuedEvent)
                SaveEventQueue(globalNode)
            end if
        else
            LogInfo("AnalyticsExport", "No payload or URL for final export")
        end if

        LogInfo("AnalyticsExport", "Analytics export finalized")
    catch e
        LogError("AnalyticsExport", "AnalyticsOnAppExit: " + e.message)
    end try
end sub

' Build export payload from analytics history
function BuildExportPayload (globalNode) as object
    if globalNode = invalid or globalNode.analytics = invalid
        return invalid
    end if

    summary = GetAnalyticsSummary()
    if summary = invalid or summary.Count() = 0
        return invalid
    end if

    ' Collect all event data — include all fields for each event type
    screenEvents = []
    if globalNode.analytics.screenHistory <> invalid
        for each evt in globalNode.analytics.screenHistory
            if evt <> invalid
                eventObj = {
                    eventType: evt.eventType
                    timestamp: evt.timestamp
                    sessionDuration: evt.sessionDuration
                    appVersion: evt.appVersion
                }
                if evt.eventType = "screen_view"
                    eventObj.screenName = evt.screenName
                    eventObj.previousScreen = evt.previousScreen
                else if evt.eventType = "interaction"
                    eventObj.action = evt.action
                    eventObj.target = evt.target
                    eventObj.details = evt.details
                end if
                screenEvents.Push(eventObj)
            end if
        end for
    end if

    playEvents = []
    if globalNode.analytics.playHistory <> invalid
        for each evt in globalNode.analytics.playHistory
            if evt <> invalid
                eventObj = {
                    eventType: evt.eventType
                    timestamp: evt.timestamp
                    sessionDuration: evt.sessionDuration
                    appVersion: evt.appVersion
                }
                if evt.eventType = "content_play"
                    eventObj.contentId = evt.contentId
                    eventObj.contentTitle = evt.contentTitle
                    eventObj.contentDuration = evt.contentDuration
                    eventObj.sourceScreen = evt.sourceScreen
                else if evt.eventType = "playback_state"
                    eventObj.state = evt.state
                    eventObj.contentId = evt.contentId
                end if
                playEvents.Push(eventObj)
            end if
        end for
    end if

    deepLinkEvents = []
    if globalNode.analytics.deepLinkHistory <> invalid
        for each evt in globalNode.analytics.deepLinkHistory
            if evt <> invalid
                eventObj = {
                    eventType: evt.eventType
                    contentId: evt.contentId
                    mediaType: evt.mediaType
                    source: evt.source
                    timestamp: evt.timestamp
                }
                deepLinkEvents.Push(eventObj)
            end if
        end for
    end if

    errorEvents = []
    if globalNode.analytics.errorHistory <> invalid
        for each evt in globalNode.analytics.errorHistory
            if evt <> invalid
                eventObj = {
                    eventType: evt.eventType
                    errorType: evt.errorType
                    errorMessage: evt.errorMessage
                    context: evt.context
                    timestamp: evt.timestamp
                }
                errorEvents.Push(eventObj)
            end if
        end for
    end if

    payload = {
        appVersion: summary.appVersion
        sessionStartTime: summary.sessionStartTime
        activeScreen: summary.activeScreen
        eventCount: summary.eventCount
        summary: {
            screenViews: summary.screenViews
            plays: summary.plays
            deepLinks: summary.deepLinks
            errors: summary.errors
        }
        events: {
            screenViews: screenEvents
            plays: playEvents
            deepLinks: deepLinkEvents
            errors: errorEvents
        }
    }

    return payload
end function

' Add an event to the local queue
sub QueueEvent(globalNode, event)
    if globalNode = invalid or globalNode.analytics = invalid or event = invalid
        return
    end if

    if not globalNode.analytics.DoesExist("eventQueue")
        globalNode.analytics.eventQueue = CreateObject("roArray", 500, true)
    end if

    queue = globalNode.analytics.eventQueue

    ' Enforce max size - drop oldest if full (reduced from 500 to 200 to limit memory usage)
    if queue.Count() >= 200
        queue.Shift()
        LogInfo("AnalyticsExport", "Queue full, dropped oldest event")
    end if

    queue.Push(event)
    LogInfo("AnalyticsExport", "Event queued (queue size: " + queue.Count().ToStr() + ")")
end sub

' Save event queue to persistent storage
sub SaveEventQueue(globalNode)
    if globalNode = invalid or globalNode.analytics = invalid
        return
    end if

    if not globalNode.analytics.DoesExist("eventQueue") or globalNode.analytics.eventQueue = invalid
        return
    end if

    queue = globalNode.analytics.eventQueue
    if queue.Count() = 0
        return
    end if

    ' Convert queue to serializable format
    serializableQueue = []
    for each event in queue
        if event <> invalid
            eventObj = {
                eventType: event.eventType
                timestamp: event.timestamp
                appVersion: event.appVersion
                screenViews: event.screenViews
                plays: event.plays
                deepLinks: event.deepLinks
                errors: event.errors
                sessionDuration: event.sessionDuration
            }
            serializableQueue.Push(eventObj)
        end if
    end for

    ' Write to file
    try
        jsonStr = FormatJson(serializableQueue)
    catch e
        LogError("AnalyticsExport", "SaveEventQueue: FormatJson failed: " + e.message)
        return
    end try
    if jsonStr <> invalid and jsonStr <> ""
        result = WriteAsciiFile("tmp:/cache/analytics_queue.json", jsonStr)
        if result
            LogInfo("AnalyticsExport", "Event queue saved to tmp:/cache/analytics_queue.json")
        else
            LogError("AnalyticsExport", "Failed to save event queue to tmp:/cache/analytics_queue.json")
        end if
    end if
end sub

' Load event queue from persistent storage
function LoadEventQueue () as object
    try
        ' roDirectory is a legacy component - use roFileSystem instead
        fs = CreateObject("roFileSystem")
        if fs = invalid
            return []
        end if
        ' Check if cache directory exists
        if not fs.Exists("tmp:/cache/")
            fs.MkDir("tmp:/cache/")
        end if
    catch e
        LogWarn("AnalyticsExport", "Persistent storage unavailable: " + e.message)
    end try

    content = ReadAsciiFile("tmp:/cache/analytics_queue.json")
    if content = invalid or content = ""
        return []
    end if

    queue = invalid
    try
        queue = ParseJson(content)
    catch e
        LogError("AnalyticsExport", "Failed to parse event queue: " + e.message)
        return []
    end try

    if Type(queue) <> "roArray"
        return []
    end if

    LogInfo("AnalyticsExport", "Loaded " + queue.Count().ToStr() + " events from persistent queue")
    return queue
end function

' Flush queued events to the export endpoint
sub FlushEventQueue(exportUrl)
    if exportUrl = ""
        return
    end if

    queue = LoadEventQueue()
    if queue = invalid or queue.Count() = 0
        return
    end if

    LogInfo("AnalyticsExport", "Flushing " + queue.Count().ToStr() + " queued events")

    ' Send each queued event individually
    for each queuedEvent in queue
        if queuedEvent <> invalid
            eventPayload = {
                eventType: queuedEvent.eventType
                timestamp: queuedEvent.timestamp
                appVersion: queuedEvent.appVersion
                screenViews: queuedEvent.screenViews
                plays: queuedEvent.plays
                deepLinks: queuedEvent.deepLinks
                errors: queuedEvent.errors
                sessionDuration: queuedEvent.sessionDuration
            }

            success = SendAnalyticsWithRetry(eventPayload, exportUrl)
            if success
                LogInfo("AnalyticsExport", "Flushed queued event: " + queuedEvent.eventType)
            else
                LogError("AnalyticsExport", "Failed to flush queued event: " + queuedEvent.eventType)
            end if
        end if
    end for

    ' Clear the persistent queue file
    WriteAsciiFile("tmp:/cache/analytics_queue.json", "[]")
    LogInfo("AnalyticsExport", "Event queue flushed successfully")
end sub

' Rate limiter for analytics beacons
' Tracks last send time and enforces minimum interval
sub AnalyticsRateLimit(globalNode)
    if globalNode = invalid or globalNode.analytics = invalid
        return
    end if

    if globalNode.config = invalid or not globalNode.config.DoesExist("analytics")
        return
    end if

    exportInterval = 300 ' Default: 5 minutes
    if globalNode.config.analytics.DoesExist("exportIntervalSeconds")
        exportInterval = globalNode.config.analytics.exportIntervalSeconds
    end if

    lastExport = globalNode.analytics.lastExportTime
    if lastExport = "" or lastExport = invalid
        globalNode.analytics.lastExportTime = GetTimestamp()
        return
    end if

    ' Check if enough time has passed since last export
    duration = GetSessionDuration()
    ' We need a separate counter for export intervals
    if not globalNode.analytics.DoesExist("lastExportSeconds")
        globalNode.analytics.lastExportSeconds = duration
    end if

    elapsedSeconds = duration - globalNode.analytics.lastExportSeconds
    if elapsedSeconds < 0 then elapsedSeconds = 0

    if elapsedSeconds >= exportInterval
        globalNode.analytics.lastExportSeconds = duration
        globalNode.analytics.lastExportTime = GetTimestamp()
    end if
end sub

' Check if export is allowed (rate limiting gate)
function IsExportAllowed (globalNode) as boolean
    if globalNode = invalid or globalNode.analytics = invalid
        return false
    end if

    exportInterval = 300
    config = invalid
    if globalNode.config <> invalid
        config = globalNode.config
    end if
    if config <> invalid and config.DoesExist("analytics")
        if config.analytics.DoesExist("exportIntervalSeconds")
            exportInterval = config.analytics.exportIntervalSeconds
        end if
    end if

    if not globalNode.analytics.DoesExist("lastExportSeconds")
        globalNode.analytics.lastExportSeconds = 0
        return true
    end if

    duration = GetSessionDuration()
    elapsedSeconds = duration - globalNode.analytics.lastExportSeconds
    if elapsedSeconds < 0 then elapsedSeconds = 0

    return elapsedSeconds >= exportInterval
end function

' Mark that an export was sent successfully (update timestamp)
sub MarkExportSent(globalNode)
    if globalNode = invalid or globalNode.analytics = invalid
        return
    end if

    globalNode.analytics.lastExportTime = GetTimestamp()
    duration = GetSessionDuration()
    globalNode.analytics.lastExportSeconds = duration

    LogInfo("AnalyticsExport", "Export marked as sent at " + globalNode.analytics.lastExportTime)
end sub
