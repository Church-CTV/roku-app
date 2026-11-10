' FocusManager.brs - Central focus management system
' Coordinates focus state and navigation across all components
'
' Architecture:
'   Scene → LeftNavScreen (nav items) → ContentPanel → ChildPanels → Items
'
' Usage:
'   Initialize in main scene, then components call requestFocus/setFocus to change
'   focus state. Focus state is tracked via event observers, not polling.
'
'   m.focusManager.requestFocus("nav:home")  ' Route to home nav item
'   m.focusManager.requestFocus("panel:search")  ' Route to search panel
'
' Edge Cases:
'   - MiniKeyboard requires explicit focus before accepting input
'   - RowList edge detection via rowItemFocused, not text polling
'   - Focus verification with retry on failure

sub Init()
    ' Initialize focus state
    m.focusChain = ["scene"]
    m.currentFocusArea = ""
    m.previousFocusArea = ""
    m.activePanel = ""
    m.navFocusKey = ""

    ' Track edge positions
    m.isAtEdge = false
    m.edgeType = "" ' "left", "right", "none"

    ' Focus verification state
    m.verifyingFocus = false
    m.focusVerified = false
    m.targetFocusNode = invalid
    m.attempts = 0
    m.maxAttempts = 3

    ' MiniKeyboard specific state
    m.kbHasFocus = false
    m.kbAtLeftEdge = false
    m.kbAtRightEdge = false

    ' RowList edge tracking
    m.rowItemAtEdge = false
    m.rowItemAtLeftEdge = false
    m.rowItemAtRightEdge = false
end sub

' Request focus on a specific node
' Returns true if focus was successfully set
function requestFocus (node as object) as boolean
    if node = invalid then return false

    ' Set target and start focus operation
    m.targetFocusNode = node
    m.attempts = 0
    m.verifyingFocus = true

    ' Attempt to set focus with verification
    if node.SetFocus(true)
        ' Start verification process
        StartFocusVerification()
    end if

    return true
end function

' Request focus by area name (for navigation)
sub requestFocusByArea(area as string)
    ' Parse the area name to determine target
    areaLower = LCase(area)

    ' Route based on area type - using BrightScript string functions
    if InStr(areaLower, "nav:") = 1
        ' Navigate to nav item
        handleNavFocusRequest(areaLower)
    else if InStr(areaLower, "panel:") = 1
        ' Navigate to panel
        handlePanelFocusRequest(areaLower)
    else if InStr(areaLower, "keyboard:") = 1
        ' Navigate to keyboard
        handleKeyboardFocusRequest(areaLower)
    else if InStr(areaLower, "rowlist:") = 1
        ' Navigate to rowlist
        handleRowListFocusRequest(areaLower)
    else if areaLower = "scene"
        ' Return to scene level
        handleSceneFocusRequest()
    end if
end sub

' Handle nav item focus request
sub handleNavFocusRequest(area as string)
    ' Extract nav item name (after "nav:" - 4 chars, BrightScript strings are 1-indexed)
    navItem = Mid(area, 5)

    ' Update previous state
    m.previousFocusArea = m.currentFocusArea
    m.navFocusKey = navItem

    ' Route focus to appropriate nav item
    if navItem = "home" and m.navHomeNode <> invalid
        requestFocus(m.navHomeNode)
    else if navItem = "search" and m.navSearchNode <> invalid
        requestFocus(m.navSearchNode)
    else if navItem = "settings" and m.navSettingsNode <> invalid
        requestFocus(m.navSettingsNode)
    end if

    m.currentFocusArea = area
    m.isAtEdge = false
    m.edgeType = ""
end sub

' Handle panel focus request
sub handlePanelFocusRequest(area as string)
    ' Extract panel name (after "panel:" - 6 chars)
    panelName = Mid(area, 6)

    ' Update state
    m.previousFocusArea = m.currentFocusArea
    m.activePanel = panelName

    ' Route focus to appropriate panel
    if panelName = "home" and m.homePanel <> invalid
        requestFocus(m.homePanel)
    else if panelName = "search" and m.searchPanel <> invalid
        requestFocus(m.searchPanel)
    else if panelName = "settings" and m.settingsPanel <> invalid
        requestFocus(m.settingsPanel)
    end if

    m.currentFocusArea = area
    m.isAtEdge = false
    m.edgeType = ""
end sub

' Handle MiniKeyboard focus request
sub handleKeyboardFocusRequest(area as string)
    ' Extract keyboard type (after "keyboard:" - 9 chars)
    kbType = Mid(area, 10)

    ' Update state
    m.previousFocusArea = m.currentFocusArea
    m.kbHasFocus = true

    ' Route focus to appropriate keyboard
    if kbType = "search" and m.kbNode <> invalid
        requestFocus(m.kbNode)
    end if

    m.currentFocusArea = area
    m.isAtEdge = false
    m.edgeType = ""
end sub

' Handle RowList focus request
sub handleRowListFocusRequest(area as string)
    ' Extract rowlist type (after "rowlist:" - 8 chars)
    rowlistType = Mid(area, 9)

    ' Update state
    m.previousFocusArea = m.currentFocusArea
    m.rowlistType = rowlistType
    m.rowItemAtEdge = false

    ' Route focus to appropriate rowlist
    if rowlistType = "home" and m.homeRowList <> invalid
        requestFocus(m.homeRowList)
    else if rowlistType = "search" and m.searchRowList <> invalid
        requestFocus(m.searchRowList)
    end if

    m.currentFocusArea = area
    m.isAtEdge = false
    m.edgeType = ""
end sub

' Handle scene level focus request
sub handleSceneFocusRequest()
    ' Update state
    m.previousFocusArea = m.currentFocusArea
    m.currentFocusArea = "scene"
    m.isAtEdge = false
    m.edgeType = ""
end sub

' Start focus verification process
sub StartFocusVerification()
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

' Focus verification timer callback
sub OnVerificationTimer()
    try
        if m.verifyingFocus = false or m.targetFocusNode = invalid then return

        ' Check if target has focus
        hasFocus = m.targetFocusNode.hasFocus()
        isInChain = m.targetFocusNode.isInFocusChain()

        if hasFocus or isInChain
            m.verifyingFocus = false
            m.focusVerified = true
            ' Focus verified successfully
            m.top.focusVerified = true
            return
        end if

        ' Retry focus request
        m.targetFocusNode.SetFocus(true)
        StartFocusVerification()
    catch e
        SafeLog("ERROR", "FocusManager", "OnVerificationTimer failed: " + e.message)
        m.verifyingFocus = false
    end try
end sub

' Check if at edge position
function isAtEdge () as boolean
    return m.isAtEdge
end function

' Set edge position
sub setEdgePosition(atEdge as boolean, edgeType as string)
    m.isAtEdge = atEdge
    m.edgeType = edgeType
end sub

' Get current focus area
function getCurrentFocusArea () as string
    return m.currentFocusArea
end function

' Get previous focus area
function getPreviousFocusArea () as string
    return m.previousFocusArea
end function

' Get active panel
function getActivePanel () as string
    return m.activePanel
end function

' Set active panel
sub setActivePanel(panelName as string)
    m.activePanel = panelName
end sub

' Check if MiniKeyboard has focus
function kbHasFocus () as boolean
    return m.kbHasFocus
end function

' Set MiniKeyboard focus state
sub setKbFocus(hasFocus as boolean)
    m.kbHasFocus = hasFocus
end sub

' Check if keyboard is at left edge
function kbAtLeftEdge () as boolean
    return m.kbAtLeftEdge
end function

' Set MiniKeyboard left edge state
sub setKbLeftEdge(atEdge as boolean)
    m.kbAtLeftEdge = atEdge
end sub

' Check if keyboard is at right edge
function kbAtRightEdge () as boolean
    return m.kbAtRightEdge
end function

' Set MiniKeyboard right edge state
sub setKbRightEdge(atEdge as boolean)
    m.kbAtRightEdge = atEdge
end sub

' Check if rowlist is at edge
function rowItemAtEdge () as boolean
    return m.rowItemAtEdge
end function

' Set rowlist edge state
sub setRowListEdge(atEdge as boolean)
    m.rowItemAtEdge = atEdge
end sub

' Check if rowlist is at left edge
function rowItemAtLeftEdge () as boolean
    return m.rowItemAtLeftEdge
end function

' Set rowlist left edge state
sub setRowListLeftEdge(atEdge as boolean)
    m.rowItemAtLeftEdge = atEdge
end sub

' Check if rowlist is at right edge
function rowItemAtRightEdge () as boolean
    return m.rowItemAtRightEdge
end function

' Set rowlist right edge state
sub setRowListRightEdge(atEdge as boolean)
    m.rowItemAtRightEdge = atEdge
end sub

' Get current focus chain
function getFocusChain () as object
    return m.focusChain
end function

' Add node to focus chain
sub addToFocusChain(node as object)
    if node <> invalid
        m.focusChain.Push(node)
    end if
end sub

' Remove node from focus chain
sub removeFromFocusChain(node as object)
    if node <> invalid
        for i = 0 to m.focusChain.Count() - 1
            if m.focusChain[i] = node
                m.focusChain.Remove(i)
                exit for
            end if
        end for
    end if
end sub

' Clear focus chain
sub clearFocusChain()
    m.focusChain = ["scene"]
end sub

' Check if node is in focus chain
function isInFocusChain (node as object) as boolean
    try
        if node = invalid then return false
        return node.isInFocusChain()
    catch e
        SafeLog("ERROR", "FocusManager", "isInFocusChain failed: " + e.message)
        return false
    end try
end function

' Get current focused node
function getCurrentFocusedNode () as object
    if m.top.scene <> invalid
        return m.top.scene.focusedNode
    end if
    return invalid
end function

' Handle key event for focus routing
function handleKeyEvent (key as string, press as boolean) as boolean
    if not press then return false

    ' Handle navigation keys
    if key = "left" and m.isAtEdge
        ' Left edge navigation
        return handleLeftEdgeNavigation()
    end if

    if key = "right" and m.isAtEdge
        ' Right edge navigation
        return handleRightEdgeNavigation()
    end if

    return false
end function

' Handle left edge navigation
function handleLeftEdgeNavigation () as boolean
    activePanel = m.activePanel

    if activePanel = "home"
        requestFocusByArea("nav:home")
    else if activePanel = "search"
        requestFocusByArea("nav:search")
    else if activePanel = "settings"
        requestFocusByArea("nav:settings")
    end if

    return true
end function

' Handle right edge navigation
function handleRightEdgeNavigation () as boolean
    navFocusKey = m.navFocusKey

    if navFocusKey = "home"
        requestFocusByArea("panel:home")
    else if navFocusKey = "search"
        requestFocusByArea("panel:search")
    else if navFocusKey = "settings"
        requestFocusByArea("panel:settings")
    end if

    return true
end function

' Handle focus chain change
sub handleFocusChange()
    ' Update focus state when focus changes
    m.currentFocusArea = ""
    m.isAtEdge = false
    m.edgeType = ""
    m.kbHasFocus = false
    m.rowItemAtEdge = false
end sub

' Handle MiniKeyboard edge detection
function handleMiniKeyboardEdgeEvent (key as string) as boolean
    if key = "left" and m.kbHasFocus
        ' Left edge - route to nav
        handleNavFocusRequest("nav:search")
        return true
    end if

    if key = "right" and m.kbHasFocus
        ' Right edge - route to results
        handlePanelFocusRequest("panel:search")
        return true
    end if

    return false
end function

' Handle RowList edge event
function handleRowListEdgeEvent (key as string) as boolean
    if key = "left" and m.rowItemAtLeftEdge
        ' Left edge - route to left nav
        handleNavFocusRequest("nav:" + m.activePanel)
        return true
    end if

    if key = "right" and m.rowItemAtRightEdge
        ' Right edge - route to scene
        handleSceneFocusRequest()
        return true
    end if

    return false
end function

' Handle focus gain event
sub handleFocusGain()
    ' Update state when gaining focus
    m.verifyingFocus = false
    m.focusVerified = false
    m.attempts = 0
end sub

' Handle focus loss event
sub handleFocusLoss()
    ' Update state when losing focus
    m.verifyingFocus = false
    m.focusVerified = false
    m.attempts = 0
end sub

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
    m.focusVerified = false
    m.attempts = 0
    m.kbHasFocus = false
    m.rowItemAtEdge = false
end sub
