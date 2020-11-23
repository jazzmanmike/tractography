#!/bin/sh

#  code_store.sh
#  
#
#  Created by Michael Hart on 11/11/2020.
#

#################

#10. Connectomics

#################


echo $(date)
echo "10. Starting connectomics ProbTrackX"

#Set up parcellation templates
#Test for optional parcellation, if not use HO
#deparcellate
#set up text file

#test me then remove me***

tempdir=`pwd`
codedir=${HOME}/code/github/tractography

echo "parcellation template set for connectomics is: {$template}"
if [ $(imtest ${template}) == 1 ];
then
    echo "${template} dataset for connectomics ok"
else
    template="${codedir}/templates/HarvardOxford.nii.gz"
    echo "No parcellation template for connectomics has been supplied - using HarvardOxford"
fi

deparcellator.sh ${template}
outname=`basename ${template} .nii.gz` #for parsing output to probtrackx below
echo "outname is: ${outname}"


echo "Starting connectome --network option"

#check seed path
#set verbose and removed seeds_target_list

probtrackx2 \
--network \
--samples=${tempdir}/diffusion.bedpostX/merged \
--mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
--xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
--invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
--dir=connectome_${outname} \
--seed=${outname}_seeds/seeds_targets_list.txt \
--loopcheck \
--onewaycondition \
--forcedir \
--opd \
--nsamples=5000 \
-V 2

echo "Finished connectome --network option"
echo $(date)


