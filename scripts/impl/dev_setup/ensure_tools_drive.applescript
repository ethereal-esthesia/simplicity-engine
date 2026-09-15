on run argv
    tell application "UTM"
        set targetVM to virtual machine id (item 1 of argv)
        if status of targetVM is not stopped then error "Shut down Windows before adding the empty CD drive."
        set config to configuration of targetVM
        set driveList to drives of config
        set cdCount to 0
        repeat with d in driveList
            if removable of d then set cdCount to cdCount + 1
        end repeat
        if cdCount < 2 then
            set drives of config to driveList & {{removable:true, interface:USB}}
            update configuration of targetVM with config
        end if
    end tell
end run
