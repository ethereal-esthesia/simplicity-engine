on run argv
    set vmID to item 1 of argv
    set mediaFile to POSIX file (item 2 of argv)
    tell application "UTM"
        set targetVM to virtual machine id vmID
        if status of targetVM is not stopped then error "Shut down Windows and rerun setup to attach guest tools; the running VM was not changed."
        set config to configuration of targetVM
        set cdCount to 0
        set toolsIndex to 0
        set driveList to drives of config
        repeat with i from 1 to (count of driveList)
            if removable of item i of driveList then
                set cdCount to cdCount + 1
                if cdCount is 2 then set toolsIndex to i
            end if
        end repeat
        if cdCount > 2 then error "Multiple extra removable drives found; select guest tools manually in UTM."
        if toolsIndex is 0 then
            set existingDrives to drives of config
            set toolsIndex to (count of existingDrives) + 1
            set drives of config to existingDrives & {{removable:true, interface:USB, source:mediaFile}}
        else
            set toolsID to id of item toolsIndex of drives of config
            set item toolsIndex of drives of config to {id:toolsID, source:mediaFile}
        end if
        update configuration of targetVM with config
        set verifiedConfig to configuration of targetVM
        return host size of item toolsIndex of drives of verifiedConfig
    end tell
end run
