#!/bin/bash
set -e

# make_electrodes.sh
#
#
# Michael Hart, St George's University of London, June 2022 (c)

#input: postop_ct.nii; anat_t1.nii; anat_t2.nii
#output: lead_dbs analysis,

#Define
outdir=$(pwd);

#Lead_DBS
matlab -nodisplay -nosplash -nodesktop -r "run('lead_job');exit;"
cd ${outdir}/electrode_analysis

#Electrode analysis
matlab -nodisplay -nosplash -nodesktop -r "run('electrode_analysis');exit;"


#Do registrations CT to MNI
standard=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz


#Register CT to MNI (FSL)
#Brain extraction
make_CTbrain.sh -i postop_ct.nii
ct=CT_brain/Head_Image_1_SS_0.01.nii.gz
brain=${outdir}/structural.anat/T1_biascorr_brain.nii.gz
warp=${outdir}/registrations/str2standard_warp
#CT to T1
flirt -in ${ct} -omat ct2str.mat -out ct2structural_fsl -ref ${brain} -cost mutualinfo -dof 12
#CT to MNI
convertwarp -o ct2standard_fsl -r ${standard} --premat=ct2str.mat --warp1=${warp}
applywarp --in=${ct} --ref=${standard} --warp=ct2standard_fsl --out=CT_MNI_FSL.nii.gz
slicer ${standard} CT_MNI_FSL.nii.gz -a ct2standard_check_fsl.ppm

#Register CT to MNI (ANTS)
#Brain extractions
ants_brains.sh -s postop_ct.nii
ct=ants_brains/BrainExtractionBrain.nii.gz
brain=${outdir}/ants_brains/BrainExtractionBrain.nii.gz
warp=${outdir}/ants_struct2stand/structural2standard.nii.gz
#CT to T1
antsRegistrationSyN.sh -d 3 -o ct -f ${brain} -m ${ct} -t r
#CT to MNI
antsApplyTransforms -d 3 -t ${warp} -t  ct0GenericAffine.mat -o [ct2standard_ants.nii.gz, 1] -r ${standard}
antsApplyTransforms -d 3 -o ct_MNI_ANTS.nii.gz -t ct2standard_ants.nii.gz -r ${standard} -i ${ct}
slicer ${standard} ct_MNI_ANTS.nii.gz -a ct2standard_check_ants.ppm


#Make Lead_DBS electrodes (MNI space)
#Make right electrode tip
cat XYZ_right_lead.txt | awk 'FNR == 1' | std2imgcoord -img glpostop_ct.nii -std glpostop_ct.nii -vox >> XYZ_right_lead_vox.txt
xr=`cat XYZ_right_lead_vox.txt | awk 'FNR == 1 {print $1}'`
yr=`cat XYZ_right_lead_vox.txt | awk 'FNR == 1 {print $2}'`
zr=`cat XYZ_right_lead_vox.txt | awk 'FNR == 1 {print $3}'`
fslmaths glpostop_ct.nii -mul 0 -add 1 -roi ${xr} 1 ${yr} 1 ${zr} 1 0 1 lead_electrode_right -odt float
fslmaths lead_electrode_right -kernel sphere 1 -fmean lead_electrode_right_sphere -odt float
fslmaths lead_electrode_right_sphere -bin lead_electrode_right_sphere

#Make left electrode tip
cat XYZ_left_lead.txt | awk 'FNR == 1' | std2imgcoord -img glpostop_ct.nii -std glpostop_ct.nii -vox >> XYZ_left_lead_vox.txt
xl=`cat XYZ_left_lead_vox.txt | awk 'FNR == 1 {print $1}'`
yl=`cat XYZ_left_lead_vox.txt | awk 'FNR == 1 {print $2}'`
zl=`cat XYZ_left_lead_vox.txt | awk 'FNR == 1 {print $3}'`
fslmaths glpostop_ct.nii -mul 0 -add 1 -roi ${xl} 1 ${yl} 1 ${zl} 1 0 1 lead_electrode_left -odt float
fslmaths lead_electrode_left -kernel sphere 1 -fmean lead_electrode_left_sphere -odt float
fslmaths lead_electrode_left_sphere -bin lead_electrode_left_sphere


#Make electrodes using PaCER with postop_ct.nii
#Make right electrode tip
cat XYZ_right_CT.txt | awk 'FNR == 1' | std2imgcoord -img postop_ct.nii -std postop_ct.nii -vox >> XYZ_right_CT_vox.txt
xr=`cat XYZ_right_CT_vox.txt | awk 'FNR == 1 {print $1}'`
yr=`cat XYZ_right_CT_vox.txt | awk 'FNR == 1 {print $2}'`
zr=`cat XYZ_right_CT_vox.txt | awk 'FNR == 1 {print $3}'`
fslmaths postop_ct.nii -mul 0 -add 1 -roi ${xr} 1 ${yr} 1 ${zr} 1 0 1 ct_electrode_right -odt float
fslmaths ct_electrode_right -kernel sphere 1 -fmean ct_electrode_right_sphere -odt float
fslmaths ct_electrode_right_sphere -bin ct_electrode_right_sphere

#fsl
applywarp --in=ct_electrode_right.nii.gz --ref=${standard} --warp=ct2standard_fsl --out=ct_electrode_right_MNI_FSL
fslstats ct_electrode_right_MNI_FSL -C > XYZ_right_MNI_fsl.txt

#ANTS
antsApplyTransforms -d 3 -o ct_electrode_right_MNI_ANTS.nii.gz -t ct2standard_ants.nii.gz -r ${standard} -i ct_electrode_right.nii.gz
fslstats ct_electrode_right_MNI_ANTS -C > XYZ_right_MNI_ants.txt

#Make left electrode tip
cat XYZ_left_CT.txt | awk 'FNR == 1' | std2imgcoord -img postop_ct.nii -std postop_ct.nii -vox >> XYZ_left_CT_vox.txt
xl=`cat XYZ_left_CT_vox.txt | awk 'FNR == 1 {print $1}'`
yl=`cat XYZ_left_CT_vox.txt | awk 'FNR == 1 {print $2}'`
zl=`cat XYZ_left_CT_vox.txt | awk 'FNR == 1 {print $3}'`
fslmaths postop_ct.nii -mul 0 -add 1 -roi ${xl} 1 ${yl} 1 ${zl} 1 0 1 ct_electrode_left -odt float
fslmaths ct_electrode_left -kernel sphere 1 -fmean ct_electrode_left_sphere -odt float
fslmaths ct_electrode_left_sphere -bin ct_electrode_left_sphere

#fsl
applywarp --in=ct_electrode_left.nii.gz --ref=${standard} --warp=ct2standard_fsl --out=ct_electrode_left_MNI_FSL
fslstats ct_electrode_left_MNI_FSL -C > XYZ_left_MNI_fsl.txt

#ANTS
antsApplyTransforms -d 3 -o ct_electrode_left_MNI_ANTS.nii.gz -t ct2standard_ants.nii.gz -r ${standard} -i ct_electrode_left.nii.gz
fslstats ct_electrode_left_MNI_ANTS -C > XYZ_left_MNI_ants.txt

cd ../
