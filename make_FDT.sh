#!/bin/bash
set -e

# make_FDT.sh data mask bvecs bvals
#
#
# Michael Hart, St George's University of London, January 2022 (c)

#define
codedir=${HOME}/Dropbox/Github/tractography
basedir="$(pwd -P)"
FSLOUTPUTTYPE=NIFTI_GZ #occassionally not set as standard

#input: data | bvecs | bvals
#output: nodif_brain_mask, DTI_brain_images, dti_FDT files

#following from make_registrations.sh in diffusion.bedpostx/xfms
#extract B0 volume
#fslroi ${data} nodif 0 1
#create binary brain mask
#bet nodif nodif_brain -m -f 0.2
#slicer diffusion.bedpostX/xfms/nodif_brain.nii.gz -a QC/DTI_brain_images.ppm

mkdir -pv FDT
cd FDT

#fit diffusion tensor
dtifit --data=${1} --mask=${2} --bvecs=${3} --bvals=${4} --out=dti --save_tensor

cd ..
