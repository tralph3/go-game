package main

when ODIN_OS == .Windows {
    PACHI_PATH :: "./engines/pachi/pachi.exe"
} else {
    PACHI_PATH :: "./engines/pachi/pachi"
}

PachiDefault :: []string{ PACHI_PATH, "-d", "", "threads=2" }
