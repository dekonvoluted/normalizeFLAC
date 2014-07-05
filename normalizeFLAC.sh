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

	This script will reencode FLAC files and apply replay gain normalization. The replay gain values will be written in the Vorbis comments tags.

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

normalize()
{
    # Find FLAC files
    if [[ "${1}" != *.flac ]]
    then
        return
    fi

    # Act only on regular files
    if [ -h "${1}" ]
    then
        echo $PROGNAME: Avoiding link "${1}"
        return
    fi

    # Re-encode and normalize
    flac --silent --force "${1}" || echo -n $PROGNAME: "Encoding error: "
    metaflac --preserve-modtime --add-replay-gain "${1}" || echo -n $PROGNAME: "Replay gain error: "

    echo $(basename "${1}")
}

processDir()
{
    echo $(basename "${1}")/

    for content in "${1}"/*
    do
        if [ -f "${content}" ]
        then
            normalize "${content}"
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
        normalize "${ARG}"
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

