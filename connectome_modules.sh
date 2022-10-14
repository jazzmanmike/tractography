#!/bin/bash
set -e

#define

codedir=${HOME}/Dropbox/Github/tractography/
basedir="$(pwd -P)"

usage()
{
cat<<EOF
usage: $0 options

=============================================================================================

connectome_modules.sh template

- performs a connectomics modularity analysis (connectome_modules.m)
- makes a folder with each modules nifti image (combined parcels)
- creates a .txt list of module image paths
- compares module similarity with sensori -motor region ROIs
- performs tractography based segmentation based on modules

Runs with: connectome_modules.m

Written by Michael Hart, University of British Columbia, May 2021

=============================================================================================

EOF
exit 1
}

basedir=`pwd`
template=$1
echo ${template}
#outname=`basename ${atlas} .nii.gz` #for parsing outputs
mkdir connectome_modules_${template}

#1. Connectome modularity matlab analysis
file_matlab=test_modules
echo "connectome_modules('${template}');exit" > ${file_matlab}.m
matlab -nodisplay -nosplash -nodesktop -r "${file_matlab}"


#2-4.Form modules from parcels, generate a .txt list of module image paths, perform cross-correlation of module with cortico-spinal seed

cd connectome_modules_${template}
touch cross_correlation.txt
touch modules_targets_list.txt

nModules=`ls module_* | wc -l` #number of modules in directory
echo "nModules = ${nModules}"
for iModule in module_*.txt; #for each module
do
    echo "doing module: ${iModule}"
    moduleName=`basename ${iModule} .txt`
    nParcels=`wc -l ${iModule} | awk '{print $1}'` #number of lines (parcels) in module_*.txt
    echo "nParcels = ${nParcels}"
    topparcel=`cat ${iModule} | awk 'FNR == 1 {print $1}'` #first parcel in module
    topparcel=`head -n ${topparcel} ${basedir}/${template}_seeds/seeds_targets_list.txt | tail -1` #.nii.gz image of parcel
    echo "topparcel is: ${topparcel}"
    cp ${topparcel} ${moduleName}.nii.gz
    echo "cp ${topparcel} ${moduleName}.nii.gz"

    while read line;
    do
        echo "doing parcel: ${line}"
        parcel=`head -n ${line} ${basedir}/${template}_seeds/seeds_targets_list.txt | tail -1`
        echo "parcel is: ${parcel}"
        fslmaths ${moduleName}.nii.gz -add ${parcel} ${moduleName}.nii.gz
    done < ${iModule}

    #doing cross correlation
    echo "cross correlation of ${moduleName}" >> cross_correlation.txt
    echo "cst_l" >> cross_correlation.txt
    echo `fslcc ${moduleName}.nii.gz ${codedir}/templates/cst_l_MNI.nii.gz` >> cross_correlation.txt
    echo "cst_r" >> cross_correlation.txt
    echo `fslcc ${moduleName}.nii.gz ${codedir}/templates/cst_r_MNI.nii.gz` >> cross_correlation.txt

    #make text list (for probtrackx call)
    echo `pwd`/${moduleName}.nii.gz >> modules_targets_list.txt

done


#5. Tractography

#Left - seed to target
probtrackx2 --samples=${basedir}/bpx.bedpostX/merged \
--mask=${basedir}/bpx.bedpostX/nodif_brain_mask \
--xfm=${basedir}/bpx.bedpostX/xfms/standard2diff \
--invxfm=${basedir}/bpx.bedpostX/xfms/diff2standard \
--seedref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
--seed=${basedir}/segmentation/thalamus_left_MNI.nii.gz \
--targetmasks=modules_targets_list.txt \
--dir=connectome_modules_left \
--loopcheck \
--onewaycondition \
--forcedir \
--opd \
--os2t \
--nsamples=5000

#find_the_biggest
find_the_biggest connectome_modules_left/seeds_to_* connectome_modules_left/biggest_segmentation


#Right - seed to target
probtrackx2 --samples=${basedir}/bpx.bedpostX/merged \
--mask=${basedir}/bpx.bedpostX/nodif_brain_mask \
--xfm=${basedir}/bpx.bedpostX/xfms/standard2diff \
--invxfm=${basedir}/bpx.bedpostX/xfms/diff2standard \
--seedref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
--seed=${basedir}/segmentation/thalamus_right_MNI.nii.gz \
--targetmasks=modules_targets_list.txt \
--dir=connectome_modules_right \
--loopcheck \
--onewaycondition \
--forcedir \
--opd \
--os2t \
--nsamples=5000

#find_the_biggest
find_the_biggest connectome_modules_right/seeds_to_* connectome_modules_right/biggest_segmentation


#all done
