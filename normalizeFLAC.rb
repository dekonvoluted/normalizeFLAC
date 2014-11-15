#!/usr/bin/env ruby

# Normalizes FLAC files one directory at a time
# Reencodes FLAC files (removing non-standard tags)

require 'tmpdir'
require 'optparse'

# Normalize a single FLAC file
class FlacFile
    def initialize filePath
        if File.file?( filePath )
            if File.extname( filePath ) == ".flac"
                @filePath = File.absolute_path( filePath )
                @baseName = File.basename( @filePath )
                puts @baseName
                @dirName = File.dirname( @filePath )
                @albumArt = File.file?( "#{@dirName}/album.jpg" )
                @validFile = true
                %x( flac --silent --test "#{@filePath}" )
                if $?.exitstatus != 0
                    @validFile = false
                end
            end
        end
    end

    # Normalize FLAC files
    def normalize
        return if not @validFile

        %x( flac --silent --force "#{@filePath}" )
        if $?.exitstatus != 0
            reencode
        else
            %x( metaflac --preserve-modtime --add-replay-gain "#{@filePath}" )
            if $?.exitstatus != 0
                puts "Replay gain error."
            end
        end
    end

    # Reencode FLAC files
    def reencode
        puts "Removing ID3 tags."

        Dir.mktmpdir do | tmpDir |
            FileUtils.cd( tmpDir ) do
                FileUtils.cp( @filePath, "original.flac" )

                # Decode file
                # Export tags
                %x( flac --silent --decode --output-name=original.wav original.flac )
                %x( metaflac --export-tags-to=metadata.ini original.flac )

                # Encode file
                # Import tags
                %x( flac --silent --force --output-name="#{@filePath}" original.wav )
                %x( metaflac --import-tags-from=metadata.ini "#{@filePath}" )
            end

            # Embed album art, if found
            if @albumArt
                %x( metaflac --import-picture-from="#{@dirName}/album.jpg" "#{@filePath}" )
            end

            # Calculate replay gain
            %x( metaflac --add-replay-gain "#{@filePath}" )
        end
    end
    private :reencode
end

# Process a single directory recursively
def processDir( dirPath )
    return if not File.directory?( dirPath )

    puts File.basename( dirPath ) + "/"

    Dir.foreach( dirPath ) do | content |
        next if content == "." or content == ".."

        contentPath = dirPath + "/" + content
        next if File.symlink?( contentPath )

        if File.directory?( contentPath )
            processDir contentPath
        elsif File.file?( contentPath )
            fork do
                flacFile = FlacFile.new contentPath
                flacFile.normalize
            end
        end
    end

    Process.wait
end

# Process an input argument
def process( input )
    if not File.exists?( input )
        puts "ERROR. #{input} not found."
        return
    end

    inputPath = File.absolute_path( input )

    if File.file?( input )
        flacFile = FlacFile.new inputPath
        flacFile.normalize
    elsif File.directory?( inputPath )
        if not File.symlink?( inputPath )
            processDir inputPath
        end
    end
end

if __FILE__ == $0

    optparse = OptionParser.new do | opts |
        opts.banner = "Usage: #{$0} [-h|--help] [FILE|DIR] [FILE|DIR] ..."

        opts.on( '-h', '--help', '''Display help.

This script will reencode FLAC files and apply replay gain normalization. The replay gain values will be written in the Vorbis tags.

The script takes no options. If called with -h or --help, it prints this help message and exits.

Each file passed an an argument will be reencoded and normalized. Each directory passed as an argument will be recursively searched for FLAC files which will then be reencoded and normalized.

Files and directories that are symlinked will be avoided to prevent any infinite loops.

Files in the same directory will be processed altogether, at the same time. This can take up system resources if the directory contains a large number of FLAC files.''' ) do
            puts opts
            exit
        end
    end

    optparse.parse!

    ARGV.each do | input |
        process input
    end
end

