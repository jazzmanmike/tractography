#!/bin/bash
set -e

# make_bedpostx.sh data bvecs bvals mask
#
#
# Michael Hart, St George's University of London, January 2022 (c)

#define

codedir="${HOME}"/Dropbox/Github/tractography
basedir="$(pwd -P)"
FSLOUTPUTTYPE=NIFTI_GZ #occassionally not set as standard


mkdir -pv bpx

cp ${1} bpx/data.nii.gz
cp ${2} bpx/bvecs
cp ${3} bpx/bvals
cp ${4} bpx/nodif_brain_mask.nii.gz

echo "BedPostX datacheck"
bedpostx_datacheck bpx

#call to run with CPU
echo "running BedPostX with CPU"
#set to just sticks
bedpostx bpx --model=2

#call to run with GPU
#echo "running BedPostX with GPU"
#bedpostx_gpu bpx --model=2
