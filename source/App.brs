

' App.brs - Shared application utilities for Roku channel template
' Provides unified logging, focus helpers, content node factory, and analytics helpers

' NodeHasField: Returns true if the node or associative array has the specified field.
function NodeHasField (node, fieldName) as boolean
    try
        if node = invalid then return false
        nodeType = Type(node)
        if nodeType = "roAssociativeArray"
            return node.DoesExist(fieldName)
        else
            ' For roSGNode, check interface fields via GetInterfaces().
            interfaces = node.GetInterfaces()
            if interfaces <> invalid
                for each ifc in interfaces
                    if ifc.IsFunction(fieldName)
                        return true
                    end if
                end for
            end if
            return false
        end if
    catch e
        SafeLog("WARN", "NodeHasField", "Error checking field '" + fieldName + "': " + e.message)
        return false
    end try
end function

' EnsureField: Ensures a field exists on a node, adding it if necessary.
' Returns true if the field was usable (existed or was added).
function EnsureField (node as object, fieldName as string, fieldType as string) as boolean
    if node = invalid then return false
    nodeType = Type(node)
    if nodeType = "roAssociativeArray"
        if node.DoesExist(fieldName) then return true
        return node.AddField(fieldName, fieldType, false)
    else
        ' Try to read the field — if it works, field exists.
        try
            node.GetField(fieldName)
            return true
        catch e
            ' Field doesn't exist — add it.
            SafeLog("DEBUG", "EnsureField", "Adding missing field '" + fieldName + "' to " + nodeType + e.message)
            return node.AddField(fieldName, fieldType, false)
        end try
    end if
end function

' Initialize shared app state
sub AppInit()
    try
        if m.global = invalid
            return
        end if
        ' Add custom fields to the global node. addFields() is idempotent: it returns
        ' false for fields that already exist but does not throw or overwrite values.
        m.global.addFields({
            DeepContentId: "",
            DeepMediaType: "",
            AppVersion: "1.0.0",
            ContentLoaded: false,
            ErrorOccurred: false,
            ErrorMessage: "",
            locationKey: ""
        })
    catch e
        SafeLog("ERROR", "AppInit", "Exception during global field registration: " + e.message)
    end try
end sub

' Unified logging with severity levels and component prefix
sub AppLog(severity, component, message)
    try
        timestamp = GetTimestamp()
        print "[" + timestamp + "] [" + severity + "] [" + component + "] " + message
    catch e
        ' If logging fails, print a minimal message to the console.
        print "[LOG ERROR] [" + component + "] " + message + " (Logging failed: " + e.message + ")"
    end try
end sub

' Safe logging — never crashes even if GetTimestamp fails
sub SafeLog(severity, component, message)
    try
        if GetTimestamp <> invalid
            AppLog(severity, component, message)
        else
            print "[SAFE] [" + severity + "] [" + component + "] " + message
        end if
    catch e
        print "[SAFE LOG ERROR] [" + component + "] " + message + " (Logging failed: " + e.message + ")"
    end try
end sub

' SafeRun: universal safety wrapper with retry and error reporting
' fn must be a function that returns true on success, false on failure
' On failure: logs error, reports to CrashReporter, retries once, gives up
' Note: fn is called directly (not via .call()) so it can access m in its own scope
function SafeRun (fn as object, label as string) as boolean
    try
        if fn = invalid
            SafeLog("ERROR", "SafeRun", "fn is invalid: " + label)
            return false
        end if

        ' First attempt
        result = fn()
        if result = true
            return true
        end if

        ' First attempt failed — log and report
        SafeLog("ERROR", "SafeRun", "Failed: " + label)

        ' Retry once
        result = fn()
        if result = true
            SafeLog("WARN", "SafeRun", "Retry succeeded: " + label)
            return true
        end if

        ' Retry also failed — give up
        SafeLog("ERROR", "SafeRun", "Failed after retry, giving up: " + label)
        return false
    catch e
        SafeLog("ERROR", "SafeRun", "Exception in SafeRun('" + label + "'): " + e.message)
        return false
    end try
end function

' SafeGetScene: returns scene or invalid (never crashes)
function SafeGetScene (node as object) as object
    try
        if node = invalid then return invalid
        try
            scene = node.GetScene()
            return scene
        catch e
            SafeLog("WARN", "SafeGetScene", "GetScene failed: " + e.message)
            return invalid
        end try
    catch e
        SafeLog("WARN", "SafeGetScene", "Exception in SafeGetScene: " + e.message)
        return invalid
    end try
end function

' SafeFindNode: safe wrapper for FindNode that never crashes
function SafeFindNode (parent as object, nodeId as string) as object
    if parent = invalid then return invalid
    try
        node = parent.FindNode(nodeId)
        return node
    catch e
        SafeLog("WARN", "SafeFindNode", "FindNode('" + nodeId + "') failed: " + e.message)
        return invalid
    end try
end function

' SafeObserveField: safe wrapper for ObserveField that never crashes
function SafeObserveField (node as object, field as string, handler as string) as boolean
    if node = invalid then return false
    try
        result = node.ObserveField(field, handler)
        return result
    catch e
        SafeLog("WARN", "SafeObserveField", "ObserveField('" + field + "') failed: " + e.message)
        return false
    end try
end function

' SafeUnobserveField: safe wrapper for UnobserveField that never crashes
sub SafeUnobserveField (node as object, field as string)
    if node = invalid then return
    try
        node.UnobserveField(field)
    catch e
        SafeLog("WARN", "SafeUnobserveField", "UnobserveField('" + field + "') failed: " + e.message)
    end try
end sub

' SafeCallFunc: safe wrapper for CallFunc that never crashes
function SafeCallFunc (node as object, funcName as string, arg1) as object
    if node = invalid then return invalid
    try
        result = node.CallFunc(funcName, arg1)
        return result
    catch e
        SafeLog("WARN", "SafeCallFunc", "CallFunc('" + funcName + "') failed: " + e.message)
        return invalid
    end try
end function

' Get current timestamp as HH:MM:SS
function GetTimestamp () as string
    try
        now = CreateObject("roDateTime")
        now.ToLocalTime()
        return PadLeft(now.GetHours().ToStr(), "0", 2) + ":" + PadLeft(now.GetMinutes().ToStr(), "0", 2) + ":" + PadLeft(now.GetSeconds().ToStr(), "0", 2)
    catch e
        SafeLog("ERROR", "GetTimestamp", "Exception in GetTimestamp: " + e.message)
        return "00:00:00"
    end try
end function

' Log info level
sub LogInfo(component, message)
    AppLog("INFO", component, message)
end sub

' Log error level
sub LogError(component, message)
    AppLog("ERROR", component, message)
end sub

' Log debug level
sub LogDebug(component, message)
    AppLog("DEBUG", component, message)
end sub

' Log warn level
sub LogWarn(component, message)
    AppLog("WARN", component, message)
    ' Track warning with heartbeat (disabled - function not resolved by compiler)
    ' HeartbeatTrackWarning(component + ": " + message)
end sub

' Set focus with animation delay for smoother transitions
sub SetFocusWithAnimation(node, delay)
    if node <> invalid
        Sleep(delay)
        node.SetFocus(true)
    end if
end sub

' Create a standardized content node from feed data
function CreateContentNode (item) as object
    node = CreateObject("roSGNode", "ContentNode")
    if item <> invalid
        node.title = item.title
        node.description = item.description
        if item.content <> invalid and item.content.videos <> invalid and item.content.videos.Count() > 0
            node.streamFormat = "mp4"
            node.url = item.content.videos[0].url
            if item.content.duration <> invalid
                node.length = item.content.duration
            end if
        end if
        if item.thumbnail <> invalid
            node.hdPosterUrl = item.thumbnail
        end if
        if item.category <> invalid
            node.category = item.category
        end if
        ' Set for playlist behavior
        node.contentIsPlaylist = false
        node.showNext = true
    end if
    return node
end function

' Format duration for display
function FormatDuration (seconds) as string
    if seconds < 0
        return "0:00"
    end if
    hours = seconds \ 3600
    minutes = (seconds mod 3600) \ 60
    secs = seconds mod 60

    if hours > 0
        return Stri(hours) + ":" + PadLeft(Stri(minutes), "0", 2) + ":" + PadLeft(Stri(secs), "0", 2)
    else
        return Stri(minutes) + ":" + PadLeft(Stri(secs), "0", 2)
    end if
end function

' Pad a string on the left with a character
function PadLeft (str, padChar, width) as string
    result = str
    while Len(result) < width
        result = padChar + result
    end while
    return result
end function

' Simple string split helper
function SplitString (str, delimiter) as object
    if str = invalid or str = "" or delimiter = ""
        return []
    end if
    result = []
    delimLen = Len(delimiter)
    while Len(str) > 0
        delimPos = 0
        for i = 1 to Len(str)
            if Mid(str, i, delimLen) = delimiter
                delimPos = i
                exit for
            end if
        end for
        if delimPos > 0
            result.Push(Mid(str, 1, delimPos - 1))
            str = Mid(str, delimPos + delimLen)
        else
            result.Push(str)
            str = ""
        end if
    end while
    return result
end function

' HasFocusInterface: Silently checks if a node supports the ifSGNodeFocus interface
' (hasFocus, GetFocus, SetFocus, isInFocusChain, etc). Returns true if supported.
' Non-visual nodes (ContentNode, Timer, Task) do not support this interface.
function HasFocusInterface (node) as boolean
    if node = invalid then return false
    try
        node.hasFocus()
        return true
    catch e
        _e = e
        return false
    end try
end function

' SafeNodeGetFocus: Safely gets the currently focused descendant of a node.
' Catches "Member function not found" silently since this is expected for
' non-visual nodes (ContentNode, Timer, Task) that don't implement ifSGNodeFocus.
' Only logs unexpected errors (not member-not-found) for debugging.
function SafeNodeGetFocus (node) as object
    if node = invalid then return invalid
    try
        return node.GetFocus()
    catch e
        _e = e
        return invalid
    end try
end function

' SafeGetFocusedNode: Get the focused node within a parent, or return invalid.
function GetFocusedNode (parentNode) as object
    if parentNode = invalid then return invalid
    return SafeNodeGetFocus(parentNode)
end function

' FindFocusableNode: Recursively finds the first focusable, enabled, visible
' descendant of a node. Returns invalid if none found.
' Guards against node types that don't support focusable/enabled/visible or
' GetChild/GetNextSibling (e.g., Video, MiniKeyboard, ContentNode).
function FindFocusableNode (node) as object
    if node = invalid then return invalid
    try
        if node.focusable = true and node.enabled = true and node.visible = true
            return node
        end if
    catch e
        ' Some nodes don't support focusable/enabled/visible fields — skip
        SafeLog("DEBUG", "FindFocusableNode", "Node type lacks focus fields: " + Type(node))
    end try

    try
        nodeType = Type(node)
        if nodeType <> "roSGNode" and nodeType <> "roArray" then return invalid
        child = node.GetChild()
        if child = invalid then return invalid
        while child <> invalid
            result = FindFocusableNode(child)
            if result <> invalid then return result
            try
                child = child.GetNextSibling()
            catch e
                SafeLog("DEBUG", "FindFocusableNode", "GetNextSibling not supported on " + Type(child))
                exit while
            end try
        end while
    catch e
        ' GetChild not supported on this node type — skip
        SafeLog("DEBUG", "FindFocusableNode", "GetChild not supported on " + Type(node) + ": " + e.message)
    end try
    return invalid
end function

' SetFocusSafe: Hardened focus setter that verifies focus actually landed.
function SetFocusSafe (node) as boolean
    if node = invalid then return false
    try
        if node.focusable = true and node.enabled = true and node.visible = true
            node.SetFocus(true)
            return true
        end if
    catch e
        SafeLog("WARN", "SetFocusSafe", "Direct focus check failed: " + e.message)
    end try

    try
        target = FindFocusableNode(node)
        if target <> invalid
            target.SetFocus(true)
            return true
        end if
    catch e
        SafeLog("WARN", "SetFocusSafe", "Focusable node search failed: " + e.message)
    end try

    try
        node.SetFocus(true)
        return true
    catch e
        SafeLog("WARN", "SetFocusSafe", "Fallback SetFocus failed: " + e.message)
    end try

    return false
end function

' EnsureFocusLanded: After calling SetFocus, verifies focus actually landed.
sub EnsureFocusLanded(primaryTarget, fallbackTargets)
    try
        Sleep(50)

        if fallbackTargets <> invalid
            for each fallback in fallbackTargets
                if fallback <> invalid
                    if SetFocusSafe(fallback)
                        Sleep(30)
                        if GetFocusedNode(fallback) <> invalid
                            return
                        end if
                    end if
                end if
            end for
        end if

        if SetFocusSafe(primaryTarget)
            return
        end if

        LogWarn("App", "EnsureFocusLanded: focus may not be on any expected target")
    catch e
        LogError("App", "EnsureFocusLanded: " + e.message)
    end try
end sub

' ================================================================
' Memory Monitoring APIs (Roku Certification 3.2+ / rsg_version=1.3)
' ================================================================

' GetChannelAvailableMemory — returns available memory in KB
function GetChannelAvailableMemory () as integer
    try
        memMon = CreateObject("roAppMemoryMonitor")
        if memMon <> invalid and memMon.HasInterface("ifAppMemoryMonitor")
            return memMon.GetChannelAvailableMemory()
        end if
        return -1
    catch e
        LogWarn("App", "GetChannelAvailableMemory failed: " + e.message)
        return -1
    end try
end function

' EnableMemoryWarningEvent — enables low memory warning events
sub EnableMemoryWarningEvent(enable as boolean)
    try
        memMon = CreateObject("roAppMemoryMonitor")
        if memMon <> invalid and memMon.HasInterface("ifAppMemoryMonitor")
            memMon.EnableMemoryWarningEvent(enable)
        end if
    catch e
        LogWarn("App", "EnableMemoryWarningEvent failed: " + e.message)
    end try
end sub

' GetMemoryLimitPercent — returns the memory limit percentage threshold
function GetMemoryLimitPercent () as integer
    try
        memMon = CreateObject("roAppMemoryMonitor")
        if memMon <> invalid and memMon.HasInterface("ifAppMemoryMonitor")
            return memMon.GetMemoryLimitPercent()
        end if
        return 0
    catch e
        LogWarn("App", "GetMemoryLimitPercent failed: " + e.message)
        return 0
    end try
end function

' GetChannelMemoryLimit — returns the channel memory limit in KB
function GetChannelMemoryLimit () as object
    try
        memMon = CreateObject("roAppMemoryMonitor")
        if memMon <> invalid and memMon.HasInterface("ifAppMemoryMonitor")
            return memMon.GetChannelMemoryLimit()
        end if
        return {}
    catch e
        LogWarn("App", "GetChannelMemoryLimit failed: " + e.message)
        return {}
    end try
end function

' EnableLowGeneralMemoryEvent — enables general low memory events on device info
sub EnableLowGeneralMemoryEvent(enabled as boolean)
    try
        di = CreateObject("roDeviceInfo")
        if di <> invalid and di.HasInterface("ifDeviceInfo")
            di.EnableLowGeneralMemoryEvent(enabled)
        end if
    catch e
        LogWarn("App", "EnableLowGeneralMemoryEvent failed: " + e.message)
    end try
end sub
