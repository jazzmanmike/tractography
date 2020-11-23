#!/bin/sh

#  test_bet.sh
#  
#
#  Created by Michael Hart on 15/11/2020.
#  

structural=t1_UBC.nii.gz

#bet standard

bet $structural t1_UBC_bet -o
slicer t1_UBC_bet -a bet.ppm

#bet biascorr

bet $structural t1_UBC_bet_b -B -o
slicer t1_UBC_bet_b -a bet_b.ppm

#ants
#NB: needs MNI brain & mask

ants_brains.sh -s $structural

#fsl_anat

touch test_batch_anat.sh
echo '#!/bin/bash' >> test_batch_anat.sh
printf "structural=%s\n" "${structural}" >> test_batch_anat.sh
echo 'fsl_anat -i ${structural} -o test_structural --clobber --nosubcortseg' >> test_batch_anat.sh
echo 'slicer test_structural.anat/T1_biascorr_brain.nii.gz -a fsl_anat_bet.ppm' >> test_batch_anat.sh

chmod 777 test_batch_anat.sh

sbatch --time 12:00:00 --nodes=1 --mem=30000 --tasks-per-node=12  --cpus-per-task=1 test_batch_anat.sh

#now run first (e.g. for thalamus & pallidum to be used later)

echo "running fsl first"

mkdir first_segmentation

cd first_segmentation

run_first_all -i ../t1_UBC.nii.gz -o first -d

cd ../


#Freesurfer

export QA_TOOLS=${HOME}/code/QAtools_v1.2
export SUBJECTS_DIR=`pwd`

echo "QA Tools set up as ${QA_TOOLS}"
echo "SUBJECTS_DIR set up as ${SUBJECTS_DIR}"

#create batch file
touch test_batch_FS.sh
echo '#!/bin/bash' >> test_batch_FS.sh
printf "structural=%s\n" "${structural}" >> test_batch_FS.sh

#run Freesurfer
echo 'recon-all -i ${structural} -s test_FS -all' >> test_batch_FS.sh

#run QA tools
echo '${QA_TOOLS}/recon_checker -s test_FS' >> test_batch_FS.sh

#additional parcellation for connectomics
echo 'parcellation2individuals.sh' >> test_batch_FS.sh

#run as batch
chmod 777 test_batch_FS.sh

sbatch --time 18:00:00 --nodes=1 --mem=30000 --tasks-per-node=12 --cpus-per-task=1 test_batch_FS.sh



