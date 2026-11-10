' StateExporterTask.brs - Registry-based state bridge for ECP state tracking
' Runs as a Task in its own scope to avoid function name conflicts
' Writes app state snapshots to device registry under section "E2EState"
' E2E tests can read state via GET /query/registry/dev

sub Init()
    m.top.functionName = "ExportState"
    m.exportCount = 0
    m.registryAvailable = false

    ' Use roRegistrySection for E2E state persistence
    m.registry = invalid
    try
        m.registry = CreateObject("roRegistrySection", "E2EState")
        if m.registry <> invalid
            m.registryAvailable = true
        end if
    catch e
        print "ERROR", "StateExporterTask", "Failed to initialize registry: " + e.message
        m.registry = invalid
        m.registryAvailable = false
    end try
end sub

' Called by Task framework when control = "run" or via CallFunc("ExportNow")
sub ExportState()
    if m.registry = invalid or m.registryAvailable = false then return

    ' Accept state from either m.top.state or m.args
    state = invalid
    if m.top.state <> invalid
        state = m.top.state
    else if m.args <> invalid and m.args.state <> invalid
        state = m.args.state
    end if
    if state = invalid then return

    try
        jsonStr = FormatJson(state)
    catch e
        print "ERROR", "StateExporterTask", "FormatJson failed: " + e.message
        return
    end try
    if jsonStr = invalid or jsonStr = "" then return

    m.registry.Write("snapshot", jsonStr)

    now = CreateObject("roDateTime")
    if now <> invalid
        now.ToLocalTime()
        h = now.GetHours().ToStr()
        mi = now.GetMinutes().ToStr()
        s = now.GetSeconds().ToStr()
        if h.Len() = 1 then h = "0" + h
        if mi.Len() = 1 then mi = "0" + mi
        if s.Len() = 1 then s = "0" + s
        ts = h + ":" + mi + ":" + s
        m.registry.Write("lastExport", ts)
    end if

    m.exportCount = m.exportCount + 1
    m.registry.Write("exportCount", m.exportCount.ToStr())
end sub

' Explicit export trigger - can be called via CallFunc with state in m.args
sub ExportNow()
    ExportState()
end sub
