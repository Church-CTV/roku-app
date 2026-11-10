' SubscriptionManager.brs - Subscription management for Roku Channel Template
' Handles: checkout, status checks, cancellation, and local state persistence

sub InitSubscriptionManager(config as object)
    if m.global = invalid
        LogError("SubscriptionManager", "global node is invalid")
        return
    end if

    m.config = config
    m.serverUrl = ""
    if m.config <> invalid and m.config.serverUrl <> invalid
        m.serverUrl = m.config.serverUrl
    else
        m.serverUrl = ""
    end if
    if m.serverUrl = ""
        LogWarn("SubscriptionManager", "serverUrl not configured — checkout and status checks will be disabled")
    end if

    LogInfo("SubscriptionManager", "Initialized with server: " + m.serverUrl)
    LoadStoredSubscription()
end sub

' Get the local subscription state
function GetSubscriptionState () as object
    try
        state = CreateObject("roAssociativeArray")
        state.subscriberId = m.global.GetField("SubscriberId")
        state.customerId = m.global.GetField("CustomerId")
        state.subscriptionId = m.global.GetField("SubscriptionId")
        state.status = m.global.GetField("SubscriptionStatus")
        state.planId = m.global.GetField("PlanId")
        state.planName = m.global.GetField("PlanName")
        state.active = (state.status = "active")
        return state
    catch e
        SafeLog("ERROR", "GetSubscriptionState", "Error: " + e.message)
        return invalid
    end try
end function

' Start a checkout session for a subscription plan
function StartCheckout (productId as string, email as string) as boolean
    if productId = "" or email = ""
        LogError("SubscriptionManager", "productId and email are required")
        return false
    end if

    if m.serverUrl = ""
        LogError("SubscriptionManager", "serverUrl not configured")
        return false
    end if

    url = m.serverUrl + "/api/checkout"
    try
        postData = FormatJson({ productId: productId, customerEmail: email })
    catch e
        LogError("SubscriptionManager", "FormatJson failed in StartCheckout: " + e.message)
        return false
    end try

    LogInfo("SubscriptionManager", "Starting checkout: " + url)
    emailMasked = Left(email, 3) + "***@***.com"
    LogInfo("SubscriptionManager", "Product: " + productId + ", Email: " + emailMasked)

    http = CreateObject("roUrlTransfer")
    if http = invalid
        LogError("SubscriptionManager", "Failed to create roUrlTransfer for purchase")
        return false
    end if
    http.SetUrl(url)
    http.AddHeader("Content-Type", "application/json")
    http.SetRequest("POST")
    http.SetConnectTimeout(15)
    http.SetCertificatesFile("common:/certs/ca-bundle.crt")
    http.EnableSslCertificates(true)

    statusCode = http.Post(postData)

    if statusCode = 200
        responseText = http.GetString()
        LogInfo("SubscriptionManager", "Checkout response: " + responseText)

        try
            response = ParseJson(responseText)
            if response <> invalid and response.url <> invalid
                LogInfo("SubscriptionManager", "Checkout URL: " + response.url)
            else
                LogWarn("SubscriptionManager", "Checkout response missing URL")
            end if
        catch e
            LogError("SubscriptionManager", "ParseJson error in StartCheckout: " + e.message)
        end try
    else
        LogWarn("SubscriptionManager", "Checkout failed with status: " + statusCode.ToStr())
    end if

    ' Release roUrlTransfer after all HTTP operations complete
    http = invalid

    return statusCode = 200
end function

' Check subscription status from the server
function CheckSubscriptionStatus (subscriberId as string) as object
    if subscriberId = ""
        LogError("SubscriptionManager", "subscriberId is required")
        return invalid
    end if

    if m.serverUrl = ""
        LogError("SubscriptionManager", "serverUrl not configured")
        return invalid
    end if

    url = m.serverUrl + "/api/subscription/status?subscriberId=" + subscriberId

    LogInfo("SubscriptionManager", "Checking status for: " + subscriberId)

    http = CreateObject("roUrlTransfer")
    if http = invalid
        LogError("SubscriptionManager", "Failed to create roUrlTransfer for status check")
        return invalid
    end if
    http.SetUrl(url)
    http.SetConnectTimeout(15)
    http.SetHeaders([])
    http.SetCertificatesFile("common:/certs/ca-bundle.crt")
    http.EnableSslCertificates(true)

    responseText = http.Get()
    statusCode = http.GetResponseCode()

    ' Release roUrlTransfer immediately after HTTP operations complete
    http = invalid

    if statusCode <> 200
        LogError("SubscriptionManager", "HTTP error status: " + statusCode.ToStr())
        return invalid
    end if

    if responseText = invalid or responseText = ""
        LogError("SubscriptionManager", "Empty or invalid response from server")
        return invalid
    end if

    LogInfo("SubscriptionManager", "Status response: " + responseText)

    try
        response = ParseJson(responseText)
        if response = invalid
            LogError("SubscriptionManager", "Failed to parse server response as JSON")
            return invalid
        end if
        return response
    catch e
        LogError("SubscriptionManager", "ParseJson error in CheckSubscriptionStatus: " + e.message)
        return invalid
    end try
end function

' Cancel subscription
function CancelSubscription (subscriberId as string) as boolean
    if subscriberId = ""
        LogError("SubscriptionManager", "subscriberId is required")
        return false
    end if

    if m.serverUrl = ""
        LogError("SubscriptionManager", "serverUrl not configured")
        return false
    end if

    url = m.serverUrl + "/api/subscription/cancel"
    try
        postData = FormatJson({ subscriberId: subscriberId })
    catch e
        LogError("SubscriptionManager", "FormatJson failed in CancelSubscription: " + e.message)
        return false
    end try

    LogInfo("SubscriptionManager", "Cancelling subscription: " + subscriberId)

    http = CreateObject("roUrlTransfer")
    if http = invalid
        LogError("SubscriptionManager", "Failed to create roUrlTransfer for cancellation")
        return false
    end if
    http.SetUrl(url)
    http.AddHeader("Content-Type", "application/json")
    http.SetRequest("POST")
    http.SetConnectTimeout(15)
    http.SetCertificatesFile("common:/certs/ca-bundle.crt")
    http.EnableSslCertificates(true)

    statusCode = http.Post(postData)

    if statusCode = 200
        responseText = http.GetString()
        LogInfo("SubscriptionManager", "Cancel response: " + responseText)

        try
            response = ParseJson(responseText)
            if response <> invalid and response.status <> invalid
                if response.status = "cancelled"
                    StoreSubscription(subscriberId, response.customerId, response.subscriptionId, response.planId, "cancelled")
                else
                    LogWarn("SubscriptionManager", "Cancel response status: " + response.status)
                end if
            end if
        catch e
            LogError("SubscriptionManager", "ParseJson error in CancelSubscription: " + e.message)
        end try
    else
        LogWarn("SubscriptionManager", "Cancel failed with status: " + statusCode.ToStr())
    end if

    ' Release roUrlTransfer after all HTTP operations complete
    http = invalid

    return statusCode = 200
end function

' Store subscription data locally
sub StoreSubscription(subscriberId as string, customerId as string, subscriptionId as string, planId as string, status as string)
    if m.global = invalid
        return
    end if

    m.global.AddReplace("SubscriberId", subscriberId)
    m.global.AddReplace("CustomerId", customerId)
    m.global.AddReplace("SubscriptionId", subscriptionId)
    m.global.AddReplace("PlanId", planId)
    m.global.AddReplace("SubscriptionStatus", status)

    LogInfo("SubscriptionManager", "Stored subscription: " + subscriberId + " -> " + status)

    ' Also save to roRegistry for persistence across app restarts
    registry = CreateObject("roRegistry")
    if registry <> invalid
        ' roRegistry uses prefixed keys instead of Init() sections
        prefix = "sub_"
        prefData = CreateObject("roAssociativeArray")
        prefData.subscriberId = subscriberId
        prefData.customerId = customerId
        prefData.subscriptionId = subscriptionId
        prefData.planId = planId
        prefData.status = status
        prefData.updatedAt = GetTimestamp()

        try
            registry.WriteString(prefix + "data", FormatJson(prefData))
            LogInfo("SubscriptionManager", "Subscription saved to registry")
        catch e
            LogWarn("SubscriptionManager", "Failed to save to registry: " + e.message)
        end try
    end if
end sub

' Load stored subscription from roRegistry
sub LoadStoredSubscription()
    if m.global = invalid
        return
    end if

    registry = CreateObject("roRegistry")
    if registry = invalid
        LogWarn("SubscriptionManager", "roRegistry is invalid")
        return
    end if

    ' roRegistry uses prefixed keys instead of Init() sections
    prefix = "sub_"

    try
        prefData = registry.ReadString(prefix + "data")
        if prefData <> invalid and prefData <> ""
            data = ParseJson(prefData)
            if data <> invalid
                m.global.AddReplace("SubscriberId", data.subscriberId)
                m.global.AddReplace("CustomerId", data.customerId)
                m.global.AddReplace("SubscriptionId", data.subscriptionId)
                m.global.AddReplace("PlanId", data.planId)
                m.global.AddReplace("SubscriptionStatus", data.status)
                LogInfo("SubscriptionManager", "Loaded subscription: " + data.status)
            else
                ClearStoredSubscription()
            end if
        else
            ClearStoredSubscription()
        end if
    catch e
        LogWarn("SubscriptionManager", "Error loading subscription from registry: " + e.message)
        ClearStoredSubscription()
    end try
end sub

' Clear stored subscription
sub ClearStoredSubscription()
    if m.global = invalid
        return
    end if

    m.global.AddReplace("SubscriberId", "")
    m.global.AddReplace("CustomerId", "")
    m.global.AddReplace("SubscriptionId", "")
    m.global.AddReplace("PlanId", "")
    m.global.AddReplace("SubscriptionStatus", "")

    LogInfo("SubscriptionManager", "Cleared subscription state")
end sub


