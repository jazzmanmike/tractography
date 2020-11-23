#!/bin/sh

#  tester.sh
#  
#
#  Created by Michael Hart on 05/11/2020.
#

#remove me
tempdir=`pwd`
codedir=${HOME}/code/github/tractography

###Hard Segmentation

mkdir -p ${tempdir}/hardsegmentation

#Thalamus

#Generate cortical targets

#Convert DK parcellation
#mri_convert ${tempdir}/FS/mri/aparc+aseg.mgz ${tempdir}/hardsegmentation/DK_template.nii.gz

#fsl_reorient2std
#fslreorient2std ${tempdir}/hardsegmentation/DK_template.nii.gz ${tempdir}/hardsegmentation/DK_template.nii.gz

#run deparcellator
#***test independently*** - check makes correct reference to files
#echo "renumDesikan_sub('${tempdir}/hardsegmentation/DK_template.nii.gz', 0); exit" > deparcellator_file.m


#***test independently***
#matlab -nodisplay -r deparcellator_file.m

#***test independently***
atlas=
echo "atlas set is: {$atlas}"
if [ $(imtest ${atlas}) == 1 ];
then
    echo "${atlas} dataset ok"
else
    atlas="${codedir}/templates/HarvardOxford.nii.gz"
    echo "No atlas for segmentation has been supplied - using HarvardOxford"
fi

deparcellator.sh ${atlas}
outname=`basename ${atlas} .nii.gz` #for parsing output to probtrackx below
echo "outname is: ${outname}"

#Move individual nucleus (seed) to be segmentated to standard space (i.e. same as target parcellation / atlas)
applywarp --in=${tempdir}/first_segmentation/first-R_Thal_first.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain --warp=${tempdir}/diffusion.bedpostX/xfms/str2standard_warp --out=${tempdir}/hardsegmentation/thalamus_right_MNI.nii.gz

fslmaths ${tempdir}/hardsegmentation/thalamus_right_MNI.nii.gz -bin ${tempdir}/hardsegmentation/thalamus_right_MNI.nii.gz

#Split up targets (hardsegmentation folder)

echo "Running segmentation of thalamus"
#echo "Starting thalamic segmentation" >> $log

#Right thalamus: named targets

probtrackx2 --samples=${tempdir}/diffusion.bedpostX/merged \
--mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
--xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
--invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
--seedref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
--seed=${tempdir}/hardsegmentation/thalamus_right_MNI.nii.gz \
--targetmasks=${outname}_seeds/seeds_targets_list.txt \
--dir=thalamus2cortex_right \
--loopcheck \
--onewaycondition \
--forcedir \
--opd \
--os2t \
--nsamples=5000
       
#hard segmentation
find_the_biggest thalamus2cortex_right/seeds_to_* thalamus2cortex_right/biggest_segmentation


#Alternative segmentation method (hypothesis free): requires subsequent Matlab run for kmeans segmentation

#Make GM cortical mask in MNI space

applywarp --in=${tempdir}/structural.anat/T1_fast_pve_1.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain --warp=${tempdir}/diffusion.bedpostX/xfms/str2standard_warp --out=${tempdir}/hardsegmentation/GM_mask_MNI

fslmaths ${tempdir}/hardsegmentation/GM_mask_MNI -thr 0.95 ${tempdir}/hardsegmentation/GM_mask_MNI

fslmaths ${tempdir}/hardsegmentation/GM_mask_MNI -bin ${tempdir}/hardsegmentation/GM_mask_MNI

#Right thalamus: cortical mask
#some error with missing file - try on laptop - os2t error
probtrackx2 --omatrix2 \
--samples=${tempdir}/diffusion.bedpostX/merged \
--mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
--xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
--invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
--seed=${tempdir}/hardsegmentation/thalamus_right_MNI.nii.gz \
--target2=${tempdir}/hardsegmentation/GM_mask_MNI.nii.gz \
--dir=thalamus2cortex_right_omatrix2 \
--loopcheck \
--onewaycondition \
--forcedir \
--opd \
--nsamples=5000


#Left thalamus


#Pallidum


#Right GPi

#Left GPi
