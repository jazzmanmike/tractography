#!/bin/bash
set -e

# make_masks.sh
#
# outputs: registration of masks to MNI space, volumes of masks in text file
# registration is mask_image to T1 to MNI with FSL & ANTs
#
# incomplete: see make_multireg for appropriate lesion function
#
# Michael Hart, St George's University of London, April 2022 (c)

#define
codedir=${HOME}/Dropbox/Github/tractography
basedir="$(pwd -P)"
FSLOUTPUTTYPE=NIFTI_GZ #occassionally not set as standard

if [ -f ${basedir}/masks ];
then
    echo "Doing masks analysis (for lesion patient)"
    cd masks/
else
    echo "No masks folder: skipping masks analysis"
fi


#identify


outdir=`pwd`
brain=${outdir}/structural.anat/T1_biascorr_brain.nii.gz



#FSL
#T2 mask to T1
flirt -in T2_mask -ref ${brain} -omat T22str.mat -dof 6

#FLAIR mask to T1
flirt -in registrations/nodif_brain.nii.gz -ref $1 -omat registrations/diff2str.mat -dof 6


#T2 mask to MNI with FSL

#T2 mask to MNI with ANTs

#FLAIR mask to MNI with FSL

#FLAIR mask to MNI with ANTs
