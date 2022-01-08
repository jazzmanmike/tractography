#!/bin/bash

#  bit_anatomy.sh
#
#  Separate script for running fsl_anat, FIRST, and FreeSurfer calls
#
#  Created by Michael Hart, July 2021

#################

#Set up

#################


#remove me from tract_van.sh
tempdir=`pwd`
echo ${tempdir}
codedir=${HOME}/code/github/tractography
FSLOUTPUTTYPE=NIFTI_GZ #occassionally not set as standard

#make log
test -f bit_anatomy_log.txt && rm bit_anatomy_log.txt
touch ${tempdir}/bit_anatomy_log.txt
log=${tempdir}/bit_anatomy_log.txt

echo $(date) >> ${log}
echo "starting bit_anatomy" >> ${log}
echo "workingdir is ${tempdir}" >> ${log}
echo "codedir is ${codedir}" >> ${log}


#########

#FSL_ANAT

#########


echo "" >> $log
echo $(date) >> $log
echo "Starting fsl_anat" >> $log
  

if [ "${parallel}" == 1 ] ;
then
    echo "submitting fsl_anat to slurm"

    #make batch file
    touch batch_anat.sh
    echo '#!/bin/bash' >> batch_anat.sh
    printf "structural=%s\n" "${structural}" >> batch_anat.sh
    printf "tempdir=%s\n" "${tempdir}" >> batch_anat.sh
    echo 'fsl_anat -i ${structural} -o ${tempdir}/structural --clobber --nosubcortseg' >> batch_anat.sh
    echo 'slicer structural.anat/T1_biascorr_brain.nii.gz -a ${tempdir}/QC/fsl_anat_bet.ppm' >> batch_anat.sh

    #now set up first (e.g. for thalamus & pallidum to be used later)
    mkdir ${tempdir}/first_segmentation
    echo 'run_first_all -i structural.anat/T1_biascorr_brain.nii.gz -o ${tempdir}/first_segmentation -b -d' >> batch_anat.sh
    echo 'first_roi_slicesdir structural.anat/T1_biascorr_brain.nii.gz ${tempdir}/first-*nii.gz' >> batch_anat.sh

    #now call it
    chmod 777 ${tempdir}/batch_anat.sh
    sbatch --time 12:00:00 --nodes=1 --mem=30000 --tasks-per-node=12  --cpus-per-task=1 batch_anat.sh
    
    #bet
    mkdir bet
    cd bet
    bet ${structural} ${structural}_bet -A
    cd ..

else
    echo "sequential turned off for now - not running fsl_anat"
fi
   
   
echo "" >> $log
echo $(date) >> $log
echo "Finished with fsl_anat" >> $log
echo "" >> $log


###########

#Freesurfer

###########


echo "" >> $log
echo $(date) >> $log
echo "Starting FreeSurfer" >> ${log}

if [[ ! -d ${tempdir}/FS ]] ;
then
    echo "No FS directory - running FreeSurfer now"
    
    if [ "${parallel}" == 1 ] ;
    then

        export QA_TOOLS=${HOME}/code/QAtools_v1.2
        export SUBJECTS_DIR=`pwd`

        echo "QA Tools set up as ${QA_TOOLS}" >> ${log}
        echo "SUBJECTS_DIR set up as ${SUBJECTS_DIR}" >> ${log}

        #create batch file
        #rm batch_FS.sh
        touch batch_FS.sh
        echo '#!/bin/bash' >> batch_FS.sh
        printf "structural=%s\n" "${structural}" >> batch_FS.sh
        printf "patient_dir=%s\n" "${SUBJECTS_DIR}" >> batch_FS.sh

        #run Freesurfer
        echo 'recon-all -i ${structural} -s ${patient_dir}/FS -all' >> batch_FS.sh

        #run QA tools
        #NB: images don't always run with Linux/SLURM due to lack of tkmedit / tksurfer
        echo '${QA_TOOLS}/recon_checker -s ./FS' >> batch_FS.sh

        #additional parcellation for connectomics (muchas gracias cunado!)
        echo 'parcellation2individuals.sh' >> batch_FS.sh
          
        #now call it
        chmod 777 ${SUBJECTS_DIR}/batch_FS.sh
        #sbatch --time 18:00:00 --nodes=1 --mem=30000 --tasks-per-node=12 --cpus-per-task=1 batch_FS.sh
        sbatch --time 23:00:00 batch_FS.sh
    else
        echo "sequential turned off for now - not running FreeSurfer"
    fi
fi


echo "" >> $log
echo $(date) >> $log
echo "Finished with FreeSurfer" >> $log
echo "" >> $log


#########

#FSL_ANAT

#########


echo "" >> $log
echo $(date) >> $log
echo "Starting ANTs" >> ${log}


cp ${structural} ${tempdir}/structural.nii.gz

ants_brains.sh -s structural.nii.gz

ants_corthick.sh -s ${structural}

ants_struct2stand.sh -s ants_brains/BrainExtractionBrain.nii.gz

#ants_diff2struct.sh -d nodif_brain.nii.gz -s ants_brains/BrainExtractionBrain.nii.gz

#ants_regcheck.sh -d nodif_brain.nii.gz -w ants_struct2stand/structural2standard.nii.gz -i ants_struct2stand/standard2structural.nii.gz -r ants_diff2struct/rigid0GenericAffine.mat


echo "" >> $log
echo $(date) >> $log
echo "Finished with ANTs" >> $log
echo "" >> $log


#########

#Close up

#########


echo "Cleanup of slurm* files"
echo "Cleanup of slurm* files" >> ${log}

rm slurm*
rm batch*

echo $(date) >> ${log}
echo "all done with bit_anatomy"
echo "all done with bit_anatomy" >> ${log}

#fin
