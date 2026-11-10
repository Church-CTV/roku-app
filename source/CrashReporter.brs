' CrashReporter.brs - Crash and error reporting for example Roku channel
' Captures runtime errors, stores crash data locally, and reports on next app launch
' Uses the global node for persistent storage across scene transitions

sub CrashReporterInit()
    try
        ' Note: m.global.crashReporter is set via MainScene.brs Init()
        ' This function no longer creates the crashReporter node directly
        ' (roSGNode does not support adding node-typed fields at runtime)
    catch e
        LogWarn("CrashReporter", "CrashReporterInit: " + e.message)
    end try
end sub

' Report a crash with full context
sub ReportCrash(errorMessage, stackTrace, context)
    try
        if m.global = invalid or m.global.crashReporter = invalid
            return
        end if

        crash = CreateObject("roSGNode", "CrashEvent")
        crash.type = "crash"
        crash.message = errorMessage
        crash.stackTrace = stackTrace
        crash.timestamp = GetTimestamp()
        crash.appVersion = m.global.AppVersion
        crash.sessionDuration = GetSessionDuration()
        crash.activeScreen = ""
        if m.global.analytics <> invalid and m.global.analytics.activeScreen <> invalid
            crash.activeScreen = m.global.analytics.activeScreen
        end if

        ' Capture context data if available
        if context <> invalid
            crash.contextData = context
        end if

        ' Increment crash count
        m.global.crashReporter.crashCount = m.global.crashReporter.crashCount + 1

        ' Store in pending crashes
        m.global.crashReporter.pendingCrashes.Push(crash)

        ' Update last crash info
        m.global.crashReporter.lastCrashTime = GetTimestamp()
        m.global.crashReporter.lastCrashMessage = errorMessage
        m.global.crashReporter.lastCrashStack = stackTrace

        ' Track crash with heartbeat
        HeartbeatTrackCrash(errorMessage)

        ' If we have a stack trace, log it
        if stackTrace <> invalid and stackTrace <> ""
            LogError("CrashReporter", "Crash #" + m.global.crashReporter.crashCount.ToStr() + ": " + errorMessage)
        end if
    catch e
        LogError("CrashReporter", "ReportCrash: " + e.message)
    end try
end sub

' Report a recoverable error (not a full crash)
sub ReportError(errorType, errorMessage, context)
    try
        if m.global = invalid or m.global.crashReporter = invalid
            return
        end if

        ' Also track via analytics module
        TrackError(errorType, errorMessage, context)

        errorEvent = CreateObject("roSGNode", "ErrorEvent")
        errorEvent.type = "error"
        errorEvent.errorType = errorType
        errorEvent.message = errorMessage
        errorEvent.context = context
        errorEvent.timestamp = GetTimestamp()
        errorEvent.appVersion = m.global.AppVersion

        ' Increment error count
        m.global.crashReporter.errorCount = m.global.crashReporter.errorCount + 1
    catch e
        LogError("CrashReporter", "ReportError: " + e.message)
    end try
end sub

' Get crash report summary
function GetCrashSummary () as object
    try
        if m.global = invalid or m.global.crashReporter = invalid
            return {}
        end if

        summary = {
            totalCrashes: m.global.crashReporter.crashCount
            totalErrors: m.global.crashReporter.errorCount
            pendingCrashes: m.global.crashReporter.pendingCrashes.Count()
            lastCrashTime: m.global.crashReporter.lastCrashTime
            lastCrashMessage: m.global.crashReporter.lastCrashMessage
        }

        return summary
    catch e
        LogError("CrashReporter", "GetCrashSummary: " + e.message)
        return {}
    end try
end function

' Export pending crash reports as JSON-serializable array
function ExportPendingCrashes () as object
    try
        if m.global = invalid or m.global.crashReporter = invalid
            return {}
        end if

        pending = m.global.crashReporter.pendingCrashes
        exported = []

        for each crash in pending
            if crash <> invalid
                exportItem = {
                    type: crash.type
                    message: crash.message
                    stackTrace: crash.stackTrace
                    timestamp: crash.timestamp
                    appVersion: crash.appVersion
                    sessionDuration: crash.sessionDuration
                    activeScreen: crash.activeScreen
                }
                exported.Push(exportItem)
            end if
        end for

        return exported
    catch e
        LogError("CrashReporter", "ExportPendingCrashes: " + e.message)
        return {}
    end try
end function

' Clear pending crash reports (after successful export)
sub ClearPendingCrashes()
    try
        if m.global = invalid or m.global.crashReporter = invalid
            return
        end if

        m.global.crashReporter.pendingCrashes.Clear()
        m.global.crashReporter.crashCount = 0
        LogInfo("CrashReporter", "Pending crash reports cleared")
    catch e
        LogError("CrashReporter", "ClearPendingCrashes: " + e.message)
    end try
end sub
