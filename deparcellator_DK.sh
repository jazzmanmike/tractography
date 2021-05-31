#!/bin/bash
set -e

#define

codedir=${HOME}/code
basedir="$(pwd -P)"

usage()
{
cat<<EOF
usage: $0 options

=============================================================================================

deparcellator_DK.sh

As deparcellator but for DK atlas

Example:

deparcellator_DK.sh parcellation.nii.gz

***Entirely based on code from Dr Rafael Romero-Garcia ('El Cunado'), University of Cambridge - Muchas Gracias Cunado!***


Written by Michael Hart, University of British Columbia, April 2021

=============================================================================================

EOF
exit 1
}

# If empty options
if [[ $1 == "" ]]; then
    usage
    exit 1
fi

volume=$1
outname=`basename ${volume} .nii.gz`
mkdir -p ${basedir}/${outname}_seeds
outdir=${basedir}/${outname}_seeds
nParcel=1
maxParcel=`fslstats $1 -R | awk '{print $2}'`
numParcels=`printf "%0.0f\n" $maxParcel`

echo "basedir is: ${basedir}"
echo "number of parcels is: ${numParcels}"
echo "outdir is: ${outdir}"

if [ $(imtest ${volume}) == 1 ] ;
then
    echo "parcellation template is ok: ${volume}"
else
    echo "Cannot locate parcellation template ${volume}. Please ensure the ${volume} dataset is in this directory -> exiting now" >&2
    exit 1
fi

newID=1;
while [ ${nParcel} -le  ${numParcels} ]
do
    
    fslmaths \
    ${volume} \
    -thr ${nParcel} \
    -uthr ${nParcel} \
    -bin \
    ${outdir}/Seg`printf %04d ${nParcel}`.nii.gz
    
    current_parcel=${outdir}/Seg`printf %04d ${nParcel}`.nii.gz
    
    if [ `fslstats ${current_parcel} -V | awk '{print $1}'` == 0 ]; then
        echo "removing ${current_parcel} as it's empty"
        rm ${current_parcel}
    else
        mv ${current_parcel} ${outdir}/Seg`printf %04d newID`.nii.gz
        newID=$(( $newID+1 ))
        echo ${newID}
    fi
    
    nParcel=$((${nParcel}+1))
done
