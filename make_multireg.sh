#!/bin/bash
set -e

# make_multireg.sh
#
# Registers T2, FLAIR, SWI & FGATIR to MNI space with FSL & ANTs
# Runs as part of image_analysis suite
# Part of lesion analysis pipeline (hence interp=nn)
#
# Michael Hart, St George's University of London, May 2022 (c)

#define
codedir=${HOME}/Dropbox/Github/tractography
basedir="$(pwd -P)"
FSLOUTPUTTYPE=NIFTI_GZ #occassionally not set as standard
standard=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz

cd multi_reg

#FSL
brain=${basedir}/structural.anat/T1_biascorr_brain.nii.gz
warp=${basedir}/registrations/str2standard_warp

#T2
if [ $(imtest *t2.nii.gz) == 1 ] ; then
    t2=`ls *t2.nii.gz`
    bet ${t2} t2_brain -R -f 0.3
    #T2 to T1
    flirt -in t2_brain -ref ${brain} -omat t22str.mat -dof 6
    #T2 to MNI
    convertwarp -o t22standard -r ${standard} --premat=t22str.mat --warp1=${warp}
    applywarp --in=t2_brain --ref=${standard} --warp=t22standard --out=t22standard_check.nii.gz --interp=nn
    slicer ${standard} t22standard_check.nii.gz -a t22standard_check.ppm
fi

#FLAIR
if [ $(imtest *flair.nii.gz) == 1 ] ; then
    flair=`ls *flair.nii.gz`
    bet ${flair} flair_brain -R
    #FLAIR to T1
    flirt -in flair_brain -ref ${brain} -omat flair2str.mat -dof 6
    #FLAIR to MNI
    convertwarp -o flair2standard -r ${standard} --premat=flair2str.mat --warp1=${warp}
    applywarp --in=flair_brain --ref=${standard} --warp=flair2standard --out=flair2standard_check.nii.gz --interp=nn
    slicer ${standard} flair2standard_check.nii.gz -a flair2standard_check.ppm
fi

#SWI
if [ $(imtest *swi.nii.gz) == 1 ] ; then
    swi=`ls *swi.nii.gz`
    bet ${swi} swi_brain -R
    #SWI to T1
    flirt -in swi_brain -ref ${brain} -omat swi2str.mat -dof 6
    #SWI to MNI
    convertwarp -o swi2standard -r ${standard} --premat=swi2str.mat --warp1=${warp}
    applywarp --in=swi_brain --ref=${standard} --warp=swi2standard --out=swi2standard_check.nii.gz --interp=nn
    slicer ${standard} swi2standard_check.nii.gz -a swi2standard_check.ppm
fi

#FGATIR
if [ $(imtest *fgatir.nii.gz) == 1 ] ; then
    fgatir=`ls *fgatir.nii.gz`
    bet ${fgatir} fgatir_brain -R
    #FGATIR to T1
    flirt -in fgatir_brain -ref ${brain} -omat fgatir2str.mat -dof 6
    #FGATIR to MNI
    convertwarp -o fgatir2standard -r ${standard} --premat=fgatir2str.mat --warp1=${warp}
    applywarp --in=fgatir_brain --ref=${standard} --warp=fgatir2standard --out=fgatir2standard_check.nii.gz --interp=nn
    slicer ${standard} fgatir2standard_check.nii.gz -a fgatir2standard_check.ppm
fi


#ANTS
brain=${basedir}/ants_brains/BrainExtractionBrain.nii.gz
warp=${basedir}/ants_struct2stand/structural2standard.nii.gz

#T2
if [ $(imtest $t2) == 1 ] ; then
    #T2 to T1
    antsRegistrationSyN.sh -d 3 -o t2 -f ${brain} -m ${t2} -t r
    #T2 to MNI
    antsApplyTransforms -d 3 -t ${warp} -t t20GenericAffine.mat -o [t22standard.nii.gz, 1] -r ${standard}
    antsApplyTransforms -d 3 -o t2_MNI.nii.gz -t t22standard.nii.gz -r ${standard} -i ${t2}
    slicer ${standard} t2_MNI.nii.gz -a t22standard.ppm
fi

#FLAIR
if [ $(imtest $flair) == 1 ] ; then
    #FLAIR to T1
    antsRegistrationSyN.sh -d 3 -o flair -f ${brain} -m ${flair} -t r
    #FLAIR to MNI
    antsApplyTransforms -d 3 -t ${warp} -t flair0GenericAffine.mat -o [flair2standard.nii.gz, 1] -r ${standard}
    antsApplyTransforms -d 3 -o flair_MNI.nii.gz -t flair2standard.nii.gz -r ${standard} -i ${flair}
    slicer ${standard} flair_MNI.nii.gz -a flair2standard.ppm
fi

#SWI
if [ $(imtest $swi) == 1 ] ; then
    #SWI to T1
    antsRegistrationSyN.sh -d 3 -o swi -f ${brain} -m ${swi} -t r
    #SWI to MNI
    antsApplyTransforms -d 3 -t ${warp} -t swi0GenericAffine.mat -o [swi2standard.nii.gz, 1] -r ${standard}
    antsApplyTransforms -d 3 -o swi_MNI.nii.gz -t swi2standard.nii.gz -r ${standard} -i ${swi}
    slicer ${standard} swi_MNI.nii.gz -a swi2standard.ppm
fi

#FGATIR
if [ $(imtest $fgatir) == 1 ] ; then
    #FGATIR to T1
    antsRegistrationSyN.sh -d 3 -o fgatir -f ${brain} -m ${fgatir} -t r
    #FGATIR to MNI
    antsApplyTransforms -d 3 -t ${warp} -t fgatir0GenericAffine.mat -o [fgatir2standard.nii.gz, 1] -r ${standard}
    antsApplyTransforms -d 3 -o fgatir_MNI.nii.gz -t fgatir2standard.nii.gz -r ${standard} -i ${fgatir}
    slicer ${standard} fgatir_MNI.nii.gz -a fgatir2standard.ppm
fi
