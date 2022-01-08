#!/bin/bash
set -e

# make_registration.sh
#
#
# Michael Hart, St George's University of London, January 2022 (c)

#define
codedir=${HOME}/Dropbox/Github/tractography
basedir="$(pwd -P)"
FSLOUTPUTTYPE=NIFTI_GZ #occassionally not set as standard


#Main input is T1_biascorr_brain.nii.gz from fsl_anat
#Final outputs need to be diff2standard.nii.gz & standard2diff.nii.gz for probtrackx2/xtract
#1. Registrations
#a. flirt
#b. epi_reg
#c. fnirt
#2. Check images
#3. Cost functions

#Check if fsl_anat finished
if [ ! -f ${tempdir}/structural.anat/T1_biascorr_brain.nii.gz ] ;
then
    echo "Waiting for fsl_anat to finish - set to sleep for 6h"
    Sleep 6h
fi

#diffusion to structural (6 DOF)
echo "starting diff2str"
flirt -in nodif_brain.nii.gz -ref structural.anat/T1_biascorr_brain.nii.gz -omat diffusion.bedpostX/xfms/diff2str.mat -dof 6

#structural to diffusion inverse
echo "starting str2diff"
convert_xfm -omat diffusion.bedpostX/xfms/str2diff.mat -inverse diffusion.bedpostX/xfms/diff2str.mat

#epi_reg
echo "starting epi_reg"
epi_reg --epi=nodif_brain.nii.gz --t1=structural.anat/T1_biascorr.nii.gz --t1brain=structural.anat/T1_biascorr_brain.nii.gz --out=diffusion.bedpostX/xfms/epi2str

#structural to epi inverse (epi_reg)
echo "starting epi2diff"
convert_xfm -omat diffusion.bedpostX/xfms/str2epi.mat -inverse diffusion.bedpostX/xfms/epi2str.mat

#structural to standard affine
echo "starting flirt affine"
flirt -in structural.anat/T1_biascorr_brain.nii.gz -ref ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz -omat diffusion.bedpostX/xfms/str2standard.mat -dof 12

#standard to structural affine inverse
echo "starting inverse affine"
convert_xfm -omat diffusion.bedpostX/xfms/standard2str.mat -inverse diffusion.bedpostX/xfms/str2standard.mat

#diffusion to standard (6 & 12 DOF)
echo "starting diff2standard.mat"
convert_xfm -omat diffusion.bedpostX/xfms/diff2standard.mat -concat diffusion.bedpostX/xfms/str2standard.mat diffusion.bedpostX/xfms/diff2str.mat

#standard to diffusion (12 & 6 DOF)
echo "starting standard2diff.mat"
convert_xfm -omat diffusion.bedpostX/xfms/standard2diff.mat -inverse diffusion.bedpostX/xfms/diff2standard.mat

#epi to standard (6 & 12 DOF) (epi_reg)
echo "starting epi2standard.mat"
convert_xfm -omat diffusion.bedpostX/xfms/epi2standard.mat -concat diffusion.bedpostX/xfms/str2standard.mat diffusion.bedpostX/xfms/epi2str.mat

#standard to epi (12 & 6 DOF) (epi_reg)
echo "starting standard2epi.mat"
convert_xfm -omat diffusion.bedpostX/xfms/standard2epi.mat -inverse diffusion.bedpostX/xfms/epi2standard.mat

#structural to standard: non-linear
echo "starting fnirt"
fnirt --in=structural.anat/T1_biascorr.nii.gz --aff=diffusion.bedpostX/xfms/str2standard.mat --cout=diffusion.bedpostX/xfms/str2standard_warp --config=T1_2_MNI152_2mm

#standard to structural: non-linear
echo "starting inv_warp"
invwarp -w diffusion.bedpostX/xfms/str2standard_warp -o diffusion.bedpostX/xfms/standard2str_warp -r structural.anat/T1_biascorr_brain.nii.gz

#diffusion to standard: non-linear
echo "starting diff2standard"
convertwarp -o diffusion.bedpostX/xfms/diff2standard -r ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz --premat=diffusion.bedpostX/xfms/diff2str.mat --warp1=diffusion.bedpostX/xfms/str2standard_warp

#standard to diffusion: non-linear
echo "starting standard2diff"
convertwarp -o diffusion.bedpostX/xfms/standard2diff -r nodif_brain.nii.gz --warp1=diffusion.bedpostX/xfms/standard2str_warp --postmat=diffusion.bedpostX/xfms/str2diff.mat

#epi to standard: non-linear (epi_reg)
echo "starting epi2standard"
convertwarp -o diffusion.bedpostX/xfms/epi2standard -r ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz --premat=diffusion.bedpostX/xfms/epi2str.mat --warp1=diffusion.bedpostX/xfms/str2standard_warp

#standard to epi: non-linear (epi_reg)
echo "starting standard2epi"
convertwarp -o diffusion.bedpostX/xfms/standard2epi -r nodif_brain.nii.gz --warp1=diffusion.bedpostX/xfms/standard2str_warp --postmat=diffusion.bedpostX/xfms/str2epi.mat



#check images
mkdir diffusion.bedpostX/xfms/reg_check

#diffusion to structural
echo "starting diff2str check"
flirt -in nodif_brain.nii.gz -ref structural.anat/T1_biascorr_brain.nii.gz -init diffusion.bedpostX/xfms/diff2str.mat -out diffusion.bedpostX/xfms/reg_check/diff2str_check.nii.gz
slicer structural.anat/T1_biascorr_brain.nii.gz diffusion.bedpostX/xfms/reg_check/diff2str_check.nii.gz -a diffusion.bedpostX/xfms/reg_check/diff2str_check.ppm

#epi_reg
echo "starting epi_reg check"
flirt -in nodif_brain.nii.gz -ref structural.anat/T1_biascorr_brain.nii.gz -init diffusion.bedpostX/xfms/epi2str.mat -out diffusion.bedpostX/xfms/reg_check/epi2str_check.nii.gz
slicer structural.anat/T1_biascorr_brain.nii.gz diffusion.bedpostX/xfms/reg_check/epi2str_check.nii.gz -a diffusion.bedpostX/xfms/reg_check/epi2str_check.ppm

#structural to standard
echo "starting str2standard check"
applywarp --in=structural.anat/T1_biascorr_brain.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz --warp=diffusion.bedpostX/xfms/str2standard_warp --out=diffusion.bedpostX/xfms/reg_check/str2standard_check.nii.gz
slicer ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz diffusion.bedpostX/xfms/reg_check/str2standard_check.nii.gz -a diffusion.bedpostX/xfms/reg_check/str2standard_check.ppm

#diffusion to standard: warp & premat
echo "starting diff2standard check"
applywarp --in=nodif_brain.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz --warp=diffusion.bedpostX/xfms/str2standard_warp --premat=diffusion.bedpostX/xfms/diff2str.mat --out=diffusion.bedpostX/xfms/reg_check/diff2standard_check.nii.gz
slicer ${FSLDIR}/data/standard/MNI152_T1_2mm_brain diffusion.bedpostX/xfms/reg_check/diff2standard_check.nii.gz -a diffusion.bedpostX/xfms/reg_check/diff2standard_check.ppm

#diffusion to standard with convertwarp: diff2standard as used in XTRACT
echo "starting convert warp check"
applywarp --in=nodif_brain.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain --warp=diffusion.bedpostX/xfms/diff2standard --out=diffusion.bedpostX/xfms/reg_check/diff2standard_check_applywarp.nii.gz
slicer ${FSLDIR}/data/standard/MNI152_T1_2mm_brain diffusion.bedpostX/xfms/reg_check/diff2standard_check_applywarp.nii.gz -a diffusion.bedpostX/xfms/reg_check/diff2standard_check_appywarp.ppm

#diffusion to standard: warp & premat
echo "starting epi2standard check"
applywarp --in=nodif_brain.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz --warp=diffusion.bedpostX/xfms/str2standard_warp --premat=diffusion.bedpostX/xfms/epi2str.mat --out=diffusion.bedpostX/xfms/reg_check/epi2standard_check.nii.gz
slicer ${FSLDIR}/data/standard/MNI152_T1_2mm_brain diffusion.bedpostX/xfms/reg_check/epi2standard_check.nii.gz -a diffusion.bedpostX/xfms/reg_check/epi2standard_check.ppm



#Check cost functions
echo "Cost function of diff2str" >> $log
flirt -in nodif_brain.nii.gz -ref ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz -schedule $FSLDIR/etc/flirtsch/measurecost1.sch -init diffusion.bedpostX/xfms/diff2str.mat >> $log

echo "Cost function of epi2str" >> $log
flirt -in nodif_brain.nii.gz -ref ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz -schedule $FSLDIR/etc/flirtsch/measurecost1.sch -init diffusion.bedpostX/xfms/epi2str.mat >> $log
