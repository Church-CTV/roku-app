sub Init()
    try
        m.settingsTitle = SafeFindNode(m.top, "settingsTitle")
        m.channelNameLabel = SafeFindNode(m.top, "channelNameLabel")
        m.channelVersionLabel = SafeFindNode(m.top, "channelVersionLabel")
        m.contentSourceLabel = SafeFindNode(m.top, "contentSourceLabel")
        m.layoutToggleRow = SafeFindNode(m.top, "layoutToggleRow")
        m.layoutToggleValue = SafeFindNode(m.top, "layoutToggleValue")

        m.featureSearchValue = SafeFindNode(m.top, "featureSearchValue")
        m.featureDeepLinkingValue = SafeFindNode(m.top, "featureDeepLinkingValue")
        m.featureAnalyticsValue = SafeFindNode(m.top, "featureAnalyticsValue")
        m.featureCrashReportingValue = SafeFindNode(m.top, "featureCrashReportingValue")

        m.channelQrCode = SafeFindNode(m.top, "channelQrCode")
        m.qrFallbackUrl = SafeFindNode(m.top, "qrFallbackUrl")

        SafeObserveField(m.top, "close", "OnClose")
        SafeObserveField(m.layoutToggleRow, "focus", "OnLayoutToggleFocus")
        SafeObserveField(m.layoutToggleRow, "select", "OnLayoutToggleSelect")

        ' Feature row focus/select handlers
        if m.featureSearchValue <> invalid
            SafeObserveField(m.featureSearchValue, "focus", "OnFeatureRowFocus")
            SafeObserveField(m.featureSearchValue, "select", "OnFeatureRowSelect")
        end if
        if m.featureDeepLinkingValue <> invalid
            SafeObserveField(m.featureDeepLinkingValue, "focus", "OnFeatureRowFocus")
            SafeObserveField(m.featureDeepLinkingValue, "select", "OnFeatureRowSelect")
        end if
        if m.featureAnalyticsValue <> invalid
            SafeObserveField(m.featureAnalyticsValue, "focus", "OnFeatureRowFocus")
            SafeObserveField(m.featureAnalyticsValue, "select", "OnFeatureRowSelect")
        end if
        if m.featureCrashReportingValue <> invalid
            SafeObserveField(m.featureCrashReportingValue, "focus", "OnFeatureRowFocus")
            SafeObserveField(m.featureCrashReportingValue, "select", "OnFeatureRowSelect")
        end if

        UpdateAllDisplay()
        InitializeQrCode()

        if m.layoutToggleRow <> invalid
            m.layoutToggleRow.SetFocus(true)
        end if

        LogInfo("SettingsScreen", "Settings screen initialized")
        TrackScreenView("SettingsScreen", "")
    catch e
        LogError("SettingsScreen", "Init: " + e.message)
    end try
end sub

sub InitializeQrCode()
    url = GetQrDonationUrl()
    if m.channelQrCode <> invalid
        m.channelQrCode.text = url
    end if
    if m.qrFallbackUrl <> invalid
        m.qrFallbackUrl.text = url
    end if
    LogInfo("SettingsScreen", "QR code initialized with giving URL: " + url)
end sub

function GetQrDonationUrl () as string
    if m.top.givingDonationUrl <> invalid and m.top.givingDonationUrl <> ""
        return m.top.givingDonationUrl
    end if
    return "https://example.invalid/giving"
end function

sub OnGivingDonationUrlChanged()
    url = GetQrDonationUrl()
    if m.channelQrCode <> invalid
        m.channelQrCode.text = url
    end if
    if m.qrFallbackUrl <> invalid
        m.qrFallbackUrl.text = url
    end if
    LogInfo("SettingsScreen", "QR code updated with giving URL: " + url)
end sub

' Channel info display updates
sub OnChannelNameChanged()
    if m.channelNameLabel <> invalid
        m.channelNameLabel.text = "Channel: " + m.top.channelName
    end if
end sub

sub OnChannelVersionChanged()
    if m.channelVersionLabel <> invalid
        m.channelVersionLabel.text = "Version: " + m.top.channelVersion
    end if
end sub

sub OnContentSourceChanged()
    if m.contentSourceLabel <> invalid
        m.contentSourceLabel.text = "Content Source: " + m.top.contentSourceUrl
    end if
end sub

' Layout display update
sub OnCurrentLayoutChanged()
    if m.layoutToggleValue <> invalid
        layoutDisplay = ""
        if m.top.currentLayout = "leftnav"
            layoutDisplay = "Left Nav"
        else if m.top.currentLayout = "grid"
            layoutDisplay = "Grid"
        else
            layoutDisplay = m.top.currentLayout
        end if
        m.layoutToggleValue.text = layoutDisplay
    end if
end sub

' Feature display updates
sub OnFeatureSearchChanged()
    UpdateFeatureLabel(m.featureSearchValue, m.top.featureSearch)
end sub

sub OnFeatureDeepLinkingChanged()
    UpdateFeatureLabel(m.featureDeepLinkingValue, m.top.featureDeepLinking)
end sub

sub OnFeatureAnalyticsChanged()
    UpdateFeatureLabel(m.featureAnalyticsValue, m.top.featureAnalytics)
end sub

sub OnFeatureCrashReportingChanged()
    UpdateFeatureLabel(m.featureCrashReportingValue, m.top.featureCrashReporting)
end sub

' Layout toggle focus visual
sub OnLayoutToggleFocus()
    if m.layoutToggleValue <> invalid
        m.layoutToggleValue.color = "0xE8B931"
    end if
    ' Reset feature row value colors to default when focus moves to layout toggle
    if m.featureSearchValue <> invalid then m.featureSearchValue.color = "0xA0A0B0"
    if m.featureDeepLinkingValue <> invalid then m.featureDeepLinkingValue.color = "0xA0A0B0"
    if m.featureAnalyticsValue <> invalid then m.featureAnalyticsValue.color = "0xA0A0B0"
    if m.featureCrashReportingValue <> invalid then m.featureCrashReportingValue.color = "0xA0A0B0"
end sub

' Layout toggle selection - cycle between layouts
sub OnLayoutToggleSelect()
    newLayout = ""
    if m.top.currentLayout = "leftnav"
        newLayout = "grid"
    else
        newLayout = "leftnav"
    end if
    m.top.layoutToggle = newLayout
    TrackInteraction("layout_toggle", "SettingsScreen", newLayout)
end sub

' Feature row focus visual feedback
' Reset all feature row value labels to default color, then highlight the focused one
sub OnFeatureRowFocus()
    focusedValue = SafeNodeGetFocus(m.top)
    if focusedValue <> invalid
        ' Reset all feature value labels to default color
        if m.featureSearchValue <> invalid then m.featureSearchValue.color = "0xA0A0B0"
        if m.featureDeepLinkingValue <> invalid then m.featureDeepLinkingValue.color = "0xA0A0B0"
        if m.featureAnalyticsValue <> invalid then m.featureAnalyticsValue.color = "0xA0A0B0"
        if m.featureCrashReportingValue <> invalid then m.featureCrashReportingValue.color = "0xA0A0B0"

        ' Highlight the focused feature value label
        if m.featureSearchValue <> invalid and focusedValue.IsSameNode(m.featureSearchValue)
            m.featureSearchValue.color = "0xE8B931"
        else if m.featureDeepLinkingValue <> invalid and focusedValue.IsSameNode(m.featureDeepLinkingValue)
            m.featureDeepLinkingValue.color = "0xE8B931"
        else if m.featureAnalyticsValue <> invalid and focusedValue.IsSameNode(m.featureAnalyticsValue)
            m.featureAnalyticsValue.color = "0xE8B931"
        else if m.featureCrashReportingValue <> invalid and focusedValue.IsSameNode(m.featureCrashReportingValue)
            m.featureCrashReportingValue.color = "0xE8B931"
        end if
    end if
end sub

' Feature row selection - toggle the feature on the config
sub OnFeatureRowSelect()
    try
        focusedValue = SafeNodeGetFocus(m.top)
        if focusedValue <> invalid
            ' Determine which feature row was selected by checking the parent's id
            parent = focusedValue.getParent()
            if parent <> invalid
                parentId = parent.id
                if parentId = "featureSearchRow"
                    m.top.featureSearch = not m.top.featureSearch
                    TrackInteraction("feature_toggle", "SettingsScreen", "Search=" + m.top.featureSearch.ToStr())
                else if parentId = "featureDeepLinkingRow"
                    m.top.featureDeepLinking = not m.top.featureDeepLinking
                    TrackInteraction("feature_toggle", "SettingsScreen", "DeepLinking=" + m.top.featureDeepLinking.ToStr())
                else if parentId = "featureAnalyticsRow"
                    m.top.featureAnalytics = not m.top.featureAnalytics
                    TrackInteraction("feature_toggle", "SettingsScreen", "Analytics=" + m.top.featureAnalytics.ToStr())
                else if parentId = "featureCrashReportingRow"
                    m.top.featureCrashReporting = not m.top.featureCrashReporting
                    TrackInteraction("feature_toggle", "SettingsScreen", "CrashReporting=" + m.top.featureCrashReporting.ToStr())
                end if
            end if
        end if
    catch e
        SafeLog("ERROR", "SettingsScreen", "OnFeatureRowSelect failed: " + e.message)
    end try
end sub

' Update all display values from current interface fields
sub UpdateAllDisplay()
    OnChannelNameChanged()
    OnChannelVersionChanged()
    OnContentSourceChanged()
    OnCurrentLayoutChanged()
    OnFeatureSearchChanged()
    OnFeatureDeepLinkingChanged()
    OnFeatureAnalyticsChanged()
    OnFeatureCrashReportingChanged()
end sub

' Helper: update ON/OFF label
sub UpdateFeatureLabel(labelNode as object, enabled as boolean)
    if labelNode <> invalid
        if enabled
            labelNode.text = "ON"
            labelNode.color = "0xE8B931"
        else
            labelNode.text = "OFF"
            labelNode.color = "0xA0A0B0"
        end if
    end if
end sub

' Handle close event
sub OnClose()
    m.top.close = true
end sub

' Handle key events
function OnKeyEvent (key, press) as boolean
    result = false
    if press
        if LCase(key) = "back"
            m.top.close = true
            result = true
        end if
    end if
    return result
end function

' OnExit handler - cleanup resources when screen exits
sub OnExit()
    LogInfo("SettingsScreen", "OnExit: Cleaning up resources")

    ' Clean up observers
    SafeUnobserveField(m.top, "close")
    if m.layoutToggleRow <> invalid
        SafeUnobserveField(m.layoutToggleRow, "focus")
        SafeUnobserveField(m.layoutToggleRow, "select")
    end if
    if m.featureSearchValue <> invalid
        SafeUnobserveField(m.featureSearchValue, "focus")
        SafeUnobserveField(m.featureSearchValue, "select")
    end if
    if m.featureDeepLinkingValue <> invalid
        SafeUnobserveField(m.featureDeepLinkingValue, "focus")
        SafeUnobserveField(m.featureDeepLinkingValue, "select")
    end if
    if m.featureAnalyticsValue <> invalid
        SafeUnobserveField(m.featureAnalyticsValue, "focus")
        SafeUnobserveField(m.featureAnalyticsValue, "select")
    end if
    if m.featureCrashReportingValue <> invalid
        SafeUnobserveField(m.featureCrashReportingValue, "focus")
        SafeUnobserveField(m.featureCrashReportingValue, "select")
    end if

    LogInfo("SettingsScreen", "OnExit: Cleanup complete")
end sub

