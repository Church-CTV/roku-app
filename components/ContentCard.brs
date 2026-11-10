' ContentCard.brs - Performance-optimized focusable card
' Optimizations: deferred image loading, reduced property changes, efficient focus transitions
'
' Interaction:
'   - Single select: normal content selection
'   - Double select (within 500ms): toggle watch later

sub Init()
    try
        m.top.focusable = true
        m.focusRing = SafeFindNode(m.top, "focusRing")
        m.poster = SafeFindNode(m.top, "poster")
        m.titleLabel = SafeFindNode(m.top, "titleLabel")
        m.descLabel = SafeFindNode(m.top, "descLabel")

        m.isFocused = false
        m.posterUriSet = false
        m.contentItem = invalid
        m.lastSelectTime = 0

        SafeObserveField(m.top, "focused", "OnFocusChanged")
        SafeObserveField(m.top, "select", "OnSelect")
        SafeObserveField(m.top, "itemContent", "OnContentSet")
    catch e
        LogError("ContentCard", "Init: " + e.message)
    end try
end sub

sub OnContentSet()
    try
        content = m.top.itemContent
        if content = invalid then return

        m.contentItem = content

        if m.titleLabel <> invalid and content.title <> invalid
            m.titleLabel.text = content.title
        end if
        if m.descLabel <> invalid and content.description <> invalid
            m.descLabel.text = content.description
        end if

        if m.poster <> invalid and content.hdPosterUrl <> invalid
            if content.sdPosterUrl <> invalid
                m.poster.uri = content.sdPosterUrl
            else
                m.poster.uri = content.hdPosterUrl
            end if
            m.posterUriSet = true
        end if
    catch e
        LogError("ContentCard", "OnContentSet: " + e.message)
    end try
end sub

sub OnFocusChanged()
    try
        isFocused = m.top.focused
        if isFocused and not m.isFocused
            ' Show focus ring (white, 4px, clipped to rounded corners by MaskGroup)
            if m.focusRing <> invalid
                m.focusRing.visible = true
                m.focusRing.opacity = 1
            end if
            ' Scale poster slightly on focus
            if m.poster <> invalid
                m.poster.scale = 1.05
            end if
            if m.poster <> invalid and m.posterUriSet
                content = m.top.itemContent
                if content <> invalid and content.hdPosterUrl <> invalid
                    if content.sdPosterUrl <> invalid and content.sdPosterUrl <> content.hdPosterUrl
                        m.poster.uri = content.hdPosterUrl
                    end if
                end if
            end if
            m.isFocused = true
        else if not isFocused and m.isFocused
            ' Hide focus ring
            if m.focusRing <> invalid
                m.focusRing.visible = false
                m.focusRing.opacity = 0
            end if
            ' Reset poster scale on unfocus
            if m.poster <> invalid
                m.poster.scale = 1.0
            end if
            if m.poster <> invalid and m.posterUriSet
                content = m.top.itemContent
                if content <> invalid and content.sdPosterUrl <> invalid
                    m.poster.uri = content.sdPosterUrl
                end if
            end if
            m.isFocused = false
        end if
    catch e
        LogError("ContentCard", "OnFocusChanged: " + e.message)
    end try
end sub

sub OnSelect()
    try
        ' Check if this is a double-select (watch later toggle)
        DOUBLE_SELECT_TIMEOUT = 500
        currentTime = GetTimestamp()
        elapsed = currentTime - m.lastSelectTime
        m.lastSelectTime = currentTime

        if elapsed < DOUBLE_SELECT_TIMEOUT and m.lastSelectTime > 0
            ' Double select - watch later removed (feature disabled)
            ' Double select now just triggers normal selection
            SafeLog("INFO", "ContentCard", "Double select: watch later feature disabled, triggering select")
        else
            ' Single select - normal selection
            m.top.postMessage("select", {})
        end if
    catch e
        LogError("ContentCard", "OnSelect: " + e.message)
    end try
end sub

' OnExit handler - cleanup resources when card exits
sub OnExit()
    try
        SafeUnobserveField(m.top, "focused")
        SafeUnobserveField(m.top, "select")
        SafeUnobserveField(m.top, "itemContent")

        m.isFocused = false
        m.posterUriSet = false
        m.contentItem = invalid
        m.lastSelectTime = 0
    catch e
        LogError("ContentCard", "OnExit: " + e.message)
    end try
end sub
