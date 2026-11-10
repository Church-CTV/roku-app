' FocusVerifier.brs - Verifies focus operations succeeded
' Uses SceneGraph's built-in focus chain verification

sub Init()
    m.verifyingFocus = false
    m.targetFocusNode = invalid
    m.attempts = 0
    m.maxAttempts = 3
end sub

' Request focus with verification
function RequestFocusWithVerification (node as object) as boolean
    if node = invalid
        return false
    end if

    m.targetFocusNode = node
    m.attempts = 0
    m.verifyingFocus = true

    ' Start verification process
    StartVerification()
    return true
end function

' Start the verification timer
sub StartVerification()
    if m.attempts >= m.maxAttempts
        m.verifyingFocus = false
        return
    end if

    m.attempts = m.attempts + 1

    ' Create verification timer
    if m.verifyTimer = invalid
        m.verifyTimer = CreateObject("roSGNode", "Timer")
        m.verifyTimer.duration = 0.1 ' 100ms delay
        m.verifyTimer.repeat = false
        m.verifyTimer.ObserveField("fire", "OnVerificationTimer")
    end if

    m.verifyTimer.control = "start"
end sub

' Verification timer callback
sub OnVerificationTimer()
    try
        if m.verifyingFocus = false or m.targetFocusNode = invalid
            return
        end if

        ' Check if target has focus
        hasFocus = m.targetFocusNode.hasFocus()
        isInChain = m.targetFocusNode.isInFocusChain()

        if hasFocus or isInChain
            m.verifyingFocus = false
            ' Focus verified - send event
            m.top.focusVerified = true
            return
        end if

        ' Retry focus request
        m.targetFocusNode.SetFocus(true)
        StartVerification()
    catch e
        SafeLog("ERROR", "FocusVerifier", "OnVerificationTimer failed: " + e.message)
        m.verifyingFocus = false
    end try
end sub

' Check current focus state
function GetCurrentFocus () as object
    if m.top.scene <> invalid
        return m.top.scene.focusedNode
    end if
    return invalid
end function

' OnExit handler - cleanup resources when screen exits
sub OnExit()
    ' Stop verification timer if active
    if m.verifyTimer <> invalid
        m.verifyTimer.control = "stop"
        m.verifyTimer.UnobserveField("fire")
        m.verifyTimer = invalid
    end if

    ' Reset state
    m.verifyingFocus = false
    m.targetFocusNode = invalid
    m.attempts = 0
end sub
