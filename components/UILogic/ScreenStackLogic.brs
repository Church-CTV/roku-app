' ScreenStackLogic.brs - Screen stack management for Roku channel template
' ********** Copyright 2020 Roku Corp.  All Rights Reserved. **********
' Enhanced: hardened focus system — focus gap eliminated, fallback focus targets


sub InitScreenStack()
    m.screenStack = []
end sub

sub ShowScreen(node as object)
    if node = invalid then return
    prev = invalid
    if m.screenStack.Count() > 0
        prev = m.screenStack[m.screenStack.Count() - 1]
    end if
    prevScreenName = ""
    if prev <> invalid
        prevScreenName = prev.id
        prev.visible = false ' hide current screen if it exist
    end if
    m.top.AppendChild(node) ' add new screen to scene
    ' show new screen
    node.visible = true
    SetFocusSafe(node)
    m.screenStack.Push(node) ' add new screen to the screen stack

    ' Track screen view
    screenName = ""
    if node <> invalid and node.id <> invalid
        screenName = node.id
    else
        screenName = "unknown"
    end if
    try
        TrackScreenView(screenName, prevScreenName)
    catch e
        LogError("ScreenStack", "TrackScreenView failed: " + e.message)
    end try
end sub

sub CloseScreen(node as object)
    if m.screenStack.Count() = 0 then return
    topItem = invalid
    if m.screenStack.Count() > 0
        topItem = m.screenStack[m.screenStack.Count() - 1]
    end if
    if node = invalid or (topItem <> invalid and topItem.IsSameNode(node))
        last = m.screenStack.Pop() ' remove screen from screenStack

        ' CRITICAL: Restore previous screen visibility BEFORE removing the
        ' departing screen. This eliminates the microsecond focus gap where
        ' no visible focusable node exists in the scene graph.
        prev = invalid
        if m.screenStack.Count() > 0
            prev = m.screenStack[m.screenStack.Count() - 1]
        end if

        ' Make prev visible FIRST, before removing last
        if prev <> invalid
            prev.visible = true
        end if

        if last <> invalid
            last.visible = false ' hide screen
            m.top.RemoveChild(last) ' remove screen from scene
        end if

        if prev <> invalid
            ' Check if previous screen is LeftNavScreen (has selectedNavItem interface field)
            ' LeftNavScreen manages its own focus restoration internally
            isLeftNav = false
            try
                if prev.selectedNavItem <> invalid then isLeftNav = true
            catch e
                SafeLog("DEBUG", "ScreenStackLogic", "selectedNavItem not available on prev screen")
                isLeftNav = false
            end try

            if isLeftNav
                SetFocusSafe(prev)
            else
                ' Restore focus to the RowList descendant so we can set jumpToRowItem.
                rowList = prev.FindNode("rowList")
                if rowList = invalid then rowList = prev.FindNode("SearchResults")
                if rowList = invalid then rowList = prev.FindNode("gridRowList")
                if rowList = invalid then rowList = prev.FindNode("listRowList")

                if rowList <> invalid
                    ' Only use m.lastSelectedIndex as a last resort — it may be stale
                    ' or contain a nav index rather than the actual content item index.
                    ' Let the caller (e.g. OnVideoClose) handle jumpToRowItem directly.
                    rowList.SetFocus(true)
                else
                    SetFocusSafe(prev)
                end if
            end if

            try
                EnsureFocusLanded(prev, [])
            catch e
                LogWarn("ScreenStack", "EnsureFocusLanded failed: " + e.message)
            end try
        end if
    end if
end sub

' FindRowListInNode: Recursively finds a RowList node within a parent.
' Uses multiple heuristics since no single method is reliable across all firmware versions.
function FindRowListInNode (node as object) as object
    if node = invalid then return invalid
    if NodeHasField(node, "id") and node.id = "rowList"
        return node
    end if
    nodeType = Type(node)
    if nodeType = "roSGNode_RowList" or nodeType = "RowList"
        return node
    end if

    try
        child = node.getchild()
        if child = invalid then return invalid
        while child <> invalid
            result = FindRowListInNode(child)
            if result <> invalid then return result
            try
                child = child.GetNextSibling()
            catch e
                SafeLog("DEBUG", "FindRowListInNode", "GetNextSibling not supported on " + Type(child))
                exit while
            end try
        end while
    catch e
        SafeLog("DEBUG", "FindRowListInNode", "GetChild not supported on " + Type(node) + ": " + e.message)
    end try
    return invalid
end function
