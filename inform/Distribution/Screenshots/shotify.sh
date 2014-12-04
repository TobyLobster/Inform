# Crop images to a regulation size
# Makes the images opaque, replacing alpha with a background colour, and removes the alpha channel

size="1280x800"
background_color="rgb(68,105,152)"

function process {
    file_in=$1
    file_out=$2
    optional_offset=$3
    # get top-left pixel color
    color=`convert $file_in -format "%[pixel: u.p{0,0}]" info:`
    if [ "$color" == "none" ]
    then
        # if top-left pixel is transparent, crop at specific coordinates
        command="convert $file_in -crop $size+56+33 -background $background_color -alpha remove -alpha off $file_out"
        
    else
        if [ "$optional_offset" != "" ]
        then
            command="convert $file_in -crop $size$optional_offset -background $background_color -alpha remove -alpha off $file_out"
        else
            # extract the center of the image
            command="convert $file_in -gravity Center -crop $size+0+0 +repage -background $background_color -alpha remove -alpha off $file_out"
        fi
    fi
    echo $command
    `$command`
}

process inf1.png shot1.png +137+123
process inf2.png shot2.png
process inf3.png shot3.png +132+81
process inf4.png shot4.png
process inf5.png shot5.png
process inf6.png shot6.png +129+62
