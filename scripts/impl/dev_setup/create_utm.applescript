on run argv
    set vmName to item 1 of argv
    set archName to item 2 of argv
    set mediaFile to POSIX file (item 3 of argv)
    set destinationFile to POSIX file (item 4 of argv)
    set ramMiB to (item 5 of argv) as integer
    set diskMiB to (item 6 of argv) as integer
    set coreCount to (item 7 of argv) as integer
    set displayName to "virtio-ramfb"
    if archName is "x86_64" then set displayName to "virtio-vga"
    tell application "UTM"
        with timeout of 600 seconds
            set newVM to make new virtual machine with properties {backend:qemu, configuration:{name:vmName, architecture:archName, memory:ramMiB, cpu cores:coreCount, hypervisor:true, uefi:true, drives:{{removable:true, interface:USB, source:mediaFile}, {guest size:diskMiB, interface:NVMe}}, displays:{{hardware:displayName}}, network interfaces:{{mode:shared}}}}
            -- Export first; retain the staging VM on any failure for recovery.
            export newVM to destinationFile
            return id of newVM
        end timeout
    end tell
end run
