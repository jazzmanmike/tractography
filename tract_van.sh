#!/bin/bash
set -e

# tract_van.sh
#
#
# Michael Hart, University of British Columbia, August 2020 (c)

#define

codedir=${HOME}/code
basedir="$(pwd -P)"

#make usage function

usage()
{
cat<<EOF
usage: $0 options

=============================================================================================

tract_van.sh

(c) Michael Hart, University of British Columbia, August 2020

Script for running tractography on data from UBC Functional Neurosurgery Programme

Based on data acquired from: Priority MRI, Richmond BC (GE, 3 Tesla, 32 Direction DTI protocol)

Example:

tract_van.sh --data=DTI.nii.gz --T1=mprage.nii.gz --bvecs=bvecs.txt --bvals=bvals.txt

Options:

Mandatory
--data      diffusion data
--T1        structural (T1) image
--bvecs     bvecs file
--bvals     bvals file

Optional
-p          parallel processing (slurm)
-d          runs topup & eddy (see code for data requirements)
-o          overwrite
-h          show this help
-v          verbose

Pipeline
1. Baseline quality control
2. FSL_anat (+/- parallel)
3. Freesurfer (+/- parallel)
(de-noising with topup & eddy - optional)
4. FDT pipeline
5. BedPostX (+/- parallel)
6. Registration
7. XTRACT (including custom tracts)
8. ProbTrackX (including connectome parcellation & thalamic segmentation)

Version:    1.0

History:    original version

=============================================================================================

EOF
}


###################
# Standard checks #
###################


#mandatory files
data=
T1=
bvecs=
bvals=

#initialise options

echo "output is $basedir"

# Call getopt to validate the provided input.
options=$(getopt -o pdohv --long data:,T1:,bvecs:,bvals: -- "$@")

[ $? -eq 0 ] || {
    echo "Incorrect options provided -> exiting now" >&2
    usage
    exit 1
}

eval set -- "$options"
while true; do
    case "$1" in
   -p)
       parallel=1
       ;;
   -d)
       denoise=1
       ;;
   -o)
       overwrite=1
       ;;
   -h)
       usage
       exit 1
       ;;
   -v)
       shift;
       verbose=$1
       ;;
    --data )
        shift; # The arg is next in position args
        data=$1
        ;;
    --T1 )
        shift;
        T1=$1
        ;;
    --bvecs )
        shift;
        bvecs=$1
        ;;
    --bvals )
        shift;
        bvals=$1
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done


#set verbose option

if [ "$verbose" == 1 ] ;
then
    set -x verbose
fi


echo "Diffusion data is: ${data}"
echo "Structural data is: ${T1}"
echo "bvecs are: ${bvecs}"
echo "bvals are: ${bvals}"

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
else
    echo "verbose set off"
fi

echo "options ok"


#check files

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

#make output directory

if [ ! -d ${basedir}/diffusion ] ;
then
    echo "making output directory"
    mkdir ${basedir}/diffusion
    mkdir ${basedir}/diffusion/QC
else
    echo "output directory already exists"
    if [ "$overwrite" == 1 ] ;
    then
        echo "making new output directory"
        mkdir -p ${basedir}/diffusion
        mkdir -p ${basedir}/diffusion/QC
    else
        echo "no overwrite permission to make new output directory"
    exit 1
    fi
fi

outdir=${basedir}/diffusion

echo "The output directory is: ${outdir}"

#make temporary directory: work in this

tempdir="$(mktemp -t -d temp.XXXXXXXX)"

cd "${tempdir}"


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


#Start logfile: if already exists (and therefore script previously run) stops here

if [ ! -d ${outdir}/van_tractography.txt ] ;
then
    echo "making log file"
    touch van_tractography.txt
else
    echo "log file already exists - van_tractography.sh has probably already been run"
    if [ "$overwrite" == 1 ] ;
    then
        touch van_tractography.txt
    else
        echo "no overwrite permission"
    exit 1
    fi
fi

log=van_tractography.txt
echo $(date) >> ${log}
echo "${0}" >> ${log}
echo "${@}" >> ${log}
echo "Starting van_tractography.sh"
echo "" >> ${log}
echo "Options are: ${options}"
echo "${options}" >> ${log}
echo "" >> ${log}


##################
# Main programme #
##################


function tractVAN() {


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

    #2. Advanced anatomy

    #####################


    echo "" >> $log
    echo $(date) >> $log
    echo "2. Starting fsl_anat" >> $log

    if [ "${parallel}" == 1 ] ;
    then
      echo "submitting fsl_anat to slurm"
      #sbatch --time 23:00:00 fsl_anat -i ${structural} -o structural.anat
    else
      echo "running fsl_anat sequentially"
      #fsl_anat -i ${structural}
    fi

    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with fsl_anat" >> $log
    echo "" >> $log


    ###############

    #3. Freesurfer

    ###############


    echo "" >> $log
    echo $(date) >> $log
    echo "3. Starting Freesurfer" >> $log

    export QA_TOOLS=${HOME}/code/QAtools_v1.2
    export SUBJECTS_DIR=`pwd`

    echo "QA Tools set up as ${QA_TOOLS}"
    echo "QA Tools set up as ${QA_TOOLS}" >> ${log}
    echo "SUBJECTS_DIR set up as ${SUBJECTS_DIR}"
    echo "SUBJECTS_DIR set up as ${SUBJECTS_DIR}" >> ${log}
    
    if [ "${parallel}" == 1 ] ;
    then
        echo "submitting Freesurfer to slurm"
        #sbatch --time 23:00:00 recon-all -i ${structural} -s FS -all
    else
        echo "running Freesurfer sequentially"
        #recon-all -i $structural} -s FS -all
    fi

    #run QA tools
    #${QA_TOOLS}recon-checker -s FS

    #additional parcellation for connectomics
    #parcellation2individuals.sh


    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with Freesurfer" >> $log
    echo "" >> $log


    #################

    #4. FDT Pipeline

    #################


    echo "" >> $log
    echo $(date) >> $log
    echo "4. FDT pipeline" >> $log


    #extract B0 volume

    fslroi ${data} nodif 0 1

    #gzip nodif

    #create binary brain mask

    bet nodif nodif_brain -m -f 0.2

    slices nodif_brain -o ${outdir}/QC/DTI_brain_images.gif


    #fit diffusion tensor

    dtifit --data=${data} --mask=nodif_brain_mask --bvecs=${bvecs} --bvals=${bvals} --out=dti


    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with FDT pipeline" >> $log
    echo "" >> $log


    #############

    #5. BedPostX

    #############


    echo "" >> $log
    echo $(date) >> $log
    echo "5. Starting BedPostX" >> $log


    #bedpostx_datacheck ./diffusion >> $log

    #bedpostx ./diffusion

    #remove me!
    mkdir Xdiffusion.bedpostX/
    mkdir diffusion.bedpostX/xfms

    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with BedPostX" >> $log
    echo "" >> $log


    #################

    #6. Registration

    #################


    echo "" >> $log
    echo $(date) >> $log
    echo "6. Starting registration" >> $log


    #brain extract
    bet ${structural} ${outdir}/mprage_brain #put in outdir so fnirt can find structural in same place

    #diffusion to structural
    flirt -in nodif_brain -ref ${structural} -omat diffusion.bedpostX/xfms/diff2str.mat -dof 6

    #epi_reg
    epi_reg --epi=nodif_brain --t1=structural.anat/T1_biascorr.bii.gz --t1brain=/structural.anat/T1_biascorr_brain.nii.gz --out=epi2struct

    #structural to diffusion inverse
    convert_xfm -omat diffusion.bedpostX/xfms/str2diff.mat -inverse diffusion.bedpostX/xfms/diff2str.mat

    #structural to standard affine
    flirt -in mprage_brain -ref ${FSLDIR}/data/standard/MNI152_T1_2mm_brain -omat diffusion.bedpostX/xfms/str2standard.mat -dof 12

    #standard to structural affine inverse
    convert_xfm -omat vim_dti/diffusion.bedpostX/xfms/standard2str.mat -inverse vim_dti/diffusion.bedpostX/xfms/str2standard.mat

    #diffusion to standard (6 & 12 DOF)
    convert_xfm -omat vim_dti/diffusion.bedpostX/xfms/diff2standard.mat -concat vim_dti/diffusion.bedpostX/xfms/str2standard.mat vim_dti/diffusion.bedpostX/xfms/diff2str.mat

    #standard to diffusion (12 & 6 DOF)
    convert_xfm -omat vim_dti/diffusion.bedpostX/xfms/standard2diff.mat -inverse vim_dti/diffusion.bedpostX/xfms/diff2standard.mat

    #structural to standard: non-linear
    fnirt --in=${structural} --aff=/vim_dti/diffusion.bedpostX/xfms/str2standard.mat --cout=/vim_dti/diffusion.bedpostX/xfms/str2standard_warp --config=T1_2_MNI152_2mm

    #standard to structural: non-linear
    invwarp -w vim_dti/diffusion.bedpostX/xfms/str2standard_warp -o vim_dti/diffusion.bedpostX/xfms/standard2str_warp -r mprage_brain

    #diffusion to standard: non-linear
    convertwarp -o vim_dti/diffusion.bedpostX/xfms/diff2standard_warp -r ${FSLDIR}/data/standard/MNI152_T1_2mm -m vim_dti/diffusion.bedpostX/xfms/diff2str.mat -w vim_dti/diffusion.bedpostX/xfms/str2standard_warp

    #standard to diffusion: non-linear
    convertwarp -o vim_dti/diffusion.bedpostX/xfms/standard2diff_warp -r vim_dti/diffusion.bedpostX/nodif_brain_mask -w vim_dti/diffusion.bedpostX/xfms/standard2str_warp --postmat=/vim_dti/diffusion.bedpostX/xfms/str2diff.mat


    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with registration" >> $log
    echo "" >> $log


    ##########

    #7. XTRACT

    ##########


    echo "" >> $log
    echo $(date) >> $log
    echo "7. Starting XTRACT" >> $log


    #xtract -bpx diffusion.bedpostX/ -out myxtract -species HUMAN

    #xtract_stats

    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with XTRACT" >> $log
    echo "" >> $log


    ###############

    #8. ProbTrackX

    ###############

    echo "" >> $log
    echo $(date) >> $log
    echo "8. Starting ProbTrackX" >> $log




    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with ProbTrackX" >> $log
    echo "" >> $log
    
}


######################################################################

# Close up

######################################################################

#call function

tractVAN

echo "tract_van.sh completed"

#cleanup

cp -fpR . "${outdir}"
cd ${outdir}
rm -Rf ${tempdir}

#close up

echo "" >> $log
echo "all done with tract_van.sh" >> ${log}
echo $(date) >> ${log}
echo "" >> ${log}
