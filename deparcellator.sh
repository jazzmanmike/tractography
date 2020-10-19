#!/bin/sh

#  deparcellator.sh
#  
#
#  Created by Michael Hart on 19/10/2020.
#  

echo "Creating seed and target regions"

mkdir -p ${path_project}/diffusion/parcellation/${parcellation}/seeds/
i=1

while [ ${i} -le  $numParcels ]
do
    fslmaths \
    ${path_project}/diffusion/parcellation/${parcellation}_WM_dwiSpace.nii.gz \
    -thr ${i} \
    -uthr ${i} \
    -bin \
    ${path_project}/diffusion/parcellation/${parcellation}/seeds/Seg`printf %04d $i`.nii.gz
    echo ${path_project}/diffusion/parcellation/${parcellation}/seeds/Seg`printf %04d $i`.nii.gz \
    >> ${path_project}/diffusion/parcellation/${parcellation}/seeds_targets_list.txt
    i=$((${i}+1))
done
