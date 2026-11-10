' ExitButton.brs - Custom exit button with reliable OK/SELECT handling
' Note: does not load App.brs to keep it lightweight. Uses print() for debug.

sub Init()
    try
        m.focusBorder = SafeFindNode(m.top, "focusBorder")
        if m.focusBorder = invalid then return
        m.top.observeField("focused", "OnFocusChanged")
    catch e
        SafeLog("ERROR", "ExitButtonInit", "Error: " + e.message)
    end try
end sub

function OnKeyEvent (key, press) as boolean
    try
        keyLower = LCase(key)
        if press and (keyLower = "ok" or keyLower = "select")
            m.top.exitRequested = true
            return true
        end if
        return false
    catch e
        SafeLog("ERROR", "ExitButtonOnKeyEvent", "Error: " + e.message)
        return false
    end try
end function

' OnExit handler - cleanup resources when button exits
sub OnExit()
    try
        m.top.UnobserveField("focused")
    catch e
        SafeLog("ERROR", "ExitButtonOnExit", "Error: " + e.message)
    end try
end sub

' Handle focus change for visual border
sub OnFocusChanged()
    try
        if m.top.focused
            m.focusBorder.visible = true
            m.focusBorder.opacity = 0.8
        else
            m.focusBorder.visible = false
            m.focusBorder.opacity = 0
        end if
    catch e
        SafeLog("ERROR", "ExitButtonOnFocusChanged", "Error: " + e.message)
    end try
end sub
