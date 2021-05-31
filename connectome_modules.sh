#!/bin/bash
set -e

#define

codedir=${HOME}/code/github/tractography
basedir="$(pwd -P)"

usage()
{
cat<<EOF
usage: $0 options

=============================================================================================

connectome_modules.sh

Takes a connectomics modularity analysis (see connectome_modules.m)
- makes a folder with each modules nifti image (combined parcels)
- creates a .txt list (for tractography based segmentation)
- compares module similarity with sensori-motor region ROIs

Runs with: connectome_modules.m

Written by Michael Hart, University of British Columbia, May 2021

=============================================================================================

EOF
exit 1
}

touch cross_correlation.txt
touch modules_targets_list.txt

nModules=`ls module_* | wc -l` #number of modules in directory
echo "nModules = ${nModules}"
for nModule in module_*.txt; #for each module
do
    echo "doing module: ${nModule}"
    moduleName=`basename ${nModule} .txt`
    nParcels=`wc -l ${nModule} | awk '{print $1}'` #number of lines (parcels) in module_*.txt
    echo "nParcels = ${nParcels}"
    topparcel=`cat ${nModule} | awk 'FNR == 1 {print $1}'` #first parcel in module
    topparcel=`head -n ${topparcel} seeds_targets_list.txt | tail -1` #.nii.gz image of parcel
    echo "topparcel is: ${topparcel}"
    echo "cp ${topparcel} ${moduleName}.nii.gz"
    
    while read line;
    do
        echo "doing parcel: ${line}"
        parcel=`head -n ${line} seeds_targets_list.txt | tail -1`
        echo "parcel is: ${parcel}"
        echo "fslmaths ${moduleName}.nii.gz -add ${parcel} ${moduleName}.nii.gz"
    done < ${nModule}

    #doing cross correlation
    echo "cross correlation of ${moduleName}" >> cross_correlation.txt
    echo "cst_l" >> cross_correlation.txt
    echo "fslcc ${moduleName}.nii.gz ${codedir}/templates/cst_l.nii.gz" >> cross_correlation.txt
    echo "cst_r" >> cross_correlation.txt
    echo "fslcc ${moduleName}.nii.gz ${codedir}/templates/cst_r.nii.gz" >> cross_correlation.txt
    
    #make text list (for probtrackx call)
    echo `pwd`/${moduleName}.nii.gz >> modules_targets_list.txt

done

#all done

        
        
    


