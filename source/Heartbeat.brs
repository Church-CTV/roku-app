' Heartbeat.brs - Periodic telemetry system
' Logs system state at configurable intervals

' IIfStr: inline if-else string helper (replaces removed IIf function)
function IIfStr (condition as boolean, trueVal as string, falseVal as string) as string
    if condition
        return trueVal
    else
        return falseVal
    end if
end function

' Initialize heartbeat - uses associative array instead of node for state
sub HeartbeatInit(global as object, config as object)
    try
        if global = invalid or config = invalid then return

        ' Use associative array to store state (supports arbitrary fields)
        m.heartbeat = CreateObject("roAssociativeArray")
        m.heartbeat["intervalSeconds"] = 60

        if config.DoesExist("heartbeat") and config.heartbeat <> invalid
            if config.heartbeat.DoesExist("intervalSeconds") and config.heartbeat["intervalSeconds"] > 0
                m.heartbeat["intervalSeconds"] = config.heartbeat["intervalSeconds"]
            end if
            if config.heartbeat.DoesExist("exportUrl")
                m.heartbeat["exportUrl"] = config.heartbeat["exportUrl"]
            else
                m.heartbeat["exportUrl"] = ""
            end if
        else
            m.heartbeat["exportUrl"] = ""
        end if

        m.heartbeat["lastExport"] = CreateObject("roDateTime").AsSeconds()
        m.heartbeat["crashCount"] = 0
        m.heartbeat["warningCount"] = 0
        m.heartbeat["screenHistory"] = CreateObject("roArray", 100, true)
        m.heartbeat["videoState"] = "idle"
        m.heartbeat["videoId"] = ""
        m.heartbeat["videoPosition"] = 0
        m.heartbeat["videoDuration"] = 0
        m.heartbeat["currentScreen"] = "MainScene"
        m.heartbeat["isVideoPlaying"] = false
        m.heartbeat["sessionStartTime"] = m.heartbeat["lastExport"]
        m.heartbeat["networkErrors"] = 0
        m.heartbeat["contentFetches"] = 0
        m.heartbeat["lastError"] = ""
        m.heartbeat["lastErrorTime"] = ""

        m.heartbeatTimer = CreateObject("roTimespan")
        m.heartbeatTimer.Mark()

        LogInfo("Heartbeat", "Initialized with " + m.heartbeat["intervalSeconds"].ToStr() + "s intervals")
    catch ex
        LogError("Heartbeat", "Initialization failed: " + ex.Message)
    end try
end sub

' Export current state - returns payload as associative array
function HeartbeatExport () as object
    try
        if m.heartbeat = invalid then return CreateObject("roAssociativeArray")

        payload = CreateObject("roAssociativeArray")
        payload.type = "heartbeat"
        payload.timestamp = GetTimestamp()
        payload.sessionId = "sess_" + CreateObject("roDateTime").AsSeconds().ToStr()
        payload.intervalSeconds = m.heartbeat["intervalSeconds"]
        payload.sessionDuration = CreateObject("roDateTime").AsSeconds() - m.heartbeat["sessionStartTime"]
        payload.screen = m.heartbeat["currentScreen"]
        payload.isVideoPlaying = m.heartbeat["isVideoPlaying"]
        payload.videoId = m.heartbeat["videoId"]
        payload.videoPosition = m.heartbeat["videoPosition"]
        payload.videoDuration = m.heartbeat["videoDuration"]
        payload.crashCount = m.heartbeat["crashCount"]
        payload.warningCount = m.heartbeat["warningCount"]
        payload.networkErrors = m.heartbeat["networkErrors"]
        payload.contentFetches = m.heartbeat["contentFetches"]
        payload.lastError = m.heartbeat["lastError"]
        payload.lastErrorTime = m.heartbeat["lastErrorTime"]

        ' Get last 20 screen views
        screenHistory = CreateObject("roArray", 100, true)
        if m.heartbeat["screenHistory"].Count() > 0
            count = m.heartbeat["screenHistory"].Count()
            start = count - 20
            if start < 0 then start = 0
            for i = start to count - 1
                screenHistory.Push(m.heartbeat["screenHistory"][i])
            end for
        end if
        payload.screenHistory = FormatJson(screenHistory)

        ' Send export if URL configured
        if m.heartbeat["exportUrl"] <> ""
            http = CreateObject("roUrlTransfer")
            http.SetUrl(m.heartbeat["exportUrl"])
            http.SetCertificatesFile("common:/certs/ca-bundle.crt")
            http.SetUrlMethod("post")
            http.SetHeader("Content-Type", "application/json")
            http.PostJson(FormatJson(payload))

            ' Reset counters after export
            m.heartbeat["lastExport"] = CreateObject("roDateTime").AsSeconds()
            m.heartbeat["screenHistory"].Clear()
            m.heartbeat["crashCount"] = 0
            m.heartbeat["warningCount"] = 0
            m.heartbeat["networkErrors"] = 0
            m.heartbeat["contentFetches"] = 0
            m.heartbeat["lastError"] = ""
            LogInfo("Heartbeat", "Exported payload to " + m.heartbeat["exportUrl"])
        else
            LogInfo("Heartbeat", "No export URL - payload not sent")
        end if

        ' Release roUrlTransfer to free network resources
        http = invalid

        return payload
    catch ex
        LogError("Heartbeat", "Export failed: " + ex.Message)
        ' Release roUrlTransfer in error path
        http = invalid
        return CreateObject("roAssociativeArray")
    end try
end function

sub HeartbeatTrackScreen(screenName as string)
    if m.heartbeat = invalid then return
    m.heartbeat["currentScreen"] = screenName

    entry = CreateObject("roAssociativeArray")
    entry.screen = screenName
    entry.time = CreateObject("roDateTime").AsSeconds()
    m.heartbeat["screenHistory"].Push(entry)
end sub

sub HeartbeatTrackVideo(playing as boolean, videoId as string, position as integer, duration as integer)
    if m.heartbeat = invalid then return
    m.heartbeat["isVideoPlaying"] = playing
    m.heartbeat["videoId"] = videoId
    m.heartbeat["videoPosition"] = position
    m.heartbeat["videoDuration"] = duration

    if playing
        m.heartbeat["videoState"] = "playing"
    else
        m.heartbeat["videoState"] = "idle"
    end if

    LogInfo("Heartbeat", "Video state: " + IIfStr(playing, "playing", "idle") + " - " + videoId)
end sub

sub HeartbeatTrackCrash(message as string)
    if m.heartbeat = invalid then return
    m.heartbeat["crashCount"] = m.heartbeat["crashCount"] + 1
    m.heartbeat["lastError"] = message
    m.heartbeat["lastErrorTime"] = CreateObject("roDateTime").AsSeconds().ToStr()
    LogError("Heartbeat", "Crash #" + m.heartbeat["crashCount"].ToStr() + ": " + message)
end sub

sub HeartbeatTrackWarning(message as string)
    if m.heartbeat = invalid then return
    m.heartbeat["warningCount"] = m.heartbeat["warningCount"] + 1
    LogWarn("Heartbeat", "Warning #" + m.heartbeat["warningCount"].ToStr() + ": " + message)
end sub
