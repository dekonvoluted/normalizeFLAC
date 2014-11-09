#!/usr/bin/env ruby

# Acts on FLAC file(s) or recurses through directory/ies
# Normalizes FLAC file
# Reencodes FLAC file (removing any non-standard tags)

require 'tmpdir'

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

class FlacDir
    def initialize dirPath
        @dirPath = dirPath
    end
end

def process( input )
    if File.file?( input )
        flacFile = FlacFile.new input
        flacFile.normalize
    elsif File.directory?( input )
        if not File.symlink?( input )
            flacDir = FlacDir.new input
        end
    end
end

if __FILE__ == $0
    ARGV.each do | input |
        process input
    end
end

