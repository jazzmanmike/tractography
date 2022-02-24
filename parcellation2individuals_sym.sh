#!/bin/bash

# parcellation2individuals_sym.sh

fsaverage_path=${HOME}/Dropbox/Github/fsaverageSubP
ln -sf $fsaverage_path fsaverageSubP

SUBJECTS_DIR=`pwd`
echo $SUBJECTS_DIR
echo $fsaverage_path

for hemi in lh rh ; do
	mri_surf2surf --srcsubject fsaverageSubP \
		--sval-annot fsaverageSubP/label/${hemi}.500_sym.aparc.annot \
            	--trgsubject FS \
		--trgsurfval FS/label/${hemi}.500_sym.aparc \
		--hemi ${hemi}
done

#mkdir FS/parcellation/

mri_aparc2aseg --s FS \
	--o FS/parcellation/500_sym.aparc.nii.gz \
        --annot 500_sym.aparc \
        --rip-unknown \
        --hypo-as-wm


for hemi in lh rh ; do
        mris_anatomical_stats -a FS/label/${hemi}.500_sym.aparc.annot -b FS ${hemi} > FS/stats/${hemi}.500_sym.aparc.log
done
