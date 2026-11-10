' FocusTracker.brs - Focus chain polling via location keys
' Location key format: <panel>:<element>[:<row>][:<col>]
' Examples:
'   nav:home            navHome focused
'   nav:search          navSearch focused
'   home:rowList:3:0    grid rowList at row 3, col 0
'   home:exitDialog     exit dialog button focused
'   search:miniKeyboard MiniKeyboard focused
'   search:results:0:1  SearchResults RowList at row 0, col 1
'   settings:toggleRow  Settings layout toggle focused

function BuildLocationKey (root as object) as string
    if root = invalid then return ""

    ' Strategy 1: try walking the focus chain from root.
    ' Non-visual nodes (ContentNode, Timer, Task) don't implement ifSGNodeFocus
    ' and can't be part of the focus chain. Each node is checked before calling
    ' GetFocus to avoid "Member function not found" logging noise.
    if not HasFocusInterface(root) then return IdToLocationKey(root)

    chain = []
    node = root
    while node <> invalid
        chain.Push(node)
        if not HasFocusInterface(node) then exit while
        nextNode = SafeNodeGetFocus(node)
        if nextNode = invalid or nextNode.IsSameNode(node) then exit while
        node = nextNode
    end while

    for i = chain.Count() - 1 to 0 step -1
        n = chain[i]
        result = IdToLocationKey(n)
        if result <> "" then return result
    end for

    ' Strategy 2: fallback — get focused descendant of root and walk up parents
    if HasFocusInterface(root)
        focusedNode = SafeNodeGetFocus(root)
        if focusedNode <> invalid
            result = IdToLocationKey(focusedNode)
            if result <> "" then return result
            parent = focusedNode
            while parent <> invalid
                result = IdToLocationKey(parent)
                if result <> "" then return result
                try
                    parent = parent.GetParent()
                catch e
                    SafeLog("DEBUG", "FocusTracker", "GetParent failed at " + Type(parent) + ": " + e.message)
                    exit while
                end try
            end while
        end if
    end if

    return ""
end function

' Convert a node's ID + relevant fields to a location key string.
' Returns "" if the node is not a recognized focus target.
function IdToLocationKey (n as object) as string
    if n = invalid then return ""
    idStr = ""
    try
        idStr = n.id
    catch e
        SafeLog("DEBUG", "FocusTracker", "Node lacks id field: " + Type(n))
        return ""
    end try

    if idStr = "rowList"
        idx = invalid
        try
            idx = n.rowItemFocused
        catch e
            SafeLog("DEBUG", "FocusTracker", "rowItemFocused not available on rowList")
        end try
        if idx <> invalid and idx.Count() >= 2
            return "home:rowList:" + idx[0].ToStr() + ":" + idx[1].ToStr()
        end if
    end if

    if idStr = "SearchResults"
        idx = invalid
        try
            idx = n.rowItemFocused
        catch e
            SafeLog("DEBUG", "FocusTracker", "rowItemFocused not available on SearchResults: " + e.message)
        end try
        if idx <> invalid and idx.Count() >= 2
            return "search:results:" + idx[0].ToStr() + ":" + idx[1].ToStr()
        end if
    end if

    if idStr = "SearchField" then return "search:miniKeyboard"
    if idStr = "layoutToggleRow" then return "settings:toggleRow"
    if idStr = "exitButton" then return "home:exitDialog"

    if idStr = "navHome" then return "nav:home"
    if idStr = "navSearch" then return "nav:search"
    if idStr = "navSchedule" then return "nav:schedule"
    if idStr = "navContinue" then return "nav:continue"
    if idStr = "navWatchLater" then return "nav:watchlater"
    if idStr = "navSettings" then return "nav:settings"

    return ""
end function

function MatchKey (key as string, pattern as string) as boolean
    try
        if key = invalid or pattern = invalid then return false
        if key = "" or pattern = "" then return false
        if pattern = "*" then return true

        keyParts = key.Split(":")
        patternParts = pattern.Split(":")

        if keyParts.Count() <> patternParts.Count() then return false

        for i = 0 to keyParts.Count() - 1
            if patternParts[i] <> "*" and LCase(keyParts[i]) <> LCase(patternParts[i])
                return false
            end if
        end for

        return true
    catch e
        SafeLog("ERROR", "MatchKey", "Error: " + e.message)
        return false
    end try
end function
