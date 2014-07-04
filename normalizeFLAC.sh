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

	The script has no options save for the single argument. This argument can be nothing (defaults to the current directory), a specific directory or a FLAC file. In the former two cases, all FLAC files found recursively under the directory will be processed. In the latter case, only the FLAC file will be processed.

	The script will process all FLAC files within the same directory (and same level) at the same time. This can take up system resources if the directory has many FLAC files in a flat hierarchy.
	EOF
}

die()
{
    case $1 in
        1)
            echo $PROGNAME: ERROR. Too many arguments.;;
        *)
            true;;
    esac
    printUsage
    exit $1
}

main()
{
    case $# in
        0)
            echo "./";;
        1)
            echo "${1}";;
        *)
            die 1
    esac
}

main "$@"

exit 0

