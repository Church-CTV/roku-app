' ServiceScheduler.brs - Service schedule fetching and display
' Fetches upcoming service times from the church website and displays them

' Fetch service schedule from API
function FetchServiceSchedule (url as string) as object
    try
        if url = "" then return invalid

        xfer = CreateObject("roURLTransfer")
        if xfer = invalid then return invalid

        xfer.SetPort(CreateObject("roMessagePort"))
        xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
        xfer.InitClientCertificates()
        xfer.EnableEncodings(true)
        xfer.SetUrl(url)
        xfer.SetRequest("GET")
        xfer.AddHeader("User-Agent", "Roku/ExampleChannel")
        xfer.AsyncGetToString()

        msg = wait(15000, xfer.GetPort())
        if Type(msg) = "roUrlEvent"
            if msg.GetInt() = 1
                responseCode = msg.GetResponseCode()
                if responseCode = 200
                    xfer = invalid
                    return ParseJson(msg.GetString())
                end if
            end if
        end if
        xfer = invalid
    catch e
        SafeLog("ERROR", "ServiceScheduler", "FetchServiceSchedule failed: " + e.message)
    end try
    return invalid
end function

' Get next upcoming service from schedule
function GetNextService (schedule as object) as object
    if schedule = invalid then return invalid
    if Type(schedule) <> "roAssociativeArray" then return invalid

    now = CreateObject("roDateTime")
    currentEpoch = now.AsSeconds()

    services = schedule.services
    if services = invalid or Type(services) <> "roArray" then return invalid

    minDiff = 999999999
    nextService = invalid

    for each service in services
        serviceTime = service.time
        if serviceTime <> invalid
            ' Parse ISO date time to epoch
            serviceEpoch = ParseDateTime(serviceTime)
            if serviceEpoch <> invalid
                diff = serviceEpoch - currentEpoch
                if diff > 0 and diff < minDiff
                    minDiff = diff
                    nextService = service
                end if
            end if
        end if
    end for

    return nextService
end function

' Parse ISO datetime string to epoch seconds
function ParseDateTime (isoString as string) as integer
    try
        ' Expected format: "2024-01-15T10:00:00Z"
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
        SafeLog("ERROR", "ServiceScheduler", "ParseDateTime failed for '" + isoString + "': " + e.message)
        return 0
    end try
end function

' Format time remaining until service
function FormatTimeRemaining (serviceTime as string) as string
    if serviceTime = "" then return ""

    serviceEpoch = ParseDateTime(serviceTime)
    if serviceEpoch = 0 then return ""

    now = CreateObject("roDateTime")
    currentEpoch = now.AsSeconds()

    diff = serviceEpoch - currentEpoch
    if diff <= 0 then return "Now"

    hours = Int(diff / 3600)
    minutes = Int((diff - hours * 3600) / 60)

    if hours > 24
        days = Int(hours / 24)
        remaining = hours - days * 24
        if remaining > 0
            return days.ToStr() + " days, " + remaining.ToStr() + " hours"
        end if
        return days.ToStr() + " days"
    else if hours > 0
        return hours.ToStr() + " hours, " + minutes.ToStr() + " minutes"
    else
        return minutes.ToStr() + " minutes"
    end if
end function

' Format service time for display
function FormatServiceTime (serviceTime as string) as string
    if serviceTime = "" then return ""

    try
        dt = CreateObject("roDateTime")
        epoch = ParseDateTime(serviceTime)
        if epoch = 0 then return ""

        dt.SetTime(epoch)
        dt.ToLocalTime()

        dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        day = dayNames[dt.GetDayOfWeek()]

        hour = dt.GetHours()
        if hour >= 12
            hour = hour - 12
            period = "PM"
        else
            period = "AM"
        end if

        return day + " at " + hour.ToStr() + ":" + PadLeft(dt.GetMinutes().ToStr(), "0", 2) + " " + period
    catch e
        SafeLog("ERROR", "ServiceScheduler", "FormatServiceTime failed for '" + serviceTime + "': " + e.message)
        return ""
    end try
end function

' Check if service is currently live
function IsServiceLive (schedule as object) as boolean
    if schedule = invalid then return false

    now = CreateObject("roDateTime")
    currentEpoch = now.AsSeconds()

    services = schedule.services
    if services = invalid then return false

    for each service in services
        startTime = service.startTime
        endTime = service.endTime

        if startTime <> invalid and endTime <> invalid
            startEpoch = ParseDateTime(startTime)
            endEpoch = ParseDateTime(endTime)

            if startEpoch <> 0 and endEpoch <> 0
                if currentEpoch >= startEpoch and currentEpoch <= endEpoch
                    return true
                end if
            end if
        end if
    end for
    return false
end function

' Get current live service
function GetCurrentLiveService (schedule as object) as object
    if schedule = invalid then return invalid

    now = CreateObject("roDateTime")
    currentEpoch = now.AsSeconds()

    services = schedule.services
    if services = invalid then return invalid

    for each service in services
        startTime = service.startTime
        endTime = service.endTime

        if startTime <> invalid and endTime <> invalid
            startEpoch = ParseDateTime(startTime)
            endEpoch = ParseDateTime(endTime)

            if startEpoch <> 0 and endEpoch <> 0
                if currentEpoch >= startEpoch and currentEpoch <= endEpoch
                    return service
                end if
            end if
        end if
    end for
    return invalid
end function
