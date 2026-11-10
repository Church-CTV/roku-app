' BrandTheme.brs - Centralized design system for Example Channel
' Provides design tokens, theme access helpers, and onChange callbacks

sub Init()
    try
        m.bgRect = SafeFindNode(m.top, "bgRect")
        m.themeCache = CreateObject("roAssociativeArray")
    catch e
        LogError("BrandTheme", "Init: " + e.message)
    end try
end sub

sub OnThemeChanged()
    try
        bgColor = m.top.bgColor
        surfaceColor = m.top.surfaceColor
        accentColor = m.top.accentColor
        textPrimary = m.top.textPrimary
        textSecondary = m.top.textSecondary
        focusColor = m.top.focusColor
        errorColor = m.top.errorColor

        if m.bgRect <> invalid
            m.bgRect.color = bgColor
        end if

        m.themeCache.bgColor = bgColor
        m.themeCache.surfaceColor = surfaceColor
        m.themeCache.accentColor = accentColor
        m.themeCache.textPrimary = textPrimary
        m.themeCache.textSecondary = textSecondary
        m.themeCache.focusColor = focusColor
        m.themeCache.errorColor = errorColor
    catch e
        LogError("BrandTheme", "OnThemeChanged: " + e.message)
    end try
end sub

function GetCachedThemeColor (colorName) as string
    if m.themeCache.DoesExist(colorName)
        return m.themeCache[colorName]
    end if
    return GetThemeColor(colorName)
end function

function GetThemeColor (colorName) as string
    colorMap = {
        "background": "0x1A1A2E"
        "surface": "0x16213E"
        "accent": "0xE8B931"
        "textPrimary": "0xFFFFFF"
        "textSecondary": "0xA0A0B0"
        "focus": "0xE8B931"
        "error": "0xFF4444"
    }
    if colorMap.DoesExist(colorName)
        return colorMap[colorName]
    end if
    return "0x1A1A2E"
end function

function GetThemeFont (fontName) as string
    fontMap = {
        "title": "font:BoldSystemFont"
        "body": "font:MediumSystemFont"
        "caption": "font:SmallSystemFont"
        "heading": "font:ExtraBoldSystemFont"
    }
    if fontMap.DoesExist(fontName)
        return fontMap[fontName]
    end if
    return "font:MediumSystemFont"
end function

sub ApplyConfigToTheme(config, theme)
    try
        if config = invalid or theme = invalid then return

        if config.DoesExist("branding") and config.branding.DoesExist("colors")
            colors = config.branding.colors
            if colors.DoesExist("background")
                theme.bgColor = colors.background
            else
                theme.bgColor = "0x1A1A2E"
            end if
            if colors.DoesExist("surface")
                theme.surfaceColor = colors.surface
            else
                theme.surfaceColor = "0x16213E"
            end if
            if colors.DoesExist("accent")
                theme.accentColor = colors.accent
            else
                theme.accentColor = "0xE8B931"
            end if
            if colors.DoesExist("textPrimary")
                theme.textPrimary = colors.textPrimary
            else
                theme.textPrimary = "0xFFFFFF"
            end if
            if colors.DoesExist("textSecondary")
                theme.textSecondary = colors.textSecondary
            else
                theme.textSecondary = "0xA0A0B0"
            end if
            if colors.DoesExist("focus")
                theme.focusColor = colors.focus
            else
                theme.focusColor = "0xE8B931"
            end if
            if colors.DoesExist("error")
                theme.errorColor = colors.error
            else
                theme.errorColor = "0xFF4444"
            end if
        end if

        if config.DoesExist("branding") and config.branding.DoesExist("spacing")
            spacing = config.branding.spacing
            if spacing.DoesExist("marginHorizontal")
                theme.marginH = spacing.marginHorizontal
            else
                theme.marginH = 80
            end if
            if spacing.DoesExist("marginVertical")
                theme.marginV = spacing.marginVertical
            else
                theme.marginV = 40
            end if
        end if

        if config.DoesExist("branding") and config.branding.DoesExist("animation")
            anim = config.branding.animation
            if anim.DoesExist("cardScale")
                theme.cardScale = anim.cardScale
            else
                theme.cardScale = 1.05
            end if
            if anim.DoesExist("transitionDuration")
                theme.transitionDuration = anim.transitionDuration
            else
                theme.transitionDuration = 0.25
            end if
        end if
    catch e
        LogError("BrandTheme", "ApplyConfigToTheme: " + e.message)
    end try
end sub

sub LogTheme(context, message)
    LogInfo("Theme:" + context, message)
end sub
