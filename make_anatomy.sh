#!/bin/bash
set -e

# make_anatomy.sh
#
#
# Michael Hart, St George's University of London, January 2022 (c)

#define
codedir=${HOME}/Dropbox/Github/tractography
basedir="$(pwd -P)"
FSLOUTPUTTYPE=NIFTI_GZ #occassionally not set as standard

#input: ${structural}
#output: structural.anat (including T1_biascorr_brain), FIRST, mprage_bet


#fsl_anat
echo "running fsl_anat"
fsl_anat -i $1 -o structural --clobber --nosubcortseg
slicer structural.anat/T1_biascorr_brain.nii.gz -a QC/fsl_anat_bet.ppm


#first
echo "running fsl first"
test -d first_segmentation && rm -r first_segmentation
mkdir first_segmentation
cd first_segmentation

#cp $1 .
#structural_name=`basename $1 .nii.gz`

cp ../structural.anat/T1_biascorr_brain.nii.gz .
structural_name=`basename T1_biascorr_brain.nii.gz .nii.gz`

run_first_all -i ${structural_name} -o first -d
first_roi_slicesdir $1 first-*nii.gz
cd ../


#quick bet call
echo "running bet"
test -d bet && rm -r bet
mkdir bet
cd bet
cp ../structural.anat/T1.nii.gz .
bet T1.nii.gz T1_brain -A
cd ..
