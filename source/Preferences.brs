' Preferences.brs — User preference persistence via roRegistry
' Stores and retrieves user-configurable settings that survive app restarts
' Registry section: "user_prefs"
' Supported keys: layout (grid | leftnav), lastNavItem, themeMode, hybrid (grid | list)
' Fallback: in-memory cache when roRegistry is unavailable

sub PreferencesInit()
    m.registryAvailable = invalid
    m.memoryCache = CreateObject("roAssociativeArray")
    SafeLog("INFO", "Preferences", "Preferences module initialized")
end sub

' Check roRegistry availability once, cache result
function CheckRegistryAvailable () as boolean
    if m.registryAvailable = invalid
        m.registryAvailable = false
        try
            registry = CreateObject("roRegistry")
            if registry <> invalid
                registry.Init("user_prefs_test")
                testVal = registry.ReadString("__test__")
                _testVal = testVal
                registry.WriteString("__test__", "test")
                registry.Delete("__test__")
                m.registryAvailable = true
            end if
        catch e
            m.registryAvailable = false
        end try
        if not m.registryAvailable
            SafeLog("WARN", "Preferences", "roRegistry unavailable — using in-memory cache only")
        else
            SafeLog("INFO", "Preferences", "roRegistry available for preference persistence" + " (Test read/write successful)")
        end if
    end if
    return m.registryAvailable
end function

' Save a preference key-value pair using roRegistry (or memory fallback)
sub SavePreference(key, value)
    if key = invalid or key = ""
        return
    end if

    if m.memoryCache = invalid
        m.memoryCache = CreateObject("roAssociativeArray")
    end if

    m.memoryCache[key] = value.ToStr()

    if not CheckRegistryAvailable()
        return
    end if

    try
        registry = CreateObject("roRegistry")
        if registry <> invalid
            registry.Init("user_prefs")
            strValue = value.ToStr()
            success = registry.WriteString(key, strValue)
            if success
                SafeLog("INFO", "Preferences", "Saved preference: " + key + " = " + strValue + " (roRegistry)")
            else
                SafeLog("ERROR", "Preferences", "Failed to save preference: " + key + " = " + strValue + " (roRegistry write failed)")
            end if
        end if
    catch e
        SafeLog("WARN", "Preferences", "Registry save failed for '" + key + "', cached in memory" + " (Error: " + e.message + ")")
    end try
end sub

' Load a preference from roRegistry (or memory fallback), returns defaultValue if not found
function LoadPreference (key, defaultValue) as object
    if key = invalid or key = ""
        return defaultValue
    end if

    if CheckRegistryAvailable()
        try
            registry = CreateObject("roRegistry")
            if registry <> invalid
                registry.Init("user_prefs")
                result = registry.ReadString(key)
                if result <> invalid and result <> ""
                    m.memoryCache[key] = result
                    SafeLog("INFO", "Preferences", "Loaded preference: " + key + " = " + result)
                    return result
                end if
            end if
        catch e
            SafeLog("WARN", "Preferences", "Registry load failed for '" + key + "', falling back to cache" + " (Error: " + e.message + ")")
        end try
    end if

    if m.memoryCache <> invalid and m.memoryCache.DoesExist(key)
        return m.memoryCache[key]
    end if

    SafeLog("INFO", "Preferences", "Preference not found, using default: " + key)
    return defaultValue
end function

' Delete a preference key
sub DeletePreference(key)
    if key = invalid or key = ""
        return
    end if

    if m.memoryCache <> invalid and m.memoryCache.DoesExist(key)
        m.memoryCache.Delete(key)
    end if

    if not CheckRegistryAvailable()
        SafeLog("INFO", "Preferences", "Deleted preference (memory): " + key)
        return
    end if

    try
        registry = CreateObject("roRegistry")
        if registry <> invalid
            registry.Init("user_prefs")
            registry.Delete(key)
        end if
    catch e
        SafeLog("WARN", "Preferences", "Registry delete failed for '" + key + "'" + " (Error: " + e.message + ")")
    end try

    SafeLog("INFO", "Preferences", "Deleted preference: " + key + " (roRegistry)")
end sub

' Clear all preferences
sub ClearAllPreferences()
    if m.memoryCache <> invalid
        m.memoryCache.Clear()
    end if

    if not CheckRegistryAvailable()
        SafeLog("INFO", "Preferences", "All preferences cleared (memory)")
        return
    end if

    try
        registry = CreateObject("roRegistry")
        if registry <> invalid
            registry.Init("user_prefs")
            registry.Delete("layout")
            registry.Delete("lastNavItem")
            registry.Delete("themeMode")
            registry.Delete("hybrid")
        end if
    catch e
        SafeLog("WARN", "Preferences", "Registry clear failed" + " (Error: " + e.message + ")")
    end try

    SafeLog("INFO", "Preferences", "All preferences cleared (roRegistry)")
end sub

' Get the layout preference
' Returns: "grid", "leftnav", "list", "pagebased", "videoplayer", or the config default ("leftnav")
function GetLayoutPreference (configDefault) as string
    saved = LoadPreference("layout", "")
    if saved <> invalid and saved <> ""
        ' Validate the saved value
        if LCase(saved) = "grid"
            return "grid"
        else if LCase(saved) = "leftnav"
            return "leftnav"
        else if LCase(saved) = "list"
            return "list"
        else if LCase(saved) = "pagebased"
            return "pagebased"
        else if LCase(saved) = "videoplayer"
            return "videoplayer"
        else if LCase(saved) = "category"
            return "category"
        else if LCase(saved) = "hybrid"
            return "hybrid"
        else if LCase(saved) = "topnav"
            return "topnav"
        else
            return configDefault
        end if
    end if

    return configDefault
end function

' Save the layout preference
sub SetLayoutPreference(layout)
    if layout = invalid or layout = ""
        return
    end if

    validLayouts = CreateObject("roArray", 7, true)
    validLayouts[0] = "grid"
    validLayouts[1] = "leftnav"
    validLayouts[2] = "list"
    validLayouts[3] = "pagebased"
    validLayouts[4] = "videoplayer"
    validLayouts[5] = "category"
    validLayouts[6] = "hybrid"

    found = false
    for each valid in validLayouts
        if valid = LCase(layout)
            found = true
            exit for
        end if
    next

    if not found
        SafeLog("ERROR", "Preferences", "Invalid layout: " + layout)
        return
    end if

    SavePreference("layout", layout)
    SafeLog("INFO", "Preferences", "Saved layout: " + layout)
end sub

' Get the view preference (grid/list) for hybrid layout
' Returns: "grid" or "list"
function GetViewPreference (preferenceKey) as string
    registryKey = "hybrid"
    if preferenceKey <> invalid and preferenceKey <> ""
        registryKey = preferenceKey
    end if
    saved = LoadPreference(registryKey, "grid")
    if saved <> invalid and saved <> ""
        if LCase(saved) = "grid"
            return "grid"
        else if LCase(saved) = "list"
            return "list"
        else
            return "grid"
        end if
    else
        return "grid"
    end if
end function

' Save the view preference (grid/list) for hybrid layout
sub SaveViewPreference(preferenceKey, value)
    if preferenceKey = invalid or preferenceKey = ""
        return
    end if

    if value = invalid or value = ""
        return
    end if

    SavePreference("hybrid", value)
    SafeLog("INFO", "Preferences", "Saved view preference: " + preferenceKey + " = " + value)
end sub

' Get the last navigation item
' Returns: last nav item or defaultValue
function GetLastNavItem (defaultValue) as string
    saved = LoadPreference("lastNavItem", defaultValue)
    if saved <> invalid and saved <> ""
        return saved
    else
        return defaultValue
    end if
end function

' Save the last navigation item
sub SetLastNavItem(navItem)
    if navItem = invalid or navItem = ""
        return
    end if

    SavePreference("lastNavItem", navItem)
    SafeLog("INFO", "Preferences", "Saved last nav item: " + navItem)
end sub

' Get the theme mode
' Returns: "dark" or "light"
function GetThemeMode (defaultValue) as string
    saved = LoadPreference("themeMode", defaultValue)
    if saved <> invalid and saved <> ""
        return saved
    else
        return defaultValue
    end if
end function

' Save the theme mode
sub SetThemeMode(themeMode)
    if themeMode = invalid or themeMode = ""
        return
    end if

    validModes = CreateObject("roArray", 2, true)
    validModes[0] = "dark"
    validModes[1] = "light"

    found = false
    for each valid in validModes
        if valid = LCase(themeMode)
            found = true
            exit for
        end if
    next

    if not found
        SafeLog("ERROR", "Preferences", "Invalid theme mode: " + themeMode)
        return
    end if

    SavePreference("themeMode", themeMode)
    SafeLog("INFO", "Preferences", "Saved theme mode: " + themeMode)
end sub
