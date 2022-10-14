#!/bin/bash
set -e

# make_registrations2.sh $T1_brain $T1 $data
#
#
# Michael Hart, St George's University of London, January 2022 (c)

#define
codedir=${HOME}/Dropbox/Github/tractography
basedir="$(pwd -P)"
FSLOUTPUTTYPE=NIFTI_GZ #occassionally not set as standard


#Main input is T1_biascorr_brain.nii.gz from fsl_anat; also includes diffusion.nii.gz
#NB: all inputs are pre-specified - goes brain / head / diffusion
#Final outputs need to be diff2standard.nii.gz & standard2diff.nii.gz for probtrackx2/xtract
#1. Registrations
#a. flirt
#b. epi_reg
#c. fnirt
#2. Check images
#3. Cost functions

echo "brain is $1"
echo "head is $2"
echo "diffusion is $3"

#make directory for outputs
mkdir -pv registrations2

#make nodif_brain
#extract B0 volume
fslroi $3 registrations2/nodif 0 1

#create binary brain mask
bet registrations2/nodif registrations2/nodif_brain -m -f 0.2

#check images
slicer registrations2/nodif_brain.nii.gz -a QC/DTI_brain_images.ppm


#diffusion to structural (6 DOF)
echo "starting diff2str"
flirt -in registrations2/nodif_brain.nii.gz -ref $1 -omat registrations2/diff2str.mat -dof 6

#structural to diffusion inverse
echo "starting str2diff"
convert_xfm -omat registrations2/str2diff.mat -inverse registrations2/diff2str.mat

#epi_reg
echo "starting epi_reg"
epi_reg --epi=registrations2/nodif_brain.nii.gz --t1=$2 --t1brain=$1 --out=registrations2/epi2str

#structural to epi inverse (epi_reg)
echo "starting epi2diff"
convert_xfm -omat registrations2/str2epi.mat -inverse registrations2/epi2str.mat

#structural to standard affine
echo "starting flirt affine"
flirt -in $1 -ref ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz -omat registrations2/str2standard.mat -dof 12

#standard to structural affine inverse
echo "starting inverse affine"
convert_xfm -omat registrations2/standard2str.mat -inverse registrations2/str2standard.mat

#diffusion to standard (6 & 12 DOF)
echo "starting diff2standard.mat"
convert_xfm -omat registrations2/diff2standard.mat -concat registrations2/str2standard.mat registrations2/diff2str.mat

#standard to diffusion (12 & 6 DOF)
echo "starting standard2diff.mat"
convert_xfm -omat registrations2/standard2diff.mat -inverse registrations2/diff2standard.mat

#epi to standard (6 & 12 DOF) (epi_reg)
echo "starting epi2standard.mat"
convert_xfm -omat registrations2/epi2standard.mat -concat registrations2/str2standard.mat registrations2/epi2str.mat

#standard to epi (12 & 6 DOF) (epi_reg)
echo "starting standard2epi.mat"
convert_xfm -omat registrations2/standard2epi.mat -inverse registrations2/epi2standard.mat

#structural to standard: non-linear: uses brain image with head available in directory minus _brain suffix
echo "starting fnirt"
fnirt --in=$1 --aff=registrations2/str2standard.mat --cout=registrations2/str2standard_warp --config=T1_2_MNI152_2mm

#standard to structural: non-linear
echo "starting inv_warp"
invwarp -w registrations2/str2standard_warp -o registrations2/standard2str_warp -r $1

#diffusion to standard: non-linear
echo "starting diff2standard"
convertwarp -o registrations2/diff2standard -r ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz --premat=registrations2/diff2str.mat --warp1=registrations2/str2standard_warp

#standard to diffusion: non-linear
echo "starting standard2diff"
convertwarp -o registrations2/standard2diff -r registrations2/nodif_brain.nii.gz --warp1=registrations2/standard2str_warp --postmat=registrations2/str2diff.mat

#epi to standard: non-linear (epi_reg)
echo "starting epi2standard"
convertwarp -o registrations2/epi2standard -r ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz --premat=registrations2/epi2str.mat --warp1=registrations2/str2standard_warp

#standard to epi: non-linear (epi_reg)
echo "starting standard2epi"
convertwarp -o registrations2/standard2epi -r registrations2/nodif_brain.nii.gz --warp1=registrations2/standard2str_warp --postmat=registrations2/str2epi.mat


#check images
mkdir -pv registrations2/reg_check

#diffusion to structural
echo "starting diff2str check"
flirt -in registrations2/nodif_brain.nii.gz -ref $1 -init registrations2/diff2str.mat -out registrations2/reg_check/diff2str_check.nii.gz
slicer $1 registrations2/reg_check/diff2str_check.nii.gz -a registrations2/reg_check/diff2str_check.ppm

#epi_reg
echo "starting epi_reg check"
flirt -in registrations2/nodif_brain.nii.gz -ref $1 -init registrations2/epi2str.mat -out registrations2/reg_check/epi2str_check.nii.gz
slicer $1 registrations2/reg_check/epi2str_check.nii.gz -a registrations2/reg_check/epi2str_check.ppm

#structural to standard
echo "starting str2standard check"
applywarp --in=$1 --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz --warp=registrations2/str2standard_warp --out=registrations2/reg_check/str2standard_check.nii.gz
slicer ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz registrations2/reg_check/str2standard_check.nii.gz -a registrations2/reg_check/str2standard_check.ppm

#diffusion to standard: warp & premat
echo "starting diff2standard check"
applywarp --in=registrations2/nodif_brain.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz --warp=registrations2/str2standard_warp --premat=registrations2/diff2str.mat --out=registrations2/reg_check/diff2standard_check.nii.gz
slicer ${FSLDIR}/data/standard/MNI152_T1_2mm_brain registrations2/reg_check/diff2standard_check.nii.gz -a registrations2/reg_check/diff2standard_check.ppm

#diffusion to standard with convertwarp: diff2standard as used in XTRACT
echo "starting convert warp check"
applywarp --in=registrations2/nodif_brain.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain --warp=registrations2/diff2standard --out=registrations2/reg_check/diff2standard_check_applywarp.nii.gz
slicer ${FSLDIR}/data/standard/MNI152_T1_2mm_brain registrations2/reg_check/diff2standard_check_applywarp.nii.gz -a registrations2/reg_check/diff2standard_check_applywarp.ppm

#diffusion to standard: warp & premat
echo "starting epi2standard check"
applywarp --in=registrations2/nodif_brain.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz --warp=registrations2/str2standard_warp --premat=registrations2/epi2str.mat --out=registrations2/reg_check/epi2standard_check.nii.gz
slicer ${FSLDIR}/data/standard/MNI152_T1_2mm_brain registrations2/reg_check/epi2standard_check.nii.gz -a registrations2/reg_check/epi2standard_check.ppm



#Check cost functions
touch registration_costs.txt
echo "Cost function of diff2str" > registration_costs.txt
flirt -in registrations2/nodif_brain.nii.gz -ref ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz -schedule $FSLDIR/etc/flirtsch/measurecost1.sch -init registrations2/diff2str.mat > registration_costs.txt

echo "Cost function of epi2str" > registration_costs.txt
flirt -in registrations2/nodif_brain.nii.gz -ref ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz -schedule $FSLDIR/etc/flirtsch/measurecost1.sch -init registrations2/epi2str.mat > registration_costs.txt
