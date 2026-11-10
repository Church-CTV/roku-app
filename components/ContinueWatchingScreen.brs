' ContinueWatchingScreen.brs - Continue watching screen
' Displays partially watched sermons with progress indicators

sub Init()
    ' Store node references
    m.title = SafeFindNode(m.top, "title")
    m.continueRowList = SafeFindNode(m.top, "continueRowList")
    m.emptyState = SafeFindNode(m.top, "emptyState")
    m.emptyTitle = SafeFindNode(m.top, "emptyTitle")
    m.emptySubtitle = SafeFindNode(m.top, "emptySubtitle")

    ' Observe row list
    if m.continueRowList <> invalid
        SafeObserveField(m.continueRowList, "select", "OnRowListSelect")
    end if

    ' Load continue watching data
    LoadContinueWatching()

    TrackScreenView("ContinueWatchingScreen", "")
end sub

function LoadContinueWatching () as void
    try
        positions = GetContinueWatchingItems()
        if positions = invalid
            m.emptyState.visible = true
            m.continueRowList.visible = false
            return
        end if

        m.emptyState.visible = false
        m.continueRowList.visible = true

        ' Create continue watching row
        row = CreateObject("roSGNode", "ContentNode")
        row.title = "Continue Watching"
        row.id = "continue_watching"

        ' Add items for each position
        for each contentId in positions
            positionData = positions[contentId]

            ' Find the content item in the main feed
            contentItem = FindContentById(m.top.content, contentId)
            if contentItem <> invalid
                ' Create continue watching node
                continueNode = CreateObject("roSGNode", "ContentNode")
                continueNode.id = contentItem.id
                continueNode.title = contentItem.title
                continueNode.description = contentItem.description
                continueNode.url = contentItem.url
                continueNode.streamFormat = contentItem.streamFormat
                continueNode.hdPosterUrl = contentItem.hdPosterUrl
                continueNode.hdBackdropUrl = contentItem.hdPosterUrl
                continueNode.hdThumbUrl = contentItem.hdPosterUrl
                continueNode.category = contentItem.category
                continueNode.pastor = contentItem.pastor
                continueNode.series = contentItem.series
                continueNode.contentIsPlaylist = false
                continueNode.showNext = true

                ' Add playback position info as numeric seconds (required for progress bar)
                pPos = 0
                pDur = 0
                if positionData.position <> invalid then pPos = positionData.position
                if positionData.duration <> invalid then pDur = positionData.duration
                continueNode.playbackPosition = pPos
                continueNode.playbackDuration = pDur
                continueNode.playbackProgress = positionData.progress

                row.AppendChild(continueNode)
            end if
        end for

        m.continueRowList.content = row
    catch e
        SafeLog("ERROR", "ContinueWatchingScreen", "LoadContinueWatching failed: " + e.message)
    end try
end function

function FindContentById (content as object, contentId as string) as object
    try
        if content = invalid then return invalid

        for i = 0 to content.GetChildCount() - 1
            row = content.GetChild(i)
            if row <> invalid
                for j = 0 to row.GetChildCount() - 1
                    item = row.GetChild(j)
                    if item <> invalid and item.id = contentId
                        return item
                    end if
                end for
            end if
        end for
        return invalid
    catch e
        SafeLog("ERROR", "ContinueWatchingScreen", "FindContentById failed: " + e.message)
        return invalid
    end try
end function

sub OnRowListSelect()
    try
        if m.continueRowList.rowItemFocused = invalid then return

        rowIdx = m.continueRowList.rowItemFocused[0]
        itemIdx = m.continueRowList.rowItemFocused[1]

        row = m.continueRowList.content.GetChild(rowIdx)
        if row = invalid then return

        item = row.GetChild(itemIdx)
        if item = invalid then return

        ' Set selectedContent for navigation context (same pattern as SearchScreen)
        m.top.selectedContent = item

        ' Set ClipStart for resume from saved playback position
        if item.playbackPosition <> invalid and item.playbackPosition > 0
            item.ClipStart = item.playbackPosition
        end if

        ' Fire play event with position info
        SafeLog("INFO", "ContinueWatchingScreen", "Playing from position: " + item.title)
        TrackInteraction("continue_watching", "ContinueWatchingScreen", item.title)
        m.top.play = true
    catch e
        SafeLog("ERROR", "ContinueWatchingScreen", "OnRowListSelect failed: " + e.message)
    end try
end sub

' OnExit handler - cleanup resources when screen exits
sub OnExit()
    SafeLog("INFO", "ContinueWatchingScreen", "OnExit: Cleaning up resources")

    ' Clean up observers
    if m.continueRowList <> invalid then SafeUnobserveField(m.continueRowList, "select")

    SafeLog("INFO", "ContinueWatchingScreen", "OnExit: Cleanup complete")
end sub
