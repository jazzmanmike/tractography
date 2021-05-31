#!/bin/bash

#  freesurfer_run.sh
#
#  Separate FreeSurfer call
#
#  Created by Michael Hart on 12/04/2021.
#  


codedir=${HOME}/code/


## Re-name

#for subject in `ls`
#do
#    echo $subject
#    cd ${subject}/*/*/*/
#    cp *nii ../../../mprage.nii
#    cd ../../..
#    rm -r MPRAGE_GRAPPA
#    gzip mprage.nii
#    patient_dir=`pwd`
#    echo $patient_dir
#    structural=${patient_dir}/mprage.nii.gz
#    echo $structural
#    cd ../ #remove this from here
#done


## Group directory batch

#for subject in `ls`
#do
#    echo ${subject}
#    cd ${subject}/
    
#    rm -r FS QA error.log slurm* batch_FS.sh fsaverageSubP
    
#    export QA_TOOLS=${HOME}/code/QAtools_v1.2
#    export SUBJECTS_DIR=`pwd`

#    echo "QA Tools set up as ${QA_TOOLS}"
#    echo "SUBJECTS_DIR set up as ${SUBJECTS_DIR}"
    
#    structural=${SUBJECTS_DIR}/anat_t1.nii
#    echo "Structural: $structural"
    
    #create batch file
    #rm batch_FS.sh
#    touch batch_FS.sh
#    echo '#!/bin/bash' >> batch_FS.sh
#    printf "structural=%s\n" "${structural}" >> batch_FS.sh
#    printf "patient_dir=%s\n" "${SUBJECTS_DIR}" >> batch_FS.sh

    #run Freesurfer
#    echo 'recon-all -i ${structural} -s ${patient_dir}/FS -all' >> batch_FS.sh

    #run QA tools
    #NB: images don't always run with Linux/SLURM
#    echo '${QA_TOOLS}/recon_checker -s ${patient_dir}/FS' >> batch_FS.sh

    #additional parcellation for connectomics
#    echo 'parcellation2individuals.sh' >> batch_FS.sh
         
    #set permissions
#    chmod 777 ${SUBJECTS_DIR}/batch_FS.sh
    
    #run as batch
    #sbatch --time 18:00:00 --nodes=1 --mem=30000 --tasks-per-node=12 --cpus-per-task=1 batch_FS.sh
#    sbatch --time 18:00:00 batch_FS.sh
    
#    cd ../
#done


## Individual call (in subject directory with anat_t1.nii)

export QA_TOOLS=${HOME}/code/QAtools_v1.2
export SUBJECTS_DIR=`pwd`

echo "QA Tools set up as ${QA_TOOLS}"
echo "SUBJECTS_DIR set up as ${SUBJECTS_DIR}"

structural=${SUBJECTS_DIR}/anat_t1.nii
echo "Structural: $structural"

#create batch file
#rm batch_FS.sh
touch batch_FS.sh
echo '#!/bin/bash' >> batch_FS.sh
printf "structural=%s\n" "${structural}" >> batch_FS.sh
printf "patient_dir=%s\n" "${SUBJECTS_DIR}" >> batch_FS.sh

#run Freesurfer
echo 'recon-all -i ${structural} -s ${patient_dir}/FS -all' >> batch_FS.sh

#run QA tools
#NB: images don't always run with Linux/SLURM
echo '${QA_TOOLS}/recon_checker -s ./FS' >> batch_FS.sh

#additional parcellation for connectomics
echo 'parcellation2individuals.sh' >> batch_FS.sh
  
#set permissions
chmod 777 ${SUBJECTS_DIR}/batch_FS.sh

#run as batch
#sbatch --time 18:00:00 --nodes=1 --mem=30000 --tasks-per-node=12 --cpus-per-task=1 batch_FS.sh
sbatch --time 23:00:00 batch_FS.sh



 

