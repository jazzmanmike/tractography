#!/bin/bash
set -e

#test_CT.sh postop_ct.nii anat_t1.nii
#
#
# Michael Hart, St George's University of London, July 2022 (c)

#define
codedir=${HOME}/Dropbox/Github/tractography
basedir="$(pwd -P)"
FSLOUTPUTTYPE=NIFTI_GZ #occassionally not set as standard

#inputs
CT=$1
T1=$2

#work with full paths (for ants)
CT=`readlink -f ${CT}`
T1=`readlink -f ${T1}`

#setup
mkdir -pv registrations_CT
cd registrations_CT

#makes sure files are gzip
fslchfiletype NIFTI_GZ ${CT} ct.nii.gz
fslchfiletype NIFTI_GZ ${T1} t1.nii.gz

CT=ct.nii.gz
T1=t1.nii.gz

#works with image copies in registrations_CT directory
CT=`readlink -f ${CT}`
T1=`readlink -f ${T1}`

echo "CT is: ${CT}"
echo "T1 is: ${T1}"

if [ $(imtest $CT) == 1 ] ;
then
    echo "CT is an image"
else
    echo "CT is not an image"
fi

touch test_CT_log.txt
log=test_CT_log.txt
echo $(date) >> ${log}
echo "${0}" >> ${log}
echo "${@}" >> ${log}
echo "Starting test_CT.sh"
echo "" >> ${log}
echo "basedir is ${basedir}" >> ${log}
echo "CT is: ${CT}" >> ${log}
echo "T1 is: ${T1}" >> ${log}

#FSL

#1. With BET & CT_brain to MNI_brain
#Works well but electrode poorly visualised in MNI space
#Basal ganglia registers well but sometimes brain extraction cuts cortex

echo "" >> ${log}
date >> ${log}
echo "Starting FSL CT_brain with BET to MNI_brain" >> ${log}

#CT_brain
echo "Doing make_CTbrain.sh" >> ${log}
make_CTbrain.sh -i "${CT}"
CT_brain_FSL=CT_brain/Head_Image_1_SS_0.01.nii.gz
echo "Finishing make_CTbrain.sh" >> ${log}
date >> ${log}

#T1_brain
echo "" >> ${log}
date >> ${log}
echo "Doing fsl_anat" >> ${log}
fsl_anat -i "${T1}" -o structural
T1B_FSL=structural.anat/T1_biascorr_brain.nii.gz
echo "Finishing fsl_anat" >> ${log}
date >> ${log}

#T1_brain to MNI_brain FNIRT
T1B2MNIB_warp_FSL=structural.anat/T1_to_MNI_nonlin_field.nii.gz

#CT_brain to T1_brain
flirt -in "${CT_brain_FSL}" -ref "${T1B_FSL}" -omat CTB2T1B_FSL.mat -out CTB2T1B_FSL -cost mutualinfo -interp nearestneighbour

#CT_brain to MNI_brain
convertwarp --out=CTB2MNIB_FSL_warp --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz --premat=CTB2T1B_FSL.mat --warp1="${T1B2MNIB_warp_FSL}"
applywarp --in="${CT_brain_FSL}" --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz --warp=CTB2MNIB_FSL_warp --out=CTB2MNIB_FSL_check
slicer ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz CTB2MNIB_FSL_check -a CTB2MNIB_FSL_check.ppm

echo "Finishing FSL CT_brain with BET to MNI_brain" >> ${log}
date >> ${log}


#2. CT (with skull) to T1_brain to MNI_brain
#Works less well - brain smaller than template
echo "" >> ${log}
date >> ${log}
echo "Starting FSL CT (+skull) to MNI_brain" >> ${log}

#CT with skull to T1_brain
T1BFSL=structural.anat/T1_biascorr_brain.nii.gz
flirt -in "${CT}" -ref "${T1BFSL}" -omat CT2T1B_FSL.mat -out CT2T1B_FSL -cost mutualinfo -interp nearestneighbour

#CT to MNI_brain
convertwarp --out=CT2MNIB_FSL_warp --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz --premat=CT2T1B_FSL.mat --warp1="${T1B2MNIB_warp_FSL}"
applywarp --in="${CT}" --ref="${FSLDIR}"/data/standard/MNI152_T1_2mm_brain.nii.gz --warp=CT2MNIB_FSL_warp --out=CT2MNIB_FSL_check
slicer "${FSLDIR}"/data/standard/MNI152_T1_2mm_brain.nii.gz CT2MNIB_FSL_check -a CT2MNIB_FSL_check.ppm

echo "Finishing FSL CT (+skull) to MNI_brain" >> "${log}"
date >> "${log}"


#3. CT (with skull) to T1 (with skull) to MNI (with skull)
echo "" >> ${log}
date >> ${log}
echo "Starting FSL CT to MNI (both with skull)" >> ${log}

#CT with skull
T1SFSL=structural.anat/T1_biascorr.nii.gz
flirt -in "${CT}" -ref "${T1SFSL}" -omat CT2T1_FSL.mat -out CT2T1_FSL -cost mutualinfo -interp nearestneighbour

#CT to MNI (both with skull)
convertwarp --out=CT2MNI_FSL_warp --ref=${FSLDIR}/data/standard/MNI152_T1_2mm.nii.gz --premat=CT2T1_FSL.mat --warp1="${T1B2MNIB_warp_FSL}"
applywarp --in="${CT}" --ref=${FSLDIR}/data/standard/MNI152_T1_2mm.nii.gz --warp=CT2MNI_FSL_warp --out=CT2MNI_FSL_check
slicer ${FSLDIR}/data/standard/MNI152_T1_2mm.nii.gz CT2MNI_FSL_check -a CT2MNI_FSL_check.ppm

echo "Finishing FSL CT to MNI" >> ${log}
date >> ${log}


######
#ANTS#
######


echo "" >> ${log}
echo "Doing ANTs registration" >> ${log}

#CT_brain to T1_brain to MNI_brain
#CT to T1 skull then T1 brain to MNI_brain
#CT to T1 to MNI (all skull)

#1. #CT_brain to T1_brain to MNI_brain

echo "" >> ${log}
date >> ${log}
echo "Starting ANTS CT_brain to T1_brain to MNI_brain" >> ${log}

#CT_brain
echo "Doing ANTS_BET CT" >> ${log}
ants_brains.sh -s "${CT}"
cp ants_brains/BrainExtractionBrain.nii.gz ct_brain_ants.nii.gz
rm -r ants_brains/
CT_brain_ANTS=`readlink -f ct_brain_ants.nii.gz`
echo "Finishing ANTS_BET CT" >> ${log}
date >> ${log}

#T1_brain
echo "" >> ${log}
date >> ${log}
echo "Doing ANTS BET T1" >> ${log}
ants_brains.sh -s "${T1}"
cp ants_brains/BrainExtractionBrain.nii.gz T1_brain_ants.nii.gz
rm -r ants_brains/
T1_brain_ANTS=`readlink -f T1_brain_ants.nii.gz`
echo "Finishing ANTS BET T1" >> ${log}
date >> ${log}

#CT_brain to T1_brain (full paths)
ants_diff2struct.sh -d "${CT_brain_ANTS}" -s "${T1_brain_ANTS}" -o
mv ants_diff2struct ants_CTB2T1B

#T1 brain to MNI brain (needs full path)
ants_struct2stand.sh -s "${T1_brain_ANTS}" -o
mv ants_struct2stand ants_T1B2MNIB

#CT_brain to MNI_brain
ants_regcheck.sh -d "${CT_brain_ANTS}" -w "${basedir}"/registrations_CT/ants_T1B2MNIB/structural2standard.nii.gz -i "${basedir}"/registrations_CT/ants_T1B2MNIB/standard2structural.nii.gz -r "${basedir}"/registrations_CT/ants_CTB2T1B/rigid0GenericAffine.mat -o
mv ants_reg ants_CTB2MNIB

echo "Finishing ANTS CT_brain to T1_brain to MNI_brain" >> ${log}
date >> ${log}


#2. #CT to T1 skull then T1 brain to MNI_brain
echo "" >> ${log}
date >> ${log}
echo "Starting ANTS CT (+skull) to T1 then T1_brain to MNI_brain" >> ${log}

#CT to T1 (both + skull)
ants_diff2struct.sh -d "${CT}" -s "${T1}" -o
mv ants_diff2struct ants_CT2T1

#T1B2MNIB: already done

#CT to MNI_brain
ants_regcheck.sh -d "${CT}" -w "${basedir}"/registrations_CT/ants_T1B2MNIB/structural2standard.nii.gz -i "${basedir}"/registrations_CT/ants_T1B2MNIB/standard2structural.nii.gz -r "${basedir}"/registrations_CT/ants_CT2T1/rigid0GenericAffine.mat -o
mv ants_reg ants_CT2MNIB

echo "Finishing ANTS CT (+skull) to T1 then T1_brain to MNI_brain" >> ${log}
date >> ${log}


#3. CT (with skull) to T1 (with skull) to MNI (with skull)
echo "" >> ${log}
date >> ${log}
echo "Starting ANTS CT to MNI (both with skull)" >> ${log}

#CT2T1: already done

#T1 to MNI (both +skull)
ants_struct2stand.sh -s "${T1}" -t "${codedir}"/ANTS_templates/MNI152_T1_2mm.nii.gz -o
mv ants_struct2stand ants_T12MNI

#CT to MNI (both with skull)
ants_regcheck.sh -d "${CT}" -w "${basedir}"/registrations_CT/ants_T12MNI/structural2standard.nii.gz -i "${basedir}"/registrations_CT/ants_T12MNI/standard2structural.nii.gz -r "${basedir}"/registrations_CT/ants_CT2T1/rigid0GenericAffine.mat -o
mv ants_reg ants_CT2MNI

echo "Finishing ANTS CT to MNI" >> "${log}"
date >> "${log}"


#Run PaCER: to provide XYZ_L/R.txt in CT space
electrodes#makes CSV too for ANTS

#Convert above XYZ to MNI (FSL x3) (ANTS x3)

#FSL1: CTB2MNIB
cat XYZ_right_CT.txt | awk 'FNR == 1' | std2imgcoord -img postop_ct.nii -warp CTB2MNIB_FSL_warp.nii.gz -std "${FSLDIR}}"/data/standard/MNI152_T1_2mm_brain.nii.gz -vox >> XYZ_right_FSL1.txt
cat XYZ_left_CT.txt | awk 'FNR == 1' | std2imgcoord -img postop_ct.nii -warp CTB2MNIB_FSL_warp.nii.gz -std "${FSLDIR}}"/data/standard/MNI152_T1_2mm_brain.nii.gz -vox >> XYZ_left_FSL1.txt

#FSL2:
cat XYZ_right_CT.txt | awk 'FNR == 1' | std2imgcoord -img postop_ct.nii -warp CT2MNIB_FSL_warp.nii.gz -std "${FSLDIR}}"/data/standard/MNI152_T1_2mm_brain.nii.gz -vox >> XYZ_right_FSL2.txt
cat XYZ_left_CT.txt | awk 'FNR == 1' | std2imgcoord -img postop_ct.nii -warp CT2MNIB_FSL_warp.nii.gz -std "${FSLDIR}}"/data/standard/MNI152_T1_2mm_brain.nii.gz -vox >> XYZ_left_FSL2.txt

#FSL3:
cat XYZ_right_CT.txt | awk 'FNR == 1' | std2imgcoord -img postop_ct.nii -warp CT2MNI_FSL_warp.nii.gz -std "${FSLDIR}}"/data/standard/MNI152_T1_2mm_brain.nii.gz -vox >> XYZ_right_FSL3.txt
cat XYZ_left_CT.txt | awk 'FNR == 1' | std2imgcoord -img postop_ct.nii -warp CT2MNI_FSL_warp.nii.gz -std "${FSLDIR}}"/data/standard/MNI152_T1_2mm_brain.nii.gz -vox >> XYZ_left_FSL3.txt


#ANTS1: CTB2MNIB
antsApplyTransformsToPoints -d 3 -i XYZ_left_CT.csv -t ants_CTB2MNIB/diff2standard.nii.gz -o XYZ_right_ANTS1.csv
antsApplyTransformsToPoints -d 3 -i XYZ_right_CT.csv -t ants_CTB2MNIB/diff2standard.nii.gz -o XYZ_left_ANTS1.csv

#ANTS2: CT2MNIB
antsApplyTransformsToPoints -d 3 -i XYZ_left_CT.csv -t ants_CT2MNIB/diff2standard.nii.gz -o XYZ_right_ANTS2.csv
antsApplyTransformsToPoints -d 3 -i XYZ_right_CT.csv -t ants_CT2MNIB/diff2standard.nii.gz -o XYZ_left_ANTS2.csv

#ANTS3
antsApplyTransformsToPoints -d 3 -i XYZ_left_CT.csv -t ants_CT2MNI/diff2standard.nii.gz -o XYZ_right_ANTS3.csv
antsApplyTransformsToPoints -d 3 -i XYZ_right_CT.csv -t ants_CT2MNI/diff2standard.nii.gz -o XYZ_left_ANTS3.csv


#######

#Notes#

#######


#Notes:
#Options are: CT+/-brain &  T1+/-brain & MNI+/-brain

#1. All brains
#CT_brain to T1_brain
#T1_brain to MNI_brain
#CT_brain to MNI_brain

#2. CT skull to MNI brain
#CT with skull to T1 brain
#T1_brain to MNI_brain
#CT to MNI_brain

#3. All skulls
#CT with skull to T1
#T1_brain to MNI
#CT to MNI


#Different cost (mutualinfo versus normmi) / interpolations (nn versus trilinear versus spline): but, FSL doesn't work well....

#analysis
#1. PaCER in CT space
#2. Warp co-ordinates to MNI
#3. Compare methods x3 FSl x3 ANTs
#do for 10 STN (ideally already done & homogeneous)
