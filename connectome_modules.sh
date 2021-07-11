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

connectome_modules.sh patientID template

- performs a connectomics modularity analysis (connectome_modules.m)
- makes a folder with each modules nifti image (combined parcels)
- creates a .txt list of module image paths
- compares module similarity with sensori-motor region ROIs
- performs tractography based segmentation based on modules

Runs with: connectome_modules.m

Written by Michael Hart, University of British Columbia, May 2021

=============================================================================================

EOF
exit 1
}

tempdir=`pwd`

mkdir connectome_modules

cd connectome_modules

#1. Connectome modularity matlab analysis
file_matlab=test_modules
echo "connectome_modules(patientID, template);exit" > ${file_matlab}.m
matlab -nodisplay -r "${file_matlab}"


#2-4.Form modules from parcels, generate a .txt list of module image paths, perform cross-correlation of module with cortico-spinal seed

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


#5. Tractography

#Left - seed to target
touch ${tempdir}/batch_connectomemodules_left.sh
echo "#!/bin/bash" >> ${tempdir}/batch_connectomemodules_left.sh
echo "probtrackx2 --samples=${tempdir}/diffusion.bedpostX/merged \
--mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
--xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
--invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
--seedref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
--seed=${tempdir}/segmentation/thalamus_left_MNI.nii.gz \
--targetmasks=${tempdir}/connectome_modules/modules_targets_list.txt \
--dir=connectome_modules_left \
--loopcheck \
--onewaycondition \
--forcedir \
--opd \
--os2t \
--nsamples=5000" >> ${tempdir}/batch_connectomemodules_left.sh
chmod 777 ${tempdir}/batch_connectomemodules_left.sh
sbatch --time=3:00:00 ${tempdir}/batch_connectomemodules_left.sh
           
#find_the_biggest
find_the_biggest connectome_modules_left/seeds_to_* connectome_modules_left/biggest_segmentation


#Right - seed to target
touch ${tempdir}/batch_connectomemodules_right.sh
echo "#!/bin/bash" >> ${tempdir}/batch_connectomemodules_right.sh
echo "probtrackx2 --samples=${tempdir}/diffusion.bedpostX/merged \
--mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
--xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
--invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
--seedref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
--seed=${tempdir}/segmentation/thalamus_right_MNI.nii.gz \
--targetmasks=${tempdir}/connectome_modules/modules_targets_list.txt \
--dir=connectome_modules_right \
--loopcheck \
--onewaycondition \
--forcedir \
--opd \
--os2t \
--nsamples=5000" >> ${tempdir}/batch_connectomemodules_right.sh
chmod 777 ${tempdir}/batch_connectomemodules_right.sh
sbatch --time=3:00:00 ${tempdir}/batch_connectomemodules_right.sh
           
#find_the_biggest
find_the_biggest connectome_modules_right/seeds_to_* connectome_modules_right/biggest_segmentation


fi


#all done

        
        
    


