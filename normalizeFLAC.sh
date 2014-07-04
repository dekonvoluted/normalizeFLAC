#!/bin/bash

# Apply replay gain normalization to FLAC files
# Files are found recursively in the current directory
# A different directory than the current directory may be specified
# A single FLAC file may also be specified

readonly PROGNAME=$(basename $0)

printUsage()
{
    cat <<-EOF
	Usage $PROGNAME [FILE|DIR]

	This script will apply replay gain normalization to FLAC files. The FLAC files are reencoded prior to normalization.

        The script has no options save for the single argument. This argument can be nothing (defaults to the current directory), a specific directory or a FLAC file. In the former two cases, all FLAC files found recursively under the directory will be processed. In the latter case, only the FLAC file will be processed. The script will NOT enter any symlinked directories (as there is a danger of an infinite loop that way).

	The script will process all FLAC files within the same directory (and same level) at the same time. This can take up system resources if the directory has many FLAC files in a flat hierarchy.
	EOF
}

die()
{
    case $1 in
        1)
            echo $PROGNAME: ERROR. Too many arguments.;;
        2)
            echo $PROGNAME: ERROR. "${2}": No such file or directory.;;
        *)
            true;;
    esac
    printUsage
    exit $1
}

processDir()
{
    echo $(basename "${1}")/

    for content in "${1}"/*
    do
        if [ -f "${content}" ]
        then
            echo "File: ${content}"
        elif [ -d "${content}" ]
        then
            [ -h "${content}" ] || processDir "${content}"
        fi
    done

    wait
}

process()
{
    local ARG=$(realpath "${1}")

    if [ -f "${ARG}" ]
    then
        echo "File: ${ARG}"
    elif [ -d "${ARG}" ]
    then
        processDir "${ARG}"
    else
        die 2 "${ARG}"
    fi
}

main()
{
    case $# in
        0)
            process "./";;
        1)
            process "${1}";;
        *)
            die 1
    esac
}

main "$@"

exit 0

