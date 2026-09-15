on run argv
    tell application "UTM"
        set v to virtual machine id (item 1 of argv)
        if status of v is not stopped then error "Staging VM is running; retained."
        delete v
    end tell
end run
