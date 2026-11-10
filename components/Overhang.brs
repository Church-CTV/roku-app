' Overhang.brs — Roku banner/overhang component logic

sub init()
    try
        m.logoPoster = SafeFindNode(m.top, "logo")
        m.clockLabel = SafeFindNode(m.top, "clockLabel")
        m.top.ObserveField("logoUri", "OnLogoUriChanged")
        m.top.ObserveField("showClock", "OnShowClockChanged")
        if m.top.showClock = true
            StartClock()
        end if
    catch e
        LogError("Overhang", "init error: " + e.message)
    end try
end sub

sub OnLogoUriChanged()
    if m.top.logoUri <> "" and m.top.logoUri <> invalid and m.logoPoster <> invalid
        m.logoPoster.uri = m.top.logoUri
    end if
end sub

sub OnShowClockChanged()
    if m.top.showClock = true
        StartClock()
    else
        StopClock()
    end if
end sub

sub StartClock()
    if m.clockLabel = invalid then return
    m.clockLabel.visible = true
    UpdateClock()
    if m.clockTimer = invalid
        m.clockTimer = CreateObject("roSGNode", "Timer")
        m.clockTimer.duration = 30
        m.clockTimer.repeat = true
        m.clockTimer.ObserveField("fire", "OnClockTick")
        m.top.AppendChild(m.clockTimer)
    end if
    m.clockTimer.control = "start"
end sub

sub StopClock()
    if m.clockLabel = invalid then return
    m.clockLabel.visible = false
    if m.clockTimer <> invalid
        m.clockTimer.control = "stop"
    end if
end sub

sub OnClockTick()
    if m.top.showClock = true
        UpdateClock()
    end if
end sub

sub UpdateClock()
    if m.clockLabel = invalid then return
    dt = CreateObject("roDateTime")
    hours = dt.GetHours()
    minutes = dt.GetMinutes()
    ampm = "AM"
    if hours >= 12
        ampm = "PM"
        if hours > 12 then hours = hours - 12
    end if
    if hours = 0 then hours = 12
    timeStr = hours.ToStr() + ":" + PadLeft(minutes.ToStr(), "0", 2) + " " + ampm
    m.clockLabel.text = timeStr
end sub

' OnExit handler - cleanup resources when overhang exits
sub OnExit()
    ' Stop clock timer
    StopClock()

    ' Clean up observers
    if m.clockTimer <> invalid
        m.clockTimer.UnobserveField("fire")
    end if
    m.top.UnobserveField("logoUri")
    m.top.UnobserveField("showClock")
end sub
