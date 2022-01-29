#!/bin/bash
set -e

# make_bedpostx.sh
#
#
# Michael Hart, St George's University of London, January 2022 (c)

#define

codedir=${HOME}/Dropbox/Github/tractography
basedir="$(pwd -P)"
FSLOUTPUTTYPE=NIFTI_GZ #occassionally not set as standard


mkdir -pv bpx

cp ${1} bpx/data.nii.gz
cp ${2} bpx/bvecs
cp ${3} bpx/bvals
cp ${4} bpx/nodif_brain_mask.nii.gz

echo "BedPostX datacheck"
bedpostx_datacheck bpx

echo "running BedPostX in serial"
#set to just sticks
bedpostx bpx --model=1

#call to run with GPU
#bedpostx_gpu

#transfer registrations
cp -r registrations/* bpx.bedpostX/xfms
