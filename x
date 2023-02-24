#!/bin/bash

set -e

function debug {
    if [ -n "$XBUILD_DEBUG" ]; then
        echo $1
    fi
}

function print_step {
    echo -e "\033[1;32m==== [$1] ====\033[0m"
}

PROJECT_ROOT=$(dirname $(realpath $BASH_SOURCE))

function project_lang_is_valid {
    if [ "$1" == "c++" ]; then
        return 0
    elif [ "$1" == "c" ]; then
        return 0
    fi
    return 1
}

if [ "$1" == "update" ]; then
    print_step "Updating x"

    if ! ping raw.githubusercontent.com -c 1 >> /dev/null; then
        echo "Failed to ping raw.githubusercontent.com"
        exit 1
    fi

    url="https://raw.githubusercontent.com/zacklukem/xbuild/main/x"
    curl -s "$url" > $BASH_SOURCE
    chmod +x x
    exit 0
fi

if [ "$1" == "init" ]; then
    if [ -a "$PROJECT_ROOT/x.config" ]; then
        echo "x.config already exists"
        exit 1
    fi

    if [ -z "$2" ]; then
        print_step "Using default language: c++"
        PROJECT_LANG="c++"
    else
        PROJECT_LANG="$2"
    fi

    if ! project_lang_is_valid $PROJECT_LANG; then
        echo "Invalid language: $PROJECT_LANG"
        echo "Valid languages: c, c++"
        exit 1
    fi

    print_step "Creating new $PROJECT_LANG project"

    PROJECT_NAME=$(basename $PROJECT_ROOT)

    if [ ! -a "CMakeLists.txt" ]; then

        if [ "$PROJECT_LANG" == "c++" ]; then
cmake_cxx_source=$(cat << EOF
cmake_minimum_required(VERSION 3.0)
project($PROJECT_NAME)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED true)

file(GLOB ${PROJECT_NAME}_SOURCES src/*.cpp)

add_executable($PROJECT_NAME \${${PROJECT_NAME}_SOURCES})
EOF
)

            echo "$cmake_cxx_source" >> CMakeLists.txt
        else
cmake_c_source=$(cat << EOF
cmake_minimum_required(VERSION 3.0)
project($PROJECT_NAME)

file(GLOB ${PROJECT_NAME}_SOURCES src/*.c)

add_executable($PROJECT_NAME ${PROJECT_NAME}_SOURCES)
EOF
)

            echo "$cmake_c_source" >> CMakeLists.txt
        fi
    fi

    main_file="src/main.cpp"
    if [ "$PROJECT_LANG" == "c" ]; then
        main_file="src/main.c"
    fi
    # init c++
    if [ ! -a "src" ]; then
        mkdir -p src
        echo "int main() {" >> $main_file
        echo "    return 0;" >> $main_file
        echo "}" >> $main_file
    fi

xconfig_source=$(cat << EOF
PROJECT_NAME=$PROJECT_NAME
PROJECT_LANG=$PROJECT_LANG
EOF
)

clangfmt_source=$(cat << EOF
---
BasedOnStyle: LLVM
IndentWidth: 4
ColumnLimit: 100
PointerAlignment: Left
AlignAfterOpenBracket: BlockIndent
BinPackArguments: false
BinPackParameters: false
AllowShortBlocksOnASingleLine: Empty
AllowShortEnumsOnASingleLine: false
AllowShortFunctionsOnASingleLine: Empty
AllowShortIfStatementsOnASingleLine: Never
AlwaysBreakTemplateDeclarations: Yes
EOF
)

gitignore_source=$(cat << EOF
/build
/.vscode
EOF
)

    echo "$xconfig_source" >> ./x.config
    echo "$clangfmt_source" >> ./.clang-format
    echo "$gitignore_source" >> ./.gitignore

    if [ ! -a ".git" ]; then
        git init >> /dev/null
    fi

    exit 0
fi

if [ ! -f "$PROJECT_ROOT/x.config" ]; then
    echo "x.config not found or was invalid, run './x init' to create it."
    exit 1
fi

source "$PROJECT_ROOT/x.config"

NUM_CPUS=10
CMD_ARG="$1"
ORIGINAL_PWD=$(pwd)

function build {
    print_step "Configuring"
    if [ ! -d build ]; then
        mkdir build
    fi
    cd "$PROJECT_ROOT/build"
    cmake ..

    print_step "Building"
    cmake --build . --parallel $NUM_CPUS
}

function run {
    build
    print_step "Running"
    cd "$PROJECT_ROOT/build"
    ./$PROJECT_NAME
}

function usage {
    echo "Usage: $0 [build|run|fmt|clean|init|update]"
    exit 1
}

case $CMD_ARG in
    build)
        build
        ;;
    run)
        run
        ;;
    fmt)
        print_step "Formatting"
        clang-format -i `find src -name "*.cpp" -or -name "*.hpp" -or -name "*.c" -or -name "*.h"` 
        ;;
    clean)
        print_step "Cleaning"
        rm -rf build
        ;;
    *)
        usage
        ;;
esac

cd $ORIGINAL_PWD
