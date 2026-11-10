' RowListFocusHandler.brs - Proper RowList focus handling
' Implements edge detection using rowItemFocused instead of text-based polling
'
' Usage:
'   Import this module into your component, then call init with your RowList node
'   Call handleEdgeKeyEvent(key) to check for edge navigation
'
' Edge detection works by tracking the current rowItemFocused position
' and comparing to the row/column count to determine if at edge

' Initialize focus handler - named uniquely to avoid clash with MainScene's sub Init()
' when this script is included as a mixin library (no .xml companion)
sub InitRowListFocusHandler()
    try
        ' Track current position
        m.rowItemFocused = invalid
        m.prevRowItemFocused = invalid
        m.rowItemCount = 0
        m.columnCount = 0
        m.isAtLeftEdge = false
        m.isAtRightEdge = false
        m.rowList = invalid
    catch e
        SafeLog("ERROR", "InitRowListFocusHandler", "Error: " + e.message)
    end try
end sub

' Called when RowList focus changes
sub OnRowListFocusChanged(event as dynamic)
    try
        hasFocus = false
        if Type(event) = "roSGNodeEvent"
            hasFocus = event.GetData()
        end if

        if hasFocus
            if m.rowList <> invalid
                m.rowList.UnobserveField("rowItemFocused")
                m.rowList.UnobserveField("content")
                m.rowList = invalid
            end if

            if m.top.rowList <> invalid
                m.rowList = m.top.rowList
                m.rowList.ObserveField("rowItemFocused", "OnRowItemFocusedChanged")
                m.rowList.ObserveField("content", "OnContentChanged")
            end if
        else
            if m.rowList <> invalid
                m.rowList.UnobserveField("rowItemFocused")
                m.rowList.UnobserveField("content")
                m.rowList = invalid
            end if
        end if
    catch e
        SafeLog("ERROR", "OnRowListFocusChanged", "Error: " + e.message)
    end try
end sub

' Track focused item position
sub OnRowItemFocusedChanged(event as dynamic)
    try
        if Type(event) = "roSGNodeEvent"
            m.rowItemFocused = event.GetData()

            if m.rowItemFocused <> invalid and m.rowItemFocused.Count() >= 2
                m.prevRowItemFocused = m.rowItemFocused
                CheckEdgePosition()
            end if
        end if
    catch e
        SafeLog("ERROR", "OnRowItemFocusedChanged", "Error: " + e.message)
    end try
end sub

' Check edge position and set appropriate state
sub CheckEdgePosition()
    try
        if m.rowItemFocused = invalid
            return
        end if

        col = m.rowItemFocused[1]
        m.isAtLeftEdge = (col = 0)

        ' Check if at right edge by looking at row content
        if m.rowList <> invalid and m.rowList.content <> invalid
            row = m.rowItemFocused[0]
            rowContent = m.rowList.content.GetChild(row)
            if rowContent <> invalid
                m.columnCount = rowContent.GetChildCount()
                m.isAtRightEdge = (col >= m.columnCount - 1)
            end if
        end if

        m.top.isAtEdge = m.isAtLeftEdge or m.isAtRightEdge

        ' Set edge type without using IIf function
        if m.isAtLeftEdge
            m.top.edgeType = "left"
        else if m.isAtRightEdge
            m.top.edgeType = "right"
        else
            m.top.edgeType = "none"
        end if
    catch e
        SafeLog("ERROR", "CheckEdgePosition", "Error: " + e.message)
    end try
end sub

' Handle edge navigation
function OnEdgeKeyEvent (key as string) as boolean
    try
        if key = "left" and m.isAtLeftEdge
            ' Route focus to left navigation
            return true
        end if

        if key = "right" and m.isAtRightEdge
            ' Route focus to right navigation
            return true
        end if

        return false
    catch e
        SafeLog("ERROR", "OnEdgeKeyEvent", "Error: " + e.message)
        return false
    end try
end function

' Return current position for external reference
function GetRowItemPosition () as object
    try
        return m.rowItemFocused
    catch e
        SafeLog("ERROR", "GetRowItemPosition", "Error: " + e.message)
        return invalid
    end try
end function

' Handle content changes
sub OnContentChanged()
    try
        ' Reset edge state when content changes
        m.isAtLeftEdge = false
        m.isAtRightEdge = false
        m.columnCount = 0
    catch e
        SafeLog("ERROR", "OnContentChanged", "Error: " + e.message)
    end try
end sub
