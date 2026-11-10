' ********** Copyright 2020 Roku Corp.  All Rights Reserved. **********
' Performance-optimized content loader with HTTP caching, timeouts, and retry logic

sub Init()
    ' Set the function to execute when the task control field changes to "run"
    m.top.functionName = "GetContent"
end sub

sub GetContent()
    try
        ' Load config - check global cache first to avoid redundant file I/O
        config = invalid
        if m.global <> invalid and m.global.config <> invalid
            config = m.global.config
        end if
        if config = invalid
            config = LoadConfig("pkg:/config/default.json")
        end if
        sourceUrl = ""
        userAgent = "Roku/Template"
        sslCerts = "common:/certs/ca-bundle.crt"
        timeoutSeconds = 30

        ' Priority 1: Read from manifest (roAppMetadata) — allows environment-level overrides
        manifestUrl = GetManifestValue("content_feed_url")
        if manifestUrl <> invalid and manifestUrl <> ""
            sourceUrl = manifestUrl
        end if

        ' Priority 2: Fall back to JSON config for sourceUrl
        if sourceUrl = "" and config <> invalid and config.DoesExist("content")
            if config.content.DoesExist("sourceUrl")
                sourceUrl = config.content.sourceUrl
            end if
        end if

        ' Always read userAgent and sslCerts from config when available
        if config <> invalid and config.DoesExist("content")
            if config.content.DoesExist("userAgent") and config.content.userAgent <> ""
                userAgent = config.content.userAgent
            end if
            if config.content.DoesExist("sslCertificates") and config.content.sslCertificates <> ""
                sslCerts = config.content.sslCertificates
            end if
            if config.content.DoesExist("fetchTimeout") and config.content.fetchTimeout > 0
                timeoutSeconds = config.content.fetchTimeout
            end if
        end if

        ' Manifest timeout override (highest priority)
        manifestTimeout = GetManifestValue("content_fetch_timeout")
        if manifestTimeout <> invalid and manifestTimeout <> ""
            parsedTimeout = manifestTimeout.ToInt()
            if parsedTimeout > 0
                timeoutSeconds = parsedTimeout
            end if
        end if

        if sourceUrl = ""
            LogError("MainLoaderTask", "No content source URL configured")
            m.top.error = "No content source URL configured"
            m.top.content = CreateObject("roSGNode", "ContentNode")
            return
        end if

        LogInfo("MainLoaderTask", "Source URL: " + sourceUrl)
        LogInfo("MainLoaderTask", "Timeout: " + timeoutSeconds.ToStr() + "s")

        ' Try cached content first (HTTP caching optimization)
        cachedContent = TryLoadCachedContent()
        if cachedContent <> invalid
            LogInfo("MainLoaderTask", "Using cached content (faster launch)")

            ' Apply live stream thumbnail override BEFORE setting m.top.content
            overrideThumb = GetLiveStreamThumbnailOverride()
            if overrideThumb <> "" and overrideThumb <> invalid
                ApplyLiveStreamThumbnailOverride(cachedContent, overrideThumb)
            end if

            m.top.content = cachedContent
            m.top.cardStyle = TryLoadCachedCardStyle()
            return
        end if

        ' Fetch with retry and timeout
        rsp = FetchWithRetry(sourceUrl, userAgent, sslCerts, timeoutSeconds * 1000)
        if rsp = invalid
            LogWarn("MainLoaderTask", "All fetch attempts failed, using empty content")
            if m.top.error = ""
                m.top.error = "Failed to load content. Please check your network connection and try again."
            end if
            m.top.content = CreateObject("roSGNode", "ContentNode")
            return
        end if

        ' Parse and build content tree
        json = invalid
        try
            json = ParseJson(rsp)
        catch e
            LogError("MainLoaderTask", "ParseJson failed: " + e.message)
            json = invalid
        end try
        if json = invalid or Type(json) <> "roAssociativeArray"
            LogError("MainLoaderTask", "Failed to parse JSON from feed")
            m.top.error = "Invalid feed format"
            m.top.content = CreateObject("roSGNode", "ContentNode")
            return
        end if

        ' Build optimized content tree
        contentNode = invalid
        try
            contentNode = BuildContentTree(json)
        catch e
            LogError("MainLoaderTask", "BuildContentTree failed: " + e.message)
            contentNode = CreateObject("roSGNode", "ContentNode")
        end try

        ' Apply live stream thumbnail override BEFORE setting m.top.content
        ' (so observers see the override value, not the feed thumbnail)
        overrideThumb = GetLiveStreamThumbnailOverride()
        if overrideThumb <> "" and overrideThumb <> invalid
            ApplyLiveStreamThumbnailOverride(contentNode, overrideThumb)
        end if

        m.top.content = contentNode

        ' Extract cardStyle from feed
        if json.DoesExist("cardStyle") and Type(json.cardStyle) = "roAssociativeArray"
            m.top.cardStyle = json.cardStyle
            CacheCardStyle(json.cardStyle)
            LogInfo("MainLoaderTask", "cardStyle extracted from feed")
        end if

        ' Extract config from feed for runtime use
        if json.DoesExist("config") and Type(json.config) = "roAssociativeArray"
            feedConfig = json.config
            ' Extract server config
            if feedConfig.DoesExist("server")
                m.top.serverConfig = feedConfig.server
            end if
            ' Extract content config
            if feedConfig.DoesExist("content")
                m.top.contentConfig = feedConfig.content
            end if
            ' Extract analytics config
            if feedConfig.DoesExist("analytics")
                m.top.analyticsConfig = feedConfig.analytics
            end if
            ' Extract feature flags
            if feedConfig.DoesExist("features")
                m.top.featureFlags = feedConfig.features
            end if
            ' Extract giving config
            if feedConfig.DoesExist("giving")
                m.top.givingConfig = feedConfig.giving
            end if
            LogInfo("MainLoaderTask", "Config extracted from feed")
        end if

        ' Cache the content for faster subsequent launches
        CacheContent(json)
    catch e
        LogError("MainLoaderTask", "GetContent: " + e.message)
    end try
end sub

' Fetch content with retry logic and connection timeout
function FetchWithRetry (url, userAgent, sslCerts, timeout) as dynamic
    try
        for attempt = 1 to 3
            LogInfo("MainLoaderTask", "Fetch attempt " + attempt.ToStr() + "/3")
            xfer = CreateObject("roURLTransfer")
            if xfer = invalid
                LogError("MainLoaderTask", "Failed to create roURLTransfer object")
                m.top.error = "Network request failed: Unable to create URL transfer object"
                return invalid
            end if
            xfer.SetPort(CreateObject("roMessagePort"))
            xfer.SetCertificatesFile(sslCerts)
            xfer.InitClientCertificates()
            xfer.EnableEncodings(true)
            xfer.SetUrl(url)
            xfer.SetRequest("GET")
            xfer.AddHeader("User-Agent", userAgent)
            LogInfo("MainLoaderTask", "GET " + url)

            ' Add If-Modified-Since for HTTP caching on server side
            cachedTimestamp = ReadCacheTimestamp()
            if cachedTimestamp <> invalid
                xfer.AddHeader("If-Modified-Since", cachedTimestamp)
            end if

            xfer.AsyncGetToString()

            ' Wait with timeout
            startTimeSecs = CreateObject("roDateTime").AsSeconds()
            while true
                msg = wait(timeout, xfer.GetPort())
                if Type(msg) = "roUrlEvent"
                    if msg.GetInt() = 1
                        responseCode = msg.GetResponseCode()
                        if responseCode = 304
                            LogInfo("MainLoaderTask", "Server returned 304 Not Modified")
                            xfer = invalid
                            cachedJson = LoadCachedJsonString()
                            if cachedJson <> invalid
                                WriteAsciiFile("common:/cache/roku-channel-content.timestamp", CreateObject("roDateTime").ToISOString())
                            end if
                            return cachedJson
                        else if responseCode = 200
                            rsp = msg.GetString()
                            if rsp <> invalid and rsp <> ""
                                LogInfo("MainLoaderTask", "Fetch successful (" + rsp.Len().ToStr() + " bytes)")
                                xfer = invalid
                                return rsp
                            else
                                LogWarn("MainLoaderTask", "HTTP 200 but empty body, retrying...")
                            end if
                        else
                            LogWarn("MainLoaderTask", "HTTP " + responseCode.ToStr() + ", retrying...")
                        end if
                    else
                        LogWarn("MainLoaderTask", "Request failed (" + msg.GetFailureReason() + "), retrying...")
                    end if
                    exit while ' Break to retry loop on non-success HTTP/transport errors
                else if (CreateObject("roDateTime").AsSeconds() - startTimeSecs) * 1000 >= timeout
                    LogWarn("MainLoaderTask", "Fetch timeout after " + timeout.ToStr() + "ms")
                    xfer = invalid
                    m.top.error = "Connection timed out after " + (timeout / 1000).ToStr() + " seconds."
                    return invalid ' Stop all retries on hard timeout
                end if
            end while

            ' Explicitly release roUrlTransfer to free network resources before retry
            xfer = invalid

            if attempt < 3
                delayMs = 1000 * (2 ^ (attempt - 1))
                LogInfo("MainLoaderTask", "Retrying in " + delayMs.ToStr() + "ms...")
                Sleep(delayMs)
            end if
        end for
    catch e
        LogError("MainLoaderTask", "FetchWithRetry error: " + e.message)
        ' Release roUrlTransfer in error path
        xfer = invalid
    end try
    m.top.error = "Failed to load content after 3 attempts"
    return invalid
end function

' Try to load cached content from persistent storage
function TryLoadCachedContent () as object
    try
        ' Check if cache file exists and is recent (within 1 hour)
        cachePath = "common:/cache/roku-channel-content.json"

        ' Check cache timestamp
        cachedTs = ReadCacheTimestamp()
        if cachedTs = invalid
            return invalid
        end if

        ' Parse timestamp and check if within 1 hour
        cacheAgeSeconds = GetTimestampAgeSeconds(cachedTs)
        if cacheAgeSeconds > 3600
            LogInfo("MainLoaderTask", "Cache expired (" + cacheAgeSeconds.ToStr() + "s old)")
            return invalid
        end if

        ' Load cached content
        cachedContent = ReadCacheFile(cachePath)
        if cachedContent = invalid
            return invalid
        end if

        json = invalid
        try
            json = ParseJson(cachedContent)
        catch e
            LogError("MainLoaderTask", "Cached content ParseJson failed: " + e.message)
            json = invalid
        end try
        if json = invalid or Type(json) <> "roAssociativeArray"
            return invalid
        end if

        ' Build content tree from cached JSON
        return BuildContentTree(json)
    catch e
        LogError("MainLoaderTask", "TryLoadCachedContent: " + e.message)
        return invalid
    end try
end function

' Build the ContentNode tree efficiently
function BuildContentTree (json) as object
    try
        rootChildren = []

        ' Get all month-year keys
        monthKeys = []
        for each key in json
            if key <> "providerName" and key <> "lastUpdated" and key <> "language" and key <> "cardStyle"
                monthKeys.Push(key)
            end if
        end for

        ' Sort months descending with early-exit optimization
        MonthSortDescending(monthKeys)

        ' Process each month
        for each monthKey in monthKeys
            videos = json[monthKey]
            if Type(videos) = "roArray" and videos.Count() > 0
                row = CreateObject("roSGNode", "ContentNode")
                row.title = monthKey

                ' Sort videos by releaseDate descending
                sortedVideos = SortVideosByDateDescending(videos)

                ' Build item data efficiently
                for each item in sortedVideos
                    itemData = GetItemData(item)
                    if itemData <> invalid
                        row.appendChild(itemData)
                    end if
                end for

                rootChildren.Push(row)
            end if
        end for

        contentNode = CreateObject("roSGNode", "ContentNode")
        for each child in rootChildren
            contentNode.appendChild(child)
        end for

        LogInfo("MainLoaderTask", "Built content tree: " + rootChildren.Count().ToStr() + " rows")
        return contentNode
    catch e
        LogError("MainLoaderTask", "BuildContentTree: " + e.message)
        return CreateObject("roSGNode", "ContentNode")
    end try
end function

' Efficient descending sort for month strings
sub MonthSortDescending(arr)
    if arr.Count() <= 1 then return
    ' Use bubble sort but with early exit optimization
    swapped = true
    n = arr.Count()
    while swapped
        swapped = false
        for i = 0 to n - 2
            if CompareDates(arr[i], arr[i + 1]) < 0
                temp = arr[i]
                arr[i] = arr[i + 1]
                arr[i + 1] = temp
                swapped = true
            end if
        end for
        n = n - 1
    end while
end sub

' Efficient descending sort for videos by releaseDate
function SortVideosByDateDescending (videos) as object
    if videos.Count() <= 1 then return videos
    sorted = []
    for each v in videos
        sorted.Push(v)
    end for
    swapped = true
    n = sorted.Count()
    while swapped
        swapped = false
        for i = 0 to n - 2
            d1 = sorted[i].releaseDate
            d2 = sorted[i + 1].releaseDate
            if d1 <> invalid and d2 <> invalid and d1 < d2
                temp = sorted[i]
                sorted[i] = sorted[i + 1]
                sorted[i + 1] = temp
                swapped = true
            end if
        end for
        n = n - 1
    end while
    return sorted
end function

' Cache content to persistent storage for faster subsequent launches
sub CacheContent(json)
    try
        cachePath = "common:/cache/roku-channel-content.json"
        tsPath = "common:/cache/roku-channel-content.timestamp"

        ' Write content cache
        if WriteAsciiFile(cachePath, FormatJson(json))
            ' Write timestamp
            now = CreateObject("roDateTime")
            WriteAsciiFile(tsPath, now.ToISOString())
            LogInfo("MainLoaderTask", "Content cached for faster subsequent launches")
        end if
    catch e
        LogError("MainLoaderTask", "CacheContent: " + e.message)
    end try
end sub

' Cache cardStyle separately for quick access
sub CacheCardStyle(cardStyle)
    try
        cachePath = "common:/cache/roku-channel-cardStyle.json"
        if cardStyle <> invalid and Type(cardStyle) = "roAssociativeArray"
            if WriteAsciiFile(cachePath, FormatJson(cardStyle))
                LogInfo("MainLoaderTask", "cardStyle cached")
            end if
        end if
    catch e
        LogError("MainLoaderTask", "CacheCardStyle: " + e.message)
    end try
end sub

' Load cached cardStyle from persistent storage
function TryLoadCachedCardStyle () as dynamic
    try
        cachePath = "common:/cache/roku-channel-cardStyle.json"
        content = ReadCacheFile(cachePath)
        if content = invalid then return invalid
        json = ParseJson(content)
        if json <> invalid and Type(json) = "roAssociativeArray"
            return json
        end if
    catch e
        LogError("MainLoaderTask", "TryLoadCachedCardStyle: " + e.message)
    end try
    return invalid
end function

function ReadCacheTimestamp () as dynamic
    return ReadCacheFile("common:/cache/roku-channel-content.timestamp")
end function

function ReadCacheFile (path) as dynamic
    try
        fs = CreateObject("roFileSystem")
        if fs = invalid or not fs.Exists(path)
            return invalid
        end if
        content = ReadAsciiFile(path)
        if content <> invalid and content <> ""
            return content.Trim()
        end if
    catch e
        LogError("MainLoaderTask", "ReadCacheFile: " + e.message)
    end try
    return invalid
end function

' Load the raw cached JSON string (used by 304 Not Modified handler)
' Returns the file contents as a string, or invalid if not present
function LoadCachedJsonString () as dynamic
    return ReadCacheFile("common:/cache/roku-channel-content.json")
end function

function GetTimestampAgeSeconds (timestamp) as integer
    try
        now = CreateObject("roDateTime")
        cacheTime = CreateObject("roDateTime")
        cacheTime.FromISO8601String(timestamp)
        return now.AsSeconds() - cacheTime.AsSeconds()
    catch e
        LogError("MainLoaderTask", "GetTimestampAgeSeconds: " + e.message)
        return 999999
    end try
end function

' Compare two "Month YYYY" strings (e.g., "May 2025")
' Returns: 1 if date1 > date2, -1 if date1 < date2, 0 if equal
function CompareDates (date1, date2) as integer
    months = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]

    d1Parts = SplitString(date1, " ")
    d2Parts = SplitString(date2, " ")

    if d1Parts.Count() < 2 or d2Parts.Count() < 2
        return 0
    end if

    year1 = d1Parts[1].ToInt()
    year2 = d2Parts[1].ToInt()

    if year1 > year2 then return 1
    if year1 < year2 then return -1

    month1 = -1
    month2 = -1

    for i = 0 to months.Count() - 1
        if months[i] = d1Parts[0] then month1 = i
        if months[i] = d2Parts[0] then month2 = i
        if month1 >= 0 and month2 >= 0 then exit for
    end for

    if month1 > month2 then return 1
    if month1 < month2 then return -1
    return 0
end function

' Read a value from the channel manifest via roAppInfo
' Returns invalid if the key is not found or roAppInfo is unavailable
function GetManifestValue (key) as dynamic
    try
        appInfo = CreateObject("roAppInfo")
        if appInfo <> invalid
            val = appInfo.GetValue(key)
            if val <> invalid and val <> ""
                return val
            end if
        end if
    catch e
        LogError("MainLoaderTask", "GetManifestValue: " + e.message)
    end try
    return invalid
end function

' Extract standard content metadata from a video item.
' Returns an roSGNode (ContentNode) ready to be appended to a row, or invalid.
function GetItemData (item) as object
    try
        if item = invalid then return invalid

        node = CreateObject("roSGNode", "ContentNode")
        node.title = DecodeHtmlEntities(item.title)
        node.description = DecodeHtmlEntities(item.shortDescription)
        if item.sdPosterUrl <> invalid
            node.sdPosterUrl = item.sdPosterUrl
        else
            node.sdPosterUrl = item.thumbnail
        end if
        if item.hdPosterUrl <> invalid
            node.hdPosterUrl = item.hdPosterUrl
        else
            node.hdPosterUrl = item.thumbnail
        end if

        ' Set id for deep linking support
        if item.id <> invalid
            node.id = item.id
        end if

        ' Use flattened URL from feed, or fall back to nested content.videos[0].url
        if item.url <> invalid and item.url <> ""
            node.url = item.url
            ' Determine stream format - default to mp4 for flattened URLs
            node.streamFormat = "mp4"
            if InStr(LCase(item.url), ".m3u8") > 0 or InStr(LCase(item.url), "/playlist") > 0
                node.streamFormat = "hls"
            end if
        else if item.content <> invalid and item.content.videos <> invalid and item.content.videos.Count() > 0
            video = item.content.videos[0]
            node.url = video.url
            ' Determine stream format from videoType (HLS or MP4)
            if video.videoType <> invalid and LCase(video.videoType) = "hls"
                node.streamFormat = "hls"
            else
                node.streamFormat = "mp4"
            end if
        end if

        ' Extract duration for time formatting in GridScreen
        if item.content <> invalid and item.content.duration <> invalid
            node.length = item.content.duration
        end if

        ' Mark live content if applicable
        if item.isLive = true
            node.live = true
        end if

        return node
    catch e
        LogError("MainLoaderTask", "GetItemData: " + e.message)
        return invalid
    end try
end function

' Decode common HTML entities found in feed text fields
function DecodeHtmlEntities (s as dynamic) as string
    if s = invalid then return ""
    out = s
    out = out.Replace("&#39;", "'")
    out = out.Replace("&quot;", Chr(34))
    out = out.Replace("&amp;", "&")
    out = out.Replace("&lt;", "<")
    out = out.Replace("&gt;", ">")
    return out
end function

' Read the live stream thumbnail override directly from the config file
function GetLiveStreamThumbnailOverride () as dynamic
    try
        configPath = "pkg:/config/default.json"
        fileContent = ReadAsciiFile(configPath)
        if fileContent = invalid or fileContent = ""
            return ""
        end if
        json = ParseJson(fileContent)
        if json = invalid or Type(json) <> "roAssociativeArray"
            return ""
        end if
        if json.DoesExist("branding") and Type(json.branding) = "roAssociativeArray"
            if json.branding.DoesExist("images") and Type(json.branding.images) = "roAssociativeArray"
                if json.branding.images.DoesExist("liveStreamThumbnail")
                    val = json.branding.images.liveStreamThumbnail
                    if val <> invalid and GetInterface(val, "ifString") <> invalid and Len(val) > 0
                        return val
                    end if
                end if
            end if
        end if
    catch e
        LogError("MainLoaderTask", "GetLiveStreamThumbnailOverride: " + e.message)
    end try
    return ""
end function

' Override the poster URLs for the first item at row [0,0] (the live broadcast card)
sub ApplyLiveStreamThumbnailOverride(contentNode, overrideThumb)
    try
        if contentNode = invalid or overrideThumb = "" then
            return
        end if
        firstRow = contentNode.GetChild(0)
        if firstRow = invalid then return
        firstItem = firstRow.GetChild(0)
        if firstItem = invalid then return
        firstItem.sdPosterUrl = overrideThumb
        firstItem.hdPosterUrl = overrideThumb
        ' Verify the fields were actually set
    catch e
        LogError("MainLoaderTask", "ApplyLiveStreamThumbnailOverride: " + e.message)
    end try
end sub
