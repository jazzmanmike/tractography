#!/bin/bash
set -e

# make_template_fsl.sh
#
#
# Michael Hart, St George's University of London, July 2022 (c)


#Need to set up parallel [ ]
#Then need large directories of all fgatirs [ ]

#All images in a folder with same name structure
#Select all images
#Big loop
#Register all to image 1
#Register all to image n
#Average all group registrations
#Register to average

#Registration is:
#flirt
#fnirt
#convertwarp / applywarp
#slices

for base_template in `ls -d *fgatir*`;
do
  base=`basename "${base_template}" .nii`
  for registering_template in `ls -d *fgatir*`;
  do
    if [ "${registering_template}" != "${base_template}" ];
    then
        registering=`basename "${registering_template}" .nii`
        echo "flirt -in "${registering_template}" -ref "${base_template}" -omat "${base}"_to_"${registering}".mat -dof 12 | fnirt --in="${registering_template}" --ref="${base_template}" --aff="${base}"_to_"${registering}".mat --iout="${base}"_to_"${registering}" --config=T1_2_MNI152_2mm" >> my_parallel_file.txt #try as a one liner
    fi
    #Submit to parallel
    #parallel my_parallel_file
    #Catch for when done: wait or sleep
    #wait
    #Now add all templates
    #cp "${base_template}" "${base}"_average
    #for image in `ls -d *"${base}"_to*fgatir*`;
    #do
    #    echo "fslmaths "${base}"_average -add "${image}" "${base}"_average"
    #done
  done
done

#average_all_groups

#do one final registration loop to average_all_groups

#average this

#nb: do with only 3 images to start
