#!/bin/sh

#  test_reg.sh
#  
#
#  Created by Michael Hart on 12/11/2020.
#


#Start with FSL
#Need to define best BET image first: use ants_brain - rename as mprage_brain

echo "starting test_reg"
echo $(date)

echo "starting diff2str"

#diffusion to structural
flirt -in nodif_brain.nii.gz -ref bet_check/test_structural.anat/T1_biascorr_brain.nii.gz -omat diffusion.bedpostX/xfms/diff2str.mat -dof 6

echo "starting epi_reg"

#epi_reg
epi_reg --epi=nodif_brain.nii.gz --t1=bet_check/test_structural.anat/T1_biascorr.nii.gz --t1brain=bet_check/test_structural.anat/T1_biascorr_brain.nii.gz --out=diffusion.bedpostX/xfms/epi2str

echo "starting str2diff"

#structural to diffusion inverse
convert_xfm -omat diffusion.bedpostX/xfms/str2diff.mat -inverse diffusion.bedpostX/xfms/diff2str.mat

echo "starting flirt affine"

#structural to standard affine
flirt -in bet_check/test_structural.anat/T1_biascorr_brain.nii.gz -ref ${FSLDIR}/data/standard/MNI152_T1_2mm_brain -omat diffusion.bedpostX/xfms/str2standard.mat -dof 12

echo "starting inverse affine"

#standard to structural affine inverse
convert_xfm -omat diffusion.bedpostX/xfms/standard2str.mat -inverse diffusion.bedpostX/xfms/str2standard.mat

echo "starting diff2standard.mat"

#diffusion to standard (6 & 12 DOF)
convert_xfm -omat diffusion.bedpostX/xfms/diff2standard.mat -concat diffusion.bedpostX/xfms/str2standard.mat diffusion.bedpostX/xfms/diff2str.mat

echo "starting standard2diff.mat"

#standard to diffusion (12 & 6 DOF)
convert_xfm -omat diffusion.bedpostX/xfms/standard2diff.mat -inverse diffusion.bedpostX/xfms/diff2standard.mat

echo "starting fnirt"

#structural to standard: non-linear
fnirt --in=bet_check/test_structural.anat/T1_biascorr.nii.gz --aff=diffusion.bedpostX/xfms/str2standard.mat --cout=diffusion.bedpostX/xfms/str2standard_warp --config=T1_2_MNI152_2mm

echo "starting inv_warp"

#standard to structural: non-linear
invwarp -w diffusion.bedpostX/xfms/str2standard_warp -o diffusion.bedpostX/xfms/standard2str_warp -r bet_check/test_structural.anat/T1_biascorr_brain.nii.gz

echo "starting diff2standard"

#diffusion to standard: non-linear
convertwarp -o diffusion.bedpostX/xfms/diff2standard -r ${FSLDIR}/data/standard/MNI152_T1_2mm_brain --premat=diffusion.bedpostX/xfms/diff2str.mat --warp1=diffusion.bedpostX/xfms/str2standard_warp

echo "starting standard2diff"

#standard to diffusion: non-linear
convertwarp -o diffusion.bedpostX/xfms/standard2diff -r nodif_brain     --warp1=diffusion.bedpostX/xfms/standard2str_warp --postmat=diffusion.bedpostX/xfms/str2diff.mat

#check images

mkdir diffusion.bedpostX/xfms/reg_check

#diffusion to structural

echo "starting diff2str check"

#flirt
flirt -in nodif_brain.nii.gz -ref bet_check/test_structural.anat/T1_biascorr_brain.nii.gz -init diffusion.bedpostX/xfms/diff2str.mat -out diffusion.bedpostX/xfms/reg_check/diff2str_check.nii.gz

slicer bet_check/test_structural.anat/T1_biascorr_brain.nii.gz diffusion.bedpostX/xfms/reg_check/diff2str_check.nii.gz -a diffusion.bedpostX/xfms/reg_check/diff2str_check.ppm

echo "starting epi_reg check"

#epi_reg
flirt -in nodif_brain.nii.gz -ref bet_check/test_structural.anat/T1_biascorr_brain.nii.gz -init diffusion.bedpostX/xfms/epi2str.mat -out diffusion.bedpostX/xfms/reg_check/epi2str_check.nii.gz

slicer bet_check/test_structural.anat/T1_biascorr_brain.nii.gz diffusion.bedpostX/xfms/reg_check/epi2str.nii.gz -a diffusion.bedpostX/xfms/reg_check/epi2str_check.ppm

echo "starting str2standard check"

#structural to standard
applywarp --in=bet_check/test_structural.anat/T1_biascorr_brain.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain --warp=diffusion.bedpostX/xfms/str2standard_warp --out=diffusion.bedpostX/xfms/reg_check/str2standard_check.nii.gz

slicer ${FSLDIR}/data/standard/MNI152_T1_2mm_brain diffusion.bedpostX/xfms/reg_check/str2standard_check.nii.gz -a diffusion.bedpostX/xfms/reg_check/str2standard_check.ppm

echo "starting diff2standard check"

#diffusion to standard
applywarp --in=nodif_brain.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain --warp=diffusion.bedpostX/xfms/str2standard_warp --premat=diffusion.bedpostX/xfms/diff2str.mat --out=diffusion.bedpostX/xfms/reg_check/diff2standard_check.nii.gz

slicer ${FSLDIR}/data/standard/MNI152_T1_2mm_brain diffusion.bedpostX/xfms/reg_check/diff2standard_check.nii.gz -a diffusion.bedpostX/xfms/reg_check/diff2standard_check.ppm

echo "starting convert warp check"

#diffusion to standard with convertwarp
applywarp --in=nodif_brain.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain --warp=diffusion.bedpostX/xfms/diff2standard --out=diffusion.bedpostX/xfms/reg_check/diff2standard_check_applywarp.nii.gz

slicer ${FSLDIR}/data/standard/MNI152_T1_2mm_brain diffusion.bedpostX/xfms/reg_check/diff2standard_check_applywarp.nii.gz -a diffusion.bedpostX/xfms/reg_check/diff2standard_check_appywarp.ppm

echo "starting ants"


#ANTS pipeline

ants_brains.sh -s t1_UBC.nii.gz -o

ants_diff2struct.sh -d nodif_brain.nii.gz -s ants_brains/BrainExtractionBrain.nii.gz -o

ants_struct2stand.sh -s ants_brains/BrainExtractionBrain.nii.gz -o

ants_regcheck.sh -d nodif_brain.nii.gz -w ants_struct2stand/structural2standard.nii.gz -i ants_struct2stand/standard2structural.nii.gz -r ants_diff2struct/rigid0GenericAffine.mat

echo "finished test_reg"
echo $(date)

