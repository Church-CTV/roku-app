' ConfigManager.brs - Runtime configuration access component
' Loads config and exposes it as observed SG fields for binding

sub Init()
    try
        m.top.configLoaded = false
        m.top.configError = ""
        ' Load configuration synchronously so it is ready before MainScene.Init runs
        LoadAndApplyConfig()
    catch e
        LogError("ConfigManager", "Init: " + e.message)
    end try
end sub

sub LoadAndApplyConfig()
    try
        LogInfo("ConfigManager", "Loading configuration")

        config = LoadConfig("pkg:/config/default.json")
        if config = invalid
            m.top.configError = "Failed to load configuration"
            m.top.configLoaded = false
            return
        end if

        ' Store config as JSON string for access
        m.top.config = FormatJson(config)

        if config.DoesExist("channel")
            if config.channel.DoesExist("name")
                m.top.channelName = config.channel.name
            else
                m.top.channelName = ""
            end if
            if config.DoesExist("version")
                m.top.channelVersion = config.version
            else
                m.top.channelVersion = ""
            end if
            if config.channel.DoesExist("language")
                m.top.channelLanguage = config.channel.language
            else
                m.top.channelLanguage = "en"
            end if
        end if

        if config.DoesExist("branding") and config.branding.DoesExist("colors")
            colors = config.branding.colors
            if colors.DoesExist("background")
                m.top.bgColor = colors.background
            else
                m.top.bgColor = "0x1A1A2E"
            end if
            if colors.DoesExist("surface")
                m.top.surfaceColor = colors.surface
            else
                m.top.surfaceColor = "0x16213E"
            end if
            if colors.DoesExist("accent")
                m.top.accentColor = colors.accent
            else
                m.top.accentColor = "0xE8B931"
            end if
            if colors.DoesExist("textPrimary")
                m.top.textPrimary = colors.textPrimary
            else
                m.top.textPrimary = "0xFFFFFF"
            end if
            if colors.DoesExist("textSecondary")
                m.top.textSecondary = colors.textSecondary
            else
                m.top.textSecondary = "0xA0A0B0"
            end if
            if colors.DoesExist("focus")
                m.top.focusColor = colors.focus
            else
                m.top.focusColor = "0xE8B931"
            end if
            if colors.DoesExist("error")
                m.top.errorColor = colors.error
            else
                m.top.errorColor = "0xFF4444"
            end if
        end if

        if config.DoesExist("branding") and config.branding.DoesExist("images")
            images = config.branding.images
            if images.DoesExist("overhangLogo")
                m.top.overhangLogoUri = images.overhangLogo
            else
                m.top.overhangLogoUri = "pkg:/images/hd_overhang_logo.png"
            end if
            if images.DoesExist("backgroundImage")
                m.top.backgroundImageUri = images.backgroundImage
            else
                m.top.backgroundImageUri = "pkg:/images/background.png"
            end if
            if images.DoesExist("iconFocus")
                m.top.iconFocusUri = images.iconFocus
            else
                m.top.iconFocusUri = "pkg:/images/icon_focus_hd.png"
            end if
        end if

        if config.DoesExist("features")
            features = config.features
            if features.DoesExist("search")
                m.top.featureSearch = features.search
            else
                m.top.featureSearch = true
            end if
            if features.DoesExist("deepLinking")
                m.top.featureDeepLinking = features.deepLinking
            else
                m.top.featureDeepLinking = true
            end if
            if features.DoesExist("analytics")
                m.top.featureAnalytics = features.analytics
            else
                m.top.featureAnalytics = true
            end if
            if features.DoesExist("crashReporting")
                m.top.featureCrashReporting = features.crashReporting
            else
                m.top.featureCrashReporting = true
            end if
            if features.DoesExist("overhangLogo")
                m.top.featureOverhangLogo = features.overhangLogo
            else
                m.top.featureOverhangLogo = true
            end if
            if features.DoesExist("overhangClock")
                m.top.featureOverhangClock = features.overhangClock
            else
                m.top.featureOverhangClock = true
            end if
            if features.DoesExist("overhangOptions")
                m.top.featureOverhangOptions = features.overhangOptions
            else
                m.top.featureOverhangOptions = true
            end if
            if features.DoesExist("layoutPreference")
                m.top.layoutPreference = features.layoutPreference
            else
                m.top.layoutPreference = "leftnav"
            end if
        end if

        if config.DoesExist("content")
            content = config.content
            if content.DoesExist("sourceUrl")
                m.top.contentSourceUrl = content.sourceUrl
            else
                m.top.contentSourceUrl = ""
            end if
            if content.DoesExist("userAgent")
                m.top.contentUserAgent = content.userAgent
            else
                m.top.contentUserAgent = "Roku/Template"
            end if
            if content.DoesExist("maxRows")
                m.top.contentMaxRows = content.maxRows
            else
                m.top.contentMaxRows = 6
            end if
            if content.DoesExist("maxItemsPerRow")
                m.top.contentMaxItemsPerRow = content.maxItemsPerRow
            else
                m.top.contentMaxItemsPerRow = 12
            end if
            if content.DoesExist("retryAttempts")
                m.top.contentRetryAttempts = content.retryAttempts
            else
                m.top.contentRetryAttempts = 3
            end if
            if content.DoesExist("retryDelayMs")
                m.top.contentRetryDelayMs = content.retryDelayMs
            else
                m.top.contentRetryDelayMs = 2000
            end if
        end if

        if config.DoesExist("ui")
            ui = config.ui
            if ui.DoesExist("backgroundColor")
                m.top.uiBackgroundColor = ui.backgroundColor
            else
                m.top.uiBackgroundColor = "0x1A1A2E"
            end if
            if ui.DoesExist("welcome") and ui.welcome <> invalid
                if ui.welcome.DoesExist("title")
                    m.top.uiWelcomeTitle = ui.welcome.title
                else
                    m.top.uiWelcomeTitle = "Loading..."
                end if
                if ui.welcome.DoesExist("subtitle")
                    m.top.uiWelcomeSubtitle = ui.welcome.subtitle
                else
                    m.top.uiWelcomeSubtitle = "Please wait"
                end if
            end if
            if ui.DoesExist("error") and ui.error <> invalid
                if ui.error.DoesExist("title")
                    m.top.uiErrorTitle = ui.error.title
                else
                    m.top.uiErrorTitle = "Connection Error"
                end if
                if ui.error.DoesExist("message")
                    m.top.uiErrorMessage = ui.error.message
                else
                    m.top.uiErrorMessage = "Unable to load content."
                end if
                if ui.error.DoesExist("retryLabel")
                    m.top.uiRetryLabel = ui.error.retryLabel
                else
                    m.top.uiRetryLabel = "Retry"
                end if
            end if
            if ui.DoesExist("loading") and ui.loading <> invalid
                if ui.loading.DoesExist("message")
                    m.top.uiLoadingMessage = ui.loading.message
                else
                    m.top.uiLoadingMessage = "Loading..."
                end if
            end if
        end if

        if config.DoesExist("analytics")
            analytics = config.analytics
            if analytics.DoesExist("exportUrl") and analytics.exportUrl <> invalid
                m.top.analyticsExportUrl = analytics.exportUrl
            else
                m.top.analyticsExportUrl = ""
            end if
            if analytics.DoesExist("exportIntervalSeconds")
                m.top.analyticsExportIntervalSeconds = analytics.exportIntervalSeconds
            else
                m.top.analyticsExportIntervalSeconds = 300
            end if
        end if

        if config.DoesExist("cardStyle")
            cardStyle = config.cardStyle
            if cardStyle.DoesExist("showTitle")
                m.top.cardShowTitle = cardStyle.showTitle
            else
                m.top.cardShowTitle = true
            end if
            if cardStyle.DoesExist("showDescription")
                m.top.cardShowDescription = cardStyle.showDescription
            else
                m.top.cardShowDescription = true
            end if
            if cardStyle.DoesExist("titleFont")
                m.top.cardTitleFont = cardStyle.titleFont
            else
                m.top.cardTitleFont = "font:SmallBoldSystemFont"
            end if
            if cardStyle.DoesExist("descriptionFont")
                m.top.cardDescriptionFont = cardStyle.descriptionFont
            else
                m.top.cardDescriptionFont = "font:SmallSystemFont"
            end if
            if cardStyle.DoesExist("titleColor")
                m.top.cardTitleColor = cardStyle.titleColor
            else
                m.top.cardTitleColor = "0xFFFFFF"
            end if
            if cardStyle.DoesExist("descriptionColor")
                m.top.cardDescriptionColor = cardStyle.descriptionColor
            else
                m.top.cardDescriptionColor = "0xA0A0B0"
            end if
            if cardStyle.DoesExist("titleNumLines")
                m.top.cardTitleNumLines = cardStyle.titleNumLines
            else
                m.top.cardTitleNumLines = 1
            end if
            if cardStyle.DoesExist("descriptionNumLines")
                m.top.cardDescriptionNumLines = cardStyle.descriptionNumLines
            else
                m.top.cardDescriptionNumLines = 1
            end if
            if cardStyle.DoesExist("showDetailTitle")
                m.top.detailShowTitle = cardStyle.showDetailTitle
            else
                m.top.detailShowTitle = true
            end if
            if cardStyle.DoesExist("showDetailDescription")
                m.top.detailShowDescription = cardStyle.showDetailDescription
            else
                m.top.detailShowDescription = true
            end if
            if cardStyle.DoesExist("detailTitleFont")
                m.top.detailTitleFont = cardStyle.detailTitleFont
            else
                m.top.detailTitleFont = "font:SmallBoldSystemFont"
            end if
            if cardStyle.DoesExist("detailDescriptionFont")
                m.top.detailDescriptionFont = cardStyle.detailDescriptionFont
            else
                m.top.detailDescriptionFont = "font:SmallSystemFont"
            end if
            if cardStyle.DoesExist("detailTitleColor")
                m.top.detailTitleColor = cardStyle.detailTitleColor
            else
                m.top.detailTitleColor = "0xFFFFFF"
            end if
            if cardStyle.DoesExist("detailDescriptionColor")
                m.top.detailDescriptionColor = cardStyle.detailDescriptionColor
            else
                m.top.detailDescriptionColor = "0xA0A0B0"
            end if
            if cardStyle.DoesExist("detailTitleNumLines")
                m.top.detailTitleNumLines = cardStyle.detailTitleNumLines
            else
                m.top.detailTitleNumLines = 1
            end if
            if cardStyle.DoesExist("detailDescriptionNumLines")
                m.top.detailDescriptionNumLines = cardStyle.detailDescriptionNumLines
            else
                m.top.detailDescriptionNumLines = 3
            end if
        else
            m.top.cardShowTitle = true
            m.top.cardShowDescription = true
            m.top.cardTitleFont = "font:SmallBoldSystemFont"
            m.top.cardDescriptionFont = "font:SmallSystemFont"
            m.top.cardTitleColor = "0xFFFFFF"
            m.top.cardDescriptionColor = "0xA0A0B0"
            m.top.cardTitleNumLines = 1
            m.top.cardDescriptionNumLines = 1
            m.top.detailShowTitle = true
            m.top.detailShowDescription = true
            m.top.detailTitleFont = "font:SmallBoldSystemFont"
            m.top.detailDescriptionFont = "font:SmallSystemFont"
            m.top.detailTitleColor = "0xFFFFFF"
            m.top.detailDescriptionColor = "0xA0A0B0"
            m.top.detailTitleNumLines = 1
            m.top.detailDescriptionNumLines = 3
        end if

        if config.DoesExist("giving")
            givingConfig = config.giving
            if givingConfig.DoesExist("donationUrl") and givingConfig.donationUrl <> ""
                m.top.givingDonationUrl = givingConfig.donationUrl
            else
                m.top.givingDonationUrl = "https://example.invalid/giving"
            end if
        else
            m.top.givingDonationUrl = "https://example.invalid/giving"
        end if

        ' Load live stream URL from branding images
        if config.DoesExist("branding") and config.branding.DoesExist("images")
            images = config.branding.images
            if images.DoesExist("liveStreamUrl") and images.liveStreamUrl <> ""
                m.top.liveStreamUrl = images.liveStreamUrl
            else
                m.top.liveStreamUrl = ""
            end if
            if images.DoesExist("liveStreamThumbnail") and images.liveStreamThumbnail <> ""
                m.top.liveStreamThumbnail = images.liveStreamThumbnail
            else
                m.top.liveStreamThumbnail = ""
            end if
        else
            m.top.liveStreamUrl = ""
            m.top.liveStreamThumbnail = ""
        end if

        ValidateConfigUrls(config)
        m.top.configLoaded = true

        ' Config is already stored on m.top.config (line 26)
        ' Do NOT set m.global.config — roSGNode does not support assocarray fields at runtime
        ' Other code accesses config via m.top.FindNode("configManager").config

        LogInfo("ConfigManager", "Configuration loaded and applied successfully")
    catch e
        m.top.configError = "Failed to apply configuration: " + e.message
        m.top.configLoaded = false
        LogError("ConfigManager", "LoadAndApplyConfig: " + e.message)
    end try
end sub

sub OnConfigChanged()
    ' Field-level change hook (intentionally quiet to avoid log spam during bulk load)
end sub

sub OnCardStyleChanged()
    ' Signal that card style has changed so listeners can re-apply
    ' (harmless if no one is listening yet — fires before GridScreen exists)
end sub

sub ApplyRemoteCardStyle(remoteStyle)
    try
        if remoteStyle = invalid or Type(remoteStyle) <> "roAssociativeArray"
            LogInfo("ConfigManager", "No remote cardStyle to apply")
            return
        end if

        LogInfo("ConfigManager", "Applying remote cardStyle from feed")

        fields = [
            "showTitle", "showDescription",
            "titleFont", "descriptionFont",
            "titleColor", "descriptionColor",
            "titleNumLines", "descriptionNumLines",
            "showDetailTitle", "showDetailDescription",
            "detailTitleFont", "detailDescriptionFont",
            "detailTitleColor", "detailDescriptionColor",
            "detailTitleNumLines", "detailDescriptionNumLines"
        ]

        applied = 0
        for each field in fields
            if remoteStyle.DoesExist(field)
                val = remoteStyle[field]
                fieldName = GetCardStyleFieldName(field)
                if NodeHasField(m.top, fieldName)
                    m.top[fieldName] = val
                    applied = applied + 1
                end if
            end if
        end for

        LogInfo("ConfigManager", "Applied " + applied.ToStr() + " remote cardStyle fields")
    catch e
        LogError("ConfigManager", "ApplyRemoteCardStyle: " + e.message)
    end try
end sub

sub ApplyRemoteGivingConfig(remoteGiving as object)
    try
        if remoteGiving = invalid or Type(remoteGiving) <> "roAssociativeArray"
            LogInfo("ConfigManager", "No remote giving config to apply")
            return
        end if
        if remoteGiving.DoesExist("donationUrl") and remoteGiving.donationUrl <> ""
            m.top.givingDonationUrl = remoteGiving.donationUrl
            LogInfo("ConfigManager", "Applied remote giving donationUrl: " + remoteGiving.donationUrl)
        end if
    catch e
        LogError("ConfigManager", "ApplyRemoteGivingConfig: " + e.message)
    end try
end sub

' Map remote cardStyle field names to ConfigManager field names.
' The ConfigManager XML fields use camelCase: "cardShowTitle", "detailTitleFont", etc.
' Remote feed fields: "showTitle", "detailTitleFont", "showDetailTitle", etc.
' Rules:
'   1. Field already starts with "detail" (e.g., "detailTitleFont") -> pass through unchanged
'   2. Field contains "detail" or "Detail" elsewhere (e.g., "showDetailTitle") -> prefix with "detail"
'   3. All other fields (e.g., "showTitle") -> prefix with "card"
' NOTE: BrightScript InStr() returns 1-based position when found, 0 when NOT found.
' It NEVER returns -1. Check > 0 (not <> -1) to avoid always-true conditions.
function GetCardStyleFieldName (remoteField) as string
    if remoteField.InStr("detail") > 0 and remoteField.Left(6) = "detail"
        return remoteField
    end if
    if remoteField.InStr("detail") > 0 or remoteField.InStr("Detail") > 0
        return "detail" + UCase(remoteField.Mid(1, 1)) + remoteField.Mid(2)
    end if
    firstChar = UCase(remoteField.Left(1))
    rest = remoteField.Mid(2)
    return "card" + firstChar + rest
end function

' Get the current layout preference
function GetLayoutPreference () as string
    if m.top.layoutPreference <> invalid and m.top.layoutPreference <> "" then
        return m.top.layoutPreference
    end if
    return "leftnav"
end function

' Get config as associative array
function GetConfig () as object
    if m.top.config <> invalid and m.top.config <> ""
        try
            return ParseJson(m.top.config)
        catch e
            LogError("ConfigManager", "Failed to parse config JSON: " + e.message)
        end try
    end if
    return invalid
end function

' Set the layout preference
sub SetLayoutPreference(layout as string)
    if layout <> invalid and layout <> "" then
        m.top.layoutPreference = layout
        LogInfo("ConfigManager", "Layout preference set to: " + layout)
    else
        LogError("ConfigManager", "Invalid layout preference: " + StrI(layout))
    end if
end sub

sub ValidateConfigUrls(config)
    urls = [
        { name: "analytics.exportUrl", value: "" },
        { name: "server.baseUrl", value: "" }
    ]

    if config.DoesExist("analytics")
        if config.analytics.DoesExist("exportUrl")
            urls[0].value = config.analytics.exportUrl
        end if
    end if
    if config.DoesExist("server") and config.server <> invalid
        if config.server.DoesExist("baseUrl")
            urls[1].value = config.server.baseUrl
        end if
    end if

    for i = 0 to urls.Count() - 1
        entry = urls[i]
        val = entry.value
        if val <> "" and (InStr(val, "PLACEHOLDER") > 0 or InStr(val, "localhost") > 0)
            LogWarn("ConfigManager", "Misconfigured URL detected: " + entry.name + " = " + val + " - feature will be disabled until valid URL is set")
        end if
    end for
end sub
