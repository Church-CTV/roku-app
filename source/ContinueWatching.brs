' ContinueWatching.brs - Track playback position and resume sermons
' Stores and retrieves playback positions using Roku preferences

' Preference keys

' Preference keys (inlined)


' Save playback position for a video
function SavePlaybackPosition (contentId as string, position as integer, duration as integer) as boolean
    try
        ' Get existing data
        data = GetContinueWatchingData()
        if data = invalid
            data = CreateObject("roAssociativeArray")
        end if

        ' Update position
        positionData = CreateObject("roAssociativeArray")
        positionData.contentId = contentId
        positionData.position = position
        positionData.duration = duration
        positionData.timestamp = CreateObject("roDateTime").AsSeconds()

        if duration > 0
            positionData.progress = (position * 100) / duration
        else
            positionData.progress = 0
        end if

        data[contentId] = positionData

        ' Limit to max items - remove oldest if exceeded
        keys = GetAssociativeArrayKeys(data)
        if keys.Count() > 20
            ' Sort by timestamp and remove oldest
            SortKeysByTimestamp(data, keys)
            for i = 0 to keys.Count() - 20 - 1
                data.Delete(keys[i])
            end for
        end if

        ' Save to preference
        return SavePreference("continue_watching", FormatJson(data))
    catch e
        SafeLog("ERROR", "ContinueWatching", "SavePlaybackPosition failed: " + e.message)
        return false
    end try
end function

' Get playback position for a video
function GetPlaybackPosition (contentId as string) as object
    try
        data = GetContinueWatchingData()
        if data = invalid then return invalid

        if data.DoesExist(contentId)
            return data[contentId]
        end if
        return invalid
    catch e
        SafeLog("ERROR", "ContinueWatching", "GetPlaybackPosition failed: " + e.message)
        return invalid
    end try
end function

' Get all continue watching items
function GetContinueWatchingItems () as object
    return GetContinueWatchingData()
end function

' Remove a video from continue watching
function RemoveContinueWatchingItem (contentId as string) as boolean
    try
        data = GetContinueWatchingData()
        if data = invalid then return false

        data.Delete(contentId)
        return SavePreference("continue_watching", FormatJson(data))
    catch e
        SafeLog("ERROR", "ContinueWatching", "RemoveContinueWatchingItem failed: " + e.message)
        return false
    end try
end function

' Clear all continue watching data
function ClearContinueWatchingData () as boolean
    return SavePreference("continue_watching", "")
end function

' Get continue watching data from preferences
function GetContinueWatchingData () as object
    try
        json = LoadPreference("continue_watching", "{}")
        if json = "" or json = "{}" then return invalid
        return ParseJson(json)
    catch e
        SafeLog("ERROR", "ContinueWatching", "GetContinueWatchingData failed: " + e.message)
        return invalid
    end try
end function

' Get keys from associative array
function GetAssociativeArrayKeys (arr as object) as object
    keys = CreateObject("roArray", 0, true)
    for each key in arr
        keys.Push(key)
    end for
    return keys
end function

' Sort keys by timestamp (oldest first)
sub SortKeysByTimestamp (data as object, keys as object)
    ' Simple bubble sort by timestamp
    count = keys.Count()
    for i = 0 to count - 2
        for j = 0 to count - i - 2
            key1 = keys[i]
            key2 = keys[i + 1]

            ts1 = 0
            ts2 = 0
            if data[key1] <> invalid and data[key1].timestamp <> invalid
                ts1 = data[key1].timestamp
            end if
            if data[key2] <> invalid and data[key2].timestamp <> invalid
                ts2 = data[key2].timestamp
            end if

            if ts1 < ts2
                temp = keys[i]
                keys[i] = keys[i + 1]
                keys[i + 1] = temp
            end if
        end for
    end for
end sub

' Check if video has been partially watched
function HasPartiallyWatched (contentId as string) as boolean
    positionData = GetPlaybackPosition(contentId)
    if positionData = invalid then return false

    position = positionData.position
    duration = positionData.duration

    if position > 0 and duration > 0
        progress = (position * 100) / duration
        return progress > 5 and progress < 95
    end if
    return false
end function
