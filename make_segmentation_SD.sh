#!/bin/bash

#  make_segmentation_SD.sh ${segmentation}
#
#  Default atlases include:
#  Desikan-Killiany (individual segmentation, from FreeSurfer): cluster based segmentation, thalamus only
#  Yeo7: hard segmentation, thalamus & pallidum
#  Kmeans: cortex mask only
#
#  Can also run with custom atlas individually
#
# Michael Hart, St George's University of London, January 2022 (c)


#######

#Set up

#######


#define
codedir=${HOME}/Dropbox/Github/tractography
basedir="$(pwd -P)"
FSLOUTPUTTYPE=NIFTI_GZ #occassionally not set as standard


############################################

#6. Dystonia Network (Corp et al Brain 2019)
#   (only in SD - as an extra)

############################################


segmentation=${codedir}/templates/r_neg_all_overlap_3.nii.gz

if [ $(imtest ${segmentation}) == 1 ] ;
then
    echo "${segmentation} dataset for segmentation ok"
    echo "Doing stand alone ${segmentation} segmentation analysis"

    atlas=${segmentation}

    #Mask atlas by hemisphere (faster & avoids conflict with connectome)
    #cd segmentation
    #cp ${atlas} .
    outname=`basename ${atlas} .nii.gz` #for parsing outputs
    echo ${atlas} > ${outname}.txt
    #fslmaths ${atlas} -mas ${codedir}/templates/right_brain.nii.gz ${outname}_right
    #fslmaths ${atlas} -mas ${codedir}/templates/left_brain.nii.gz ${outname}_left

    #Split atlas into individual ROI files
    #echo "running deparcellator ${outname}"
    #deparcellator.sh ${outname}
    #deparcellator.sh ${outname}_right
    #deparcellator.sh ${outname}_left
    #cd ../


    #Left thalamus: hard segmentation

    probtrackx2 --samples=bpx.bedpostX/merged \
    --mask=bpx.bedpostX/nodif_brain_mask \
    --xfm=bpx.bedpostX/xfms/standard2diff \
    --invxfm=bpx.bedpostX/xfms/diff2standard \
    --seedref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
    --seed=segmentation/thalamus_left_MNI.nii.gz \
    --targetmasks=segmentation=${outname}.txt \
    --dir=thalamus2cortex_left_${outname} \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --os2t \
    --nsamples=5000

    #left thalamus
    #find_the_biggest thalamus2cortex_left_${outname}/seeds_to_* thalamus2cortex_left/biggest_segmentation
    cluster --in=thalamus2cortex_left_${outname}/seeds_to_${outname}.nii.gz --thresh=100 --othresh=thalamus2cortex_left_${outname}/cluster_${outname}

else
    echo "No specified segmentation template identified. Continuing with default DK (clustering), Yeo7, & kmeans segmentation."
    default=1
fi


segmentation=${codedir}/templates/r_pos_all_overlap_4.nii.gz

if [ $(imtest ${segmentation}) == 1 ] ;
then
    echo "${segmentation} dataset for segmentation ok"
    echo "Doing stand alone ${segmentation} segmentation analysis"

    atlas=${segmentation}

    #Mask atlas by hemisphere (faster & avoids conflict with connectome)
    #cd segmentation
    #cp ${atlas} .
    outname=`basename ${atlas} .nii.gz` #for parsing outputs
    echo ${atlas} > ${outname}.txt
    #fslmaths ${atlas} -mas ${codedir}/templates/right_brain.nii.gz ${outname}_right
    #fslmaths ${atlas} -mas ${codedir}/templates/left_brain.nii.gz ${outname}_left

    #Split atlas into individual ROI files
    #echo "running deparcellator ${outname}"
    #deparcellator.sh ${outname}
    #deparcellator.sh ${outname}_right
    #deparcellator.sh ${outname}_left
    #cd ../


    #Left thalamus: hard segmentation

    probtrackx2 --samples=bpx.bedpostX/merged \
    --mask=bpx.bedpostX/nodif_brain_mask \
    --xfm=bpx.bedpostX/xfms/standard2diff \
    --invxfm=bpx.bedpostX/xfms/diff2standard \
    --seedref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
    --seed=segmentation/thalamus_left_MNI.nii.gz \
    --targetmasks=${outname}.txt \
    --dir=thalamus2cortex_left_${outname} \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --os2t \
    --nsamples=5000

    #left thalamus
    #find_the_biggest thalamus2cortex_left_${outname}/seeds_to_* thalamus2cortex_left/biggest_segmentation
    cluster --in=thalamus2cortex_left_${outname}/seeds_to_${outname}.nii.gz --thresh=100 --othresh=thalamus2cortex_left_${outname}/cluster_${outname}


else
    echo "No specified segmentation template identified. Continuing with default DK (clustering), Yeo7, & kmeans segmentation."
    default=1
fi


#fin
