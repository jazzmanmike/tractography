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

image_analysis.sh --T1=mprage.nii.gz --data=diffusion.nii.gz --bvecs=bvecs.txt --bvals=bvals.txt

Options:

Mandatory
--T1            structural (T1) image
--data          diffusion data (e.g. standard = single B0 as first volume)
--bvecs         bvecs file
--bvals         bvals file

Optional
--acqparams     acquisition parameters (custom values, for Eddy/TopUp, or leave acqparams.txt in basedir)
--index         diffusion PE directions (custom values, for Eddy/TopUp, or leave index.txt in basedir)
--segmentation  additional segmentation template (for segmentation: default is Yeo7)
--parcellation  additional parcellation template (for connectomics: default is AAL90 cortical)
--nsamples      number of samples for tractography (xtract, segmentation, connectome)
-d              denoise: runs topup & eddy (see code for default acqparams/index parameters or enter custom as above)
-p              parallel processing (slurm)*
-o              overwrite
-h              show this help
-v              verbose

Pipeline
1.  Baseline quality control
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
options=$(getopt -n image_analysis.sh -o dpohv --long data:,T1:,bvecs:,bvals:,acqparams:,index:,segmentation:,parcellation:,nsamples: -- "$@")
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
    -p)             parallel=1      ;   shift   ;;
    -d)             denoise=1       ;   shift   ;;
    -o)             overwrite=1     ;   shift   ;;
    -h)             usage           ;   exit 1  ;;
    -v)             verbose=1       ;   shift   ;;
    --data)         data="$2"       ;   shift 2 ;;
    --T1)           T1="$2"         ;   shift 2 ;;
    --bvecs)        bvecs="$2"      ;   shift 2 ;;
    --bvals)        bvals="$2"      ;   shift 2 ;;
    --acqparams)    acqp="$2"       ;   shift 2 ;;
    --index)        index="$2"      ;   shift 2 ;;
    --segmentation) atlas="$2"      ;   shift 2 ;;
    --parcellation) template="$2"   ;   shift 2 ;;
    --nsamples)     nsamples="$2"   ;   shift 2 ;;
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

#segmentation atlas

atlas_test=${basedir}/${atlas}

if [ $(imtest $atlas_test) == 1 ] ;
then
    echo "Using ${atlas_test} for segmentation: file is ok"
    template=${atlas_test}
else
    echo "Cannot locate additional segmentation template file: ${atlas_test}. Please ensure the ${atlas_test} is in this directory. Will continue with Yeo7 segmentation template."
fi

#parcellation template

template_test=${basedir}/${template}

if [ $(imtest $template_test) == 1 ] ;
then
    echo "Using ${template_test} for parcellation: file is ok"
    template=${template_test}
else
    echo "Cannot locate additional parcellation template file: ${template_test}. Please ensure the ${template_test} is in this directory. Will continue with AAL90 parcellation template."
fi


#make directory structure

if [ ! -d ${basedir}/diffusion ] ;
then
    echo "making output directory"
    mkdir -p ${basedir}/diffusion
else
    echo "output directory already exists"
    if [ "$overwrite" == 1 ] ;
    then
        echo "making new output directory"
        mkdir -p ${basedir}/diffusion
    else
        echo "no overwrite permission to make new output directory"
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

#same for remaining files
fslchfiletype NIFTI_GZ ${T1_test} ${outdir}/structural
structural=${outdir}/structural.nii.gz

cp $bvecs_test ${outdir}
bvecs=${outdir}/${bvecs}
cp $bvals_test ${outdir}
bvals=${outdir}/${bvals}

cd ${outdir}

#Start logfile: if already exists (and therefore script previously run) stops here

if [ ! -f ${outdir}/image_analysis_log.txt ] ;
then
    echo "making log file"
    touch image_analysis_log.txt
else
    echo "log file already exists - tract_van.sh has probably been run already"
    if [ "$overwrite" == 1 ] ;
    then
        touch image_analysis_log.txt
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
    echo "" >> $log


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


    #####################

    #2. Anatomy

    #####################


    echo "" >> $log
    echo $(date) >> $log
    echo "2. Starting advanced anatomy" >> $log


    #make_anatomy.sh


    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with advanced anatomy" >> $log
    echo "" >> $log


    ###############

    #3. Freesurfer

    ###############


    echo "" >> $log
    echo $(date) >> $log
    echo "3. Starting Freesurfer" >> $log


    #make_freesurfer.sh
    #sort path to QA tools [ ]


    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with Freesurfer" >> $log
    echo "" >> $log

    #################

    #4. Registration

    #################


    echo "" >> $log
    echo $(date) >> $log
    echo "4. Starting registration" >> $log


    #make_registration.sh
    #make_ants.sh


    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with registration" >> $log
    echo "" >> $log

    #####################

    #5. Advanced de-noising

    #####################


    echo "" >> $log
    echo $(date) >> $log
    echo "5. Starting advanced de-noising" >> $log


    #make_diffusiondenoise.sh


    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with advanced de-noising" >> $log
    echo "" >> $log


    #################

    #6. FDT Pipeline

    #################


    echo "" >> $log
    echo $(date) >> $log
    echo "6. FDT pipeline" >> $log


    #make_FDT.sh


    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with FDT pipeline" >> $log
    echo "" >> $log


    #############

    #7. BedPostX

    #############


    echo "" >> $log
    echo $(date) >> $log
    echo "7. Starting BedPostX" >> $log
    echo "" >> $log


    #make_bedpostx


    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with BedPostX" >> $log
    echo "" >> $log


    ##########

    #8. XTRACT

    ##########


    echo "" >> $log
    echo $(date) >> $log
    echo "8. Starting XTRACT" >> $log


    #make_xtract.sh


    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with XTRACT" >> $log
    echo "" >> $log


    ################

    #9. Segmentation

    ################

    echo "" >> $log
    echo $(date) >> $log
    echo "9. Starting Segmentation with ProbTrackX" >> $log


    #make_segmentation.sh


    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with segmentation" >> $log
    echo "" >> $log


    #################

    #10. Connectomics

    #################


    echo "" >> $log
    echo $(date) >> $log
    echo "10. Starting connectomics with probtrackx2" >> $log


    #make_connectome.sh


    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with connectome" >> $log
    echo "" >> $log

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

rm slurm*
rm diffusion.bedpostX/command_files/*
rm diffusion.bedpostX/logs/*
rm -r probtrackx/*/Seg*
rm -r probtrackx/*/commands
rm -r *seeds


echo "" >> $log
echo $(date) >> $log
echo "Clean up complete" >> $log
echo "" >> $log

#close up

echo "" >> $log
echo "All done with image_analysis.sh" >> ${log}
echo $(date) >> ${log}
echo "" >> ${log}
