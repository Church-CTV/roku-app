' LeftNavScreen.brs - Left Navigation Layout with fixed-width sidebar
' Manages sidebar state, panel switching, and deep linking
'
' File organization:
'   Lines 1-90:   Init + deferred init
'   Lines 91-130: Deep link processing
'   Lines 131-207: Panel display (ShowHome, ShowSearch, ShowSettings)
'   Lines 208-370: Panel creation factories
'   Lines 371-446: Nav highlight + focus callbacks
'   Lines 447-576: Event handlers (play, select, close, layout)
'   Lines 577-646: Icon management
'   Lines 647-715: Focus helpers + timer
'   Lines 716-886: Key routing (OnKeyEvent, RouteToNav, RouteFocus, HandleNavUpDown)
'
' TODO: Extract key routing functions (lines 716+) into UILogic/LeftNavKeyHandler.brs

sub Init()
    try
        ' Minimal init: store node references. All active SceneGraph operations
        ' (timer, global access, panel creation, registry) are deferred via a
        ' one-shot timer to avoid "Member function not found" errors that occur
        ' when the node isn't fully attached to the scene tree.

        ' Sidebar elements
        m.sidebarTitle = SafeFindNode(m.top, "sidebarTitle")
        m.navHome = SafeFindNode(m.top, "navHome")
        m.navSearch = SafeFindNode(m.top, "navSearch")
        m.navSettings = SafeFindNode(m.top, "navSettings")
        m.contentPanel = SafeFindNode(m.top, "contentPanel")

        ' Nav item backgrounds for focus highlighting
        m.navHomeBg = SafeFindNode(m.top, "navHomeBg")
        m.navSearchBg = SafeFindNode(m.top, "navSearchBg")
        m.navSettingsBg = SafeFindNode(m.top, "navSettingsBg")

        ' Nav item icons for focus URI swap
        m.navHomeIcon = SafeFindNode(m.top, "navHomeIcon")
        m.navSearchIcon = SafeFindNode(m.top, "navSearchIcon")
        m.navSettingsIcon = SafeFindNode(m.top, "navSettingsIcon")

        ' Icon URI pairs (white=unfocused, black=focused)
        m.iconUris = {
            home: { white: "pkg:/images/home.png", black: "pkg:/images/home_black.png" },
            search: { white: "pkg:/images/search.png", black: "pkg:/images/search_black.png" },
            settings: { white: "pkg:/images/settings.png", black: "pkg:/images/settings_black.png" }
        }

        ' Content references
        m.contentFeed = m.top.content

        ' Current navigation state
        m.currentNav = "home"

        ' Panel instances (created lazily)
        m.gridPanel = invalid
        m.searchPanel = invalid
        m.settingsPanel = invalid

        ' Last fired content (prevents double-fire loop)
        m.lastFiredContent = invalid

        ' Focus management state
        m.lastGridRow = 0
        m.activePanel = "home"

        ' Guard to run deferred init only once
        m.deferredInitDone = false

        ' Observe nav item select events
        if m.navHome <> invalid then SafeObserveField(m.navHome, "select", "OnNavHomeSelect")
        if m.navSearch <> invalid then SafeObserveField(m.navSearch, "select", "OnNavSearchSelect")
        if m.navSettings <> invalid then SafeObserveField(m.navSettings, "select", "OnNavSettingsSelect")

        ' Observe focus for visual highlight
        if m.navHome <> invalid then SafeObserveField(m.navHome, "focus", "OnNavHomeFocus")
        if m.navSearch <> invalid then SafeObserveField(m.navSearch, "focus", "OnNavSearchFocus")
        if m.navSettings <> invalid then SafeObserveField(m.navSettings, "focus", "OnNavSettingsFocus")

        ' Observe content panel events
        if m.contentPanel <> invalid then SafeObserveField(m.contentPanel, "select", "OnContentPanelSelect")

        ' Observe play/selectedContent from child panels
        SafeObserveField(m.top, "play", "OnPlay")
        SafeObserveField(m.top, "selectedContent", "OnSelectedContent")

        ' Observe close from child panels
        SafeObserveField(m.top, "close", "OnClose")

        ' Observe channelName changes
        SafeObserveField(m.top, "channelName", "OnChannelNameChanged")

        ' One-shot timer defers the full init to the next render frame
        ' This avoids "Member function not found" during Init
        m.deferTimer = CreateObject("roSGNode", "Timer")
        m.deferTimer.duration = 0.01
        m.deferTimer.repeat = false
        m.deferTimer.ObserveField("fire", "OnDeferredInit")
        m.deferTimer.control = "start"

    catch e
        SafeLog("ERROR", "LeftNavScreen", "Init failed: " + e.message)
    end try
end sub

' Deferred full initialization — runs one frame after Init.
' The node should be attached to the scene tree by now, making
' SceneGraph operations safe (global, timer, panel appending, registry).
sub OnDeferredInit()
    try
        if m.deferredInitDone then return
        m.deferredInitDone = true

        m.global.locationKey = ""
        m.prevLocationKey = ""
        m.currentLocationKey = ""

        ' Initialize focus management system
        m.focusManager = SafeFindNode(m.top, "focusManager")
        if m.focusManager <> invalid
            m.focusManager.currentFocusArea = "LeftNavScreen"
            SafeObserveField(m.focusManager, "requestFocus", "OnFocusRequest")
        end if

        m.focusVerifier = SafeFindNode(m.top, "focusVerifier")
        if m.focusVerifier <> invalid
            SafeObserveField(m.focusVerifier, "focusVerified", "OnFocusVerified")
            SafeObserveField(m.focusVerifier, "verifyingFocus", "OnVerifyingFocus")
        end if

        m.focusTimer = CreateObject("roSGNode", "Timer")
        m.focusTimer.duration = 0.5
        m.focusTimer.repeat = true
        m.focusTimer.ObserveField("fire", "OnFocusTimerTick")
        m.focusTimer.control = "start"

        UpdateSidebarTitle()
        ResetAllNavHighlights()

        print("[E2E-READY]")

        savedNav = LoadPreference("lastNavItem", "home")
        initialNav = "home"
        if m.global <> invalid and m.global.DeepNav <> invalid and m.global.DeepNav <> ""
            initialNav = LCase(m.global.DeepNav)
        else if savedNav <> invalid and savedNav <> ""
            initialNav = LCase(savedNav)
        end if

        if initialNav = "search"
            ShowSearchPanel()
        else if initialNav = "settings"
            ShowSettingsPanel()
        else
            ShowHomePanel()
        end if

        RouteToNav(initialNav)

        LogInfo("LeftNavScreen", "Left navigation screen initialized")
        TrackScreenView("LeftNavScreen", "")
    catch e
        SafeLog("ERROR", "LeftNavScreen", "OnDeferredInit failed: " + e.message)
    end try
end sub

' Update sidebar title from channel name
sub UpdateSidebarTitle()
    if m.sidebarTitle <> invalid and m.top.channelName <> invalid and m.top.channelName <> ""
        m.sidebarTitle.text = m.top.channelName
    end if
end sub

' Handle channel name changes
sub OnChannelNameChanged()
    UpdateSidebarTitle()
end sub

' Process deep link parameters to show correct panel on load
sub ProcessDeepLink()
    try
        navParam = ""
        if m.global <> invalid
            if m.global.DeepNav <> invalid and m.global.DeepNav <> ""
                navParam = m.global.DeepNav
            end if
        end if

        if navParam <> ""
            navLower = LCase(navParam)
            if navLower = "search"
                ShowSearchPanel()
            else if navLower = "settings"
                ShowSettingsPanel()
            else
                ShowHomePanel()
            end if
        else
            ShowHomePanel()
        end if
    catch e
        LogError("LeftNavScreen", "ProcessDeepLink: " + e.message)
    end try
end sub

' Switch to Home (Grid) panel
sub ShowHomePanel()
    try
        ClearContentPanel()
        if m.gridPanel <> invalid
            m.contentPanel.AppendChild(m.gridPanel)
        else
            m.gridPanel = CreateGridPanel()
            if m.gridPanel <> invalid
                m.contentPanel.AppendChild(m.gridPanel)
            end if
        end if
        m.currentNav = "home"
        m.activePanel = "home"
        UpdateNavHighlight("home")
        SavePreference("lastNavItem", "home")
        if m.gridPanel <> invalid then m.gridPanel.visible = true
        if m.gridPanel <> invalid
            rl = m.gridPanel.FindNode("rowList")
            if rl <> invalid
                if rl.content <> invalid and rl.content.GetChildCount() > 0
                    rl.jumpToRowItem = [0, 0]
                    rl.SetFocus(true)
                    Sleep(30)
                    if SafeNodeGetFocus(rl) = invalid
                        rl.jumpToRowItem = [0, 0]
                        rl.SetFocus(true)
                    end if
                    m.currentLocationKey = "home:rowList:0:0"
                    m.global.locationKey = "home:rowList:0:0"
                    print("[E2E-FOCUS] home:rowList:0:0")
                else
                    m.gridPanel.SetFocus(true)
                end if
            else
                m.gridPanel.SetFocus(true)
            end if
        end if
    catch e
        LogError("LeftNavScreen", "ShowHomePanel: " + e.message)
    end try
end sub

' Switch to Search panel
sub ShowSearchPanel()
    try
        ClearContentPanel()
        if m.searchPanel <> invalid
            m.contentPanel.AppendChild(m.searchPanel)
        else
            m.searchPanel = CreateSearchPanel()
            if m.searchPanel <> invalid
                try
                    m.searchPanel.leftNav = m.top
                catch e2
                    SafeLog("DEBUG", "LeftNavScreen", "leftNav field missing on searchPanel" + e2.message)
                    ' leftNav assignment may fail on some firmware versions
                end try
                m.contentPanel.AppendChild(m.searchPanel)
            end if
        end if

        if m.searchPanel <> invalid then m.searchPanel.visible = true

        m.currentNav = "search"
        m.activePanel = "search"
        UpdateNavHighlight("search")
        SavePreference("lastNavItem", "search")

        if m.searchPanel <> invalid
            try
                m.searchPanel.FocusSearchField()
            catch e3
                SafeLog("DEBUG", "LeftNavScreen", "FocusSearchField failed, attempting direct node focus: " + e3.message)
                ' FocusSearchField may fail on some firmware — direct fallback
                miniKb = m.searchPanel.FindNode("SearchField")
                if miniKb <> invalid
                    miniKb.SetFocus(true)
                else
                    m.searchPanel.SetFocus(true)
                end if
            end try
            if miniKb = invalid
                miniKb = m.searchPanel.FindNode("SearchField")
                if miniKb <> invalid
                    miniKb.SetFocus(true)
                else
                    m.searchPanel.SetFocus(true)
                end if
            end if
        end if
    catch e
        LogError("LeftNavScreen", "ShowSearchPanel: " + e.message)
    end try
end sub

' Switch to Settings panel
sub ShowSettingsPanel()
    try
        ClearContentPanel()
        if m.settingsPanel <> invalid
            m.contentPanel.AppendChild(m.settingsPanel)
        else
            m.settingsPanel = CreateSettingsPanel()
            if m.settingsPanel <> invalid
                m.contentPanel.AppendChild(m.settingsPanel)
            end if
        end if

        if m.settingsPanel <> invalid then m.settingsPanel.visible = true

        m.currentNav = "settings"
        m.activePanel = "settings"
        UpdateNavHighlight("settings")
        SavePreference("lastNavItem", "settings")

        if m.settingsPanel <> invalid
            ltr = m.settingsPanel.FindNode("layoutToggleRow")
            if ltr <> invalid
                ltr.SetFocus(true)
                Sleep(30)
                if SafeNodeGetFocus(ltr) = invalid
                    ltr.SetFocus(true)
                end if
            else
                m.settingsPanel.SetFocus(true)
            end if
        end if
    catch e
        LogError("LeftNavScreen", "ShowSettingsPanel: " + e.message)
    end try
end sub

' Switch to Continue Watching panel — removed for KISS
' sub ShowContinuePanel() — removed

' Clear the content panel of all children (keeps references for reuse)
sub ClearContentPanel()
    try
        if m.gridPanel <> invalid
            m.contentPanel.RemoveChild(m.gridPanel)
        end if
        if m.searchPanel <> invalid
            m.contentPanel.RemoveChild(m.searchPanel)
            m.top.searchResultsRowList = invalid
        end if
        if m.settingsPanel <> invalid
            m.contentPanel.RemoveChild(m.settingsPanel)
        end if
    catch e
        LogError("LeftNavScreen", "ClearContentPanel: " + e.message)
    end try
end sub

' Create a GridScreen panel for the content area
function CreateGridPanel () as object
    try
        gridScreen = CreateObject("roSGNode", "GridScreen")
        if gridScreen <> invalid
            if m.contentFeed <> invalid
                gridScreen.content = m.contentFeed
            end if
            SafeObserveField(gridScreen, "play", "OnGridPlay")
            SafeObserveField(gridScreen, "close", "OnGridClose")
            m.gridRowList = gridScreen.FindNode("rowList")
        end if
        return gridScreen
    catch e
        LogError("LeftNavScreen", "CreateGridPanel: " + e.message)
        return invalid
    end try
end function

' Create a SearchScreen panel
function CreateSearchPanel () as object
    try
        searchScreen = CreateObject("roSGNode", "SearchScreen")
        if searchScreen <> invalid
            m.top.searchPanel = searchScreen
            if m.contentFeed <> invalid
                searchScreen.content = m.contentFeed
            end if
            SafeObserveField(searchScreen, "play", "OnSearchPlay")
            SafeObserveField(searchScreen, "selectedContent", "OnSearchSelectedContent")
            SafeObserveField(searchScreen, "close", "OnSearchClose")
            m.searchResultsRowList = searchScreen.FindNode("SearchResults")
            m.top.searchResultsRowList = m.searchResultsRowList
        end if

        return searchScreen
    catch e
        LogError("LeftNavScreen", "CreateSearchPanel: " + e.message)
        return invalid
    end try
end function

' Create a SettingsScreen panel
function CreateSettingsPanel () as object
    try
        settingsScreen = CreateObject("roSGNode", "SettingsScreen")
        if settingsScreen <> invalid
            settingsScreen.channelName = m.top.channelName
            settingsScreen.channelVersion = m.top.channelVersion
            settingsScreen.contentSourceUrl = m.top.contentSourceUrl
            settingsScreen.currentLayout = m.top.currentLayout
            settingsScreen.featureSearch = m.top.featureSearch
            settingsScreen.featureDeepLinking = m.top.featureDeepLinking
            settingsScreen.featureAnalytics = m.top.featureAnalytics
            settingsScreen.featureCrashReporting = m.top.featureCrashReporting
            settingsScreen.iconFocusUri = m.top.iconFocusUri
            settingsScreen.givingDonationUrl = m.top.givingDonationUrl
            SafeObserveField(settingsScreen, "play", "OnSettingsPlay")
            SafeObserveField(settingsScreen, "selectedContent", "OnSettingsSelectedContent")
            SafeObserveField(settingsScreen, "close", "OnSettingsClose")
            SafeObserveField(settingsScreen, "layoutToggle", "OnSettingsLayoutToggle")
        end if

        return settingsScreen
    catch e
        LogError("LeftNavScreen", "CreateSettingsPanel: " + e.message)
        return invalid
    end try
end function

' Create a ContinueWatchingScreen panel — removed for KISS
' function CreateContinuePanel() — removed

' Update sidebar highlight for selected nav item
' Called when a panel is shown (after nav item select).
' Resets all backgrounds and highlights the selected item.
sub UpdateNavHighlight(selectedItem as string)
    ResetAllNavHighlights()
    selLower = LCase(selectedItem)
    SetNavItemHighlight(selLower, 0.5)
    UpdateNavIcons(selLower)
end sub

' Nav item select handlers
sub OnNavHomeSelect()
    ShowHomePanel()
end sub

sub OnNavSearchSelect()
    ShowSearchPanel()
end sub

' OnNavContinueSelect — removed for KISS

sub OnNavSettingsSelect()
    ShowSettingsPanel()
end sub

' Nav item focus handlers - visual feedback
' These fire when a nav item GAINS focus. We reset ALL backgrounds and
' highlight only the focused item to avoid stale highlights.
sub OnNavHomeFocus(event)
    focusState = true
    if Type(event) = "roSGNodeEvent"
        focusState = event.GetData()
    end if
    if focusState = true
        print("[E2E-FOCUS] nav:home")
        ResetAllNavHighlights()
        SetNavItemHighlight("home", 1.0)
        UpdateNavIcons("home")
    else
        ResetAllNavHighlights()
        if m.activePanel = "home"
            SetNavItemHighlight("home", 0.5)
        end if
    end if
end sub

sub OnNavSearchFocus(event as dynamic)
    focusState = true
    if Type(event) = "roSGNodeEvent"
        focusState = event.GetData()
    end if
    if focusState = true
        print("[E2E-FOCUS] nav:search")
        ResetAllNavHighlights()
        SetNavItemHighlight("search", 1.0)
        UpdateNavIcons("search")
    else
        ResetAllNavHighlights()
        if m.activePanel = "search"
            SetNavItemHighlight("search", 0.5)
        end if
    end if
end sub

sub OnNavSettingsFocus(event as dynamic)
    focusState = true
    if Type(event) = "roSGNodeEvent"
        focusState = event.GetData()
    end if
    if focusState = true
        print("[E2E-FOCUS] nav:settings")
        ResetAllNavHighlights()
        SetNavItemHighlight("settings", 1.0)
        UpdateNavIcons("settings")
    else
        ResetAllNavHighlights()
        if m.activePanel = "settings"
            SetNavItemHighlight("settings", 0.5)
        end if
    end if
end sub

' Continue Watching nav item focus handler — removed for KISS
' sub OnNavContinueFocus(event as dynamic) — removed

' Content panel select handler
sub OnContentPanelSelect()
    if m.top.onContentPanelSelect <> invalid
        m.top.onContentPanelSelect()
    end if
end sub

' Event handlers for child panels

' Grid panel play event - reads item from rowItemFocused directly
sub OnGridPlay()
    if m.gridPanel = invalid
        return
    end if
    if m.gridPanel.play = false
        return
    end if
    rl = m.gridPanel.FindNode("rowList")
    if rl = invalid
        return
    end if
    rowItem = rl.rowItemFocused
    if rowItem = invalid or rowItem.Count() < 2
        return
    end if
    contentItem = rl.content.GetChild(rowItem[0]).GetChild(rowItem[1])
    if contentItem = invalid
        return
    end if
    m.lastGridItemIdx = rowItem
    ' Also store as SGNode int fields for reliable read on all firmwares
    if m.top <> invalid and rowItem.Count() >= 2
        m.top.lastFocusedRowIndex = rowItem[0]
        m.top.lastFocusedItemIndex = rowItem[1]
    end if
    m.gridPanel.play = false
    m.top.selectedContent = contentItem
    m.top.play = true
end sub

' Grid panel close event - this is the confirmed exit from GridScreen, so actually close
sub OnGridClose()
    LogInfo("LeftNavScreen", "OnGridClose: forwarding close event")
    m.top.close = true
end sub

' Search panel play event - reads the item from rowItemFocused directly
' to eliminate the race condition between play and selectedContent
sub OnSearchPlay()
    if m.searchPanel = invalid
        return
    end if
    if m.searchPanel.play = false
        return
    end if
    sr = m.searchPanel.FindNode("SearchResults")
    if sr = invalid
        return
    end if
    rowItem = sr.rowItemFocused
    if rowItem = invalid or rowItem.Count() < 2
        return
    end if
    contentItem = sr.content.GetChild(rowItem[0]).GetChild(rowItem[1])
    if contentItem = invalid
        return
    end if
    m.lastSearchItemIdx = rowItem
    ' Also store as SGNode int fields for reliable read on all firmwares
    if m.top <> invalid and rowItem.Count() >= 2
        m.top.lastFocusedRowIndex = rowItem[0]
        m.top.lastFocusedItemIndex = rowItem[1]
    end if
    m.searchPanel.play = false
    m.top.selectedContent = contentItem
    m.top.play = true
end sub

' Search panel selected content event
sub OnSearchSelectedContent(event)
    if event <> invalid
        contentItem = event.GetData()
        if contentItem <> invalid
            m.top.selectedContent = contentItem
        end if
    end if
end sub

' Search panel close event - go back to home, don't close LeftNavScreen
sub OnSearchClose()
    m.activePanel = "home"
    m.currentNav = "home"
    ShowHomePanel()
end sub

' Settings panel play event
sub OnSettingsPlay()
    m.top.play = true
end sub

' Settings panel selected content event
sub OnSettingsSelectedContent(content as object)
    m.top.selectedContent = content
end sub

' Settings panel close event - go back to home, don't close LeftNavScreen
sub OnSettingsClose()
    m.activePanel = "home"
    m.currentNav = "home"
    ShowHomePanel()
end sub

' Settings panel layout toggle event
sub OnSettingsLayoutToggle(newLayout as string)
    m.top.layoutToggle = newLayout
end sub

' Continue panel play event — removed for KISS
' sub OnContinuePlay() — removed

' Continue panel close event — removed for KISS
' sub OnContinueClose() — removed

' Handle play event from top-level interface
sub OnPlay()
    LogInfo("LeftNavScreen", "Play event received")
end sub

' Handle selectedContent onChange - triggered when selectedContent field is set
' The relay to MainScene happens via the observer on MainScene
sub OnSelectedContent(event as dynamic)
    if Type(event) = "roSGNodeEvent"
        content = event.GetData()
    else
        content = event
    end if
    if content <> invalid
        LogInfo("LeftNavScreen", "selectedContent updated: " + content.title)
    end if
end sub

' Handle close event from top-level interface
sub OnClose()
    LogInfo("LeftNavScreen", "Close event received")
end sub

' Highlight nav icon to black for contrast on focus
sub HighlightNavIcon(icon, navKey)
    if icon <> invalid and m.iconUris <> invalid and m.iconUris[navKey] <> invalid then
        icon.uri = m.iconUris[navKey].black
    end if
end sub

' Reset nav icon to white when unfocused
sub ResetNavIcon(icon, navKey)
    if icon <> invalid and m.iconUris <> invalid and m.iconUris[navKey] <> invalid then
        icon.uri = m.iconUris[navKey].white
    end if
end sub

' Set all nav icons based on state:
'   focusedKey = "home"/"search"/"settings" → that icon black, others white
'   focusedKey = "" or invalid → all icons white
sub UpdateNavIcons(focusedKey)
    if focusedKey = invalid or focusedKey = "" or m.iconUris = invalid
        ResetNavIcon(m.navHomeIcon, "home")
        ResetNavIcon(m.navSearchIcon, "search")
        ResetNavIcon(m.navSettingsIcon, "settings")
    else
        if focusedKey = "home"
            HighlightNavIcon(m.navHomeIcon, "home")
            ResetNavIcon(m.navSearchIcon, "search")
            ResetNavIcon(m.navSettingsIcon, "settings")
        else if focusedKey = "search"
            ResetNavIcon(m.navHomeIcon, "home")
            HighlightNavIcon(m.navSearchIcon, "search")
            ResetNavIcon(m.navSettingsIcon, "settings")
        else if focusedKey = "settings"
            ResetNavIcon(m.navHomeIcon, "home")
            ResetNavIcon(m.navSearchIcon, "search")
            HighlightNavIcon(m.navSettingsIcon, "settings")
        end if
    end if
end sub

sub ResetAllNavHighlights()
    if m.navHomeBg <> invalid then m.navHomeBg.opacity = 0
    if m.navSearchBg <> invalid then m.navSearchBg.opacity = 0
    if m.navSettingsBg <> invalid then m.navSettingsBg.opacity = 0
end sub

sub SetNavItemHighlight(navKey as string, opacityLevel as float)
    if navKey = "home" and m.navHomeBg <> invalid
        m.navHomeBg.opacity = opacityLevel
    else if navKey = "search" and m.navSearchBg <> invalid
        m.navSearchBg.opacity = opacityLevel
    else if navKey = "settings" and m.navSettingsBg <> invalid
        m.navSettingsBg.opacity = opacityLevel
    end if
end sub

' Handle nav item changed interface update
sub OnNavItemChanged()
    newNav = m.top.selectedNavItem
    if newNav <> invalid and newNav <> ""
        newNavLower = LCase(newNav)
        if newNavLower = "home"
            ShowHomePanel()
        else if newNavLower = "search"
            ShowSearchPanel()
        else if newNavLower = "settings"
            ShowSettingsPanel()
        else
            ' Placeholder items consume the event without switching panels
            return
        end if
    end if
end sub

' Handle content set interface update
sub OnContentSet()
    if m.top.content <> invalid
        m.contentFeed = m.top.content
    end if
    if m.currentNav = "home" and m.gridPanel <> invalid then
        m.gridPanel.content = m.contentFeed
        rl = m.gridPanel.FindNode("rowList")
        if rl <> invalid and rl.content <> invalid and rl.content.GetChildCount() > 0
            rl.SetFocus(true)
            m.currentLocationKey = "home:rowList:0:0"
            m.global.locationKey = "home:rowList:0:0"
            print("[E2E-FOCUS] home:rowList:0:0")
        end if
    else if m.currentNav = "search" and m.searchPanel <> invalid then
        m.searchPanel.content = m.contentFeed
    end if
end sub


' Returns the current rowItemFocused from the RowList inside the gridPanel.
' Returns invalid if the gridPanel or rowList is not available.
function GetFocusedRowItem () as object
    ' Return captured grid index first (more reliable after focus shift)
    if m.lastGridItemIdx <> invalid and m.lastGridItemIdx.Count() >= 2
        return m.lastGridItemIdx
    end if
    ' Return captured search index if grid index not available
    if m.lastSearchItemIdx <> invalid and m.lastSearchItemIdx.Count() >= 2
        return m.lastSearchItemIdx
    end if
    ' Fallback: read live rowItemFocused from grid
    if m.gridPanel <> invalid
        rowList = m.gridPanel.FindNode("rowList")
        if rowList <> invalid
            idx = rowList.rowItemFocused
            if idx <> invalid and idx.Count() >= 2
                return idx
            end if
        end if
    end if
    ' Fallback: read live rowItemFocused from search panel
    if m.searchPanel <> invalid
        sr = m.searchPanel.FindNode("SearchResults")
        if sr <> invalid
            idx = sr.rowItemFocused
            if idx <> invalid and idx.Count() >= 2
                return idx
            end if
        end if
    end if
    return invalid
end function

' Returns the current rowItemFocused from the SearchResults RowList inside the searchPanel.
' Returns invalid if the searchPanel or SearchResults RowList is not available.
function GetSearchFocusedItem () as object
    ' Return captured index first (more reliable after focus shift)
    if m.lastSearchItemIdx <> invalid and m.lastSearchItemIdx.Count() >= 2
        return m.lastSearchItemIdx
    end if
    ' Fallback: read live rowItemFocused
    if m.searchPanel <> invalid
        sr = m.searchPanel.FindNode("SearchResults")
        if sr <> invalid
            idx = sr.rowItemFocused
            if idx <> invalid and idx.Count() >= 2
                return idx
            end if
        end if
    end if
    return invalid
end function

' Live service check timer — removed (schedule page removed)
' Timer kept for future live service detection if needed

' Focus tracker timer — polls focus chain and updates location key
sub OnFocusTimerTick()
    newKey = BuildLocationKey(m.top)
    if newKey <> "" and newKey <> m.currentLocationKey
        m.prevLocationKey = m.currentLocationKey
        m.currentLocationKey = newKey
        m.global.locationKey = newKey
        print("[E2E-FOCUS] " + newKey)
    end if
end sub

' Public method called from child panels to route focus to a nav item
sub FocusOnNav(navItem as string)
    RouteToNav(navItem)
end sub

' Route focus to a specific nav item with proper highlighting
sub RouteToNav(navItem as string)
    if m.navHome = invalid
        return
    end if

    ResetAllNavHighlights()
    if navItem = "home"
        SetNavItemHighlight("home", 1.0)
        UpdateNavIcons("home")
        m.navHome.SetFocus(true)
        m.global.locationKey = "nav:home"
        m.currentLocationKey = "nav:home"
        print("[E2E-FOCUS] nav:home")
    else if navItem = "search"
        SetNavItemHighlight("search", 1.0)
        UpdateNavIcons("search")
        m.navSearch.SetFocus(true)
        m.global.locationKey = "nav:search"
        m.currentLocationKey = "nav:search"
        print("[E2E-FOCUS] nav:search")
    else if navItem = "settings"
        SetNavItemHighlight("settings", 1.0)
        UpdateNavIcons("settings")
        m.navSettings.SetFocus(true)
        m.global.locationKey = "nav:settings"
        m.currentLocationKey = "nav:settings"
        print("[E2E-FOCUS] nav:settings")
    end if
end sub

' Handle key events for focus routing between nav sidebar and content panel
function OnKeyEvent (key as string, press as boolean) as boolean
    try
        if not press
            return false
        end if
        locationKey = m.global.locationKey
        if locationKey = invalid or locationKey = ""
            locationKey = m.currentLocationKey
        end if
        if LCase(key) = "left"
            if MatchKey(locationKey, "home:rowList:*:0")
                rl = m.gridRowList
                if rl <> invalid
                    ri = rl.rowItemFocused
                    if ri <> invalid and ri.Count() >= 2
                        m.lastGridRow = ri[0]
                    end if
                end if
                RouteToNav("home")
                return true
            end if
            if MatchKey(locationKey, "search:results:*:0")
                ' Left from search results: focus the minikeyboard directly
                if m.searchPanel <> invalid
                    miniKb = m.searchPanel.FindNode("SearchField")
                    if miniKb <> invalid
                        miniKb.SetFocus(true)
                    end if
                end if
                m.currentLocationKey = "search:miniKeyboard"
                m.global.locationKey = "search:miniKeyboard"
                return true
            end if
            if MatchKey(locationKey, "search:miniKeyboard")
                RouteToNav("search")
                return true
            end if
            if MatchKey(locationKey, "settings:*")
                RouteToNav("settings")
                return true
            end if
        end if
        ' Right key: route focus from nav to content panel, then verify focus landed
        if LCase(key) = "right"
            if MatchKey(locationKey, "nav:*")
                RouteFocusToContentPanel()
                ' Verify focus actually landed after transition (prevents focus loss)
                EnsureFocusLanded(m.top, SafeNodeGetFocus(m.top))
                return true
            end if
        end if
        if LCase(key) = "ok"
            if MatchKey(locationKey, "nav:home")
                ShowHomePanel()
                return true
            else if MatchKey(locationKey, "nav:search")
                ShowSearchPanel()
                return true
            else if MatchKey(locationKey, "nav:settings")
                ShowSettingsPanel()
                return true
            end if
        end if
        keyLower = LCase(key)
        if keyLower = "up" or keyLower = "down"
            if MatchKey(locationKey, "nav:*")
                return HandleNavUpDown(keyLower, locationKey)
            end if
        end if
        if LCase(key) = "back"
            if MatchKey(locationKey, "nav:*")
                RouteToNav("home")
                return true
            end if
            return false
        end if
    catch e
        SafeLog("ERROR", "LeftNavScreen", "OnKeyEvent failed: " + e.message)
    end try
    return false
end function

' Route focus from nav sidebar to content panel (RIGHT key)
function RouteFocusToContentPanel () as boolean
    ResetAllNavHighlights()
    SetNavItemHighlight(m.activePanel, 0.5)
    UpdateNavIcons(m.activePanel)
    if m.activePanel = "home" and m.gridPanel <> invalid
        rl = m.gridPanel.FindNode("rowList")
        if rl <> invalid
            if m.lastGridRow <> invalid
                rl.jumpToRowItem = [m.lastGridRow, 0]
            else
                rl.jumpToRowItem = [0, 0]
            end if
            rl.SetFocus(true)
            m.currentLocationKey = "home:rowList:" + rl.jumpToRowItem[0].ToStr() + ":0"
            m.global.locationKey = m.currentLocationKey
        else
            m.gridPanel.SetFocus(true)
            m.currentLocationKey = "home:rowList:0:0"
            m.global.locationKey = "home:rowList:0:0"
        end if
    else if m.activePanel = "search" and m.searchPanel <> invalid
        miniKb = m.searchPanel.FindNode("SearchField")
        if miniKb <> invalid
            miniKb.SetFocus(true)
        end if
        m.currentLocationKey = "search:miniKeyboard"
        m.global.locationKey = "search:miniKeyboard"
    else if m.activePanel = "settings" and m.settingsPanel <> invalid
        ltr = m.settingsPanel.FindNode("layoutToggleRow")
        if ltr <> invalid
            ltr.SetFocus(true)
        else
            m.settingsPanel.SetFocus(true)
        end if
        m.currentLocationKey = "settings:toggleRow"
        m.global.locationKey = "settings:toggleRow"
    end if
    return true
end function

' Handle UP/DOWN navigation within nav sidebar
function HandleNavUpDown (keyLower as string, locationKey as string) as boolean
    navItems = [m.navHome, m.navSearch, m.navSettings]
    navKeys = ["home", "search", "settings"]
    maxIdx = 2
    idx = GetNavIndexFromLocationKey(locationKey)
    if idx >= 0
        origIdx = idx
        if keyLower = "up"
            if idx > 0 then idx = idx - 1
        else
            if idx < maxIdx then idx = idx + 1
        end if
        if idx <> origIdx
            ResetAllNavHighlights()
            SetNavItemHighlight(navKeys[idx], 1.0)
            UpdateNavIcons(navKeys[idx])
            navItems[idx].SetFocus(true)
            m.currentLocationKey = "nav:" + navKeys[idx]
            m.global.locationKey = "nav:" + navKeys[idx]
            return true
        end if
    end if
    return false
end function

' Extract nav index (0=home,1=search,2=settings) from location key
function GetNavIndexFromLocationKey (key as string) as integer
    if MatchKey(key, "nav:home") then return 0
    if MatchKey(key, "nav:search") then return 1
    if MatchKey(key, "nav:settings") then return 2
    return 0
end function

' ================================================
' Focus Management Callbacks
' ================================================

' Handle focus request from FocusManager
sub OnFocusRequest(focusArea as string)
    LogInfo("LeftNavScreen", "Focus request for area: " + focusArea)

    if focusArea = "home" then
        if m.navHome <> invalid then SetFocusSafe(m.navHome)
    else if focusArea = "search" then
        if m.navSearch <> invalid then SetFocusSafe(m.navSearch)
    else if focusArea = "settings" then
        if m.navSettings <> invalid then SetFocusSafe(m.navSettings)
    else if focusArea = "grid" then
        if m.gridPanel <> invalid
            rl = m.gridPanel.FindNode("rowList")
            if rl <> invalid then SetFocusSafe(rl)
        end if
    end if
end sub

' Handle focus verification result
sub OnFocusVerified(focusVerified as boolean)
    LogInfo("LeftNavScreen", "Focus verification result: " + Str(focusVerified))
    if not focusVerified
        ' Focus verification failed - attempt to restore focus to current target
        if m.focusTarget <> invalid
            m.focusTarget.SetFocus(true)
        end if
    end if
end sub

' Handle focus verification in progress
sub OnVerifyingFocus(verifyingFocus as boolean)
    LogInfo("LeftNavScreen", "Focus verification in progress: " + Str(verifyingFocus))
end sub

' OnExit handler - cleanup resources when screen exits
sub OnExit()
    LogInfo("LeftNavScreen", "OnExit: Cleaning up resources")

    ' Clean up focus timer
    if m.focusTimer <> invalid
        m.focusTimer.control = "stop"
        m.focusTimer.UnobserveField("fire")
        m.focusTimer = invalid
    end if

    ' Unobserve all observed fields
    if m.navHome <> invalid
        try
            m.navHome.UnobserveField("select")
            m.navHome.UnobserveField("focus")
        catch e
            SafeLog("ERROR", "LeftNavScreen", "Failed to unobserve navHome: " + e.message)
        end try
    end if
    if m.navSearch <> invalid
        try
            m.navSearch.UnobserveField("select")
            m.navSearch.UnobserveField("focus")
        catch e
            SafeLog("ERROR", "LeftNavScreen", "Failed to unobserve navSearch: " + e.message)
        end try
    end if
    if m.navSettings <> invalid
        try
            m.navSettings.UnobserveField("select")
            m.navSettings.UnobserveField("focus")
        catch e
            SafeLog("ERROR", "LeftNavScreen", "Failed to unobserve navSettings: " + e.message)
        end try
    end if

    ' Clean up content panel observers
    if m.contentPanel <> invalid
        try
            m.contentPanel.UnobserveField("select")
        catch e
            SafeLog("ERROR", "LeftNavScreen", "Failed to unobserve contentPanel: " + e.message)
        end try
    end if

    ' Clean up top-level field observers
    try
        m.top.UnobserveField("play")
        m.top.UnobserveField("selectedContent")
        m.top.UnobserveField("close")
        m.top.UnobserveField("channelName")
    catch e
        SafeLog("ERROR", "LeftNavScreen", "Failed to unobserve top fields: " + e.message)
    end try

    ' Clean up deferred init timer
    if m.deferTimer <> invalid
        m.deferTimer.UnobserveField("fire")
    end if

    ' Clean up grid panel observers
    if m.gridPanel <> invalid
        try
            m.gridPanel.UnobserveField("play")
            m.gridPanel.UnobserveField("close")
        catch e
            SafeLog("ERROR", "LeftNavScreen", "Failed to unobserve gridPanel: " + e.message)
        end try
    end if

    ' Clean up search panel observers
    if m.searchPanel <> invalid
        try
            m.searchPanel.UnobserveField("play")
            m.searchPanel.UnobserveField("selectedContent")
            m.searchPanel.UnobserveField("close")
        catch e
            SafeLog("ERROR", "LeftNavScreen", "Failed to unobserve searchPanel: " + e.message)
        end try
    end if

    ' Clean up settings panel observers
    if m.settingsPanel <> invalid
        try
            m.settingsPanel.UnobserveField("play")
            m.settingsPanel.UnobserveField("selectedContent")
            m.settingsPanel.UnobserveField("close")
            m.settingsPanel.UnobserveField("layoutToggle")
        catch e
            SafeLog("ERROR", "LeftNavScreen", "Failed to unobserve settingsPanel: " + e.message)
        end try
    end if

    ' Clean up focus manager observers
    if m.focusManager <> invalid
        try
            m.focusManager.UnobserveField("requestFocus")
        catch e
            SafeLog("ERROR", "LeftNavScreen", "Failed to unobserve focusManager: " + e.message)
        end try
    end if

    ' Clean up focus verifier observers
    if m.focusVerifier <> invalid
        try
            m.focusVerifier.UnobserveField("focusVerified")
            m.focusVerifier.UnobserveField("verifyingFocus")
        catch e
            SafeLog("ERROR", "LeftNavScreen", "Failed to unobserve focusVerifier: " + e.message)
        end try
    end if

    ' Reset global state
    m.activePanel = ""
    m.currentLocationKey = ""
    m.focusTarget = invalid

    LogInfo("LeftNavScreen", "OnExit: Cleanup complete")
end sub


