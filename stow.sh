#!/bin/sh

# MIT License
#
# Copyright (c) 2024 Luca Saccarola
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -ef

PROG_NAME=$(basename "$0")
SRC="$PWD"
SRC_NAME=$(basename "$SRC")
DST=..

panic() { printf "$PROG_NAME: ERROR: %s\n" "$1" >&2 && exit 1; }
version() { echo "$PROG_NAME version 1.0.0"; }

help() {
    version
    cat <<EOF

SYNOPSIS:

    $PROG_NAME [OPTION ...] [-D|-S|-R] PACKAGE ... [-D|-S|-R] PACKAGE ...

OPTIONS:

    -d DIR, --dir=DIR     Set stow dir to DIR (default is current dir)
    -t DIR, --target=DIR  Set target to DIR (default is parent of stow dir)

    -S, --stow            Stow the package names that follow this option
    -D, --delete          Unstow the package names that follow this option
    -R, --restow          Restow (like stow -D followed by stow -S)

    --dotfiles            Enables special handling for dotfiles that are
                          Stow packages that start with "dot-" and not "."

    -n, --no, --simulate  Do not actually make any filesystem changes
    -v, --verbose         Turn on verbose mode
    -V, --version         Show stow version number
    -h, --help            Show this help

EOF
}

__ls() {
    arg="$1"
    [ "$(echo "$arg" | tail -c 2)" = / ] || arg="$1/"
    find "$arg" -maxdepth 1 -mindepth 1
}

# $1: flag to process
__process_flag() {
    # Iterate character by character
    for f in $(echo "$1" | grep -o .); do
        case "$f" in
        v) VERBOSE=1 ;;
        n) SIMULATION=1 ;;
        V) version && exit 0 ;;
        h) help && exit 0 ;;
        esac
    done
}

# $1: package to stow
stow() {
    if [ -d "$SRC/$1" ]; then
        panic "The stow directory $SRC_NAME does not contain package $1"
    fi

    for f in $(__ls "$SRC/$1"); do
        if [ -z "$SIMULATION" ]; then
            out=$(ln -vrs "$f" "$DST" 2>/dev/null)
        fi

        if [ -n "$VERBOSE" ]; then
            base=$(basename "$f")
            dst=$(echo "$out" | awk '{print $3}' | tr -d \')
            echo "LINK: $base => $dst"
        fi
    done
}

# $1: package to delete
delete() {
    if [ -d "$SRC/$1" ]; then
        panic "The stow directory $SRC_NAME does not contain package $1"
    fi

    for f in $(__ls "$SRC/$1"); do
        base=$(basename "$f")
        if [ -z "$SIMULATION" ]; then
            rm "$DST/$base"
        fi

        if [ -n "$VERBOSE" ]; then
            echo "UNLINK: $base"
        fi
    done
}

# $1: package to restow
restow() {
    delete "$1"
    stow "$1"
}

while [ $# -gt 0 ]; do
    case "$1" in
    --version)
        version
        exit 0
        ;;
    --help)
        help
        exit 0
        ;;
    --no | --simulate)
        SIMULATION=1
        ;;
    -d)
        SRC="$2"
        SRC_NAME=$(basename "$SRC")
        shift
        ;;
    --dir=*)
        SRC=$(echo "$2" | cut -d'=' -f2)
        SRC_NAME=$(basename "$SRC")
        shift
        ;;
    -t)
        DST="$2"
        shift
        ;;
    --target=*)
        DST=$(echo "$2" | cut -d'=' -f2)
        shift
        ;;
    -S | --stow)
        while [ $# -gt 0 ]; do
            case "$2" in
            -*) break ;;
            *) stow "$2" ;;
            esac
        done
        ;;
    -R | --restow)
        while [ $# -gt 0 ]; do
            case "$2" in
            -*) break ;;
            *) restow "$2" ;;
            esac
        done
        ;;
    -D | --delete)
        while [ $# -gt 0 ]; do
            case "$2" in
            -*) break ;;
            *) delete "$2" ;;
            esac
        done
        ;;
    -*)
        __process_flag "$1"
        ;;
    *)
        while [ $# -gt 0 ]; do
            case "$1" in
            -*) break ;;
            *) stow "$1" ;;
            esac
        done
        ;;
    esac
    shift
done

[ -n "$SIMULATION" ] && echo "WARNING: in simulation mode so not modifying filesystem."
