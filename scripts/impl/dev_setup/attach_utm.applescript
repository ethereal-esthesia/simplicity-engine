on run argv
    set vmID to item 1 of argv
    set mediaFile to POSIX file (item 2 of argv)
    tell application "UTM"
        set targetVM to virtual machine id vmID
        if status of targetVM is not stopped then error "Stop this VM before changing its installation media."
        set config to configuration of targetVM
        set removableID to id of item 1 of drives of config
        set item 1 of drives of config to {id:removableID, source:mediaFile}
        update configuration of targetVM with config
        set verifiedConfig to configuration of targetVM
        return host size of item 1 of drives of verifiedConfig
    end tell
end run
