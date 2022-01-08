#!/bin/bash

#  conversion_acpc.sh
#
#  Run in: SD/SD_001/diffusion (files already made)
#  Code in: ${HOME}/github/tractography (including voxel_AC & voxel_PC masks)
#
#  Created July 2021


#1. Initialise & set directories

workingdir=/home/mgh40/rds/hpc-work/SD/SD_001/diffusion
codedir=/home/mgh40/github/tractography

cd ${workingdir}


#2. Registrations
#Register AC-PC seed in MNI space to structural space
#Use inverse transform (affine only)
#Input for calculation of transoforms was: structural.anat/T1_biascorr_brain


applywarp --in=${HOME}/code/github/tractography/templates/sphere_AC \
--ref=structural.anat/T1_biascorr_brain \
--warp=diffusion.bedpostX/xfms/standard2str_warp \
--out=native_AC \
--interp=nn

applywarp --in=${HOME}/code/github/tractography/templates/sphere_PC \
--ref=structural.anat/T1_biascorr_brain \
--warp=diffusion.bedpostX/xfms/standard2str_warp \
--out=native_PC \
--interp=nn


#3. Co-ordinates
#Get co-ordinates of AC & PC

#MNI
#AC: 45 64 33
#PC: 45 50 35

mni_AC=`fslstats ${HOME}/code/github/tractography/templates/sphere_AC -V`
mni_PC=`fslstats ${HOME}/code/github/tractography/templates/sphere_PC -V`


#Structural
#AC: 128 136 78
#PC: 128 110 78
#Notes:

structural_AC=`fslstats native_AC -V`
structural_PC=`fslstats native_PC -V`


#Calculations

#MNI
#y-vector: 0 56 34
#Somewhere on the left (in AC-PC plane): 50 56 34
#x-vector: 5 0 0
#z-vector = cross(y-vector, x-vector)

#Structural
#y-vector: 0 119 0

