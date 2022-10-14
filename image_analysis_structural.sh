#!/bin/bash
set -e

# image_analysis_structural.sh
#
#
# Michael Hart, St George's University of London, March 2022 (c)

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

image_analysis_structural.sh

(c) Michael Hart, St George's University of London, March 2022

Image analysis pipeline for DBS data for purely structural data

Can run with tract_QC_structural.sh for post run quality control

Example:

image_analysis_structural.sh --T1=mprage.nii.gz

Options:

Mandatory
--T1            structural (T1) image

Optional
--diffusion     diffusion data (e.g. standard = single B0 as first volume)
If above specified, also requires:
--bvecs         bvecs file
--bvals         bvals file

--FLAIR         FLAIR image (for FreeSurfer)
-b              (de)bug: only run analyses not performed yet
-o              overwrite (erase & re-do everything)
-h              show this help
-v              verbose

Pipeline
1.  Baseline image quality control
2.  make_anatomy (fsl_anat, FIRST, bet)
3.  make_freesurfer (recon-all, QA_checks, re-parcellation)
4.  make_registration (fsl)
5.  make_ants (brain extraction, registration, segmentation)
6.  make_FDT
7.  lead_dbs (needs folder 'lead_analysis' in base directory with anat_t1.nii, anat_t2.nii & postop_ct.nii)
8.  make_MSN_connectome
9.  make_multireg (needs folder 'multi_reg' in base directory with files +/- *t2 *fgatir *flair *swi)


Version:    1.0 March 2022

History:

NB: requires Matlab, Freesurfer, FSL, ANTs, and set path to codedir (also see electrode_reconstruction & msn_connectome)

=============================================================================================

EOF
exit 1
}


####################
# Run options call #
####################


#unset mandatory files
diffusion=unset
T1=unset
bvecs=unset
bvals=unset


# Call getopt to validate the provided input
options=$(getopt -n image_analysis_structural.sh -o bohv --long diffusion:,T1:,bvecs:,bvals:,FLAIR: -- "$@")
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
    -b)             debug=1             ;   shift   ;;
    -o)             overwrite=1         ;   shift   ;;
    -h)             usage               ;   exit 1  ;;
    -v)             verbose=1           ;   shift   ;;
    --diffusion)    diffusion="$2"      ;   shift 2 ;;
    --T1)           T1="$2"             ;   shift 2 ;;
    --bvecs)        bvecs="$2"          ;   shift 2 ;;
    --bvals)        bvals="$2"          ;   shift 2 ;;
    --FLAIR)        FLAIR="$2"          ;   shift 2 ;;
    --) shift; break ;;
    esac
done



###############
# Run checks #
##############


#check usage

#if [[ -z ${diffusion} ]] || [[ -z ${T1} ]] || [[ -z ${bvecs} ]] || [[ -z ${bvals} ]]
if [[ -z ${T1} ]]
then
    echo "usage incorrect: mandatory inputs not entered"
    usage
    exit 1
fi


#call mandatory images / files

echo "Structural data are: ${T1}"
#echo "Diffusion data are: ${diffusion}"
#echo "bvecs are: ${bvecs}"
#echo "bvals are: ${bvals}"


#call non-mandatory options

if [ "${debug}" == 1 ] ;
then
    echo "debug set on"
    set -x verbose
else
    echo "debug set off"
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

echo "options ok"


#check mandatory images / files

echo "Checking mandatory structural is ok "


T1_test=`readlink -f ${T1}`

if [ $(imtest $T1_test) == 1 ] ;
then
    echo "structural data ok"
else
    echo "Cannot locate structural file ${T1_test}. Please ensure the ${T1_test} dataset is in this directory -> exiting now" >&2
    exit 1
fi

echo "Mandatory file (structural) is ok"


#check optional image files

diffusion_test=`readlink -f ${diffusion}`

if [ $(imtest $diffusion_test) == 1 ] ;
then
    echo "diffusion data ok: now checking for bvecs and bvals"

    bvecs_test=`readlink -f ${bvecs}`
    if [ -f $bvecs_test ] ;
    then
      echo "bvecs are ok"
    else
      echo "Cannot locate bvecs file ${bvecs_test}. Please ensure the ${bvecs_test} dataset is in this directory -> exiting now" >&2
    fi

    bvals_test=`readlink -f ${bvals}`
    if [ -f $bvals_test ] ;
    then
      echo "bvals are ok"
    else
      echo "Cannot locate bvals file ${bvals_test}. Please ensure the ${bvals_test} dataset is in this directory -> exiting now" >&2
    fi

else
    echo "Cannot locate data file ${diffusion_test}. Please ensure the ${diffusion_test} dataset is in this directory -> exiting now" >&2
fi

FLAIR_test=`readlink -f ${FLAIR}`

if [ $(imtest $FLAIR_test) == 1 ] ;
then
    echo "FLAIR data ok"
else
    echo "Cannot locate FLAIR file ${FLAIR_test}. Running FreeSurfer without FLAIR."
fi


#make directory structure
if [ ! -d ${basedir}/structural ] ;
then
    echo "making output directory"
    mkdir -p ${basedir}/structural
else
    echo "output directory already exists"
    if [[ "${overwrite}" -eq 1 ]] ;
    then
        echo "overwrite on: making new output directory"
        rm -r ${basedir}/structural
        mkdir -p ${basedir}/structural
    elif [[ "${debug}" -eq 1 ]] ;
    then
        echo "debug on: keeping directory, performing additional analyses if required"
    else
        echo "no overwrite permission (or debug) to replace existing output directory -> exiting now"
        exit 1
    fi
fi

echo "basedir is ${basedir}"

outdir=${basedir}/structural

mkdir -p ${outdir}/QC

echo "outdir is: ${outdir}"


#move & gzip & rename files: use these files & preserve originals
fslchfiletype NIFTI_GZ ${T1_test} ${outdir}/structural
structural=${outdir}/structural.nii.gz

if [ $(imtest $FLAIR_test) == 1 ] ;
then
    fslchfiletype NIFTI_GZ ${FLAIR_test} ${outdir}/FLAIR
    FLAIR=${outdir}/FLAIR.nii.gz
fi

if [ $(imtest $diffusion_test) == 1 ] ;
then
    fslchfiletype NIFTI_GZ ${diffusion_test} ${outdir}/diffusion #make copies of inputs in diffusion folder
    diffusion=${outdir}/diffusion.nii.gz #this is now working data with standard prefix

    cp $bvecs_test ${outdir}/bvecs
    bvecs=${outdir}/bvecs
    cp $bvals_test ${outdir}/bvals
    bvals=${outdir}/bvals
fi

#work in outdir (${basedir}/structural)
echo "working in ${outdir}"
cd ${outdir}

#Start logfile: if already exists (and therefore script previously run) stops here

if [ ! -f ${outdir}/image_analysis_log.txt ] ;
then
    echo "making log file"
    touch image_analysis_structural_log.txt
else
    echo "log file already exists - image_analysis_structural.sh has probably been run already"
    if [[ "$overwrite" == 1 ]] ;
    then
        echo "overwrite on: removing log file and making new one"
        rm image_analysis_structural_log.txt
        touch image_analysis_structural_log.txt
    elif [[ "$debug" == 1 ]] ;
    then
        echo "debug on: keeping log"
    else
        echo "no overwrite permission"
        exit 1
    fi
fi

log=image_analysis_structural_log.txt
echo $(date) >> ${log}
echo "${0}" >> ${log}
echo "${@}" >> ${log}
echo "Starting image_analysis_structural.sh"
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

    #structural
    fslhd ${structural} >> ${outdir}/QC/structural_header.txt
    slicer ${structural} -a ${outdir}/QC/structural_base_image.ppm

    #diffusion
    if [ $(imtest $diffusion_test) == 1 ] ;
    then
        fslhd ${outdir}/diffusion.nii.gz >> ${outdir}/QC/DTI_header.txt
        fslroi ${diffusion} B0 0 1
        fslroi ${diffusion} B1 1 1
        slicer B0.nii.gz -a ${outdir}/QC/B0_base_image.ppm
        slicer B1.nii.gz -a ${outdir}/QC/B1_base_image.ppm
    fi


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

    brain=${outdir}/structural.anat/T1_biascorr_brain.nii.gz
    head=${outdir}/structural.anat/T1_biascorr.nii.gz

    echo "brain is: ${brain}"
    echo "head is: ${head}"

    if [ $(imtest $diffusion_test) == 1 ] ;
    then
        if [ ! -d ${outdir}/registrations ] ;
        then
            echo "calling make_registrations.sh"
            make_registrations.sh ${brain} ${head} ${diffusion}
        else
            if [[ "${debug}" -eq 1 ]] ;
            then
                echo "registrations exists and debug is on: not calling make_registrations.sh again"
            else
                echo "registrations exists and debug is off: repeating & overwriting make_registrations.sh"
                make_registrations.sh ${brain} ${head} ${diffusion}
            fi
        fi
    else
        make_registrations_nodiff.sh ${brain} ${head}
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


    ########

    #6. FDT

    ########


    echo "" >> $log
    echo $(date) >> $log
    echo "6. Starting make_FDT" >> $log

    mask=${basedir}/structural/registrations/nodif_brain_mask.nii.gz

    if [ $(imtest $diffusion_test) == 1 ] ;
    then
        if [ ! -d ${outdir}/FDT ] ;
        then
            echo "calling make_FDT.sh"
            make_FDT.sh ${diffusion} ${mask} ${bvecs} ${bvals}
        else
            if [[ "${debug}" -eq 1 ]] ;
            then
                echo "FDT exists and debug is on: not calling make_FDT.sh again"
            else
                echo "FDT exists and debug is off: repeating & overwriting make_FDT.sh"
                make_FDT.sh ${diffusion} ${mask} ${bvecs} ${bvals}
            fi
        fi
    else
        echo "no diffusion data has been submitted: not calling make_FDT.sh"
    fi


    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with make_FDT" >> $log
    echo "" >> $log


    ######################

    #7. Electrode analysis

    ######################


    echo "" >> "$log"
    date >> "$log"
    echo "7. Starting electrode analysis" >> "$log"


    if [ -d ${basedir}/electrode_analysis ] ;
    then
        if [ ! -d ${outdir}/electrode_analysis ] ;
        then
            echo "calling make_electrodes.sh"
            #set up directory
            mkdir -p ${outdir}/electrode_analysis
            cp ${basedir}/electrode_analysis/anat_t1.nii ${outdir}/electrode_analysis/
            cp ${basedir}/electrode_analysis/postop_ct.nii ${outdir}/electrode_analysis/
            make_electrodes.sh
        else
            if [[ "${debug}" -eq 1 ]] ;
            then
                echo "make_electrodes.sh has been run and debug is on: not calling make_electrodes.sh again"
            else
                echo "make_electrodes.sh has been run and debug is off: repeating make_electrodes.sh"
                #set up directory
                mkdir -p ${outdir}/electrode_analysis
                cp ${basedir}/electrode_analysis/anat_t1.nii ${outdir}/electrode_analysis/
                cp ${basedir}/electrode_analysis/postop_ct.nii ${outdir}/electrode_analysis/
                make_electrodes.sh
            fi
        fi
    else
        echo "No electrode analysis folder: not calling make_electrodes.sh"
        echo "No electrode analysis folder: not calling make_electrodes.sh" >> "$log"
    fi


    echo "" >> "$log"
    date >> "$log"
    echo "Finished with electrode analysis" >> "$log"
    echo "" >> "$log"


    ################

    #8. MSN analysis

    ################


    echo "" >> $log
    echo $(date) >> $log
    echo "8. Starting MSN analysis" >> $log

    if [ $(imtest $diffusion_test) == 1 ] ;
    then
        #Register FA & MD to segmentation/dkn_volume_MNI
        applywarp --in=FDT/dti_FA.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz --warp=registrations/str2standard_warp --premat=registrations/diff2str.mat --out=FDT/dti_FA_MNI.nii.gz
        applywarp --in=FDT/dti_MD.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz --warp=registrations/str2standard_warp --premat=registrations/diff2str.mat --out=FDT/dti_MD_MNI.nii.gz

        #Make individual DK atlas in MNI space
        SUBJECTS_DIR=`pwd`
        mri_aparc2aseg --s FS --annot aparc
        mri_convert ./FS/mri/aparc+aseg.mgz dkn_volume.nii.gz
        fslreorient2std dkn_volume.nii.gz dkn_volume.nii.gz

        #Registration
        flirt -in dkn_volume.nii.gz -ref ${codedir}/templates/500.sym_4mm.nii.gz -o dkn_volume_MNI -dof 12 -interp nearestneighbour

        #Renumber sequentially
        file_matlab=temp_DK_renumDesikan
        echo "Matlab file is: ${file_matlab}.m"
        echo "Matlab file variable is: ${file_matlab}"
        echo "renumDesikan_sub('dkn_volume_MNI.nii.gz', 0);exit" > ${file_matlab}.m
        matlab -nodisplay -r "${file_matlab}"

        #end DK setup
        echo "dkn_volume_MNI_seq now made"
        atlas=dkn_volume_MNI_seq.nii.gz

        #Extract stats
        fslstats -K ${atlas} FDT/dti_FA_MNI.nii.gz -M >> FDT/FA_MNI_stats.txt
        fslstats -K ${atlas} FDT/dti_MD_MNI.nii.gz -M >> FDT/MD_MNI_stats.txt
    fi

    if [ ! -d ${outdir}/msn_connectome ] ;
    then
        matlab -nodisplay -nosplash -nodesktop -r "run('msn_individual_analysis_pipeline');exit;"
    fi


    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with MSN analysis" >> $log
    echo "" >> $log


    #############

    #9. Multi-reg

    #############


    echo "" >> "$log"
    date >> "$log"
    echo "9. Starting multi_reg analysis" >> "$log"


    if [ -d ${basedir}/multi_reg ] ;
    then
        if [ ! -d ${outdir}/multi_reg ] ;
        then
            echo "calling make_multireg.sh"
            mkdir -pv ${outdir}/multi_reg
            cp ${basedir}/multi_reg/* ${outdir}/multi_reg
            make_multireg.sh
        else
            if [[ "${debug}" -eq 1 ]] ;
            then
                echo "multireg exists and debug is on: not calling make_multireg.sh again"
            else
                echo "multireg exists and debug is off: repeating & overwriting make_multireg.sh"
                mkdir -pv ${outdir}/multi_reg
                cp ${basedir}/multi_reg/* ${outdir}/multi_reg
                make_multireg.sh
            fi
        fi
        echo "No multi_reg folder: not calling make_multi_reg.sh"
        echo "No multi_reg folder: not calling make_multi_reg.sh" >> "$log"
    fi


    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with multi_reg analysis" >> $log
    echo "" >> $log


}


######################################################################

# Round up

######################################################################


#call function

imageANALYSIS

echo "image_analysis_structural.sh completed"

#cleanup

echo "" >> $log
echo $(date) >> $log
echo "Clean up time" >> $log

#rm

echo "" >> $log
echo $(date) >> $log
echo "Clean up complete" >> $log


#close up

echo "" >> $log
echo "All done with image_analysis_structural.sh" >> ${log}
echo $(date) >> ${log}
echo "" >> ${log}
