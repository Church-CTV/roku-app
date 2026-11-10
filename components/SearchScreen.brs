sub Init()
    try
        m.SearchField = SafeFindNode(m.top, "SearchField")
        m.resultsLabel = SafeFindNode(m.top, "resultsLabel")
        m.SearchResults = SafeFindNode(m.top, "SearchResults")
        m.noResultsGroup = SafeFindNode(m.top, "noResultsGroup")
        m.searchLoading = SafeFindNode(m.top, "searchLoading")

        if m.SearchField <> invalid
            SafeObserveField(m.SearchField, "text", "OnKeyboardTextChanged")
            SafeObserveField(m.SearchField, "focus", "OnMiniKbFocusChanged")
            SafeObserveField(m.SearchField, "focusedChild", "OnMiniKbFocusedChildChanged")
        end if
        if m.SearchResults <> invalid then SafeObserveField(m.SearchResults, "rowItemSelected", "OnSearchResultSelected")
        if m.SearchResults <> invalid then SafeObserveField(m.SearchResults, "focus", "OnSearchResultsFocusChanged")
        if m.SearchResults <> invalid then SafeObserveField(m.SearchResults, "focusChange", "OnSearchResultsFocusChange")
        SafeObserveField(m.top, "close", "OnClose")

        m.debounceTimer = SafeFindNode(m.top, "debounceTimer")
        if m.debounceTimer <> invalid then SafeObserveField(m.debounceTimer, "fire", "OnDebounceFire")

        ' Focus management - track MiniKeyboard focused column for edge navigation
        m.focusTracker = SafeFindNode(m.top, "focusTracker")
        if m.focusTracker <> invalid
            SafeObserveField(m.focusTracker, "fire", "OnFocusTrackerFire")
            m.focusTracker.duration = 0.2
            m.focusTracker.control = "start"
        end if
        m.kbFocusedColumn = -1
        m.kbHasFocus = false
        m.pendingFocusRedirect = false
        m.resultsHasFocus = false
        m.kbPrevFocusedOnEdge = false

        ' Edge detection for keyboard navigation
        m.kbFocusedLeftEdge = false
        m.kbFocusedRightEdge = false
        m.kbLeftEdgeThreshold = 300
        m.kbRightEdgeThreshold = 600
        m.kbFocusedChildTranslation = ""
        m.kbPreviousChildText = ""
        m.kbLastFocusedKey = ""
        m.kbFocusedKeyHistory = ""
        m.kbEdgeDetectionMethod = "keyEvent"
        m.redirectFocusTimer = invalid ' Using key event instead of focusedChild

        m.pendingSearch = false
        m.allItems = []

        LogInfo("SearchScreen", "=== SearchScreen Init() complete ===")
        TrackScreenView("SearchScreen", "")
    catch e
        LogError("SearchScreen", "Init: " + e.message)
    end try
end sub

sub OnContentSet()
    try
        m.allItems = []
        if m.top.content <> invalid
            contentNode = m.top.content
            childCount = contentNode.GetChildCount()
            if childCount > 0
                for i = 0 to childCount - 1
                    category = contentNode.GetChild(i)
                    if category <> invalid and category.GetChildCount() > 0
                        catChildCount = category.GetChildCount()
                        for j = 0 to catChildCount - 1
                            item = category.GetChild(j)
                            if item <> invalid
                                m.allItems.Push(item)
                            end if
                        end for
                    end if
                end for
            end if
        end if
        LogInfo("SearchScreen", "Content loaded: " + m.allItems.Count().ToStr() + " items")
    catch e
        LogError("SearchScreen", "OnContentSet: " + e.message)
    end try
end sub

sub OnKeyboardTextChanged()
    try
        searchText = m.SearchField.text
        LogInfo("SearchScreen", "KEYBOARD TEXT CHANGED: '" + searchText + "'")
        m.top.searchText = searchText
        m.pendingSearch = true
        if m.debounceTimer <> invalid
            m.debounceTimer.control = "stop"
            m.debounceTimer.control = "start"
        end if
    catch e
        SafeLog("ERROR", "SearchScreen", "OnKeyboardTextChanged failed: " + e.message)
    end try
end sub

sub OnSearchTextChanged()
    try
        if m.SearchField <> invalid
            m.top.searchText = m.SearchField.text
            m.pendingSearch = true
            if m.debounceTimer <> invalid
                m.debounceTimer.control = "stop"
                m.debounceTimer.control = "start"
            end if
        end if
    catch e
        SafeLog("ERROR", "SearchScreen", "OnSearchTextChanged failed: " + e.message)
    end try
end sub

sub OnDebounceFire()
    try
        m.pendingSearch = false
        OnSearchTextDebounced()
    catch e
        SafeLog("ERROR", "SearchScreen", "OnDebounceFire failed: " + e.message)
    end try
end sub

' Poll MiniKeyboard focused column to track edge position
sub OnFocusTrackerFire()
    try
        if m.SearchField <> invalid and m.kbHasFocus
            focusedText = ""
            focusedChildNode = m.SearchField.focusedChild
            if focusedChildNode <> invalid
                focusedText = focusedChildNode.text
                if focusedText = invalid then focusedText = ""
            end if
            col = -1
            if focusedText <> ""
                ' Leftmost column: Q, A, Z
                isLeftCol = (focusedText = "Q" or focusedText = "A" or focusedText = "Z")
                ' Rightmost column (6th col): f, l, r, x, 4, 0, Back
                isRightCol = (focusedText = "f" or focusedText = "F" or focusedText = "l" or focusedText = "L" or focusedText = "r" or focusedText = "R" or focusedText = "x" or focusedText = "X" or focusedText = "4" or focusedText = "0" or focusedText = "Back")
                if isLeftCol
                    col = 0
                else if isRightCol
                    col = 1
                end if
            end if
            if col <> m.kbFocusedColumn
                m.kbFocusedColumn = col
                LogInfo("SearchScreen", "KB TRACKER: focused='" + focusedText + "' colChanged=" + col.ToStr() + " prevCol=" + m.kbFocusedColumn.ToStr())
            end if
        end if
    catch e
        SafeLog("ERROR", "SearchScreen", "OnFocusTrackerFire failed: " + e.message)
    end try
end sub

' Track focused child changes for edge detection
sub OnFocusedChildChanged(event as dynamic)
    if m.SearchField = invalid then return

    try
        ' Get the translation of focused child
        focusedChildNode = event.GetData()
        if focusedChildNode = invalid then return

        ' Read translation
        childTranslation = focusedChildNode.translation
        if childTranslation = invalid then return

        ' Store for debugging
        m.kbFocusedChildTranslation = childTranslation

        ' Determine edge position based on X translation
        childX = childTranslation[0]

        ' Left edge: first column (approximate X threshold)
        m.kbFocusedLeftEdge = (childX <= m.kbLeftEdgeThreshold)

        ' Right edge: last column (approximate X threshold)
        m.kbFocusedRightEdge = (childX >= m.kbRightEdgeThreshold)

        ' Log edge state changes
        if event.PreviousData() = invalid or event.PreviousData() <> focusedChildNode
            print("[EDGE] focusedChild changed: x=" + childX.ToStr() + " left=" + m.kbFocusedLeftEdge.ToStr() + " right=" + m.kbFocusedRightEdge.ToStr())
        end if

    catch e
        LogError("SearchScreen", "OnFocusedChildChanged: " + e.message)
    end try
end sub

' Track MiniKeyboard focus state — all routing handled in OnKeyEvent
sub OnMiniKbFocusChanged(event as dynamic)
    try
        focusState = false
        if Type(event) = "roSGNodeEvent"
            focusState = event.GetData()
        end if
        m.kbHasFocus = focusState
        if focusState
            print("[E2E-FOCUS] search:miniKeyboard")

            ' Reset edge state when keyboard gains focus
            m.kbFocusedLeftEdge = false
            m.kbFocusedRightEdge = false

            if m.focusTracker <> invalid
                m.kbFocusedColumn = -1
                m.focusTracker.control = "start"
            end if
        else
            m.kbFocusedLeftEdge = false
            m.kbFocusedRightEdge = false
        end if
    catch e
        SafeLog("ERROR", "SearchScreen", "OnMiniKbFocusChanged failed: " + e.message)
    end try
end sub

sub OnLeftNavSet()
    try
        m.leftNav = m.top.leftNav
        leftnavValid = (m.leftNav <> invalid)
        if leftnavValid then
            validStr = "true"
        else
            validStr = "false"
        end if
        LogInfo("SearchScreen", "=== LEFTNAV SET: valid=" + validStr + " ===")
    catch e
        SafeLog("ERROR", "SearchScreen", "OnLeftNavSet failed: " + e.message)
    end try
end sub

sub OnSearchResultsFocusChanged(focusState as boolean)
    try
        m.resultsHasFocus = focusState
        if focusState
            print("[E2E-FOCUS] search:results")
        end if
        if focusState then
            _focusStateStr = "true"
        else
            _focusStateStr = "false"
        end if
        LogInfo("SearchScreen", "=== SEARCH RESULTS FOCUS CHANGED: state=" + _focusStateStr + " ===")
    catch e
        SafeLog("ERROR", "SearchScreen", "OnSearchResultsFocusChanged failed: " + e.message)
    end try
end sub


sub OnSearchResultsFocusChange(event as dynamic)
    try
        if event = invalid then return
        if not event.DoesExist("hasFocus") then return
        if not event.DoesExist("currentFocus") then return
        if not event.DoesExist("previousFocus") then return

        hasFocus = event["hasFocus"]
        currentFocus = event["currentFocus"]
        previousFocus = event["previousFocus"]

        print("[FOCUS-DEBUG] RowList focusChange: hasFocus=" + hasFocus.ToStr() + ", current=" + currentFocus + ", prev=" + previousFocus)

        if not hasFocus
            ' Check if at first column when losing focus
            focusedItem = m.SearchResults.rowItemFocused
            print("[FOCUS-DEBUG] RowList losing focus, focusedItem valid=" + (focusedItem <> invalid).ToStr())

            if focusedItem <> invalid and focusedItem.Count() >= 2
                col = focusedItem[1]
                print("[FOCUS-DEBUG] RowList column: " + col.ToStr())

                if col = 0
                    ' Use timer to redirect focus to MiniKeyboard
                    if m.redirectFocusTimer = invalid
                        m.redirectFocusTimer = CreateObject("roSGNode", "Timer")
                        SafeObserveField(m.redirectFocusTimer, "fire", "OnRedirectFocusTimerFire")
                    end if
                    m.redirectFocusTimer.SetPeriod(50)
                    m.redirectFocusTimer.Start()
                end if
            end if
        end if
    catch e
        SafeLog("ERROR", "SearchScreen", "OnSearchResultsFocusChange failed: " + e.message)
    end try
end sub

sub OnRedirectFocusTimerFire()
    try
        print("[FOCUS-DEBUG] Redirecting focus to MiniKeyboard")
        if m.SearchField <> invalid
            m.SearchField.SetFocus(true)
        end if
    catch e
        SafeLog("ERROR", "SearchScreen", "OnRedirectFocusTimerFire failed: " + e.message)
    end try
end sub


sub OnMiniKbFocusedChildChanged()
    try
        if m.SearchField <> invalid
            fc = m.SearchField.focusedChild
            if fc <> invalid
                fcText = fc.text
                if fcText = invalid then fcText = ""

                print(">>> OnMiniKbFocusedChildChanged: fc.text='" + fcText + "' type=" + Type(fc) + " <<<")
                m.kbHasFocus = true

                ' Use key text to determine edge position
                ' Left edge: first column keys (Q, A, Z)
                ' Right edge: last column keys (f, l, r, s, 4, 0, Back)
                isLeftEdge = (fcText = "Q" or fcText = "A" or fcText = "Z")
                isRightEdge = (fcText = "f" or fcText = "F" or fcText = "l" or fcText = "L" or fcText = "r" or fcText = "R" or fcText = "s" or fcText = "S" or fcText = "4" or fcText = "0" or fcText = "Back")

                m.kbFocusedLeftEdge = isLeftEdge
                m.kbFocusedRightEdge = isRightEdge

                print(">>> Edge detected (text-based): left=" + m.kbFocusedLeftEdge.ToStr() + " right=" + m.kbFocusedRightEdge.ToStr() + " <<<")
            else
                print ">>> OnMiniKbFocusedChildChanged: fc IS INVALID <<<"
                m.kbHasFocus = false
            end if
        end if
    catch e
        SafeLog("ERROR", "SearchScreen", "OnMiniKbFocusedChildChanged failed: " + e.message)
    end try
end sub

sub OnSearchTextDebounced()
    try
        searchText = m.top.searchText
        LogInfo("SearchScreen", "DEBOUNCED SEARCH for: '" + searchText + "' (allItems count: " + m.allItems.Count().ToStr() + ")")
        if searchText = "" or searchText = invalid
            LogInfo("SearchScreen", "SEARCH EMPTY - clearing results")
            ClearResults()
            return
        end if

        if m.searchLoading <> invalid then m.searchLoading.visible = true
        if m.SearchResults <> invalid then m.SearchResults.visible = false
        if m.noResultsGroup <> invalid then m.noResultsGroup.visible = false

        filteredContent = FilterContentFeed(searchText)
        LogInfo("SearchScreen", "FILTER returned " + filteredContent.Count().ToStr() + " results")

        if m.searchLoading <> invalid then m.searchLoading.visible = false

        if filteredContent.Count() > 0
            DisplayResults(filteredContent)
        else
            LogInfo("SearchScreen", "SHOWING NO RESULTS")
            ShowNoResults()
        end if
    catch e
        LogError("SearchScreen", "OnSearchTextDebounced: " + e.message)
    end try
end sub

function FilterContentFeed (searchText) as object
    results = []
    try
        if searchText = invalid or searchText = ""
            LogInfo("SearchScreen", "FILTER: empty search text, returning 0 results")
            return results
        end if
        searchTextLower = LCase(searchText)
        LogInfo("SearchScreen", "FILTER: searching '" + searchTextLower + "' in " + m.allItems.Count().ToStr() + " items")
        matchCount = 0

        for each item in m.allItems
            if item <> invalid
                title = "" + item.title
                description = "" + item.description

                titleMatch = false
                descMatch = false
                if title <> "" then titleMatch = (InStr(LCase(title), searchTextLower) > 0)
                if description <> "" then descMatch = (InStr(LCase(description), searchTextLower) > 0)

                if titleMatch or descMatch
                    results.Push(item)
                    matchCount = matchCount + 1
                end if
            end if
        end for

        LogInfo("SearchScreen", "FILTER: found " + matchCount.ToStr() + " matches")
    catch e
        SafeLog("ERROR", "SearchScreen", "FilterContentFeed failed: " + e.message)
    end try
    return results
end function

sub DisplayResults(results)
    try
        if m.resultsLabel <> invalid
            m.resultsLabel.text = results.Count().ToStr() + " results"
        end if

        resultsNode = CreateObject("roSGNode", "ContentNode")
        resultsNode.title = ""

        ' Build content items
        contentItems = []
        for each item in results
            contentItem = CreateObject("roSGNode", "ContentNode")
            contentItem.id = "" + item.id
            contentItem.title = "" + item.title
            contentItem.description = "" + item.description

            if item.hdPosterUrl <> invalid
                contentItem.hdPosterUrl = "" + item.hdPosterUrl
            end if
            if item.sdPosterUrl <> invalid
                contentItem.sdPosterUrl = "" + item.sdPosterUrl
            end if

            ' Copy direct url/streamFormat if present on source item
            if item.url <> invalid
                contentItem.url = "" + item.url
            end if
            if item.streamFormat <> invalid
                contentItem.streamFormat = "" + item.streamFormat
            end if
            if item.length <> invalid
                contentItem.length = item.length
            end if

            ' Mark for below-poster title display in ContentCard
            contentItem.addField("showBelowTitle", "boolean", false)
            contentItem.showBelowTitle = true

            ' Also copy from nested content.videos as fallback
            if contentItem.url = invalid and item.content <> invalid and item.content.videos <> invalid and item.content.videos.Count() > 0
                contentItem.streamUrl = item.content.videos[0].url
                if item.content.videos[0].streamFormat <> invalid
                    contentItem.streamFormat = "" + item.content.videos[0].streamFormat
                else
                    contentItem.streamFormat = "mp4"
                end if
                if item.content.duration <> invalid
                    contentItem.length = item.content.duration
                end if
            end if

            contentItems.Push(contentItem)
        end for

        ' Chunk into rows of 2 for a 2-column grid
        itemsPerRow = 2
        totalItems = contentItems.Count()
        for i = 0 to totalItems - 1 step itemsPerRow
            rowNode = CreateObject("roSGNode", "ContentNode")
            rowNode.title = ""
            endIdx = i + itemsPerRow
            if endIdx > totalItems then endIdx = totalItems
            for j = i to endIdx - 1
                rowNode.appendChild(contentItems[j])
            end for
            resultsNode.appendChild(rowNode)
        end for

        if m.SearchResults <> invalid
            m.SearchResults.content = resultsNode
            m.SearchResults.visible = true
        end if

        if m.noResultsGroup <> invalid then m.noResultsGroup.visible = false

        TrackInteraction("search", "SearchScreen", "Found " + results.Count().ToStr() + " results")
        LogInfo("SearchScreen", "Displaying " + results.Count().ToStr() + " results in grid")
    catch e
        LogError("SearchScreen", "DisplayResults: " + e.message)
    end try
end sub

sub ClearResults()
    try
        if m.resultsLabel <> invalid then m.resultsLabel.text = ""
        if m.SearchResults <> invalid
            m.SearchResults.visible = false
            m.SearchResults.content = invalid
        end if
        if m.noResultsGroup <> invalid then m.noResultsGroup.visible = false
    catch e
        SafeLog("ERROR", "SearchScreen", "ClearResults failed: " + e.message)
    end try
end sub

sub ShowNoResults()
    try
        if m.resultsLabel <> invalid then m.resultsLabel.text = "No results found"
        if m.SearchResults <> invalid then m.SearchResults.visible = false
        if m.noResultsGroup <> invalid
            m.noResultsGroup.visible = true
        end if
    catch e
        SafeLog("ERROR", "SearchScreen", "ShowNoResults failed: " + e.message)
    end try
end sub

sub OnSearchResultSelected()
    try
        LogInfo("SearchScreen", "=== SEARCH RESULT SELECTED ===")
        rowAndItem = m.SearchResults.rowItemSelected
        if rowAndItem <> invalid and rowAndItem.Count() > 1
            ' Save the last focused item for focus restoration after video playback
            m.lastSearchFocusedItem = rowAndItem
            LogInfo("SearchScreen", "Saved last focused item: row=" + rowAndItem[0].ToStr() + " col=" + rowAndItem[1].ToStr())
            LogInfo("SearchScreen", "rowAndItem: row=" + rowAndItem[0].ToStr() + " col=" + rowAndItem[1].ToStr())
            if m.SearchResults.content <> invalid
                rowNode = m.SearchResults.content.getChild(rowAndItem[0])
                if rowNode <> invalid
                    LogInfo("SearchScreen", "rowNode valid, childCount=" + rowNode.GetChildCount().ToStr())
                    selectedItem = rowNode.getChild(rowAndItem[1])
                    if selectedItem <> invalid
                        LogInfo("SearchScreen", "SELECTED ITEM: title='" + selectedItem.title + "'")
                        TrackInteraction("search_result", "SearchScreen", selectedItem.title)
                        ' Set selectedContent BEFORE play to avoid race condition
                        m.top.selectedContent = selectedItem
                        m.top.play = true
                    else
                        LogInfo("SearchScreen", "selectedItem is invalid!")
                    end if
                else
                    LogInfo("SearchScreen", "rowNode is invalid!")
                end if
            else
                LogInfo("SearchScreen", "SearchResults.content is invalid!")
            end if
        else
            LogInfo("SearchScreen", "rowAndItem invalid or count <= 1")
        end if
    catch e
        LogError("SearchScreen", "OnSearchResultSelected: " + e.message)
    end try
end sub

' Restore focus to last focused item in search results after video playback
function RestoreSearchFocus () as boolean
    try
        if m.lastSearchFocusedItem <> invalid and m.lastSearchFocusedItem.Count() >= 2
            LogInfo("SearchScreen", "Restoring focus to search results: row=" + m.lastSearchFocusedItem[0].ToStr() + " col=" + m.lastSearchFocusedItem[1].ToStr())
            if m.SearchResults <> invalid
                m.SearchResults.jumpToRowItem = m.lastSearchFocusedItem
                m.lastSearchFocusedItem = invalid
                return true
            end if
        end if
    catch e
        SafeLog("ERROR", "SearchScreen", "RestoreSearchFocus failed: " + e.message)
    end try
    return false
end function

' Handle close event
sub OnClose()
    try
        m.top.close = true
    catch e
        SafeLog("ERROR", "SearchScreen", "OnClose failed: " + e.message)
    end try
end sub

' Handle search results
sub HandleSearchResults()
    ' This is a placeholder for future search result handling
    ' Currently search results are handled by OnSearchTextDebounced
end sub

function FocusSearchField () as boolean
    try
        if m.SearchField <> invalid
            if SetFocusSafe(m.SearchField)
                return true
            end if
            if m.focusFocusFieldTimer = invalid
                m.focusFocusFieldTimer = CreateObject("roSGNode", "Timer")
                m.focusFocusFieldTimer.duration = 0.05
                m.focusFocusFieldTimer.repeat = false
                m.focusFocusFieldTimer.ObserveField("fire", "OnDeferredFocusSearchField")
            end if
            m.focusFocusFieldTimer.control = "start"
            return true
        end if
    catch e
        SafeLog("ERROR", "SearchScreen", "FocusSearchField failed: " + e.message)
    end try
    return false
end function

sub OnDeferredFocusSearchField()
    try
        if m.SearchField <> invalid
            if SetFocusSafe(m.SearchField)
                m.kbHasFocus = true
            end if
        end if
    catch e
        SafeLog("ERROR", "SearchScreen", "OnDeferredFocusSearchField failed: " + e.message)
    end try
end sub

' Debug function to log edge detection state
sub LogEdgeDetectionState()
    try
        print("[EDGE-DEBUG] kbHasFocus=" + m.kbHasFocus.ToStr() + " left=" + m.kbFocusedLeftEdge.ToStr() + " right=" + m.kbFocusedRightEdge.ToStr() + " childTransX=" + m.kbFocusedChildTranslation.ToStr() + " thresholdLeft=" + m.kbLeftEdgeThreshold.ToStr() + " thresholdRight=" + m.kbRightEdgeThreshold.ToStr())
    catch e
        SafeLog("ERROR", "SearchScreen", "LogEdgeDetectionState failed: " + e.message)
    end try
end sub

function OnKeyEvent (key, press) as boolean
    try
        if not press then return false

        keyLower = LCase(key)

        ' Handle Back key
        if keyLower = "back"
            m.top.close = true
            return true
        end if

        ' Handle Left key
        if key = "left"
            ' MiniKeyboard has focus - navigate to LeftNav search
            if m.kbHasFocus
                print("[NAV] Left from MiniKeyboard -> LeftNav search")
                if m.leftNav <> invalid
                    m.leftNav.CallFunc("FocusOnNav", "search")
                end if
                if m.focusTracker <> invalid then m.focusTracker.control = "stop"
                return true
            end if

            ' Check if results are focused and at first column - use same pattern as LeftNavScreen
            if m.SearchResults <> invalid
                focusedItem = m.SearchResults.rowItemFocused
                if focusedItem <> invalid and focusedItem.Count() >= 2 and focusedItem[1] = 0
                    print("[NAV] Left from results edge -> keyboard")
                    ' Route to minikeyboard using same approach as LeftNavScreen line 822
                    searchField = m.top.FindNode("SearchField")
                    if searchField <> invalid
                        searchField.SetFocus(true)
                    else
                        if m.leftNav <> invalid
                            m.leftNav.CallFunc("FocusOnNav", "search")
                        end if
                    end if
                    return true
                end if
            end if
        end if

        ' Handle Right key
        if key = "right"
            ' MiniKeyboard has focus - navigate to results or LeftNav
            if m.kbHasFocus
                print("[NAV] Right from MiniKeyboard")
                if m.SearchResults <> invalid and m.SearchResults.visible
                    print("[NAV] Results visible, moving focus there")
                    SetFocusSafe(m.SearchResults)
                else
                    print("[NAV] Results not visible, returning to LeftNav")
                    if m.leftNav <> invalid then m.leftNav.callFunc("FocusOnNav", "search")
                end if
                if m.focusTracker <> invalid then m.focusTracker.control = "stop"
                return true
            end if
        end if
    catch e
        SafeLog("ERROR", "SearchScreen", "OnKeyEvent failed: " + e.message)
    end try
    return false
end function

' OnExit handler - cleanup resources when screen exits
sub OnExit()
    try
        LogInfo("SearchScreen", "OnExit: Cleaning up resources")

        ' Stop debounce timer
        if m.debounceTimer <> invalid
            m.debounceTimer.UnobserveField("fire")
            m.debounceTimer.control = "stop"
            m.debounceTimer = invalid
        end if

        ' Stop focus tracker
        if m.focusTracker <> invalid
            m.focusTracker.UnobserveField("fire")
            m.focusTracker.control = "stop"
            m.focusTracker = invalid
        end if

        ' Stop focus focus field timer
        if m.focusFocusFieldTimer <> invalid
            m.focusFocusFieldTimer.UnobserveField("fire")
            m.focusFocusFieldTimer.control = "stop"
            m.focusFocusFieldTimer = invalid
        end if

        ' Clean up search field observers
        if m.SearchField <> invalid
            try
                m.SearchField.UnobserveField("text")
                m.SearchField.UnobserveField("focus")
                m.SearchField.UnobserveField("focusedChild")
            catch e
                SafeLog("WARN", "SearchScreen", "UnobserveField search field failed: " + e.message)
            end try
        end if

        ' Clean up search results observers
        if m.SearchResults <> invalid
            try
                m.SearchResults.UnobserveField("rowItemSelected")
                m.SearchResults.UnobserveField("focus")
                m.SearchResults.UnobserveField("focusChange")
                m.SearchResults.UnobserveField("itemSelected")
            catch e
                SafeLog("WARN", "SearchScreen", "UnobserveField search results failed: " + e.message)
            end try
        end if

        ' Clean up top-level and timer observers
        try
            m.top.UnobserveField("close")
        catch e
            SafeLog("WARN", "SearchScreen", "UnobserveField close failed: " + e.message)
        end try
        if m.redirectFocusTimer <> invalid
            m.redirectFocusTimer.UnobserveField("fire")
        end if

        ' Reset state
        m.kbHasFocus = false
        m.kbFocusedLeftEdge = false
        m.kbFocusedRightEdge = false
        m.pendingSearch = false
        m.activeSearch = false

        LogInfo("SearchScreen", "OnExit: Cleanup complete")
    catch e
        SafeLog("ERROR", "SearchScreen", "OnExit failed: " + e.message)
    end try
end sub
