' main.brs - Entry point for Roku channel template
' ********** Copyright 2020 Roku Corp.  All Rights Reserved. **********
' All critical paths wrapped with safety guards for crash-proof operation

sub Main(args as dynamic)
    SafeLog("INFO", "main", "Starting Roku channel")

    try
        ' Create the SceneGraph screen and message port
        screen = CreateObject("roSGScreen")
        if screen = invalid
            SafeLog("ERROR", "main", "FATAL: Failed to create roSGScreen")
            return
        end if
        port = CreateObject("roMessagePort")
        if port <> invalid
            screen.SetMessagePort(port)
        end if
    catch e
        SafeLog("ERROR", "main", "Failed to create screen/port: " + e.message)
        return
    end try

    try
        ' Get the shared global node and add custom fields.
        m.global = screen.getGlobalNode()
        if m.global <> invalid
            appVersion = ""
            appInfo = CreateObject("roAppInfo")
            if appInfo <> invalid
                appVersion = appInfo.GetVersion()
            end if
            if appVersion = "" then appVersion = "0.0.1"
            m.global.addFields({
                startupArgs: "",
                DeepContentId: "",
                DeepMediaType: "",
                DeepNav: "",
                AppVersion: appVersion,
                ContentLoaded: false,
                ErrorOccurred: false,
                ErrorMessage: "",
                CloseChannel: false,
                locationKey: ""
            })
            m.global.startupArgs = FormatJson(args)
        end if
    catch e
        SafeLog("ERROR", "main", "Global node initialization failed: " + e.message)
    end try

    try
        ' Handle deep linking parameters if present.
        ' Roku normalizes URL query params to lowercase, so args may contain:
        '   { contentid: "X", mediatype: "Y" }  (all lowercase)
        ' or mixed casing depending on the launch source.
        ' Check each param independently for all common casings.
        deepContentId = invalid
        deepMediaType = invalid

        ' Resolve contentId from any casing variant (Roku ECP preserves URL casing)
        contentIdKeys = ["ContentId", "contentid", "contentId", "contentID", "ContentID", "CONTENTID"]
        deepContentId = invalid
        for each key in contentIdKeys
            if args[key] <> invalid
                deepContentId = args[key]
                exit for
            end if
        end for

        ' Resolve mediaType from any casing variant
        mediaTypeKeys = ["MediaType", "mediatype", "mediaType", "mediaType", "MEDIATYPE", "mediatype"]
        deepMediaType = invalid
        for each key in mediaTypeKeys
            if args[key] <> invalid
                deepMediaType = args[key]
                exit for
            end if
        end for
        if deepContentId <> invalid and deepMediaType <> invalid then
            if m.global <> invalid
                m.global.DeepContentId = deepContentId
                m.global.DeepMediaType = deepMediaType
            end if
            SafeLog("INFO", "main", "Deep link args received: " + deepContentId + " / " + deepMediaType)
            ' Also log to console for debugging
            print "DEEP LINK DEBUG: ContentId=" + deepContentId + " MediaType=" + deepMediaType
        else
            SafeLog("INFO", "main", "No deep link args found in launch parameters")
            print "DEEP LINK DEBUG: No deep link args found"
            if m.global <> invalid
                print "DEEP LINK DEBUG: startupArgs=" + m.global.startupArgs
            end if
        end if
    catch e
        SafeLog("ERROR", "main", "Deep link parameter handling failed: " + e.message)
    end try

    try
        ' Create and show the main scene
        scene = screen.CreateScene("MainScene")
        if scene <> invalid
            scene.global = m.global
            ' Set deep link interface fields so MainScene picks them up via observer
            if deepContentId <> invalid then scene.deeplinkContentId = deepContentId
            if deepMediaType <> invalid then scene.deeplinkMediaType = deepMediaType
        end if
        screen.Show()
        'vscode_rdb_on_device_component_entry
        SafeLog("INFO", "main", "Scene created, entering event loop")
    catch e
        SafeLog("ERROR", "main", "Failed to create/show scene: " + e.message)
        return
    end try

    ' Create roInput for runtime deep link handling (supports_input_launch=1 in manifest)
    try
        m.input = CreateObject("roInput")
        if m.input <> invalid then
            m.input.EnableTransportEvents(true)
        end if
    catch e
        SafeLog("WARN", "main", "roInput not available on this firmware: " + e.message)
    end try

    ' Event loop — uses 100ms timeout on wait so we can poll CloseChannel flag
    while true
        msg = wait(100, port)
        if type(msg) = "roSGScreenEvent" then
            if msg.IsScreenClosed() then
                try
                    AnalyticsOnAppExit(m.global)
                catch e
                    SafeLog("ERROR", "main", "AnalyticsOnAppExit failed: " + e.message)
                end try
                SafeLog("INFO", "main", "Screen closed, exiting")
                return
            end if
        end if

        ' Handle runtime deep links via roInputEvent (voice commands, ECP /input)
        if type(msg) = "roInputEvent" and msg <> invalid then
            if msg.IsInput() then
                info = msg.GetInfo()
                if info <> invalid and info.DoesExist("mediatype") and info.DoesExist("contentid") then
                    mediaType = info.mediatype
                    contentId = info.contentid

                    SafeLog("INFO", "main", "Runtime deep link: contentId=" + contentId + " mediaType=" + mediaType)
                    print "DEEP LINK DEBUG: Runtime deep link received: " + contentId + " / " + mediaType

                    if m.global <> invalid then
                        m.global.DeepContentId = contentId
                        m.global.DeepMediaType = mediaType
                        ' Notify MainScene to process via interface field observer
                        if scene <> invalid then
                            scene.deeplinkContentId = contentId
                            scene.deeplinkMediaType = mediaType
                        end if
                    end if

                    ' Acknowledge the input event
                    if m.input <> invalid then
                        m.input.EventResponse(info)
                    end if
                end if
            end if
        end if

        ' Poll exit flag — works even when debugger consumes port events
        if m.global <> invalid and m.global.CloseChannel = true then
            SafeLog("INFO", "main", "CloseChannel=true, exiting")
            try
                AnalyticsOnAppExit(m.global)
            catch e
                SafeLog("ERROR", "main", "AnalyticsOnAppExit failed: " + e.message)
            end try
            return
        end if
    end while
end sub
