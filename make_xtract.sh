#!/bin/bash
set -e

# make_xtract.sh
#
#
# Michael Hart, St George's University of London, January 2022 (c)

#define
codedir=${HOME}/Dropbox/Github/tractography
basedir="$(pwd -P)"
FSLOUTPUTTYPE=NIFTI_GZ #occassionally not set as standard


#XTRACT
#touch xtract_options.txt
#echo "--nsamples=${nsamples}" >> xtract_options.txt
#echo "--nsamples=500 using -ptx_options ${codedir}/xtract_options.txt"

#xtract -bpx diffusion.bedpostX -out myxtract -species HUMAN -ptx_options ${codedir}/xtract_options.txt
xtract -bpx diffusion.bedpostX -out myxtract -species HUMAN -gpu

#xtract_stats
xtract_stats -d ${tempdir}/dti_ -xtract myxtract -w diffusion.bedpostX/xfms/standard2diff.nii.gz -r ${tempdir}/dti_FA.nii.gz -keepfiles

#xtract_viewer
#xtract_viewer -dir myxtract -species HUMAN

#DBS XTRACT
xtract -bpx ${tempdir}/diffusion.bedpostX -out dbsxtract -str ${codedir}/dbsxtract/structureList -p ${codedir}/dbsxtract
