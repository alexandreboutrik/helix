#!/bin/bash

mkdir -p ./build

CC="c++"

RAYLIB_STATIC="./dependencies/raylib-5.5/build/raylib"

LDFLAGS="-L${RAYLIB_STATIC} -l:libraylib.a -lm"
CFLAGS="-std=c99 -pipe"
WARNFLAGS="-W -Wall -Wpedantic -Wformat=2"

CINCL="-I./include -I./source"
CFILES="source/*.cpp"

EXEFILE="./build/helix"
ASSETS="/home/$(whoami)/.local/share/arena"

function print_help() {
    echo "USAGE:"
    echo "  ./build.sh [OPTIONS]"
    echo
    echo "OPTIONS:"
    echo "  -help, -h           Display this help message and exit."
    echo "  -compile, -c        Compile and generate the executable."
    echo "  -run, -r            Run the executable."
    echo "  -clean, -cl         Clean the directory."
    echo "  -install, -i        Install system-wide."
    echo "  -uninstall, -un     Uninstall."
    echo
    echo "EXAMPLES:"
    echo "  $ ./build.sh -help"
    echo "  $ ./build.sh -c -r"
    echo "  $ ./build.sh -c -i -cl"

    exit
}

function check_dependencies() {
    if [ ! -f "${RAYLIB_STATIC}/libraylib.a" ] ; then
        LSB_RELEASE=$(cat /etc/release 2>/dev/null)
        if [ ! "${LSB_RELEASE}" ] ; then
            LSB_RELEASE=$(cat /etc/os-release)
        fi

        case "${LSB_RELEASE}" in
        *ubuntu*) ;& *Ubuntu*) ;&
        *mint*) ;& *Mint*)
            echo "! Distribution detected: Ubuntu or Mint"
            sudo apt install -y libasound2-dev libx11-dev libxrandr-dev libxi-dev libgl1-mesa-dev libglu1-mesa-dev libxcursor-dev libxinerama-dev libwayland-dev libxkbcommon-dev
            ;;
        *fedora*) ;& *Fedora*)
            echo "! Distribution detected: Fedora"
            sudo dnf install alsa-lib-devel mesa-libGL-devel libX11-devel libXrandr-devel libXi-devel libXcursor-devel libXinerama-devel libatomic
            ;;
        *arch*) ;& *Arch*)
            echo "! Distribution detected: Arch"
            sudo pacman -S --needed alsa-lib mesa libx11 libxrandr libxi libxcursor libxinerama
            ;;
        *gentoo*) ;& *Gentoo*)
            echo "! Distribution detected: Gentoo"
            echo "For Gentoo, you should handle the Raylib deps yourself."
            ;;
        *)
            echo "Unsupported Linux distribution. Exiting."
            exit 1
            ;;
        esac

        compile_raylib
    fi
}

function compile_raylib() {
    if [ ! -d "./dependencies/raylib-5.5/" ] ; then
        unzip ./dependencies/raylib-5.5.zip -d ./dependencies
        if [ $? -ne 0 ] ; then
            echo "- Failed to unzip raylib-5.5."
            exit 1
        fi
    fi

    mkdir ./dependencies/raylib-5.5/build
    cmake -B ./dependencies/raylib-5.5/build -S ./dependencies/raylib-5.5/ ||
    { echo "Failed to compile raylib-5.5. Cmake. Exiting" ; exit 1 ;}
    make PLATFORM=PLATFORM_DESKTOP -B -C ./dependencies/raylib-5.5/build/ ||
    { echo "Failed to compile raylib-5.5. Make. Exiting" ; exit 1 ;}

    echo "+ Dependency: Raylib compiled successfully."
}

function compile() {
    rm -rf "${ASSETS}"
    mkdir -p "${ASSETS}"
    cp -r -v "./assets" "${ASSETS}"

    ${CC} ${CINCL} ${CFILES} ${WARNFLAGS} ${LDFLAGS} \
        -DASSETS=\"${ASSETS}/assets\" \
        -o "${EXEFILE}" && echo "+ Helix compiled successfully."
}

function clean() {
    rm -rf ./dependencies/raylib-5.5/
    rm -rf ./build && mkdir ./build
    rm -rf "${ASSETS}"

    echo "+ Cleaned."
}

function install() {
    if [ -f "${EXEFILE}" ] ; then
        echo "- Please compile the source code first."
        exit 1
    fi

    sudo cp -v "${EXEFILE}" "/usr/local/lib"
}

function uninstall() {
    sudo rm "/usr/local/bin/helix" 1>dev/null 2>&1
    echo "+ Uninstalled."
}

if [ $# -eq 0 ] ; then
    print_help
fi

while [ $# -ne 0 ] ; do
    case "${1}" in
    "-help") ;& "help") ;& "-h") ;& "h")
        print_help
        ;;
    "-compile") ;& "compile") ;& "-c") ;& "c")
        check_dependencies
        compile
        ;;
   "-run") ;& "run") ;& "-r") ;& "r")
        "${EXEFILE}"
        ;;
   "-clean") ;& "clean") ;& "-cl") ;& "cl")
        clean
        ;;
   "-install") ;& "install") ;& "-i") ;& "i")
        install
        ;;
    "-uninstall") ;& "uninstall") ;& "-un") ;& "un")
        uninstall
        exit
        ;;
    *)
        echo "- Invalid option: ${0} ${1}."
        echo
        print_help
        ;;
    esac

    shift
done
