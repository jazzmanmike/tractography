#!/bin/bash
set -e

# make_registrations_nodiff.sh $T1_brain $T1
#
#
# Michael Hart, St George's University of London, June 2022 (c)

#define
codedir=${HOME}/Dropbox/Github/tractography
basedir="$(pwd -P)"
FSLOUTPUTTYPE=NIFTI_GZ #occassionally not set as standard


#Main input is T1_biascorr_brain.nii.gz from fsl_anat; does not include diffusion.nii.gz
#NB: all inputs are pre-specified - goes brain / head
#1. Registrations
#a. flirt
#b. fnirt
#2. Check images

echo "brain is $1"
echo "head is $2"

#make directory for outputs
mkdir -pv registrations


#structural to standard affine
echo "starting flirt affine"
flirt -in $1 -ref ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz -omat registrations/str2standard.mat -dof 12

#standard to structural affine inverse
echo "starting inverse affine"
convert_xfm -omat registrations/standard2str.mat -inverse registrations/str2standard.mat

#structural to standard: non-linear: uses brain image with head available in directory minus _brain suffix
echo "starting fnirt"
fnirt --in=$2 --aff=registrations/str2standard.mat --cout=registrations/str2standard_warp --config=T1_2_MNI152_2mm

#standard to structural: non-linear
echo "starting inv_warp"
invwarp -w registrations/str2standard_warp -o registrations/standard2str_warp -r $1


#check images
mkdir -pv registrations/reg_check

#structural to standard
echo "starting str2standard check"
applywarp --in=$1 --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz --warp=registrations/str2standard_warp --out=registrations/reg_check/str2standard_check.nii.gz
slicer ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz registrations/reg_check/str2standard_check.nii.gz -a registrations/reg_check/str2standard_check.ppm
