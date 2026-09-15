on run argv
    set requestedName to item 1 of argv
    tell application "UTM"
        repeat with v in virtual machines
            if name of v is requestedName then error "A registered VM already has this name. Use --vm-path with its actual bundle; no new VM created."
        end repeat
    end tell
end run
