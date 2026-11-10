' LiveServiceIndicator.brs - Live service detection and indicator
' Detects when a service is live and provides indicator state

' Check if there is a live service
function IsLiveServiceActive (schedule as object, config as object) as boolean
    if schedule = invalid then return false
    if config = invalid then return false

    ' Check if live service feature is enabled
    if config.features <> invalid and config.features.liveService = false
        return false
    end if

    ' Check if current time falls within any service window
    now = CreateObject("roDateTime")
    currentEpoch = now.AsSeconds()

    services = schedule.services
    if services = invalid then return false

    for each service in services
        startTime = service.startTime
        endTime = service.endTime

        if startTime <> invalid and endTime <> invalid
            startEpoch = ParseLiveDateTime(startTime)
            endEpoch = ParseLiveDateTime(endTime)

            if startEpoch <> 0 and endEpoch <> 0
                if currentEpoch >= startEpoch and currentEpoch <= endEpoch
                    return true
                end if
            end if
        end if
    end for

    return false
end function

' Get live stream URL from config
function GetLiveStreamUrl (config as object) as string
    if config = invalid then return ""
    if config.branding = invalid or config.branding.images = invalid then return ""
    if config.branding.images.liveStreamUrl = invalid then return ""
    return config.branding.images.liveStreamUrl
end function

' Create live content node
function CreateLiveContentNode (schedule as object, config as object) as object
    _schedule = schedule
    node = CreateObject("roSGNode", "ContentNode")
    node.id = "live_service"
    node.title = "LIVE Service"
    node.description = "Watch the current service live"
    node.streamFormat = "mp4"
    node.url = GetLiveStreamUrl(config)
    node.hdPosterUrl = config.branding.images.liveStreamThumbnail
    node.category = "live"
    node.contentIsPlaylist = false
    return node
end function

' Parse datetime for live service check
function ParseLiveDateTime (isoString as string) as integer
    try
        year = Mid(isoString, 1, 4).ToInt()
        month = Mid(isoString, 6, 2).ToInt()
        day = Mid(isoString, 9, 2).ToInt()
        hour = Mid(isoString, 12, 2).ToInt()
        minute = Mid(isoString, 15, 2).ToInt()
        second = Mid(isoString, 18, 2).ToInt()

        dt = CreateObject("roDateTime")
        dt.SetDate(year, month, day, hour, minute, second)
        return dt.AsSeconds()
    catch e
        LogWarn("LiveServiceIndicator", "ParseLiveDateTime failed for '" + isoString + "': " + e.message)
        return 0
    end try
end function

' Check if service is live
function IsLiveService (service as object) as boolean
    if service = invalid then return false
    now = CreateObject("roDateTime")
    currentEpoch = now.AsSeconds()
    startTime = service.startTime
    endTime = service.endTime
    if startTime = invalid or endTime = invalid then return false
    startEpoch = ParseLiveDateTime(startTime)
    endEpoch = ParseLiveDateTime(endTime)
    if startEpoch = 0 or endEpoch = 0 then return false
    return currentEpoch >= startEpoch and currentEpoch <= endEpoch
end function

' Get live service info
function GetLiveServiceInfo (schedule as object) as object
    info = CreateObject("roAssociativeArray")
    info.isLive = false
    info.service = invalid
    if schedule = invalid or schedule.services = invalid then return info
    for each service in schedule.services
        if IsLiveService(service)
            info.isLive = true
            info.service = service
            return info
        end if
    end for
    return info
end function

' Check live status
function CheckLiveStatus (schedule as object, config as object) as boolean
    if schedule = invalid or config = invalid then return false
    return IsLiveServiceActive(schedule, config)
end function
