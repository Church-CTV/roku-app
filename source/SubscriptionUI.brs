' SubscriptionUI.brs — UI utilities for subscription features
' Provides helper functions for creating and managing subscription UI elements

' ============================================================
' Loading Spinner for Subscription Operations
' ============================================================

' Create a loading overlay for subscription operations
' Returns: roSGNode (Group) with spinner and message
function CreateSubscriptionLoadingOverlay (message) as object
    try
        overlay = CreateObject("roSGNode", "Group")

        ' Semi-transparent background
        bg = CreateObject("roSGNode", "Rectangle")
        bg.id = "subLoadingBg"
        bg.width = 1920
        bg.height = 1080
        bg.color = "0x80000000" ' 50% transparent black

        ' Spinner
        spinner = CreateObject("roSGNode", "Poster")
        spinner.id = "subLoadingSpinner"
        spinner.uri = "pkg:/images/loader.png"
        spinner.width = 120
        spinner.height = 120
        spinner.translation = "[900, 400]"

        ' Message label
        label = CreateObject("roSGNode", "Label")
        label.id = "subLoadingMessage"
        label.text = message
        label.font = "font:MediumSystemFont"
        label.color = "0xFFFFFF"
        label.horizAlign = "center"
        label.translation = "[900, 560]"
        label.width = 600

        overlay.appendChild(bg)
        overlay.appendChild(spinner)
        overlay.appendChild(label)
        overlay.visible = false

        return overlay
    catch e
        SafeLog("ERROR", "CreateSubscriptionLoadingOverlay", "Error: " + e.message)
        return invalid
    end try
end function

' Show the loading overlay
sub ShowSubscriptionLoading(message)
    try
        if m.global = invalid or m.global.MainScene = invalid
            LogWarn("SubscriptionUI", "Guard: m.global is invalid or m.global.MainScene is invalid - ShowSubscriptionLoading skipped")
            return
        end if

        scene = m.global.MainScene
        if scene = invalid
            return
        end if

        ' Create overlay if it doesn't exist
        if m.subLoadingOverlay = invalid
            m.subLoadingOverlay = CreateSubscriptionLoadingOverlay(message)
            if m.subLoadingOverlay <> invalid
                scene.appendChild(m.subLoadingOverlay)
            end if
        end if

        if m.subLoadingOverlay <> invalid
            m.subLoadingOverlay.visible = true
            msgNode = m.subLoadingOverlay.FindNode("subLoadingMessage")
            if msgNode <> invalid
                msgNode.text = message
            end if
        end if
    catch e
        SafeLog("ERROR", "ShowSubscriptionLoading", "Error: " + e.message)
    end try
end sub

' Hide the loading overlay
sub HideSubscriptionLoading()
    try
        if m.subLoadingOverlay <> invalid
            m.subLoadingOverlay.visible = false
        end if
    catch e
        SafeLog("ERROR", "HideSubscriptionLoading", "Error: " + e.message)
    end try
end sub

' ============================================================
' Dialog/Message Display
' ============================================================

' Show a simple message dialog
' Parameters:
'   title — dialog title
'   message — dialog message
'   buttonText — label for the OK button
'   callback — function to call when button is selected
sub ShowSubscriptionDialog(title, message, buttonText, callback)
    try
        if m.global = invalid or m.global.MainScene = invalid
            LogWarn("SubscriptionUI", "Guard: m.global is invalid or m.global.MainScene is invalid - ShowSubscriptionDialog skipped")
            return
        end if

        scene = m.global.MainScene
        if scene = invalid
            return
        end if

        ' Create dialog group
        dialog = CreateObject("roSGNode", "Group")
        dialog.id = "subDialog"

        ' Background
        bg = CreateObject("roSGNode", "Rectangle")
        bg.id = "subDialogBg"
        bg.width = 800
        bg.height = 400
        bg.color = "0x16213E"
        bg.cornerRadius = 16

        ' Title
        titleLabel = CreateObject("roSGNode", "Label")
        titleLabel.id = "subDialogTitle"
        titleLabel.text = title
        titleLabel.font = "font:BoldSystemFont"
        titleLabel.color = "0xE8B931"
        titleLabel.horizAlign = "center"
        titleLabel.translation = "[400, 60]"
        titleLabel.width = 700

        ' Message
        msgLabel = CreateObject("roSGNode", "Label")
        msgLabel.id = "subDialogMessage"
        msgLabel.text = message
        msgLabel.font = "font:MediumSystemFont"
        msgLabel.color = "0xFFFFFF"
        msgLabel.horizAlign = "center"
        msgLabel.translation = "[400, 130]"
        msgLabel.width = 700
        msgLabel.wrap = true
        msgLabel.numLines = 5

        ' OK Button
        okButton = CreateObject("roSGNode", "Button")
        okButton.id = "subDialogOk"
        okButton.label = buttonText
        okButton.width = 200
        okButton.height = 50
        okButton.translation = "[400, 320]"
        okButton.backgroundColor = "0xE8B931"
        okButton.focusColor = "0xFFFFFF"
        okButton.textColor = "0x1A1A2E"
        okButton.font = "font:BoldSystemFont"

        dialog.appendChild(bg)
        dialog.appendChild(titleLabel)
        dialog.appendChild(msgLabel)
        dialog.appendChild(okButton)

        ' Observe button select
        okButton.ObserveField("select", "OnSubDialogOk")

        ' Store callback reference
        if callback <> invalid
            m.subDialogCallback = callback
        end if

        ' Add to scene
        scene.appendChild(dialog)
        okButton.SetFocus(true)

        LogInfo("SubscriptionUI", "Dialog shown: " + title)
    catch e
        SafeLog("ERROR", "ShowSubscriptionDialog", "Error: " + e.message)
    end try
end sub

' Handle OK button selection
sub OnSubDialogOk()
    try
        if m.subDialogCallback <> invalid
            m.subDialogCallback()
        end if
    catch e
        SafeLog("ERROR", "OnSubDialogOk", "Error: " + e.message)
    end try
end sub


' Close the subscription dialog
sub CloseSubDialog()
    try
        scene = invalid
        if m.global <> invalid and m.global.MainScene <> invalid
            scene = m.global.MainScene
        end if

        if scene <> invalid
            dialog = scene.FindNode("subDialog")
            if dialog <> invalid
                ' Unobserve okButton before removing from scene
                okButton = dialog.FindNode("subDialogOk")
                if okButton <> invalid
                    okButton.UnobserveField("select")
                end if
                scene.removeChild(dialog)
            end if
        end if
    catch e
        SafeLog("ERROR", "CloseSubDialog", "Error: " + e.message)
    end try
end sub

' ============================================================
' Plan Card Creation
' ============================================================

' Create a plan card node for display in a grid/list
' Parameters:
'   plan — plan object from GetSubscriptionPlans()
'   isSelected — whether this plan is currently selected
' Returns: roSGNode (ContentNode) representing the plan card
function CreatePlanCardNode (plan, isSelected) as object
    try
        card = CreateObject("roSGNode", "ContentNode")

        if plan = invalid
            return card
        end if

        ' Store plan data
        card.id = plan.id
        card.title = plan.name
        card.description = ""
        card.hdPosterUrl = ""
        card.isPopular = plan.isPopular
        card.isSelected = isSelected

        ' Build feature list for description
        features = ""
        if plan.features <> invalid
            for i = 0 to plan.features.Count() - 1
                if i > 0
                    features = features + "\n"
                end if
                features = features + "• " + plan.features[i]
            end for
        end if
        card.description = features

        ' Format the price
        card.displayPrice = ""
        if plan.price <> invalid
            dollars = plan.price / 100
            cents = plan.price mod 100
            card.displayPrice = "$" + Int(dollars).ToStr()
            if cents > 0
                card.displayPrice = card.displayPrice + "." + PadLeft(cents.ToStr(), "0", 2)
            end if
            if plan.interval = "year"
                card.displayPrice = card.displayPrice + "/yr"
            else
                card.displayPrice = card.displayPrice + "/mo"
            end if
        end if

        ' Add a monthly equivalent for yearly plans
        if plan.interval = "year" and plan.price <> invalid
            monthlyPrice = plan.price / 12
            card.displayPrice = card.displayPrice + " ($" + Int(monthlyPrice / 100).ToStr() + ".xx/mo)"
        end if

        ' Visual indicators
        card.badgeText = ""
        if plan.isPopular
            card.badgeText = "POPULAR"
        end if

        return card
    catch e
        SafeLog("ERROR", "CreatePlanCardNode", "Error: " + e.message)
        return invalid
    end try
end function

' ============================================================
' Status Badge Creation
' ============================================================

' Create a subscription status badge node
' Parameters:
'   status — subscription status string
' Returns: roSGNode (Label) with status indicator
function CreateStatusBadge (status) as object
    try
        badge = CreateObject("roSGNode", "Label")
        badge.id = "subStatusBadge"

        if status = invalid or status = ""
            badge.text = "No subscription"
            badge.color = "0xA1A0B0"
            badge.font = "font:SmallSystemFont"
        else
            lowerStatus = LCase(status)
            if lowerStatus = "active" or lowerStatus = "trialing"
                badge.text = "✓ Active"
                badge.color = "0x4CAF50" ' Green
            else if lowerStatus = "past_due"
                badge.text = "⚠ Payment Issue"
                badge.color = "0xFF9800" ' Orange
            else
                badge.text = "✗ " + status
                badge.color = "0xFF4444" ' Red
            end if
            badge.font = "font:BoldSystemFont"
        end if

        return badge
    catch e
        SafeLog("ERROR", "CreateStatusBadge", "Error: " + e.message)
        return invalid
    end try
end function

' ============================================================
' Browser Launch
' ============================================================

' Open a URL in the Roku browser (for Stripe Checkout / Customer Portal)
' Parameters:
'   url — URL to open
'   label — label for analytics tracking
' Returns: boolean (success)
function OpenBrowserUrl (url, label) as boolean
    try
        if url = invalid or url = ""
            return false
        end if

        LogInfo("SubscriptionUI", "Opening browser: " + label + " → " + url)

        ' Track the action
        if m.global <> invalid and m.global.analytics <> invalid
            if m.global.analytics.TrackInteraction <> invalid
                m.global.analytics.TrackInteraction("browser_open", "SubscriptionUI", label)
            end if
        end if

        ' Use roAppManager to open the URL
        appMgr = CreateObject("roAppManager")
        if appMgr <> invalid
            ' Use the openURL method to launch the browser
            ' This opens the default browser on the Roku device
            port = CreateObject("roMessagePort")
            appMgr.ObserveFieldRegExp("FocusedScreenChanged", ".+", port)
            appMgr.SetFocusedContentUrl(url)

            ' Wait briefly to see if the browser opens
            msg = wait(3000, port)
            if msg <> invalid
                appMgr.UnobserveFieldRegExp("FocusedScreenChanged", port)
                LogInfo("SubscriptionUI", "Browser opened successfully for: " + label)
                return true
            else
                ' Timeout — clean up observer to prevent leak
                appMgr.UnobserveFieldRegExp("FocusedScreenChanged", port)
            end if

        end if

        ' Fallback: log the URL for manual verification
        LogWarn("SubscriptionUI", "Could not open browser automatically. URL: " + url)
        return false
    catch e
        SafeLog("ERROR", "OpenBrowserUrl", "Error: " + e.message)
        return false
    end try
end function

' ============================================================
' Plan Selection UI Helpers
' ============================================================

' Highlight the selected plan in the UI
' Parameters:
'   planId — the ID of the selected plan
'   planList — the roSGNode list of plan cards
sub HighlightSelectedPlan(planId, planList)
    try
        if planList = invalid or planId = invalid
            return
        end if

        count = planList.Count()
        for i = 0 to count - 1
            card = planList[i]
            if card <> invalid and card.id <> invalid
                if card.id = planId
                    card.isSelected = true
                else
                    card.isSelected = false
                end if
            end if
        next
    catch e
        SafeLog("ERROR", "HighlightSelectedPlan", "Error: " + e.message)
    end try
end sub

' ============================================================
' Error Display
' ============================================================

' Show a subscription error message
' Parameters:
'   title — error title
'   message — error message
sub ShowSubscriptionError(title, message, retryAction)
    try
        LogError("SubscriptionUI", title + ": " + message)

        ' Show the dialog
        buttonText = "OK"
        if retryAction <> invalid
            buttonText = "Retry"
        end if

        ShowSubscriptionDialog(title, message, buttonText, retryAction)
    catch e
        SafeLog("ERROR", "ShowSubscriptionError", "Error: " + e.message)
    end try
end sub
