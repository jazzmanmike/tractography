#!/bin/bash
set -e

# make_FDT.sh
#
#
# Michael Hart, St George's University of London, January 2022 (c)

#define
codedir=${HOME}/Dropbox/Github/tractography
basedir="$(pwd -P)"
FSLOUTPUTTYPE=NIFTI_GZ #occassionally not set as standard

#input: data | bvecs | bvals
#output: nodif_brain_mask, DTI_brain_images, dti_FDT files

#extract B0 volume
fslroi ${data} nodif 0 1

#create binary brain mask
bet nodif nodif_brain -m -f 0.2
slicer nodif_brain -a ${outdir}/QC/DTI_brain_images.ppm

#fit diffusion tensor
dtifit --data=${data} --mask=nodif_brain_mask --bvecs=${bvecs} --bvals=${bvals} --out=dti --save_tensor
