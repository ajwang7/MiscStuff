#!/bin/bash
# Script to transfort .itc files into images (JPG or PNG)
#
# .itc files are located in ~/Music/iTunes/Album Artwork
#
# This script uses (/!\ needs ) ImageMagick's convert, hexdump, printf and dd.
#
# This script might be a little slow, You might want to look at Simon Kennedy's work at http://www.sffjunkie.co.uk/python-itc.html

AlbumArtwork="${HOME}/Music/iTunes/Album Artwork"
DestinationDir="$AlbumArtwork/Images"
IFS=$'\n'


if [ ! -d "$DestinationDir" ]; then
	mkdir "$DestinationDir"
	echo "new Images dir"
fi

for file in `gfind "$AlbumArtwork" -name '*.itc'`; do
	start=0x11C
	exit=0;
	i=1;
	echo $file
	while [ 1 ]; do

		typeOffset=$(($start+0x30))
		imageType=$(hexdump -n 4 -s $typeOffset -e '"0x"4/1 "%02x" "\n"' $file)

		#If there is no next byte, jump to the next itc file.
		if [[ -z $imageType ]]; then
			break
		fi

		imageOffsetOffset=$(($start+8))

		itemSize=$(hexdump -n 4 -s $start -e '"0x"4/1 "%02x" "\n"' $file)
		imageOffset=$(hexdump -n 4 -s $imageOffsetOffset -e '"0x"4/1 "%02x" "\n"' $file)

		imageStart=$(($start+$imageOffset))
		imageSize=$(($itemSize-imageOffset))

		imageWidth=$(hexdump -n 4 -s $(($start+56)) -e '"0x"4/1 "%02x" "\n"' $file)
		imageWidth=$(printf "%d" $imageWidth)
		imageHeight=$(hexdump -n 4 -s $(($start+60)) -e '"0x"4/1 "%02x" "\n"' $file)
		imageHeight=$(printf "%d" $imageHeight)

		dir=$(dirname "$file")
		xbase=${file##*/} #file.etc
		xpref=${xbase%.*} #file prefix

		#echo $file
		#echo itemsize $itemSize
		#echo start $start
		#echo imageOffset $imageOffset
		#echo imageStart $imageStart
		#echo imageSize $imageSize
		#echo imageWidth $imageWidth
		#echo imageHeight $imageHeight

		if [[ $imageType -eq 0x504E4766 ]] || [[ $imageType -eq 0x0000000E ]] ; then
			targetFile="$DestinationDir/$xpref-$i.png"
			if [ ! -f "$targetFile" ]; then
				echo PNG
				dd skip=$imageStart count=$imageSize if="$file" of="$targetFile" bs=1 &> /dev/null
			fi
		elif [[ $imageType -eq 0x41524762 ]] ; then
			targetFile="$DestinationDir/$xpref-$i.png"
			if [ ! -f "$targetFile" ]; then
				echo ARGB
				dd skip=$imageStart count=$imageSize if="$file" of="$TMPDIR/test$i" bs=1 &> /dev/null

				#Using a matrix to convert ARGB to RGBA since imagemagick does only support rgba input
				convert -size $imageWidth"x"$imageHeight -depth 8 -color-matrix '0 1 0 0 0 0 1 0 0 0 0 1 1 0 0 0' rgba:"$TMPDIR/test$i" "$targetFile"
			fi
		elif [[ $imageType -eq 0x0000000D ]] ; then
			targetFile="$DestinationDir/$xpref-$i.jpg"
			if [ ! -f "$targetFile" ]; then
				echo JPG
				dd skip=$imageStart count=$imageSize if="$file" of="$targetFile" bs=1 &> /dev/null
			fi
		else
			echo $imageType
			exit=1
			break;
		fi

		start=$(($start+$itemSize))
		i=$(($i+1))
	done
done
