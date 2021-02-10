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

deparcellator.sh

Splits up a numbered volume (e.g. parcellation template) into its constituents & makes a .txt list
Also creates co-ordinates & names them based on Harvard-Oxford cortical structural atlas

Example:

deparcellator.sh parcellation.nii.gz

***Entirely based on code from Dr Rafael Romero-Garcia ('El Cunado'), University of Cambridge - Muchas Gracias Cunado!***


Written by Michael Hart, University of British Columbia, October 2020

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

touch xyz.txt
touch parcelnames.txt

while [ ${nParcel} -le  ${numParcels} ]
do
    
    fslmaths \
    ${volume} \
    -thr ${nParcel} \
    -uthr ${nParcel} \
    -bin \
    ${outdir}/Seg`printf %04d ${nParcel}`.nii.gz
    
    current_parcel=${outdir}/Seg`printf %04d ${nParcel}`.nii.gz
    
    if [ `fslstats ${current_parcel} -R | awk '{print $2}'` == 0 ]; then
        echo "removing ${current_parcel} as it's empty"
        rm ${current_parcel}
    else
        echo ${outdir}/Seg`printf %04d ${nParcel}`.nii.gz >> ${outdir}/seeds_targets_list.txt
        fslstats ${outdir}/Seg`printf %04d ${nParcel}` -c >> ${outdir}/xyz.txt
        atlasquery -a "Harvard-Oxford Cortical Structural Atlas" \
        -m ${outdir}/Seg`printf %04d ${nParcel}` | head -n 1 >> ${outdir}/parcelnames.txt
    fi
    
    nParcel=$((${nParcel}+1))
done
