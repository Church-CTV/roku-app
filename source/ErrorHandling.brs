' ErrorHandling.brs - Centralized error handling infrastructure
' Included in MainScene.xml via <script> tag (after App.brs, before CrashReporter.brs)
' Note: GetTimestamp, LogError, LogFatal, LogWarn, LogInfo, LogDebug are provided by App.brs
' Note: ReportError is provided by CrashReporter.brs
' Note: LogErrorWithCategory, LogFatalWithCategory, LogWarnWithCategory are provided by App.brs
' This module provides the centralized error log storage and reporting

' Initialize error handling with global node reference
sub InitErrorHandling(globalNode)
    try
        LogInfo("ErrorHandling", "InitErrorHandling() START")
        ' Store global node reference for later use
        if globalNode <> invalid
            if globalNode.errorHandlerInitialized = invalid
                globalNode.errorHandlerInitialized = true
                globalNode.errorLog = CreateObject("roArray", 0, true)
                globalNode.errorCount = 0
                globalNode.lastError = invalid
            end if
        end if
    catch e
        SafeLog("ERROR", "InitErrorHandling", "Error: " + e.message)
    end try
end sub

' Get error log array from global node
function GetErrorLog (globalNode) as object
    try
        if globalNode <> invalid and globalNode.errorLog <> invalid
            return globalNode.errorLog
        end if
        return CreateObject("roArray", 0, true)
    catch e
        SafeLog("ERROR", "GetErrorLog", "Error: " + e.message)
        return CreateObject("roArray", 0, true)
    end try
end function

' Get error count from global node
function GetErrorCount (globalNode) as integer
    try
        if globalNode <> invalid and globalNode.errorCount <> invalid
            return globalNode.errorCount
        end if
        return 0
    catch e
        SafeLog("ERROR", "GetErrorCount", "Error: " + e.message)
        return 0
    end try
end function

' Get last error from global node
function GetLastError (globalNode) as object
    try
        if globalNode <> invalid and globalNode.lastError <> invalid
            return globalNode.lastError
        end if
        return invalid
    catch e
        SafeLog("ERROR", "GetLastError", "Error: " + e.message)
        return invalid
    end try
end function

' Increment error count
sub IncrementErrorCount(globalNode)
    try
        if globalNode <> invalid
            globalNode.errorCount = globalNode.errorCount + 1
        end if
    catch e
        SafeLog("ERROR", "IncrementErrorCount", "Error: " + e.message)
    end try
end sub

' Log to internal error log array
sub LogToErrorLog(component, message, category, errorType, severity, globalNode)
    try
        logArray = GetErrorLog(globalNode)
        entry = CreateObject("roAssociativeArray")
        entry.component = component
        entry.message = message
        entry.category = category
        entry.errorType = errorType
        entry.severity = severity
        entry.timestamp = GetTimestamp()
        logArray.Push(entry)
        IncrementErrorCount(globalNode)
        if globalNode <> invalid
            globalNode.lastError = entry
        end if
    catch e
        SafeLog("ERROR", "LogToErrorLog", "Error: " + e.message)
    end try
end sub

' Report error to crash reporter or analytics
' Note: This function is called by CrashReporter.brs's ReportError
' We use ExistsFunctionStub to check if ReportError is available
sub ReportErrorToCrashReporter(errorType, message, context, globalNode)
    try
        ' Try to notify the crash reporter if available
        if m.global <> invalid and m.global.crashReporter <> invalid
            ReportError(errorType, message, context)
        end if
        ' Try to track error via analytics
        if globalNode <> invalid and globalNode.analytics <> invalid
            if globalNode.analytics.TrackError <> invalid
                globalNode.analytics.TrackError(errorType, message, context)
            end if
        end if
    catch e
        LogError("ErrorHandling", "Failed to report error: " + e.message)
    end try
end sub

' Get error summary
function GetErrorSummary (globalNode) as object
    try
        return {
            errorCount: GetErrorCount(globalNode)
            lastError: GetLastError(globalNode)
            recentErrors: GetErrorLog(globalNode)
        }
    catch e
        SafeLog("ERROR", "GetErrorSummary", "Error: " + e.message)
        return {}
    end try
end function

' Clear error log
sub ClearErrorLog(globalNode)
    try
        if globalNode <> invalid
            globalNode.errorLog = CreateObject("roArray", 0, true)
            globalNode.errorCount = 0
            globalNode.lastError = invalid
        end if
    catch e
        SafeLog("ERROR", "ClearErrorLog", "Error: " + e.message)
    end try
end sub
