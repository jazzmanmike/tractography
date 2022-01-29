#!/bin/bash
set -e

# make_ants.sh
#
#
# Michael Hart, St George's University of London, January 2022 (c)

#define
codedir=${HOME}/Dropbox/Github/tractography
basedir="$(pwd -P)"
FSLOUTPUTTYPE=NIFTI_GZ #occassionally not set as standard


#inputs: structural ($1), nodif_brain (from diffusion.bedpostX/xfms)
#outputs: brain, registrations, cortical thickness mask

#Set Cores (8 max on laptop)
ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=8


#ANTS pipeline
echo "starting ants"

ants_brains.sh -s $1 -o

ants_diff2struct.sh -d ${basedir}/registrations/nodif_brain.nii.gz -s ${basedir}/ants_brains/BrainExtractionBrain.nii.gz -o

ants_struct2stand.sh -s ${basedir}/ants_brains/BrainExtractionBrain.nii.gz -o

ants_regcheck.sh -d ${basedir}/registrations/nodif_brain.nii.gz -w ${basedir}/ants_struct2stand/structural2standard.nii.gz -i ${basedir}/ants_struct2stand/standard2structural.nii.gz -r ${basedir}/ants_diff2struct/rigid0GenericAffine.mat -o

ants_corthick.sh -s $1 -o
