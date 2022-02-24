#!/bin/bash
set -e

# image_analysis.sh
#
#
# Michael Hart, St George's University of London, January 2022 (c)

#define

codedir=${HOME}/Dropbox/Github/tractography
basedir="$(pwd -P)"
FSLOUTPUTTYPE=NIFTI_GZ #occassionally not set as standard

#make usage function

usage()
{
cat<<EOF
usage: $0 options

=============================================================================================

image_analysis.sh

(c) Michael Hart, St George's University of London, January 2022

Image analysis pipeline for DBS data

Can run with tract_QC.sh for post run quality control

Example:

image_analysis.sh --T1=mprage.nii.gz --data=diffusion.nii.gz --bvecs=bvecs.txt --bvals=bvals.txt --FLAIR=FLAIR.nii.gz

Options:

Mandatory
--T1            structural (T1) image
--data          diffusion data (e.g. standard = single B0 as first volume)
--bvecs         bvecs file
--bvals         bvals file

Optional
--FLAIR         FLAIR image
--acqparams     acquisition parameters (custom values, for Eddy/TopUp, or leave acqparams.txt in basedir)
--index         diffusion PE directions (custom values, for Eddy/TopUp, or leave index.txt in basedir)
--segmentation  additional segmentation template (for segmentation: default is Yeo7)
--parcellation  additional parcellation template (for connectomics: default is AAL90 cortical)
--nsamples      number of samples for tractography (xtract, segmentation, connectome)
-d              denoise: runs topup & eddy (see code for default acqparams/index parameters or enter custom as above)
-b              (de)bug: only run analyses not performed yet
-p              parallel processing (slurm)*
-o              overwrite (re-do everything)
-h              show this help
-v              verbose

Pipeline
1.  Baseline image quality control
2.  make_anatomy (fsl_anat, FIRST, bet)
3.  make_freesurfer (recon-all, QA_checks, re-parcellation)
4.  make_registration (fsl)
5.  make_ants (brain extraction, registration, segmentation)
6.  make_diffusiondenoise (optional)
7.  make_FDT
8.  make_bedpostx
9.  make_xtract
10. make_segmentation
11. make_connectome


Version:    1.0 January 2022

History:

NB: requires Matlab, Freesurfer, FSL, ANTs, and set path to codedir

=============================================================================================

EOF
exit 1
}


####################
# Run options call #
####################


#unset mandatory files
data=unset
T1=unset
bvecs=unset
bvals=unset


# Call getopt to validate the provided input
options=$(getopt -n image_analysis.sh -o dbpohv --long data:,T1:,bvecs:,bvals:,FLAIR:,acqparams:,index:,segmentation:,parcellation:,nsamples: -- "$@")
echo "Options are: ${options}"

# If empty options
if [[ $1 == "" ]]; then
    usage
    exit 1
fi

# If options not valid
valid_options=$?

if [ "$valid_options" != "0" ]; then
    usage
    exit 1
fi

eval set -- "$options"
while :
do
    case "$1" in
    -p)             parallel=1          ;   shift   ;;
    -d)             denoise=1           ;   shift   ;;
    -b)             debug=1             ;   shift   ;;
    -o)             overwrite=1         ;   shift   ;;
    -h)             usage               ;   exit 1  ;;
    -v)             verbose=1           ;   shift   ;;
    --data)         data="$2"           ;   shift 2 ;;
    --T1)           T1="$2"             ;   shift 2 ;;
    --bvecs)        bvecs="$2"          ;   shift 2 ;;
    --bvals)        bvals="$2"          ;   shift 2 ;;
    --FLAIR)        FLAIR="$2"          ;   shift 2 ;;
    --acqparams)    acqp="$2"           ;   shift 2 ;;
    --index)        index="$2"          ;   shift 2 ;;
    --segmentation) segmentation="$2"   ;   shift 2 ;;
    --parcellation) parcellation="$2"   ;   shift 2 ;;
    --nsamples)     nsamples="$2"       ;   shift 2 ;;
    --) shift; break ;;
    esac
done



###############
# Run checks #
##############


#check usage

if [[ -z ${data} ]] || [[ -z ${T1} ]] || [[ -z ${bvecs} ]] || [[ -z ${bvals} ]]
then
    echo "usage incorrect: mandatory inputs not entered"
    usage
    exit 1
fi


#call mandatory images / files

echo "Diffusion data are: ${data}"
echo "Structural data are: ${T1}"
echo "bvecs are: ${bvecs}"
echo "bvals are: ${bvals}"


#call non-mandatory options

if [ "${parallel}" == 1 ] ;
then
    echo "running in parallel with slurm"
else
    echo "running sequentially"
fi

if [ "${denoise}" == 1 ] ;
then
    echo "denoising set up: will run topup & eddy"
else
    echo "not running topup or eddy"
fi

if [ "${overwrite}" == 1 ] ;
then
    echo "overwrite set on"
else
    echo "overwrite is off"
fi

if [ "${verbose}" == 1 ] ;
then
    echo "verbose set on"
    set -x verbose
else
    echo "verbose set off"
fi

if [ "${debug}" == 1 ] ;
then
    echo "debug set on"
    set -x verbose
else
    echo "debug set off"
fi

echo "options ok"


#check mandatory images / files

echo "Checking mandatory files are ok (data, structural, bvecs, bvals)"

data_test=${basedir}/${data}

if [ $(imtest $data_test) == 1 ] ;
then
    echo "diffusion data ok"
else
    echo "Cannot locate data file ${data_test}. Please ensure the ${data_test} dataset is in this directory -> exiting now" >&2
    exit 1
fi

T1_test=${basedir}/${T1}

if [ $(imtest $T1_test) == 1 ] ;
then
    echo "structural data ok"
else
    echo "Cannot locate structural file ${T1_test}. Please ensure the ${T1_test} dataset is in this directory -> exiting now" >&2
    exit 1
fi

bvecs_test=${basedir}/${bvecs}

if [ -f $bvecs_test ] ;
then
  echo "bvecs are ok"
else
  echo "Cannot locate bvecs file ${bvecs_test}. Please ensure the ${bvecs_test} dataset is in this directory -> exiting now" >&2
  exit 1
fi

bvals_test=${basedir}/${bvals}

if [ -f $bvals_test ] ;
then
  echo "bvals are ok"
else
  echo "Cannot locate bvals file ${bvals_test}. Please ensure the ${bvals_test} dataset is in this directory -> exiting now" >&2
  exit 1
fi

echo "All mandatory files (data, structural, bvecs, bvals) are ok"


#check optional image files

FLAIR_test=${basedir}/${FLAIR}

if [ $(imtest $FLAIR_test) == 1 ] ;
then
    echo "FLAIR data ok"
else
    echo "Cannot locate FLAIR file ${FLAIR_test}. Running FreeSurfer without FLAIR."
fi

#segmentation atlas

segmentation_test=${basedir}/${segmentation}

if [ $(imtest $segmentation_test) == 1 ] ;
then
    echo "Using ${segmentation_test} for segmentation: file is ok"
    segmentation=${segmentation_test}
else
    echo "Cannot locate additional segmentation template file: ${segmentation_test}. Please ensure the ${segmentation_test} is in this directory. Otherwise will continue with default DK (clustering), Yeo7, & kmeans segmentation."
fi

#parcellation template

parcellation_test=${basedir}/${parcellation}

if [ $(imtest $parcellation_test) == 1 ] ;
then
    echo "Using ${parcellation_test} for parcellation: file is ok"
    parcellation=${parcellation_test}
else
    echo "Cannot locate additional parcellation template file: ${parcellation_test}. Please ensure the ${parcellation_test} is in this directory. Otherwise will continue with default AAL90 parcellation template."
fi


#make directory structure
if [ ! -d ${basedir}/diffusion ] ;
then
    echo "making output directory"
    mkdir -p ${basedir}/diffusion
else
    echo "output directory already exists"
    if [[ "${overwrite}" -eq 1 ]] ;
    then
        echo "overwrite on: making new output directory"
        rm -r ${basedir}/diffusion
        mkdir -p ${basedir}/diffusion
    elif [[ "${debug}" -eq 1 ]] ;
    then
        echo "debug on: keeping directory"
    else
        echo "no overwrite permission (or debug) to replace existing output directory -> exiting now"
        exit 1
    fi
fi

echo "basedir is ${basedir}"

outdir=${basedir}/diffusion

mkdir -p ${outdir}/QC

echo "outdir is: ${outdir}"


#move & gzip & rename files: use these files & preserve originals
fslchfiletype NIFTI_GZ ${data_test} ${outdir}/data #make copies of inputs in diffusion folder
data=${outdir}/data.nii.gz #this is now working data with standard prefix

fslchfiletype NIFTI_GZ ${T1_test} ${outdir}/structural
structural=${outdir}/structural.nii.gz

fslchfiletype NIFTI_GZ ${FLAIR_test} ${outdir}/FLAIR
FLAIR=${outdir}/FLAIR.nii.gz

cp $bvecs_test ${outdir}
bvecs=${outdir}/${bvecs}
cp $bvals_test ${outdir}
bvals=${outdir}/${bvals}

#work in outdir (${basedir}/diffusion)
echo "working in ${outdir}"
cd ${outdir}

#Start logfile: if already exists (and therefore script previously run) stops here

if [ ! -f ${outdir}/image_analysis_log.txt ] ;
then
    echo "making log file"
    touch image_analysis_log.txt
else
    echo "log file already exists - image_analysis.sh has probably been run already"
    if [[ "$overwrite" == 1 ]] ;
    then
        echo "overwrite on: removing log file and making new one"
        rm image_analysis_log.txt
        touch image_analysis_log.txt
    elif [[ "$debug" == 1 ]] ;
    then
        echo "debug on: keeping log"
    else
        echo "no overwrite permission"
        exit 1
    fi
fi

log=image_analysis_log.txt
echo $(date) >> ${log}
echo "${0}" >> ${log}
echo "${@}" >> ${log}
echo "Starting image_analysis.sh"
echo "" >> ${log}
echo "Options are: ${options}" >> ${log}
echo "" >> ${log}
echo "basedir is ${basedir}" >> ${log}
echo "outdir is ${outdir}" >> ${log}
echo "" >> ${log}


##################
# Main programme #
##################


function imageANALYSIS() {


    ########################


    #1. Base image quality control


    ########################


    echo "" >> $log
    echo $(date) >> $log
    echo "1. Base image quality control" >> $log


    #run baseline checks

    #diffusion
    fslhd ${outdir}/data.nii.gz >> ${outdir}/QC/DTI_header.txt
    fslroi ${data} B0 0 1
    fslroi ${data} B1 1 1
    slicer B0.nii.gz -a ${outdir}/QC/B0_base_image.ppm
    slicer B1.nii.gz -a ${outdir}/QC/B1_base_image.ppm

    #structural
    fslhd ${structural} >> ${outdir}/QC/structural_header.txt
    slicer ${structural} -a ${outdir}/QC/structural_base_image.ppm


    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with base image quality control" >> $log
    echo "" >> $log


    ####################

    #2. Advanced Anatomy

    ####################


    echo "" >> $log
    echo $(date) >> $log
    echo "2. Starting make_anatomy" >> $log


    if [ ! -d ${outdir}/structural.anat ] ;
    then
        echo "calling make_anatomy.sh"
        make_anatomy.sh ${structural}
    else
        if [[ "${debug}" -eq 1 ]] ;
        then
            echo "structural.anat exists and debug is on: not calling make_anatomy.sh again"
        else
            echo "structural.anat exists and debug is off: repeating & overwriting make_anatomy.sh"
            make_anatomy.sh ${structural}
        fi
    fi


    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with make_anatomy" >> $log
    echo "" >> $log


    ###############

    #3. FreeSurfer

    ###############


    echo "" >> $log
    echo $(date) >> $log
    echo "3. Starting make_freesurfer" >> $log


    if [ ! -d ${outdir}/FS ] ;
    then
        echo "calling make_freesurfer.sh"
        make_freesurfer.sh ${structural} ${FLAIR}
    else
        if [[ "${debug}" -eq 1 ]] ;
        then
            echo "FS exists and debug is on: not calling make_freesurfer.sh again"
        else
            echo "FS exists and debug is off: calling make_freesurfer.sh again"
            make_freesurfer.sh ${structural} ${FLAIR}
        fi
    fi


    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with make_freesurfer" >> $log
    echo "" >> $log


    #################

    #4. Registration

    #################


    echo "" >> $log
    echo $(date) >> $log
    echo "4. Starting make_registration" >> $log

    head=${outdir}/structural.anat/T1_biascorr.nii.gz
    brain=${outdir}/structural.anat/T1_biascorr_brain.nii.gz

    echo "head is: ${head}"
    echo "brain is: ${brain}"

    if [ ! -d ${outdir}/registrations ] ;
    then
        echo "calling make_registrations.sh"
        make_registrations.sh ${brain} ${head} ${data}
    else
        if [[ "${debug}" -eq 1 ]] ;
        then
            echo "registrations exists and debug is on: not calling make_registrations.sh again"
        else
            echo "registrations exists and debug is off: repeating & overwriting make_registrations.sh"
            make_registrations.sh ${brain} ${head} ${data}
        fi
    fi

    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with make_registration" >> $log
    echo "" >> $log


    #########

    #5. ANTS

    #########


    echo "" >> $log
    echo $(date) >> $log
    echo "5. Starting make_ants" >> $log


    if [ ! -d ${outdir}/ants_corthick  ] ;
    then
        echo "calling make_ants.sh"
        make_ants.sh ${structural}
    else
        if [[ "${debug}" -eq 1 ]] ;
        then
            echo "ANTS has been run and debug is on: not calling make_ants.sh again"
        else
            echo "ANTS has been run and debug is off: repeating & overwriting make_ants.sh"
            make_ants.sh ${structural}
        fi
    fi


    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with make_ants" >> $log
    echo "" >> $log


    #######################

    #6. Advanced de-noising

    #######################


    echo "" >> $log
    echo $(date) >> $log
    echo "6. Starting make_diffusiondenoise" >> $log


    #make_diffusiondenoise.sh


    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with make_diffusiondenoise" >> $log
    echo "" >> $log


    ########

    #7. FDT

    ########


    echo "" >> $log
    echo $(date) >> $log
    echo "7. Starting make_FDT" >> $log

    mask=${basedir}/diffusion/registrations/nodif_brain_mask.nii.gz

    if [ ! -d ${outdir}/FDT ] ;
    then
        echo "calling make_FDT.sh"
        make_FDT.sh ${data} ${mask} ${bvecs} ${bvals}
    else
        if [[ "${debug}" -eq 1 ]] ;
        then
            echo "FDT exists and debug is on: not calling make_FDT.sh again"
        else
            echo "FDT exists and debug is off: repeating & overwriting make_FDT.sh"
            make_FDT.sh ${data} ${mask} ${bvecs} ${bvals}
        fi
    fi


    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with make_FDT" >> $log
    echo "" >> $log


    #############

    #8. BedPostX

    #############


    echo "" >> $log
    echo $(date) >> $log
    echo "8. Starting make_bedpostx" >> $log


    if [ ! -d ${outdir}/bpx.bedpostX ] ;
    then
        echo "calling make_bedpostx.sh"
        make_bedpostx.sh ${data} ${bvecs} ${bvals} registrations/nodif_brain_mask.nii.gz
    else
        if [[ "${debug}" -eq 1 ]] ;
        then
            echo "bpx.bedpostX exists and debug is on: not calling make_bedspotx.sh again"
        else
            echo "bpx.bedpostX exists and debug is off: repeating & overwriting make_bedpostx.sh"
            make_bedpostx.sh ${data} ${bvecs} ${bvals} registrations/nodif_brain_mask.nii.gz
          fi
    fi


    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with make_bedpostx" >> $log
    echo "" >> $log


    ##########

    #9. XTRACT

    ##########


    echo "" >> $log
    echo $(date) >> $log
    echo "9. Starting make_xtract" >> $log


    if [ ! -d ${outdir}/dbsxtract ] ;
    then
        echo "calling make_xtract.sh"
        make_xtract.sh
    else
        if [[ "${debug}" -eq 1 ]] ;
        then
            echo "dbsxtract exists and debug is on: not calling make_xtract.sh again"
        else
            echo "dbsxtract exists and debug is off: repeating & overwriting make_xtract.sh"
            make_xtract.sh
          fi
    fi


    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with make_xtract" >> $log
    echo "" >> $log


    #################

    #10. Segmentation

    #################

    echo "" >> $log
    echo $(date) >> $log
    echo "10. Starting make_segmentation" >> $log


    if [ ! -d ${outdir}/segmentation ] ;
    then
        echo "calling make_segmentation.sh"
        make_segmentation.sh ${segmentation}
    else
        if [[ "${debug}" -eq 1 ]] ;
        then
            echo "segmentation exists and debug is on: not calling make_segmentation.sh again"
        else
            echo "segmentation exists and debug is off: repeating & overwriting make_segmentation.sh"
            make_segmentation.sh ${segmentation}
          fi
    fi


    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with make_segmentation" >> $log
    echo "" >> $log


    #################

    #11. Connectomics

    #################


    echo "" >> $log
    echo $(date) >> $log
    echo "11. Starting make_connectome" >> $log


    make_connectome.sh ${template}

    template=${codedir}/templates/500.sym_4mm.nii.gz #change this
    make_connectome.sh ${template}

    template=${outdir}/segmentation/dkn_volume_MNI_seq.nii.gz
    make_connectome.sh ${template}


    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with make_connectome" >> $log
    echo "" >> $log

    #####################

    #12. Network analysis

    #####################


    #runs from standard path

    #MSN - need to optimise
    #tractography connectome (x3) - need to check images ok - just run in terminal


    #######################

    #13. Electrode analysis

    #######################

    #runs from standard path

    #matlab -nodisplay -nosplash -nodesktop -r "run('home/michaelhart/Dropbox/Github/tractography/lead_job');exit;"

    #matlab -nodisplay -nosplash -nodesktop -r "run('home/michaelhart/Dropbox/Github/tractography/electrode_autoreconstruction');exit;"

    #call for PaCER, DiODE, FastField (x4 contacts per electrode with x3 voltages)


}


######################################################################

# Round up

######################################################################


#call function

imageANALYSIS

echo "image_analysis.sh completed"

#cleanup

echo "" >> $log
echo $(date) >> $log
echo "Clean up time" >> $log
echo "" >> $log


#rm diffusion.bedpostX/command_files/*
#rm diffusion.bedpostX/logs/*
#rm -r probtrackx/*/Seg*
#rm -r probtrackx/*/commands
#rm -r *seeds


echo "" >> $log
echo $(date) >> $log
echo "Clean up complete" >> $log

#close up

echo "" >> $log
echo "All done with image_analysis.sh" >> ${log}
echo $(date) >> ${log}
echo "" >> ${log}
