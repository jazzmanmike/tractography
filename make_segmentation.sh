#!/bin/bash
set -e

# make_segmentation.sh
#
#
# Michael Hart, St George's University of London, January 2022 (c)

#define
codedir=${HOME}/Dropbox/Github/tractography
basedir="$(pwd -P)"
FSLOUTPUTTYPE=NIFTI_GZ #occassionally not set as standard

#Define atlas
if [ $(imtest ${atlas}) == 1 ];
then
    echo "${atlas} dataset ok"
else
    atlas="${codedir}/templates/Yeo7.nii.gz"
    echo "No atlas for segmentation has been supplied - using the Yeo 7 RSN atlas"
fi

echo "Atlas for hard segmentation is: ${atlas}" >> $log

#Mask atlas by hemisphere (faster & avoids conflict with connectome)
mkdir -p ${tempdir}/segmentation
cd segmentation
cp ${atlas} .
outname=`basename ${atlas} .nii.gz` #for parsing outputs
fslmaths ${atlas} -mas ${codedir}/templates/right_brain.nii.gz ${outname}_right
fslmaths ${atlas} -mas ${codedir}/templates/left_brain.nii.gz ${outname}_left

#Split atlas into individual ROI files
deparcellator.sh ${outname}_right
deparcellator.sh ${outname}_left

cd ../


#Start segmentation: thalamus then GPi, right then left
#NB: nsamples set to 5000 at start


#Thalamus

echo "Running segmentation of thalamus"
echo "Starting thalamic segmentation" >> $log

#Right thalamus

#Move individual nucleus (seed) to be segmentated to standard space (i.e. same as target parcellation / atlas)
applywarp --in=${tempdir}/first_segmentation/first-R_Thal_first.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain --warp=${tempdir}/diffusion.bedpostX/xfms/str2standard_warp --out=${tempdir}/segmentation/thalamus_right_MNI.nii.gz

fslmaths ${tempdir}/segmentation/thalamus_right_MNI.nii.gz -bin ${tempdir}/segmentation/thalamus_right_MNI.nii.gz


#Seed to target
probtrackx2 --samples=${tempdir}/diffusion.bedpostX/merged \
--mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
--xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
--invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
--seedref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
--seed=${tempdir}/segmentation/thalamus_right_MNI.nii.gz \
--targetmasks=${tempdir}/segmentation/${outname}_right_seeds/seeds_targets_list.txt \
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
applywarp --in=${tempdir}/structural.anat/T1_fast_pve_1.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain --warp=${tempdir}/diffusion.bedpostX/xfms/str2standard_warp --out=${tempdir}/segmentation/GM_mask_MNI

fslmaths ${tempdir}/segmentation/GM_mask_MNI -thr 0.5 ${tempdir}/segmentation/GM_mask_MNI #generous threshold

fslmaths ${tempdir}/segmentation/GM_mask_MNI -bin ${tempdir}/segmentation/GM_mask_MNI

#omatrix2
probtrackx2 --omatrix2 \
--samples=${tempdir}/diffusion.bedpostX/merged \
--mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
--xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
--invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
--seed=${tempdir}/segmentation/thalamus_right_MNI.nii.gz \
--target2=${tempdir}/segmentation/GM_mask_MNI.nii.gz \
--dir=thalamus2cortex_right_omatrix2 \
--loopcheck \
--onewaycondition \
--forcedir \
--opd \
--nsamples=5000

echo "kmeans segmentation in Matlab"
cd thalamus2cortex_right_omatrix2
file_matlab=temp_Segmentation
echo "segmentation_clustering;exit" > ${file_matlab}.m
matlab -nodisplay -r "${file_matlab}"
fslcpgeom fdt_paths clusters
cd ..

#Left thalamus

#Move individual nucleus (seed) to be segmentated to standard space (i.e. same as target parcellation / atlas)
applywarp --in=${tempdir}/first_segmentation/first-L_Thal_first.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain --warp=${tempdir}/diffusion.bedpostX/xfms/str2standard_warp --out=${tempdir}/segmentation/thalamus_left_MNI.nii.gz

fslmaths ${tempdir}/segmentation/thalamus_left_MNI.nii.gz -bin ${tempdir}/segmentation/thalamus_left_MNI.nii.gz

#Seed to target
probtrackx2 --samples=${tempdir}/diffusion.bedpostX/merged \
--mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
--xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
--invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
--seedref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
--seed=${tempdir}/segmentation/thalamus_left_MNI.nii.gz \
--targetmasks=${tempdir}/segmentation/${outname}_left_seeds/seeds_targets_list.txt \
--dir=thalamus2cortex_left \
--loopcheck \
--onewaycondition \
--forcedir \
--opd \
--os2t \
--nsamples=5000

#hard segmentation
find_the_biggest thalamus2cortex_left/seeds_to_* thalamus2cortex_left/biggest_segmentation

#omatrix2
probtrackx2 --omatrix2 \
--samples=${tempdir}/diffusion.bedpostX/merged \
--mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
--xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
--invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
--seed=${tempdir}/segmentation/thalamus_left_MNI.nii.gz \
--target2=${tempdir}/segmentation/GM_mask_MNI.nii.gz \
--dir=thalamus2cortex_left_omatrix2 \
--loopcheck \
--onewaycondition \
--forcedir \
--opd \
--nsamples=5000

echo "kmeans segmentation in Matlab"
cd thalamus2cortex_left_omatrix2
file_matlab=temp_Segmentation
echo "segmentation_clustering;exit" > ${file_matlab}.m
matlab -nodisplay -r "${file_matlab}"
fslcpgeom fdt_paths clusters
cd ..


#Pallidum

echo "Running segmentation of pallidum"
echo "Starting pallidum segmentation" >> $log

#Right pallidum

#Move individual nucleus (seed) to be segmentated to standard space (i.e. same as target parcellation / atlas)
applywarp --in=${tempdir}/first_segmentation/first-R_Pall_first.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain --warp=${tempdir}/diffusion.bedpostX/xfms/str2standard_warp --out=${tempdir}/segmentation/pallidum_right_MNI.nii.gz

fslmaths ${tempdir}/segmentation/pallidum_right_MNI.nii.gz -bin ${tempdir}/segmentation/pallidum_right_MNI.nii.gz


#Seed to target
probtrackx2 --samples=${tempdir}/diffusion.bedpostX/merged \
--mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
--xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
--invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
--seedref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
--seed=${tempdir}/segmentation/pallidum_right_MNI.nii.gz \
--targetmasks=${tempdir}/segmentation/${outname}_right_seeds/seeds_targets_list.txt \
--dir=pallidum2cortex_right \
--loopcheck \
--onewaycondition \
--forcedir \
--opd \
--os2t \
--nsamples=5000

#hard segmentation
find_the_biggest pallidum2cortex_right/seeds_to_* pallidum2cortex_right/biggest_segmentation

#Alternative segmentation method (hypothesis free): requires subsequent Matlab run for kmeans segmentation

#omatrix2
probtrackx2 --omatrix2 \
--samples=${tempdir}/diffusion.bedpostX/merged \
--mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
--xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
--invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
--seed=${tempdir}/segmentation/pallidum_right_MNI.nii.gz \
--target2=${tempdir}/segmentation/GM_mask_MNI.nii.gz \
--dir=pallidum2cortex_right_omatrix2 \
--loopcheck \
--onewaycondition \
--forcedir \
--opd \
--nsamples=5000

echo "kmeans segmentation in Matlab"
cd pallidum2cortex_right_omatrix2
file_matlab=temp_Segmentation
echo "segmentation_clustering;exit" > ${file_matlab}.m
matlab -nodisplay -r "${file_matlab}"
fslcpgeom fdt_paths clusters
cd ..

#Left pallidum

#Move individual nucleus (seed) to be segmentated to standard space (i.e. same as target parcellation / atlas)
applywarp --in=${tempdir}/first_segmentation/first-L_Pall_first.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain --warp=${tempdir}/diffusion.bedpostX/xfms/str2standard_warp --out=${tempdir}/segmentation/pallidum_left_MNI.nii.gz

fslmaths ${tempdir}/segmentation/pallidum_left_MNI.nii.gz -bin ${tempdir}/segmentation/pallidum_left_MNI.nii.gz

#Seed to target
probtrackx2 --samples=${tempdir}/diffusion.bedpostX/merged \
--mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
--xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
--invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
--seedref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
--seed=${tempdir}/segmentation/pallidum_left_MNI.nii.gz \
--targetmasks=${tempdir}/segmentation/${outname}_left_seeds/seeds_targets_list.txt \
--dir=pallidum2cortex_left \
--loopcheck \
--onewaycondition \
--forcedir \
--opd \
--os2t \
--nsamples=5000

#hard segmentation
find_the_biggest pallidum2cortex_left/seeds_to_* pallidum2cortex_left/biggest_segmentation

#omatrix2
probtrackx2 --omatrix2 \
--samples=${tempdir}/diffusion.bedpostX/merged \
--mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
--xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
--invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
--seed=${tempdir}/segmentation/pallidum_left_MNI.nii.gz \
--target2=${tempdir}/segmentation/GM_mask_MNI.nii.gz \
--dir=pallidum2cortex_left_omatrix2 \
--loopcheck \
--onewaycondition \
--forcedir \
--opd \
--nsamples=5000

echo "kmeans segmentation in Matlab"
cd pallidum2cortex_right_omatrix2
file_matlab=temp_Segmentation
echo "segmentation_clustering;exit" > ${file_matlab}.m
matlab -nodisplay -r "${file_matlab}"
fslcpgeom fdt_paths clusters
cd ..
