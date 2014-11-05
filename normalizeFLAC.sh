#!/bin/bash

# Apply replay gain normalization to FLAC files
# Files are found recursively in the current directory
# A different directory than the current directory may be specified
# A single FLAC file may also be specified

readonly PROGNAME=$(basename $0)
readonly ARGS="$@"

printUsage()
{
    cat <<-EOF
	Usage ${PROGNAME} [-h|--help] [FILE|DIR]

	This script will reencode FLAC files and apply replay gain normalization. The replay gain values will be written in the Vorbis comments tags.

	The script takes no options. If called with -h or --help, it prints this message and exits. The script accepts a single argument. This argument can be nothing (defaults to the current directory), a specific directory or a FLAC file. In the former two cases, all FLAC files found recursively under the directory will be processed. In the latter case, only the FLAC file will be processed. The script will NOT enter any symlinked directories (as there is a danger of an infinite loop that way).

	The script will process all FLAC files within the same directory (and at the same level) at the same time. This can take up system resources if the directory has many FLAC files in a flat hierarchy.
	EOF
}

die()
{
    case $1 in
        1)
            echo ${PROGNAME}: ERROR. Unknown argument.;;
        2)
            echo ${PROGNAME}: ERROR. Too many arguments.;;
        3)
            echo ${PROGNAME}: ERROR. "${2}": No such file or directory.;;
        *)
            true;;
    esac
    printUsage
    exit $1
}

reencode()
{
    echo "${PROGNAME}: Removing ID3 tags."

    # Decode and extract metadata to temporary location
    TMP=$(mktemp --directory)
    cp "${1}" $TMP/original.flac
    flac --silent --decode --output-name=$TMP/original.wav $TMP/original.flac
    metaflac --export-tags-to=$TMP/metadata.dat $TMP/original.flac

    # Reencode and import metadata from original file
    flac --silent --output-name="${1}" $TMP/original.wav
    metaflac --import-tags-from=$TMP/metadata.dat "${1}"

    # Embed album art, if found
    DIR=$(dirname "${1}")
    [[ -f "${DIR}"/album.jpg ]] && metaflac --import-picture-from="${DIR}"/album.jpg "${1}"

    # Recalculate replay gain
    metaflac --remove-replay-gain "${1}"
    metaflac --add-replay-gain "${1}"

    # Clean up temporary files
    rm --recursive --force $TMP
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
        echo ${PROGNAME}: Avoiding link "${1}"
        return
    fi

    # Re-encode and normalize
    flac --silent --force "${1}"
    if [[ $? -ne 0 ]]
    then
        reencode "${1}"
    else
        metaflac --preserve-modtime --add-replay-gain "${1}" || echo -n ${PROGNAME}: "Replay gain error: "
    fi

    echo $(basename "${1}")
}

processDir()
{
    echo $(basename "${1}")/

    # Recurse into directory
    for content in "${1}"/*
    do
        if [ -f "${content}" ]
        then
            normalize "${content}" &
        elif [ -d "${content}" ]
        then
            # Act only on regular directories
            if [ -h "${content}" ]
            then
                echo ${PROGNAME}: Avoiding link "${content}"
            else
                processDir "${content}"
            fi
        fi
    done

    # Wait for all files to be processed in a directory before moving on
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
        die 3 "${ARG}"
    fi
}

main()
{
    args=$(getopt --name ${PROGNAME} --options "h" --longoptions "help" -- ${ARGS})

    [ $? -eq 0 ] || die 1

    eval set -- "${args}"

    while test $# -gt 0
    do
        case "${1}" in
            -h|--help)
                die 0;;
            --)
                shift
                break;;
            *)
                shift
                break;;
        esac
        shift
    done

    case $# in
        0)
            process "./";;
        1)
            process "${1}";;
        *)
            die 2
    esac
}

main "$@"

exit 0

