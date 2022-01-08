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


#fsl_anat

echo "running fsl_anat"

fsl_anat -i ${structural} -o structural --clobber --nosubcortseg

slicer structural.anat/T1_biascorr_brain.nii.gz -a QC/fsl_anat_bet.ppm


#first

echo "running fsl first"

mkdir first_segmentation

cd first_segmentation

cp ${structural} .

structural_name=`basename ${structural} .nii.gz`

run_first_all -i ${structural_name} -o first -d

first_roi_slicesdir ${structural} first-*nii.gz

cd ../


#quick bet call

echo "running bet"

mkdir bet
cd bet
bet ${structural} -A
cd ..
