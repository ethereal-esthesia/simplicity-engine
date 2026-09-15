on run argv
    tell application "UTM"
        repeat 20 times
            try
                set v to virtual machine id (item 1 of argv)
                return id of v
            end try
            delay 0.5
        end repeat
        error "UTM did not register the requested VM."
    end tell
end run
