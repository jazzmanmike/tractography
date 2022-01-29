#!/bin/bash
set -e

# make_connectome.sh
#
#
# Michael Hart, St George's University of London, January 2022 (c)

#define
codedir=${HOME}/Dropbox/Github/tractography
basedir="$(pwd -P)"
FSLOUTPUTTYPE=NIFTI_GZ #occassionally not set as standard

template=$1

#template
if [ $(imtest ${template}) == 1 ];
then
    echo "${template} dataset for connectomics ok"
else
    template="${codedir}/templates/AAL90.nii.gz"
    echo "No parcellation template for connectomics has been supplied - using AAL90 cortical (78 nodes)"
fi


#parcels
maxParcel=`fslstats ${template} -R | awk '{print $2}'`
numParcels=`printf "%0.0f\n" $maxParcel`
echo "Parcellation template is: ${template}"
echo "numParcels: ${numParcels}"
cp ${template} .

outname=`basename ${template} .nii.gz` #for parsing output to probtrackx below
echo "outname is: ${outname}"


#generate list of seeds
if [[ ! -d ${outname}_seeds/ ]] ;
then
    echo "${outname}: making seeds & seeds_list"
    deparcellator.sh ${outname}
else
    echo "${outname} seeds already made"
fi


echo "Running probtrackx connectome in serial with --network option"


#only 500 seeds and no option '-opd'
probtrackx2 \
--network \
--samples=bpx.bedpostX/merged \
--mask=bpx.bedpostX/nodif_brain_mask \
--xfm=bpx.bedpostX/xfms/standard2diff \
--invxfm=bpx.bedpostX/xfms/diff2standard \
--dir=${outname} \
--seed=${outname}_seeds/seeds_targets_list.txt \
--loopcheck \
--onewaycondition \
--forcedir \
--nsamples=500
