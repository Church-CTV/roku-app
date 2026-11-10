' MainScene.brs - Enhanced with BrandTheme, loading/error/welcome states, and focus management
' ********** Copyright 2020 Roku Corp.  All Rights Reserved. **********

sub Init()
    try
        AppInit()
        LogInfo("MainScene", "Initializing channel")

        ' Enable low general memory events (Roku certification)
        EnableLowGeneralMemoryEvent(true)

        ' Initialize focus management system
        ' FocusManager is now a proper component - its Init() runs automatically
        ' upon node creation. We just observe fields and set context here.
        try
            m.focusManager = SafeFindNode(m.top, "focusManager")
            if m.focusManager <> invalid
                SafeObserveField(m.focusManager, "requestFocus", "OnFocusRequest")
                SafeObserveField(m.focusManager, "clearFocus", "OnFocusClear")
                m.focusManager.currentFocusArea = "MainScene"
            end if
        catch e
            LogError("MainScene", "Error initializing FocusManager: " + e.message)
        end try

        try
            m.focusVerifier = SafeFindNode(m.top, "focusVerifier")
            if m.focusVerifier <> invalid
                SafeObserveField(m.focusVerifier, "focusVerified", "OnFocusVerified")
                SafeObserveField(m.focusVerifier, "verifyingFocus", "OnVerifyingFocus")
            end if
        catch e
            LogError("MainScene", "Error initializing FocusVerifier: " + e.message)
        end try

        ' Initialize RowList focus handler mixin
        ' (named InitRowListFocusHandler to avoid sub Init() clash in MainScene namespace)
        try
            InitRowListFocusHandler()
        catch e
            LogError("MainScene", "Error initializing RowList focus handler: " + e.message)
        end try
        try
            ' Theme and overhang node references (used by config/theme application)
            m.theme = SafeFindNode(m.top, "theme")
            m.overhang = SafeFindNode(m.top, "overhang")
            m.welcomeScreen = SafeFindNode(m.top, "welcomeScreen")
            m.welcomeTitle = SafeFindNode(m.top, "welcomeTitle")
            m.welcomeSubtitle = SafeFindNode(m.top, "welcomeSubtitle")
            m.loadingIndicator = SafeFindNode(m.top, "loadingIndicator")
            m.loadingText = SafeFindNode(m.top, "loadingText")
            m.errorScreen = SafeFindNode(m.top, "errorScreen")
            m.errorTitle = SafeFindNode(m.top, "errorTitle")
            m.errorMessage = SafeFindNode(m.top, "errorMessage")
            m.retryButton = SafeFindNode(m.top, "retryButton")
        catch e
            LogError("MainScene", "Error initializing theme/welcome/error nodes: " + e.message)
        end try

        try
            ' Set background color - will be overridden by config once loaded
            m.top.backgroundColor = "0x1A1A2E"
            m.top.backgroundUri = "pkg:/images/background.png"
        catch e
            LogError("MainScene", "Error setting background: " + e.message)
        end try

        ' Initialize configuration system. ConfigManager loads synchronously in its
        ' own Init, so config is already available here.
        try
            m.configManager = SafeFindNode(m.top, "configManager")
            m.configMgrReady = false
            if m.configManager <> invalid and m.configManager.configLoaded
                OnConfigLoaded()
            else if m.configManager <> invalid and m.configManager.configError <> ""
                OnConfigError()
            else
                LogError("MainScene", "ConfigManager not available - using hardcoded defaults")
                ApplyHardcodedDefaults()
            end if
        catch e
            LogError("MainScene", "Error initializing ConfigManager: " + e.message)
        end try

        ' Initialize analytics infrastructure
        ' Create analytics and crashReporter nodes and store on global node.
        ' Note: m.global is the shared global node (roSGNode) — we create the nodes
        ' here so they survive across component boundaries.
        try
            m.analytics = CreateObject("roSGNode", "Analytics")
            if m.analytics <> invalid
                m.analytics.eventCount = 0
                m.analytics.lastExportTime = ""
                m.analytics.screenHistory = CreateObject("roArray", 50, true)
                m.analytics.playHistory = CreateObject("roArray", 100, true)
                m.analytics.deepLinkHistory = CreateObject("roArray", 50, true)
                m.analytics.errorHistory = CreateObject("roArray", 50, true)
                m.analytics.sessionStartTime = GetTimestamp()
                m.analytics.sessionStartEpoch = CreateObject("roDateTime").AsSeconds()
                m.analytics.activeScreen = "MainScene"
            end if
        catch e
            LogError("MainScene", "Error initializing Analytics node: " + e.message)
        end try

        try
            m.crashReporter = CreateObject("roSGNode", "CrashReporter")
            if m.crashReporter <> invalid
                m.crashReporter.lastCrashTime = ""
                m.crashReporter.lastCrashMessage = ""
                m.crashReporter.lastCrashStack = ""
                m.crashReporter.crashCount = 0
                m.crashReporter.pendingCrashes = CreateObject("roArray", 10, true)
                m.crashReporter.errorCount = 0
            end if
        catch e
            LogError("MainScene", "Error initializing CrashReporter node: " + e.message)
        end try

        ' Store on m.global so all scripts can access via m.global.analytics / m.global.crashReporter
        ' NOTE: m.global does NOT support node/assocarray field types at runtime.
        ' Instead, we store these as local m. variables and provide accessors.
        ' The Analytics/CrashReporter modules check m.global first, then fall back to
        ' looking them up via m.top.FindNode() if needed.
        try
            AnalyticsInit(m.global)
            AnalyticsExportInit(m.global)
            CrashReporterInit()
            TrackScreenView("MainScene", "")
        catch e
            LogError("MainScene", "Error initializing analytics/crash reporting: " + e.message)
        end try

        try
            ' Initialize heartbeat telemetry system
            if m.configManager <> invalid and m.configManager.config <> invalid and m.configManager.config <> ""
                config = m.configManager.callFunc("GetConfig")
                if config <> invalid
                    HeartbeatInit(m.global, config)
                end if
            end if
        catch e
            LogError("MainScene", "Error initializing heartbeat: " + e.message)
        end try

        try
            ' Set up periodic export interval (60 seconds default)
            m.heartbeatExportInterval = 60000
            if m.configManager <> invalid and m.configManager.config <> invalid and m.configManager.config <> ""
                config = m.configManager.callFunc("GetConfig")
                if config <> invalid and config.DoesExist("heartbeat") and config.heartbeat <> invalid
                    if config.heartbeat.DoesExist("intervalSeconds")
                        m.heartbeatExportInterval = config.heartbeat["intervalSeconds"] * 1000
                    end if
                end if
            end if
        catch e
            LogError("MainScene", "Error reading heartbeat export interval from config: " + e.message)
        end try

        try
            ' Create roTimer to fire periodic heartbeat exports
            m.heartbeatTimer = CreateObject("roSGNode", "Timer")
            if m.heartbeatTimer <> invalid
                m.heartbeatTimer.duration = 60000 ' default to 60 seconds
                ' Override with config value if available
                if m.heartbeatExportInterval <> invalid
                    m.heartbeatTimer.duration = m.heartbeatExportInterval
                end if
                m.heartbeatTimer.control = "run"
                m.heartbeatTimer.repeat = true
                SafeObserveField(m.heartbeatTimer, "fire", "OnHeartbeatTimer")
                SafeLog("INFO", "MainScene", "Heartbeat timer started - interval: " + m.heartbeatExportInterval.ToStr() + "ms")
            end if
        catch e
            LogError("MainScene", "Error initializing heartbeat timer: " + e.message)
        end try

        try
            InitScreenStack()
        catch e
            LogError("MainScene", "Error initializing screen stack: " + e.message)
        end try

        ' Initialize StateExporterTask for ECP state tracking
        ' Writes app state to device registry so E2E tests can query via GET /query/registry/dev
        try
            m.stateExporter = CreateObject("roSGNode", "StateExporterTask")
            if m.stateExporter <> invalid
                m.stateExporter.control = "run"
                ' Pass initial state via CallFunc (avoids field type mismatch errors)
                m.stateExporter.CallFunc("ExportNow", { state: BuildExporterState() })
            end if
        catch e
            LogError("MainScene", "Error initializing StateExporterTask: " + e.message)
        end try

        ' Check layout preference and show appropriate screen
        try
            if m.configMgrReady and m.configManager <> invalid then
                layoutPref = m.configManager.callFunc("GetLayoutPreference")
                if layoutPref = "leftnav" then
                    ShowLeftNavScreen()
                else
                    ShowGridScreen()
                end if
            else
                ShowGridScreen()
            end if
        catch e
            LogError("MainScene", "Error determining initial layout: " + e.message)
            ShowGridScreen()
        end try

        try
            RunContentTask()
        catch e
            LogError("MainScene", "Error running content task: " + e.message)
            ShowErrorScreen("Failed to load content: " + e.message)
        end try


        ' Watch for deep link info set via interface
        try
            SafeObserveField(m.top, "deeplinkContentId", "OnDeepLinkReceived")
        catch e
            LogError("MainScene", "Error observing deep link field: " + e.message)
        end try


        ' Observe retry button
        try
            if m.retryButton <> invalid
                SafeObserveField(m.retryButton, "select", "OnRetry")
            end if
        catch e
            LogError("MainScene", "Error observing retry button: " + e.message)
        end try

        ' Process deep link from startup args (set by main.brs on global node)
        ' DEPRECATED: Immediate processing removed to eliminate race condition with content loading.
        ' Deep link processing now happens in ContentTaskLogic.brs OnMainContentLoaded()
        ' after content is fully loaded. We only store params here and set interface fields.
        try
            if m.global <> invalid and m.global.DeepContentId <> invalid and m.global.DeepContentId <> "" then
                contentId = m.global.DeepContentId
                mediaType = m.global.DeepMediaType
                SafeLog("INFO", "MainScene", "Deep link params detected at init: contentId=" + contentId + " mediatype=" + mediaType)
                print "DEEP LINK DEBUG: MainScene Init - deep link params stored, deferring to OnMainContentLoaded"

                ' Store pending deep link on interface fields so ContentTaskLogic finds them
                m.top.deeplinkContentId = contentId
                m.top.deeplinkMediaType = mediaType

                ' Also store locally for reference
                m.deepLinkContentId = contentId
                m.deepLinkMediaType = mediaType
                m.deepLinkStartTime = CreateObject("roDateTime").AsSeconds()
                m.deepLinkTimeout = 30 ' 30 seconds

                TrackDeepLink(contentId, mediaType, true)

                ' Show loading indicator while waiting for content
                if m.loadingIndicator <> invalid then
                    m.loadingIndicator.visible = true
                end if
            else
                print "DEEP LINK DEBUG: No deep link params on global node"
            end if
        catch e
            LogError("MainScene", "Init(), Storing deep link params exception: " + e.message)
            ShowErrorScreen("Initialization failed, Storing deep link params: " + e.message)
        end try
        LogInfo("MainScene", "Initialization complete")
    catch e
        LogError("MainScene", "Init() exception: " + e.message)
        ShowErrorScreen("Initialization failed: " + e.message)
    end try
end sub

' Callback when ConfigManager finishes loading
sub OnConfigLoaded()
    LogInfo("MainScene", "Config loaded successfully")
    m.configMgrReady = true

    ' Get config values
    config = m.configManager.config
    if config = invalid then return

    ' Apply branding colors to theme
    if m.theme <> invalid
        m.theme.bgColor = m.configManager.bgColor
        m.theme.surfaceColor = m.configManager.surfaceColor
        m.theme.accentColor = m.configManager.accentColor
        m.theme.textPrimary = m.configManager.textPrimary
        m.theme.textSecondary = m.configManager.textSecondary
        m.theme.focusColor = m.configManager.focusColor
        m.theme.errorColor = m.configManager.errorColor
    end if
    LogInfo("MainScene", "Theme colors applied from config")

    ' Apply background
    m.top.backgroundColor = m.configManager.uiBackgroundColor
    m.top.backgroundUri = m.configManager.backgroundImageUri

    ' Apply overhang settings
    if m.overhang <> invalid
        if m.configManager.featureOverhangLogo
            m.overhang.logoUri = m.configManager.overhangLogoUri
        else
            m.overhang.logoUri = ""
        end if
        m.overhang.showOptions = m.configManager.featureOverhangOptions
        m.overhang.showClock = m.configManager.featureOverhangClock
    end if
    ' Apply UI text
    if m.welcomeTitle <> invalid
        m.welcomeTitle.text = m.configManager.uiWelcomeTitle
    end if
    if m.welcomeSubtitle <> invalid
        m.welcomeSubtitle.text = m.configManager.uiWelcomeSubtitle
    end if
    if m.errorTitle <> invalid
        m.errorTitle.text = m.configManager.uiErrorTitle
    end if
    if m.errorMessage <> invalid
        m.errorMessage.text = m.configManager.uiErrorMessage
    end if
    if m.retryButton <> invalid
        m.retryButton.text = m.configManager.uiRetryLabel
    end if
    if m.loadingText <> invalid
        m.loadingText.text = m.configManager.uiLoadingMessage
    end if

    ' Apply feature toggles
    if not m.configManager.featureSearch
        LogInfo("MainScene", "Search feature disabled by config")
    end if

    ' Apply analytics config
    if not m.configManager.featureAnalytics
        LogInfo("MainScene", "Analytics disabled by config")
    end if

    LogInfo("MainScene", "Configuration applied - channel: " + m.configManager.channelName)

    ' Start periodic analytics export timer (fires every ~5 minutes)
    m.analyticsExportTimer = CreateObject("roTimespan")
    m.analyticsExportTimer.Mark()
end sub

' Callback when ConfigManager encounters an error
sub OnConfigError()
    LogError("MainScene", "Config error: " + m.configManager.configError)
    ApplyHardcodedDefaults()
end sub

' Fallback: apply hardcoded defaults if config loading fails
sub ApplyHardcodedDefaults()
    LogInfo("MainScene", "Applying hardcoded defaults")
    m.configMgrReady = true

    if m.theme <> invalid
        m.theme.bgColor = "0x1A1A2E"
        m.theme.surfaceColor = "0x16213E"
        m.theme.accentColor = "0xE8B931"
        m.theme.textPrimary = "0xFFFFFF"
        m.theme.textSecondary = "0xA0A0B0"
        m.theme.focusColor = "0xE8B931"
        m.theme.errorColor = "0xFF4444"
    end if

    m.top.backgroundColor = "0x1A1A2E"
    m.top.backgroundUri = "pkg:/images/background.png"

    if m.overhang <> invalid
        m.overhang.logoUri = "pkg:/images/hd_overhang_logo.png"
        m.overhang.showOptions = false
        m.overhang.showClock = false
    end if
    if m.welcomeTitle <> invalid
        m.welcomeTitle.text = "Loading..."
    end if
    if m.welcomeSubtitle <> invalid
        m.welcomeSubtitle.text = "Please wait"
    end if
    if m.loadingText <> invalid
        m.loadingText.text = "Loading..."
    end if
    if m.errorTitle <> invalid
        m.errorTitle.text = "Connection Error"
    end if
    if m.errorMessage <> invalid
        m.errorMessage.text = "Unable to load content. Please check your network connection."
    end if
    if m.retryButton <> invalid
        m.retryButton.text = "Retry"
    end if

    LogInfo("MainScene", "Hardcoded defaults applied")
end sub

' Callback when ContentTaskLogic requests playback of a content item
' (fires when m.top.playContent is set from a task context)
sub OnPlayContentRequested()
    contentItem = m.top.playContent
    if contentItem = invalid then return
    print "DEEP LINK DEBUG: OnPlayContentRequested: playing " + contentItem.id
    m.top.playContent = invalid
    PlayContent(contentItem)
end sub

' Callback when deep link info is set via interface
' NOTE: This observer fires when deeplinkContentId is set, which may happen
' before deeplinkMediaType is set (main.brs sets them sequentially). The content
' feed may not be loaded yet either. When content isn't found, we MUST NOT clear
' the params — defer to ContentTaskLogic.OnMainContentLoaded() which runs after
' content loading completes and has the full content tree to search.
sub OnDeepLinkReceived()
    contentItem = invalid
    contentId = m.top.deeplinkContentId
    if contentId <> invalid and contentId <> "" then
        SafeLog("INFO", "MainScene", "OnDeepLinkReceived: processing contentId=" + contentId)
        print "DEEP LINK DEBUG: OnDeepLinkReceived called for: " + contentId

        ' For video and live media types, try to find and play immediately
        ' Check BOTH contentId and mediaType to avoid false positives from
        ' partial observer fires (contentId set but mediaType not yet set)
        if m.top.deeplinkMediaType <> invalid and m.top.deeplinkMediaType <> "" then
            mediaType = m.top.deeplinkMediaType
            if mediaType = "video" or mediaType = "movie" or mediaType = "episode" or mediaType = "live" then
                contentItem = FindContentById(contentId)
                ' Special case: live_0/live_stream_0 maps to the live stream item in the feed
                if contentItem = invalid then
                    liveId = LCase(contentId)
                    if liveId = "live_0" or liveId = "live_stream_0" then
                        contentItem = FindContentById("live_stream_0")
                        if contentItem = invalid then
                            config = invalid
                            if m.configManager <> invalid and m.configManager.config <> invalid then
                                config = m.configManager.callFunc("GetConfig")
                            end if
                            if config <> invalid then
                                liveUrl = ""
                                if config.branding <> invalid and config.branding.images <> invalid and config.branding.images.liveStreamUrl <> invalid then
                                    liveUrl = config.branding.images.liveStreamUrl
                                end if
                                if liveUrl <> "" then
                                    contentItem = CreateObject("roSGNode", "ContentNode")
                                    contentItem.id = "live_stream_0"
                                    contentItem.title = "LIVE Service"
                                    contentItem.description = "Watch the current service live"
                                    contentItem.streamFormat = "hls"
                                    contentItem.url = liveUrl
                                    contentItem.hdPosterUrl = ""
                                    if config.branding <> invalid and config.branding.images <> invalid and config.branding.images.liveStreamThumbnail <> invalid then
                                        contentItem.hdPosterUrl = config.branding.images.liveStreamThumbnail
                                    end if
                                    print "DEEP LINK DEBUG: live stream resolved, playing live stream"
                                end if
                            end if
                        else
                            print "DEEP LINK DEBUG: live_stream_0 found in content feed, playing"
                        end if
                    end if
                end if
                if contentItem <> invalid then
                    print "DEEP LINK DEBUG: Content found via interface, playing"
                    PlayContent(contentItem)
                    ' Clear only after successful processing
                    m.top.deeplinkContentId = ""
                    m.top.deeplinkMediaType = ""
                else
                    print "DEEP LINK DEBUG: Content not found yet (content still loading), deferring to ContentTaskLogic"
                    ' Do NOT clear deep link params — ContentTaskLogic will process them after content loads
                end if
            else
                ' Non-video/live media type — show grid but do NOT clear deep link params
                ' since ContentTaskLogic needs them to find and play content
                print "DEEP LINK DEBUG: Non-video/live media type via interface, showing grid"
                ShowGridScreen()
                ' Do NOT clear params — ContentTaskLogic.OnMainContentLoaded() will process them
            end if
        else
            ' No media type specified yet (observer fired before main.brs set it).
            ' Do NOT clear params — ContentTaskLogic needs them.
            print "DEEP LINK DEBUG: mediaType not set yet, deferring to ContentTaskLogic"
            ShowGridScreen()
        end if

        ' Always clear global params after handling (only if we consumed the deep link)
        if m.global <> invalid and contentItem <> invalid then
            m.global.DeepContentId = ""
            m.global.DeepMediaType = ""
        end if
    end if
end sub

' Search screen navigation
sub ShowSearchScreen()
    ' Create or get the search screen
    if m.searchScreen = invalid
        m.searchScreen = CreateObject("roSGNode", "SearchScreen")
        if m.searchScreen <> invalid
            m.searchScreen.content = m.contentFeed
            SafeObserveField(m.searchScreen, "close", "OnSearchBack")
            SafeObserveField(m.searchScreen, "play", "OnSearchPlay")
            m.top.appendChild(m.searchScreen)
        end if
    end if

    m.searchScreen.visible = true
    m.searchScreen.SetFocus(true)
    TrackScreenView("SearchScreen", "")
end sub

sub OnSearchBack()
    m.searchScreen.visible = false
    TrackScreenView("Back", "SearchScreen")
end sub

sub OnSearchPlay(contentItem)
    if contentItem = invalid then return
    LogInfo("MainScene", "Playing from search: " + contentItem.title)
    PlayContent(contentItem)
end sub

' Left Navigation Screen - Shows fixed-width sidebar with content panel
sub ShowLeftNavScreen()
    try
        if m.leftNavScreen = invalid then
            m.leftNavScreen = CreateObject("roSGNode", "LeftNavScreen")
            if m.leftNavScreen <> invalid
                m.leftNavScreen.content = m.contentFeed
                m.leftNavScreen.channelName = m.configManager.channelName
                m.leftNavScreen.channelVersion = m.configManager.channelVersion
                m.leftNavScreen.contentSourceUrl = m.configManager.contentSourceUrl
                m.leftNavScreen.currentLayout = m.configManager.callFunc("GetLayoutPreference")
                m.leftNavScreen.featureSearch = m.configManager.featureSearch
                m.leftNavScreen.featureDeepLinking = m.configManager.featureDeepLinking
                m.leftNavScreen.featureAnalytics = m.configManager.featureAnalytics
                m.leftNavScreen.featureCrashReporting = m.configManager.featureCrashReporting
                m.leftNavScreen.iconFocusUri = m.configManager.iconFocusUri
                m.leftNavScreen.givingDonationUrl = m.configManager.givingDonationUrl
                m.leftNavScreen.streamUrl = m.configManager.liveStreamUrl
                m.leftNavScreen.liveStreamThumbnail = m.configManager.liveStreamThumbnail
                SafeObserveField(m.leftNavScreen, "close", "OnLeftNavBack")
                SafeObserveField(m.leftNavScreen, "play", "OnLeftNavPlay")
                SafeObserveField(m.leftNavScreen, "layoutToggle", "OnLeftNavLayoutToggle")
            end if
        end if
        ShowScreen(m.leftNavScreen)
    catch e
        SafeLog("ERROR", "MainScene", "ShowLeftNavScreen failed: " + e.message)
    end try
end sub

sub OnLeftNavBack()
    LogInfo("MainScene", "OnLeftNavBack: setting CloseChannel flag")
    if m.global <> invalid
        m.global.CloseChannel = true
    end if
end sub

sub OnLeftNavPlay()
    if m.video <> invalid then return
    contentItem = m.leftNavScreen.selectedContent
    if contentItem <> invalid and (contentItem.url <> invalid or contentItem.streamUrl <> invalid)
        LogInfo("MainScene", "Playing from left nav: " + contentItem.title)
        PlayContent(contentItem)
    end if
end sub

sub OnLeftNavLayoutToggle(newLayout as string)
    try
        if m.configManager <> invalid then
            m.configManager.callFunc("SetLayoutPreference", newLayout)
        end if
        LogInfo("MainScene", "Layout toggled to: " + newLayout)
        if newLayout = "grid" then
            ShowGridScreen()
        else
            ShowLeftNavScreen()
        end if
    catch e
        SafeLog("ERROR", "MainScene", "OnLeftNavLayoutToggle failed: " + e.message)
    end try
end sub


' Show the fallback error screen when Init() crashes
sub ShowErrorScreen(errorMessage as string)
    try
        LogError("MainScene", "Showing error screen: " + errorMessage)

        ' Hide loading indicator and other UI elements
        if m.loadingIndicator <> invalid
            m.loadingIndicator.visible = false
        end if
        if m.welcomeScreen <> invalid
            m.welcomeScreen.visible = false
        end if

        ' Try to show the built-in error screen first
        if m.errorScreen <> invalid
            if m.errorTitle <> invalid
                m.errorTitle.text = "Initialization Error"
            end if
            if m.errorMessage <> invalid
                m.errorMessage.text = errorMessage
            end if
            m.errorScreen.visible = true
        end if

        ' Also show the dedicated error screen fallback
        m.errorScreenFallback = SafeFindNode(m.top, "errorScreenFallback")
        if m.errorScreenFallback <> invalid
            m.errorScreenFallback.callFunc("show", errorMessage, "Initialization Error")
            m.errorScreenFallback.visible = true
        end if

        ' Set global error state
        if m.global <> invalid
            m.global.ErrorOccurred = true
            m.global.ErrorMessage = errorMessage
        end if

        ' Report the crash
        try
            ReportCrash("MainScene_Init", errorMessage, "App launch")
        catch e
            LogError("MainScene", "ReportCrash failed: " + e.message)
        end try
    catch e
        SafeLog("ERROR", "MainScene", "ShowErrorScreen failed: " + e.message)
    end try
end sub

' Retry button handler
sub OnRetry()
    LogInfo("MainScene", "Retry button pressed, reloading content")
    TrackInteraction("retry", "errorScreen", "Network error retry")
    m.global.ErrorOccurred = false
    m.global.ErrorMessage = ""
    m.errorScreen.visible = false
    m.loadingIndicator.visible = true
    RunContentTask()
end sub

function FindContentById (contentId) as object
    try
        ' Try main content feed first
        contentNode = m.contentFeed
        if contentNode = invalid then
            ' Fallback: check currently visible screen's content
            ' (m.contentFeed may not be set when using ShowGridScreen directly)
            if m.screenStack <> invalid and m.screenStack.Count() > 0
                currentScreen = m.screenStack[m.screenStack.Count() - 1]
                if currentScreen <> invalid and currentScreen.content <> invalid
                    contentNode = currentScreen.content
                end if
            end if
        end if

        if contentNode = invalid then return invalid
        for i = 0 to contentNode.GetChildCount() - 1
            row = contentNode.GetChild(i)
            if row <> invalid
                for j = 0 to row.GetChildCount() - 1
                    item = row.GetChild(j)
                    if item <> invalid and item.id = contentId then return item
                end for
            end if
        end for
        return invalid
    catch e
        SafeLog("ERROR", "MainScene", "FindContentById failed: " + e.message)
        return invalid
    end try
end function

sub PlayContent(contentItem)
    try
        if contentItem = invalid then return
        LogInfo("MainScene", "Playing: " + contentItem.title)

        try
            ' Update focus manager state - track we're moving to video
            if m.focusManager <> invalid
                m.focusManager.previousFocusArea = m.focusManager.currentFocusArea
                m.focusManager.currentFocusArea = "video"
                m.focusManager.panelFocusContext = contentItem.id
            end if
        catch e
            LogWarn("MainScene", "FocusManager update failed: " + e.message)
        end try

        ' Track video state with heartbeat
        try
            HeartbeatTrackVideo(true, contentItem.id, 0, 0)
            HeartbeatTrackScreen("VideoScreen")
        catch e
            LogWarn("MainScene", "Heartbeat tracking failed: " + e.message)
        end try

        ' Remember which item the user selected so we can restore focus on return.
        ' Priority: capture the actual grid or search content item index from the
        ' active panel, not the nav panel's selectedIndex.
        ' IMPORTANT: All field reads and ToStr() calls must be guarded — this firmware
        ' throws "Member function not found" when calling methods on invalid values.
        m.lastSelectedIndex = invalid
        try
            if m.leftNavScreen <> invalid
                ' Try GetSearchFocusedItem first (for search results)
                searchIdx = invalid
                try
                    searchIdx = m.leftNavScreen.callFunc("GetSearchFocusedItem")
                catch e
                    LogWarn("MainScene", "GetSearchFocusedItem failed: " + e.message)
                end try
                if searchIdx <> invalid and Type(searchIdx) = "roArray" and searchIdx.Count() >= 2
                    m.lastSelectedIndex = searchIdx
                    idxStr = searchIdx[0].ToStr() + "," + searchIdx[1].ToStr()
                    LogInfo("MainScene", "PlayContent: captured search result: " + idxStr)
                end if
                ' Fallback: GetFocusedRowItem (for home grid)
                if m.lastSelectedIndex = invalid
                    gridIdx = invalid
                    try
                        gridIdx = m.leftNavScreen.callFunc("GetFocusedRowItem")
                    catch e
                        LogWarn("MainScene", "GetFocusedRowItem failed: " + e.message)
                    end try
                    if gridIdx <> invalid and Type(gridIdx) = "roArray" and gridIdx.Count() >= 2
                        m.lastSelectedIndex = gridIdx
                        idxStr = gridIdx[0].ToStr() + "," + gridIdx[1].ToStr()
                        LogInfo("MainScene", "PlayContent: captured grid index: " + idxStr)
                    end if
                end if
            end if
        catch e
            LogWarn("MainScene", "Error capturing focused index: " + e.message)
        end try

        ' 3) If still invalid, fall back to whatever the current keyboard focus is on.
        if m.lastSelectedIndex = invalid
            focusedNode = SafeNodeGetFocus(m.top)
            if focusedNode <> invalid
                rowList = focusedNode
                while rowList <> invalid
                    try
                        rowType = Type(rowList)
                        if rowType = "roSGNode_RowList" or rowType = "RowList"
                            rowItem = rowList.rowItemFocused
                        else if rowItem <> invalid and Type(rowItem) = "roArray"
                            if rowItem.Count() >= 2
                                m.lastSelectedIndex = rowItem
                                SafeLog("INFO", "MainScene", "PLAYCONTENT-15: captured from focus: " + rowItem.ToStr())
                            end if
                            exit while
                        end if
                    catch e
                        LogWarn("MainScene", "RowList type check failed: " + e.message)
                    end try
                    rowList = rowList.getParent()
                end while
            end if
        end if
        if m.lastSelectedIndex = invalid
            m.lastSelectedIndex = [0, 0]
        end if

        ' Tear down any previous video before starting a new one
        if m.video <> invalid
            if m.screenStack.Count() > 0 and m.screenStack[m.screenStack.Count() - 1].IsSameNode(m.video)
                CloseScreen(m.video)
            end if
            try
                m.video.UnobserveField("close")
            catch e
                LogError("MainScene", "Error unobserving video close: " + e.message)
            end try
            m.video = invalid
        end if

        ' Use VideoScreen for stock Roku video playback
        videoScreen = CreateObject("roSGNode", "VideoScreen")
        if videoScreen <> invalid
            videoScreen.content = contentItem
            SafeObserveField(videoScreen, "close", "OnVideoClose")
            m.video = videoScreen
            ShowScreen(videoScreen)
            videoScreen.setFocus(true)
            RefreshStateExporter()
            LogInfo("MainScene", "VideoScreen launched: " + contentItem.title)
        else
            ' Fallback: raw Video node if VideoScreen unavailable
            video = CreateObject("roSGNode", "Video")
            if video <> invalid
                video.width = 1920
                video.height = 1080
                streamUri = ""
                if contentItem.url <> invalid and contentItem.url <> ""
                    streamUri = contentItem.url
                else if contentItem.streamUrl <> invalid and contentItem.streamUrl <> ""
                    streamUri = contentItem.streamUrl
                end if
                streamFmt = ""
                if contentItem.streamFormat <> invalid
                    streamFmt = contentItem.streamFormat
                end if
                if streamFmt = "" and streamUri.InStr(".m3u8") > 0
                    streamFmt = "hls"
                end if
                video.content = CreateObject("roSGNode", "ContentNode")
                if video.content <> invalid
                    video.content.title = contentItem.title
                    video.content.url = streamUri
                    video.content.streamFormat = streamFmt
                    video.content.length = contentItem.length
                    video.content.hdPosterUrl = contentItem.hdPosterUrl
                end if
                SafeObserveField(video, "state", "OnVideoStateChange")
                m.video = video
                ShowScreen(video)
                video.setFocus(true)
                video.control = "play"
                RefreshStateExporter()
                LogInfo("MainScene", "Video playing (fallback): uri=" + streamUri + " format=" + streamFmt)
            else
                LogError("MainScene", "Failed to create Video node")
            end if
        end if
    catch e
        SafeLog("ERROR", "MainScene", "PlayContent failed: " + e.message)
    end try
end sub

' Watch the Video node's state — when playback stops (user pressed back, or
' video finished/errored), return to the grid with the previous focus restored.
sub OnVideoStateChange()
    if m.video = invalid then return
    state = m.video.state
    if state = "stopped" or state = "finished" or state = "error"
        ' Track video stopped with heartbeat
        HeartbeatTrackVideo(false, "", 0, 0)
        HeartbeatTrackScreen("MainScene")

        if m.screenStack.Count() > 0
            top = m.screenStack[m.screenStack.Count() - 1]
            if top.IsSameNode(m.video)
                CloseScreen(m.video)
            end if
        end if
        m.video.UnobserveField("state")
        m.video = invalid
    end if
end sub

' Handle close event from VideoScreen
sub OnVideoClose()
    try
        if m.video = invalid then return
        ' Track video closed with heartbeat
        HeartbeatTrackVideo(false, "", 0, 0)
        HeartbeatTrackScreen("MainScene")

        if m.screenStack.Count() > 0
            top = m.screenStack[m.screenStack.Count() - 1]
            if top.IsSameNode(m.video)
                CloseScreen(m.video)
            end if
        end if
        try
            m.video.UnobserveField("close")
        catch e
            LogError("MainScene", "Error unobserving video close: " + e.message)
        end try
        m.video = invalid
        RefreshStateExporter()

        ' Update focus manager - restore to previous area
        if m.focusManager <> invalid
            m.focusManager.currentFocusArea = m.focusManager.previousFocusArea
            m.focusManager.panelFocusContext = ""
            ' Request focus restoration to grid
            m.focusManager.requestFocus = "grid"
        end if

        ' Restore focus to the grid or search results using verifier for reliability
        if m.leftNavScreen = invalid then return
        ' Guard lastSelectedIndex — calling .ToStr() on invalid throws on this firmware
        lsiStr = "invalid"
        if m.lastSelectedIndex <> invalid
            lsiStr = "[" + m.lastSelectedIndex[0].ToStr() + "," + m.lastSelectedIndex[1].ToStr() + "]"
        end if
        LogInfo("MainScene", "OnVideoClose: restoring focus, lastSelectedIndex=" + lsiStr)

        ' --- Search panel path: use SearchScreen.RestoreSearchFocus() which reads
        ' m.lastSearchFocusedItem (set by OnSearchResultSelected on OK press) ---
        if m.searchScreen <> invalid and m.searchScreen.visible
            sr = m.searchScreen.SearchResults
            LogInfo("MainScene", "OnVideoClose: searchScreen visible=" + m.searchScreen.visible.ToStr() + " SearchResults valid=" + (sr <> invalid).ToStr())
            if sr <> invalid and sr.visible
                ' Try the search screen's own RestoreSearchFocus first (uses lastSearchFocusedItem)
                searchRestored = false
                try
                    searchRestored = m.searchScreen.callFunc("RestoreSearchFocus")
                catch e
                    LogWarn("MainScene", "RestoreSearchFocus CallFunc failed: " + e.message)
                end try
                if searchRestored
                    LogInfo("MainScene", "OnVideoClose: restored focus via RestoreSearchFocus")
                    return
                end if
                ' Fallback: use lastSelectedIndex as backup
                if m.lastSelectedIndex <> invalid and Type(m.lastSelectedIndex) = "roArray" and m.lastSelectedIndex.Count() >= 2
                    try
                        sr.jumpToRowItem = m.lastSelectedIndex
                    catch e
                        LogWarn("MainScene", "SearchResults fallback jumpToRowItem failed: " + e.message)
                    end try
                    sr.SetFocus(true)
                    lsiStr = m.lastSelectedIndex[0].ToStr() + "," + m.lastSelectedIndex[1].ToStr()
                    LogInfo("MainScene", "OnVideoClose: restored focus to search results via lastSelectedIndex: " + lsiStr)
                end if
                return
            end if
        end if

        ' --- Home grid path: restore focus to the rowList using GetFocusedRowItem ---
        if m.leftNavScreen <> invalid
            ' Use GetFocusedRowItem() which reads lastGridItemIdx (set by OnGridPlay)
            ' Wrap in try/catch — callFunc return values can throw on some firmwares
            idx = invalid
            try
                idx = m.leftNavScreen.callFunc("GetFocusedRowItem")
            catch e
                LogWarn("MainScene", "GetFocusedRowItem callFunc failed: " + e.message)
            end try
            if idx <> invalid and Type(idx) = "roArray" and idx.Count() >= 2
                rl = m.leftNavScreen.FindNode("rowList")
                if rl <> invalid
                    try
                        rl.jumpToRowItem = idx
                    catch e
                        LogWarn("MainScene", "RowList jumpToRowItem failed: " + e.message)
                    end try
                    if m.focusVerifier <> invalid
                        m.focusVerifier.callFunc("RequestFocusWithVerification", rl)
                    else
                        rl.SetFocus(true)
                    end if
                    idxStr = idx[0].ToStr() + "," + idx[1].ToStr()
                    LogInfo("MainScene", "OnVideoClose: restored focus to grid rowList: " + idxStr)
                    return
                end if
            end if

            ' Last resort: try using lastSelectedIndex and the search results RowList
            sr = m.leftNavScreen.FindNode("SearchResults")
            if sr <> invalid and sr.visible and m.lastSelectedIndex <> invalid and Type(m.lastSelectedIndex) = "roArray" and m.lastSelectedIndex.Count() >= 2
                try
                    sr.jumpToRowItem = m.lastSelectedIndex
                catch e
                    LogWarn("MainScene", "SearchResults jumpToRowItem failed: " + e.message)
                end try
                sr.SetFocus(true)
                lsiStr = m.lastSelectedIndex[0].ToStr() + "," + m.lastSelectedIndex[1].ToStr()
                LogInfo("MainScene", "OnVideoClose: restored focus to search via fallback: " + lsiStr)
                return
            end if

            ' Final fallback: set focus to the home rowList
            rl = m.leftNavScreen.FindNode("rowList")
            if rl <> invalid
                if m.lastSelectedIndex <> invalid and Type(m.lastSelectedIndex) = "roArray" and m.lastSelectedIndex.Count() >= 2
                    try
                        rl.jumpToRowItem = m.lastSelectedIndex
                    catch e
                        LogWarn("MainScene", "RowList jumpToRowItem fallback failed: " + e.message)
                    end try
                end if
                if m.focusVerifier <> invalid
                    m.focusVerifier.callFunc("RequestFocusWithVerification", rl)
                else
                    rl.SetFocus(true)
                end if
                LogInfo("MainScene", "OnVideoClose: final fallback — focused rowList")
            end if
        end if
    catch e
        SafeLog("ERROR", "MainScene", "OnVideoClose failed: " + e.message)
    end try
end sub

' Handle back key - navigate back through screen stack
function OnKeyEvent (key, press) as boolean
    result = false
    try
        if press
            if LCase(key) = "back"
                result = HandleBackKey()
            end if
        end if
        if LCase(key) = "search" and press
            LogInfo("MainScene", "Search key pressed")
            TrackInteraction("search_key", "MainScene", "Search key")
            ShowSearchScreen()
            result = true
        end if
        if LCase(key) = "menu" and press
            LogInfo("MainScene", "Menu key pressed - cycling layouts")
            TrackInteraction("menu_key", "MainScene", "Layout switch")
            currentLayout = ""
            if m.configMgrReady and m.configManager <> invalid then
                currentLayout = m.configManager.callFunc("GetLayoutPreference")
            end if
            if currentLayout = "leftnav" then
                if m.configManager <> invalid then m.configManager.callFunc("SetLayoutPreference", "grid")
                ShowGridScreen()
            else
                if m.configManager <> invalid then m.configManager.callFunc("SetLayoutPreference", "leftnav")
                ShowLeftNavScreen()
            end if
            result = true
        end if
        if m.analyticsExportTimer <> invalid and m.analyticsExportTimer.TotalMilliseconds() > 300000
            m.analyticsExportTimer.Mark()
            if m.global <> invalid and m.global.analytics <> invalid
                ExportAndSend(m.global)
            end if
        end if
    catch e
        SafeLog("ERROR", "MainScene", "OnKeyEvent failed: " + e.message)
    end try
    return result
end function

' Handle BACK key: pop screen stack or focus bottom screen
function HandleBackKey () as boolean
    if m.screenStack <> invalid and m.screenStack.Count() > 1
        prevScreen = ""
        if m.screenStack.Count() > 0
            prev = m.screenStack[m.screenStack.Count() - 1]
            if prev <> invalid
                prevScreen = prev.id
            end if
        end if
        TrackScreenView("Back", prevScreen)
        if m.video <> invalid and m.screenStack[m.screenStack.Count() - 1].IsSameNode(m.video)
            m.video.control = "stop"
        else
            CloseScreen(invalid)
        end if
        return true
    else
        if m.screenStack.Count() > 0
            bottomScreen = m.screenStack[m.screenStack.Count() - 1]
            if bottomScreen <> invalid
                SetFocusSafe(bottomScreen)
            end if
        end if
        return true
    end if
end function

' Build state snapshot for the StateExporterTask
' Use CreateObject("roAssociativeArray") to avoid "Type mismatch" errors
' on firmware versions that reject object literal `{}` syntax for assocarray
' fields passed through roSGNode CallFunc.
function BuildExporterState () as object
    state = CreateObject("roAssociativeArray")
    state.locationKey = ""
    state.currentScreen = ""
    state.screenStackDepth = 0
    state.videoPlaying = false
    state.videoState = ""
    state.contentLoaded = false
    state.errorOccurred = false
    state.timestamp = GetTimestamp()

    if m.global <> invalid
        state.locationKey = ""
        try
            state.locationKey = m.global.locationKey
        catch e
            SafeLog("DEBUG", "MainScene", "locationKey field missing on global" + e.message)
        end try
        state.contentLoaded = false
        try
            state.contentLoaded = m.global.ContentLoaded
        catch e
            SafeLog("DEBUG", "MainScene", "ContentLoaded field missing on global" + e.message)
        end try
        state.errorOccurred = false
        try
            state.errorOccurred = m.global.ErrorOccurred
        catch e
            SafeLog("DEBUG", "MainScene", "ErrorOccurred field missing on global" + e.message)
        end try
    end if

    if m.screenStack <> invalid and m.screenStack.Count() > 0
        state.screenStackDepth = m.screenStack.Count()
        topNode = m.screenStack[m.screenStack.Count() - 1]
        if topNode <> invalid
            try
                screenId = topNode.id
                if screenId <> invalid and screenId <> ""
                    state.currentScreen = screenId
                end if
            catch e
                SafeLog("DEBUG", "MainScene", "topNode.id field access failed")
            end try
        end if
    end if

    if m.video <> invalid
        try
            videoState = m.video.state
            state.videoState = videoState
            state.videoPlaying = (videoState = "playing")
        catch e
            SafeLog("DEBUG", "MainScene", "m.video.state field access failed")
        end try
    end if

    ' Export deep link state for debugging — read from global node (set by main.brs)
    if m.global <> invalid then
        state.deepLinkContentId = m.global.DeepContentId
        state.deepLinkMediaType = m.global.DeepMediaType
    else
        state.deepLinkContentId = ""
        state.deepLinkMediaType = ""
    end if
    state.deepLinkProcessed = (m.deepLinkContentId <> invalid and m.deepLinkContentId <> "")

    return state
end function

' Refresh state snapshot on the StateExporterTask
sub RefreshStateExporter()
    if m.stateExporter <> invalid
        try
            m.stateExporter.CallFunc("ExportNow", { state: BuildExporterState() })
        catch e
            LogError("MainScene", "RefreshStateExporter CallFunc failed: " + e.message)
        end try
    end if
end sub

' Focus management callbacks

' Handle focus request from FocusManager
sub OnFocusRequest(focusArea as string)
    try
        LogInfo("MainScene", "Focus request for area: " + focusArea)
        if focusArea = "search" then
            if m.leftNavScreen <> invalid
                m.leftNavScreen.FocusOnNav("search")
            end if
        else if focusArea = "settings" then
            if m.leftNavScreen <> invalid
                m.leftNavScreen.FocusOnNav("settings")
            end if
        else if focusArea = "grid" then
            if m.leftNavScreen <> invalid
                rl = m.leftNavScreen.FindNode("rowList")
                if rl <> invalid then SetFocusSafe(rl)
            end if
        else if focusArea = "video" then
            if m.video <> invalid then SetFocusSafe(m.video)
        else if focusArea = "searchField" then
            if m.searchScreen <> invalid
                m.searchScreen.FocusSearchField()
            end if
        end if
    catch e
        SafeLog("ERROR", "MainScene", "OnFocusRequest failed: " + e.message)
    end try
end sub

' Handle focus clear request
sub OnFocusClear()
    LogInfo("MainScene", "Clearing focus request")
    if m.focusManager <> invalid then m.focusManager.clearFocus = false
end sub

' Handle focus verification result
sub OnFocusVerified(focusVerified as boolean)
    LogInfo("MainScene", "Focus verification result: " + Str(focusVerified))
    if not focusVerified and m.focusVerifier <> invalid
        ' Retry focus operation
        m.focusVerifier.requestVerification = true
    end if
end sub

' Handle focus verification in progress
sub OnVerifyingFocus(verifyingFocus as boolean)
    LogInfo("MainScene", "Focus verification in progress: " + Str(verifyingFocus))
end sub

' OnExit handler - cleanup resources when scene exits
sub OnExit()
    LogInfo("MainScene", "OnExit: Cleaning up resources")

    ' Stop analytics export timer
    if m.analyticsExportTimer <> invalid
        m.analyticsExportTimer.control = "stop"
        m.analyticsExportTimer = invalid
    end if

    ' Stop state exporter task
    if m.stateExporter <> invalid
        m.stateExporter.control = "stop"
        m.stateExporter = invalid
    end if

    ' Stop heartbeat timer
    if m.heartbeatTimer <> invalid
        m.heartbeatTimer.UnobserveField("fire")
        m.heartbeatTimer.control = "stop"
        m.heartbeatTimer = invalid
    end if

    ' Clean up video
    if m.video <> invalid
        try
            m.video.UnobserveField("close")
            m.video.UnobserveField("state")
        catch e
            LogError("MainScene", "Error unobserving video on exit: " + e.message)
        end try
        m.video = invalid
    end if

    ' Clean up search screen
    if m.searchScreen <> invalid
        try
            m.searchScreen.UnobserveField("close")
            m.searchScreen.UnobserveField("play")
        catch e
            LogError("MainScene", "Error unobserving search screen on exit: " + e.message)
        end try
        m.searchScreen = invalid
    end if

    ' Clean up left nav screen
    if m.leftNavScreen <> invalid
        try
            m.leftNavScreen.UnobserveField("close")
            m.leftNavScreen.UnobserveField("play")
            m.leftNavScreen.UnobserveField("layoutToggle")
        catch e
            LogError("MainScene", "Error unobserving left nav screen on exit: " + e.message)
        end try
        m.leftNavScreen = invalid
    end if

    ' Clean up focus manager observers
    if m.focusManager <> invalid
        try
            m.focusManager.UnobserveField("requestFocus")
            m.focusManager.UnobserveField("clearFocus")
        catch e
            LogError("MainScene", "Error unobserving focus manager on exit: " + e.message)
        end try
    end if

    ' Clean up focus verifier observers
    if m.focusVerifier <> invalid
        try
            m.focusVerifier.UnobserveField("focusVerified")
            m.focusVerifier.UnobserveField("verifyingFocus")
        catch e
            LogError("MainScene", "Error unobserving focus verifier on exit: " + e.message)
        end try
    end if

    ' Clean up deep link and retry button observers
    try
        m.top.UnobserveField("deeplinkContentId")
    catch e
        LogError("MainScene", "Error unobserving deeplinkContentId on exit: " + e.message)
    end try
    if m.retryButton <> invalid
        try
            m.retryButton.UnobserveField("select")
        catch e
            LogError("MainScene", "Error unobserving retry button on exit: " + e.message)
        end try
    end if

    ' Reset global state
    if m.global <> invalid
        m.global.ErrorOccurred = false
        m.global.CloseChannel = false
    end if

    LogInfo("MainScene", "OnExit: Cleanup complete")
end sub


' Periodic heartbeat export
sub OnHeartbeatTimer()
    try
        SafeLog("INFO", "MainScene", "Heartbeat timer fired - exporting telemetry")
        HeartbeatExport()
        SafeLog("INFO", "MainScene", "Heartbeat export completed")
    catch e
        SafeLog("ERROR", "MainScene", "Heartbeat export failed: " + e.message)
    end try
end sub
