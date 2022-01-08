#!/bin/bash
set -e

# make_ants.sh
#
#
# Michael Hart, St George's University of London, January 2022 (c)

#ANTS pipeline
echo "starting ants"

cp ${structural} ${tempdir}/structural.nii.gz

ants_brains.sh -s structural.nii.gz

ants_diff2struct.sh -d nodif_brain.nii.gz -s ants_brains/BrainExtractionBrain.nii.gz

ants_struct2stand.sh -s ants_brains/BrainExtractionBrain.nii.gz

ants_regcheck.sh -d nodif_brain.nii.gz -w ants_struct2stand/structural2standard.nii.gz -i ants_struct2stand/standard2structural.nii.gz -r ants_diff2struct/rigid0GenericAffine.mat

ants_corthick.sh -s ${structural}
