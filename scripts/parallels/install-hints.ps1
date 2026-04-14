function Get-ParallelsInstallHint {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Platform,
        [Parameter(Mandatory=$true)]
        [string]$Command,
        [string]$RerunHint = "rerun the previous command"
    )

    $package = switch ("${Platform}:${Command}") {
        "windows:git" { "Git for Windows"; break }
        "windows:cmake" { "CMake"; break }
        "windows:ninja" { "Ninja"; break }
        "windows:compiler" { "Visual Studio Build Tools with the C++ workload"; break }
        "windows:cl" { "Visual Studio Build Tools with the C++ workload"; break }
        "linux:compiler" { "a C/C++ compiler toolchain such as build-essential"; break }
        default { $Command }
    }
    $platformName = switch ($Platform) {
        "windows" { "Windows"; break }
        "linux" { "Linux"; break }
        default { $Platform }
    }

    "${Command} was not found in the ${platformName} VM. Please install ${package}, then ${RerunHint}. See README.md for installation details."
}
