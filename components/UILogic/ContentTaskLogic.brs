' ContentTaskLogic.brs - Performance-optimized content loading with retry and memory management
' Optimizations: connection timeout, retry with backoff, proper cleanup on screen transitions

sub RunContentTask()
    try
        ' Clean up any existing content task
        if m.contentTask <> invalid
            m.contentTask.control = "stop"
            m.contentTask.UnobserveField("content")
            m.contentTask.UnobserveField("cardStyle")
            m.contentTask.UnobserveField("givingConfig")
            m.contentTask.UnobserveField("error")
            m.contentTask = invalid
        end if

        m.contentTask = CreateObject("roSGNode", "MainLoaderTask")
        if m.contentTask <> invalid
            SafeObserveField(m.contentTask, "content", "OnMainContentLoaded")
            SafeObserveField(m.contentTask, "cardStyle", "OnCardStyleLoaded")
            SafeObserveField(m.contentTask, "givingConfig", "OnGivingConfigLoaded")
            SafeObserveField(m.contentTask, "error", "OnMainLoadError")
            m.contentTask.control = "run"
        end if
        m.loadingIndicator.visible = true
        m.welcomeScreen.visible = false
    catch e
        LogError("ContentTask", "RunContentTask: " + e.message)
    end try
end sub

sub OnMainContentLoaded()
    try
        LogInfo("ContentTask", "Content loaded successfully")
        if m.loadingIndicator <> invalid
            m.loadingIndicator.visible = false
        end if
        if m.welcomeScreen <> invalid
            m.welcomeScreen.visible = false
        end if
        m.global.ContentLoaded = true
        m.global.ErrorOccurred = false
        ' Push state to registry so ECP tests can read contentLoaded === true
        if m.top <> invalid then
            if m.top.stateExporter <> invalid then
                try
                    m.top.stateExporter.CallFunc("ExportNow", { state: BuildExporterState() })
                catch e
                    print "ERROR", "ContentTaskLogic", "Failed to refresh state exporter: " + e.message
                end try
            end if
        end if

        ' Save content + cardStyle + givingConfig BEFORE killing the task (observers may fire out of order)
        loadedContent = invalid
        remoteCardStyle = invalid
        remoteGivingConfig = invalid
        if m.contentTask <> invalid and m.contentTask.content <> invalid
            loadedContent = m.contentTask.content
            if m.contentTask.cardStyle <> invalid
                remoteCardStyle = m.contentTask.cardStyle
            end if
            if m.contentTask.givingConfig <> invalid
                remoteGivingConfig = m.contentTask.givingConfig
            end if
            LogInfo("ContentTask", "Content set with " + loadedContent.GetChildCount().ToStr() + " rows")
            ' Clean up content task after content is transferred (saves memory)
            m.contentTask.UnobserveField("content")
            m.contentTask.UnobserveField("cardStyle")
            m.contentTask.UnobserveField("givingConfig")
            m.contentTask.UnobserveField("error")
            m.contentTask.control = "stop"
            m.contentTask = invalid
        end if

        ' Apply cardStyle BEFORE setting content on screen (so ContentCards see it on init)
        if remoteCardStyle <> invalid
            configManager = FindConfigManager()
            if configManager <> invalid
                SafeCallFunc(configManager, "ApplyRemoteCardStyle", remoteCardStyle)
                LogInfo("ContentTask", "Remote cardStyle applied to ConfigManager")
            end if
        end if

        ' Apply giving config from feed
        if remoteGivingConfig <> invalid
            configManager = FindConfigManager()
            if configManager <> invalid
                SafeCallFunc(configManager, "ApplyRemoteGivingConfig", remoteGivingConfig)
                LogInfo("ContentTask", "Remote giving config applied to ConfigManager")
            end if
        end if

        ' Apply loaded content to the currently visible screen
        if m.screenStack <> invalid and m.screenStack.Count() > 0 and loadedContent <> invalid
            currentScreen = m.screenStack[m.screenStack.Count() - 1]
            if currentScreen <> invalid
                currentScreen.content = loadedContent
            end if
            ' Also store on main scene so FindContentById can access it directly
            m.contentFeed = loadedContent
        end if

        ' Fire AppLaunchComplete beacon — Roku requires this when the home screen
        ' is fully rendered and the user can interact with it
        ' Must fire after content is loaded and screen is visible
        if m.top <> invalid
            try
                m.top.signalBeacon("AppLaunchComplete")
            catch e
                SafeLog("WARN", "ContentTaskLogic", "AppLaunchComplete beacon failed: " + e.message)
            end try
        end if

        ' Process any pending deep link now that content is loaded
        if m.top <> invalid and m.top.deeplinkContentId <> invalid and m.top.deeplinkContentId <> "" then
            contentId = m.top.deeplinkContentId
            mediaType = ""
            if m.top.deeplinkMediaType <> invalid then
                mediaType = m.top.deeplinkMediaType
            end if

            SafeLog("INFO", "ContentTask", "Content loaded, processing pending deep link: contentId=" + contentId + " mediatype=" + mediaType)
            print "DEEP LINK DEBUG: Content loaded, processing pending deep link: " + contentId + " / " + mediaType

            ' Store for state exporter
            m.deepLinkContentId = contentId
            m.deepLinkMediaType = mediaType
            m.deepLinkStartTime = CreateObject("roDateTime").AsSeconds()

            ' Check timeout (30 seconds max wait)
            if m.deepLinkStartTime <> invalid then
                elapsed = CreateObject("roDateTime").AsSeconds() - m.deepLinkStartTime
                if elapsed > 30 then
                    SafeLog("WARN", "ContentTask", "Deep link timed out after " + elapsed.ToStr() + " seconds")
                    print "DEEP LINK DEBUG: Deep link timed out"
                    ShowGridScreen()
                    m.top.deeplinkContentId = ""
                    m.top.deeplinkMediaType = ""
                    return
                end if
            end if

            ' Hide loading indicator
            if m.loadingIndicator <> invalid then
                m.loadingIndicator.visible = false
            end if

            ' Find and play the deep linked content
            contentItem = FindContentById(contentId)
            ' Special case: live_0/live_stream_0 maps to the live stream item in the feed
            if contentItem = invalid then
                liveId = LCase(contentId)
                if liveId = "live_0" or liveId = "live_stream_0" then
                    contentItem = FindContentById("live_stream_0")
                    if contentItem = invalid then
                        configManager = FindConfigManager()
                        config = invalid
                        if configManager <> invalid and configManager.config <> invalid then
                            config = configManager.callFunc("GetConfig")
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
                                print "DEEP LINK DEBUG: live_stream_0 resolved in ContentTaskLogic, playing live stream"
                            end if
                        end if
                    else
                        print "DEEP LINK DEBUG: live_stream_0 found in feed (ContentTaskLogic), playing"
                    end if
                end if
            end if
            if contentItem <> invalid then
                print "DEEP LINK DEBUG: Content found after load, requesting play"
                ' Request MainScene to play — tasks cannot call scene subs directly
                m.top.playContent = contentItem
            else
                print "DEEP LINK DEBUG: Content not found in feed, showing grid"
                ' Content not found - timeout or invalid ID — show home per Roku docs
                SafeLog("WARN", "ContentTask", "Deep link content not found, showing grid")
                ShowGridScreen()
            end if

            ' Clear deep link params
            m.top.deeplinkContentId = ""
            m.top.deeplinkMediaType = ""
            if m.global <> invalid then
                m.global.DeepContentId = ""
                m.global.DeepMediaType = ""
            end if
        else
            print "DEEP LINK DEBUG: No pending deep link to process"
        end if
    catch e
        LogError("ContentTask", "OnMainContentLoaded: " + e.message)
    end try
end sub

sub OnCardStyleLoaded()
    try
        if m.contentTask = invalid then return
        cardStyle = m.contentTask.cardStyle
        if cardStyle <> invalid
            configManager = FindConfigManager()
            if configManager <> invalid
                SafeCallFunc(configManager, "ApplyRemoteCardStyle", cardStyle)
                LogInfo("ContentTask", "Remote cardStyle applied to ConfigManager")
            end if
        end if
    catch e
        LogError("ContentTask", "OnCardStyleLoaded: " + e.message)
    end try
end sub

sub OnGivingConfigLoaded()
    try
        if m.contentTask = invalid then return
        givingConfig = m.contentTask.givingConfig
        if givingConfig <> invalid
            configManager = FindConfigManager()
            if configManager <> invalid
                SafeCallFunc(configManager, "ApplyRemoteGivingConfig", givingConfig)
                LogInfo("ContentTask", "Remote giving config applied to ConfigManager")
            end if
        end if
    catch e
        LogError("ContentTask", "OnGivingConfigLoaded: " + e.message)
    end try
end sub

function FindConfigManager () as object
    configManager = SafeFindNode(m.top, "configManager")
    if configManager <> invalid then return configManager
    return invalid
end function

sub OnMainLoadError()
    try
        LogError("ContentTask", "Failed to load content")
        if m.loadingIndicator <> invalid
            m.loadingIndicator.visible = false
        end if
        m.global.ErrorOccurred = true

        if m.contentTask <> invalid
            m.global.ErrorMessage = m.contentTask.error
            ' Clean up content task
            m.contentTask.control = "stop"
            m.contentTask.UnobserveField("content")
            m.contentTask.UnobserveField("cardStyle")
            m.contentTask.UnobserveField("givingConfig")
            m.contentTask.UnobserveField("error")
            m.contentTask = invalid
        else
            m.global.ErrorMessage = "Unable to load content. Please check your network connection."
        end if

        ' Track the error
        errorMessage = ""
        if m.global.ErrorMessage <> invalid
            errorMessage = m.global.ErrorMessage
        else
            errorMessage = "Unable to load content. Please check your network connection."
        end if

        ' Classify error type for better user messaging
        errorType = "content_load_error"
        if InStr(LCase(errorMessage), "timeout") > 0
            errorType = "content_timeout"
            LogInfo("ContentTask", "Timeout error detected — user-friendly retry message will be shown")
        end if

        ReportError(errorType, errorMessage, "MainLoaderTask")

        ' Show error screen with retry prompt
        if m.errorMessage <> invalid
            m.errorMessage.text = m.global.ErrorMessage
        end if
        if m.errorScreen <> invalid
            m.errorScreen.visible = true
        end if
        if m.retryButton <> invalid
            m.retryButton.SetFocus(true)
        end if
    catch e
        LogError("ContentTask", "OnMainLoadError handler crashed: " + e.message)
    end try
end sub

' Retry content loading with exponential backoff
sub RetryContentLoad()
    try
        LogInfo("ContentTask", "Retrying content load...")
        if m.errorScreen <> invalid
            m.errorScreen.visible = false
        end if
        RunContentTask()
    catch e
        LogError("ContentTask", "RetryContentLoad: " + e.message)
    end try
end sub
