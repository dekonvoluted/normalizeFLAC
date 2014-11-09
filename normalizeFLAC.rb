#!/usr/bin/env ruby

# Acts on FLAC file(s) or recurses through directory/ies
# Normalizes FLAC file
# Reencodes FLAC file (removing any non-standard tags)

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
                @albumArt = File.file?( "#{@dirName}" + "/album.jpg" )
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

        Dir.mktmpdir { |tmpDir|
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
        }
    end
    private :reencode
end

# Process a single directory recursively
def processDir( dirPath )
    return if not File.directory?( dirPath )

    puts File.basename( dirPath ) + '/'

    Dir.foreach( dirPath ) { |content|
        next if content == "." or content == ".."

        contentPath = dirPath + "/" + content
        next if File.symlink?( contentPath )

        if File.directory?( contentPath )
            processDir( contentPath )
        elsif File.file?( contentPath )
            fork do
                flacFile = FlacFile.new contentPath
                flacFile.normalize
            end
        end
    }

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

    optparse = OptionParser.new do |opts|
        opts.banner = "Usage: #{$0} [-h|--help] [FILE|DIR] [FILE|DIR] ..."

        opts.on( '-h', '--help', '''Display help.

This script will reencode FLAC files and apply replay gain normalization. The replay gain values will be written in the Vorbis tags.

The script takes no options. If called with -h or --help, it prints this help message and exits.

Each file passed as an argument will be processed. Each directory passed as an argument will be searched for FLAC files recursively. The script will avoid any symlinked files or directories as there is a danger of entering into an infinite loop that way.

The script will process all FLAC files within the same directory or at the same time. This can take up system resources if the directory has many FLAC files in a flac hierarchy.''' ) do
            puts opts
            exit
        end
    end

    optparse.parse!

    ARGV.each do | input |
        process input
    end
end

