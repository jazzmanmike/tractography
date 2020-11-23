#!/bin/bash
set -e

# tract_van.sh
#
#
# Michael Hart, University of British Columbia, August 2020 (c)

#define

codedir=${HOME}/code/github/tractography
basedir="$(pwd -P)"
FSLOUTPUTTYPE=NIFTI_GZ #occassionally not set as standard

#make usage function

usage()
{
cat<<EOF
usage: $0 options

=============================================================================================

tract_van.sh

(c) Michael Hart, University of British Columbia, August 2020

Script to run tractography on clinical DBS data (e.g. from UBC Functional Neurosurgery Programme)

Based on the following data: GE scanner, 3 Tesla, 32 Direction DTI protocol

Example:

tract_van.sh --data=DTI.nii.gz --T1=mprage.nii.gz --bvecs=bvecs.txt --bvals=bvals.txt

Options:

Mandatory
--data          diffusion data (e.g. standard = single B0 as first volume)
--T1            structural (T1) image
--bvecs         bvecs file
--bvals         bvals file

Optional
--acqparams     acquisition parameters (custom values, for Eddy/TopUp)
--index         diffusion PE directions (custom values, for Eddy/TopUp)
--parcellation  additional parcellation template (for connectomics: standard is HarvardOxford)
--segmentation  additional segmentation template (for segmentation: standard is HarvardOxford)
-d              runs topup & eddy (see code for default acqparams/index parameters or enter custom as above)
-p              parallel processing (slurm)*
-o              overwrite
-h              show this help
-v              verbose

Pipeline
1.  Baseline quality control
2.  FSL_anat*
3.  Freesurfer*
4.  De-noising with topup & eddy - optional (see code)
5.  FDT pipeline
6.  BedPostX
7.  Registration
8.  XTRACT (including custom tracts)
9.  Segmentation (probtrackX)
10. Connectomics (probtrackX)

Version:    1.0

History:    original

NB: requires Matlab, Freesurfer, FSL, ANTs, and set path to codedir
NNB: SGE / GPU acceleration - change eddy, bedpostx, probtrackx2, and XTRACT calls

=============================================================================================

EOF
exit 1
}


###################
# Standard checks #
###################


#unset mandatory files
data=unset
T1=unset
bvecs=unset
bvals=unset


# Call getopt to validate the provided input
options=$(getopt -n tract_van.sh -o dpohv --long data:,T1:,bvecs:,bvals:,acqparams:,index:,parcellation:,segmentation: -- "$@")
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
    --parcellation) template="$2"   ;   shift 2 ;;
    --segmentation) atlas="$2"      ;   shift 2 ;;
    --) shift; break ;;
    esac
done


#check options

#check usage

if [[ -z ${data} ]] || [[ -z ${T1} ]] || [[ -z ${bvecs} ]] || [[ -z ${bvals} ]]
then
    echo "usage incorrect: mandatory inputs not entered"
    usage
    exit 1
fi

echo "Diffusion data are: ${data}"
echo "Structural data are: ${T1}"
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
    set -x verbose
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


#check optional image files

#segmentation atlas

atlas_test=${basedir}/${atlas}

if [ $(imtest $template_atlas) == 1 ] ;
then
    echo "Using ${template_atlas} for parcellation: file is ok"
    template=${template_atlas}
else
    echo "Cannot locate additional parcellation template file ${template_atlas}. Please ensure the ${template_atlas} is in this directory. Will continue with DK template."
fi

#parcellation template

template_test=${basedir}/${template}

if [ $(imtest $template_test) == 1 ] ;
then
    echo "Using ${template_test} for parcellation: file is ok"
    template=${template_test}
else
    echo "Cannot locate additional parcellation template file ${template_test}. Please ensure the ${template_test} is in this directory. Will continue with DK template."
fi


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


#make temporary directory: work in this

tempdir="$(mktemp -t -d temp.XXXXXXXX)"

cd "${tempdir}"

echo "tempdir is ${tempdir}"

echo "basedir is ${basedir}"

outdir=${basedir}/diffusion

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


#Start logfile: if already exists (and therefore script previously run) stops here

if [ ! -d ${outdir}/van_tractography.txt ] ;
then
    echo "making log file"
    touch van_tractography.txt
else
    echo "log file already exists - tract_van.sh has probably already been run"
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
echo "Starting tract_van.sh"
echo "" >> ${log}
echo "Options are: ${options}" >> ${log}
echo "" >> ${log}
echo "basedir is ${basedir}" >> ${log}
echo "outdir is ${outdir}" >> ${log}
echo "tempdir is ${tempdir}" >> ${log}
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
    echo "2. Starting advanced anatomy" >> $log

    if [ "${parallel}" == 1 ] ;
    then
      echo "submitting fsl_anat to slurm"
      
      #make batch file
      touch batch_anat.sh
      echo '#!/bin/bash' >> batch_anat.sh
      printf "structural=%s\n" "${structural}" >> batch_anat.sh
      printf "basedir=%s\n" "${basedir}" >> batch_anat.sh
      printf "outdir=%s\n" "${outdir}" >> batch_anat.sh
      echo 'fsl_anat -i ${structural} -o structural --clobber --nosubcortseg' >> batch_anat.sh
      echo 'slicer structural.anat/T1_biascorr_brain.nii.gz -a ${outdir}/QC/fsl_anat_bet.ppm' >> test_batch_anat.sh

      
      chmod 777 ${tempdir}/batch_anat.sh
      
      sbatch --time 12:00:00 --nodes=1 --mem=30000 --tasks-per-node=12  --cpus-per-task=1 batch_anat.sh
   
    else
      echo "running fsl_anat sequentially"
      fsl_anat -i ${structural} -o structural
    fi

    #now run first (e.g. for thalamus & pallidum to be used later)
   
    echo "running fsl first"
    
    mkdir ${tempdir}/first_segmentation
    
    cd first_segmentation
    
    run_first_all -i ${structural} -o first -d

    cd ../
    
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

    export QA_TOOLS=${HOME}/code/QAtools_v1.2
    export SUBJECTS_DIR=`pwd`

    echo "QA Tools set up as ${QA_TOOLS}"
    echo "QA Tools set up as ${QA_TOOLS}" >> ${log}
    echo "SUBJECTS_DIR set up as ${SUBJECTS_DIR}"
    echo "SUBJECTS_DIR set up as ${SUBJECTS_DIR}" >> ${log}
    
    if [ "${parallel}" == 1 ] ;
    then
        echo "submitting Freesurfer to slurm"
        
        #create batch file
        touch batch_FS.sh
        echo '#!/bin/bash' >> batch_FS.sh
        printf "structural=%s\n" "${structural}" >> batch_FS.sh

        #run Freesurfer
        echo 'recon-all -i ${structural} -s FS -all' >> batch_FS.sh

        #run QA tools
        #NB: images don't always run with Linux/SLURM
        echo '${QA_TOOLS}/recon_checker -s FS' >> batch_FS.sh

        #additional parcellation for connectomics
        echo 'parcellation2individuals.sh' >> batch_FS.sh
        
        #run as batch
        chmod 777 ${tempdir}/batch_FS.sh
        
        sbatch --time 18:00:00 --nodes=1 --mem=30000 --tasks-per-node=12 --cpus-per-task=1 batch_FS.sh

    else
        echo "running Freesurfer sequentially"
        recon-all -i ${structural} -s FS -all

        #run QA tools
        ${QA_TOOLS}/recon_checker -s FS

        #additional parcellation for connectomics
        parcellation2individuals.sh

    fi
   

    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with Freesurfer" >> $log
    echo "" >> $log


    #####################

    #4. Advanced de-noising

    #####################


    echo "" >> $log
    echo $(date) >> $log
    echo "4. Starting advanced de-noising" >> $log

    if [ "${denoise}" == 1 ] ;
    then
    
        echo "doing advanced de-noising with TopUp then Eddy"

        #TopUp
        echo "" >> $log
        echo "Doing TopUp" >> $log
        echo $(date) >> $log
        echo "" >> $log
        
        #check these are the different phase encode direction B0 volumes
        fslroi data A2P_b0 0 1
        fslroi data P2A_b0 1 1
        fslmerge -t A2P_P2A_b0 A2P_b0 P2A_b0
        
        #option to set custom acqusition parameters if required, otherwise will use default
        if [ -f ${acqp} ] ; then
            cp ${acqp} acqparams.txt
        else
            printf "0 -1 0 0.0646\n0 1 0 0.0646" > acqparams.txt
        fi
        
        topup --imain=A2P_P2A_b0 --datain=acqparams.txt --config=b02b0.cnf --out=my_topup_results --iout=my_hifi_b0
        
        echo "" >> $log
        echo "Finishing TopUp" >> $log
        echo $(date) >> $log
        echo "" >> $log
        
        #Eddy
        echo "" >> $log
        echo "Doing Eddy" >> $log
        echo $(date) >> $log
        echo "" >> $log
        
        #create files
        fslmaths my_hifi_b0 -Tmean my_hifi_b0 #output from TopUp
        bet my_hifi_b0 my_hifi_b0_brain -m
       
        #option to set custom index (acquisition) file if required, otherwise will use default
        if [ -f ${index} ] ; then
           cp ${index} index.txt
        else
            indx=""
            for ((i=1; i<=64; i+=1));
            do
                indx="$indx 1";
            done
            echo ${indx} > index.txt
        fi
        
        #main eddy command
        eddy --imain=data \
        --mask=my_hifi_b0_brain_mask \
        --acqp=acqparams.txt \
        --index=index.txt \
        --bvecs=${bvecs} \
        --bvals=${bvals} \
        --topup=my_topup_results \
        --out=eddy_corrected_data
       
        echo "" >> $log
        echo "Finishing Eddy" >> $log
        echo $(date) >> $log
        echo "" >> $log
        
        #eddy quality control
        #eddy_quad <eddy_output_basename> -idx <eddy_index_file> -par <eddy_acqparams_file> -m <nodif_mask> -b <bvals>
        
    else
        echo "advanced de-noising turned off"
    fi
    

    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with advanced de-noising" >> $log
    echo "" >> $log


    #################

    #5. FDT Pipeline

    #################


    echo "" >> $log
    echo $(date) >> $log
    echo "5. FDT pipeline" >> $log


    #extract B0 volume

    fslroi ${data} nodif 0 1

    #gzip nodif

    #create binary brain mask

    bet nodif nodif_brain -m -f 0.2

    slicer nodif_brain -a ${outdir}/QC/DTI_brain_images.ppm


    #fit diffusion tensor

    dtifit --data=${data} --mask=nodif_brain_mask --bvecs=${bvecs} --bvals=${bvals} --out=dti


    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with FDT pipeline" >> $log
    echo "" >> $log


    #############

    #6. BedPostX

    #############


    echo "" >> $log
    echo $(date) >> $log
    echo "6. Starting BedPostX" >> $log

    mkdir -p ${tempdir}/diffusion
    
    cp ${data} ${tempdir}/diffusion/data.nii.gz
    cp ${bvecs} ${tempdir}/diffusion/bvecs
    cp ${bvals} ${tempdir}/diffusion/bvals
    cp nodif_brain_mask.nii.gz ${tempdir}/diffusion/nodif_brain_mask.nii.gz
    
    bedpostx_datacheck ${tempdir}/diffusion >> $log

    bedpostx ${tempdir}/diffusion

    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with BedPostX" >> $log
    echo "" >> $log


    #################

    #7. Registration

    #################


    echo "" >> $log
    echo $(date) >> $log
    echo "7. Starting registration" >> $log
    
    
    #Final outputs need to be diff2standard.nii.gz & standard2diff.nii.gz for probtrackx2/xtract

    echo "starting diff2str"

    #diffusion to structural
    flirt -in nodif_brain.nii.gz -ref structural.anat/T1_biascorr_brain.nii.gz -omat diffusion.bedpostX/xfms/diff2str.mat -dof 6

    echo "starting epi_reg"

    #epi_reg
    epi_reg --epi=nodif_brain.nii.gz --t1=structural.anat/T1_biascorr.nii.gz --t1brain=structural.anat/T1_biascorr_brain.nii.gz --out=diffusion.bedpostX/xfms/epi2str

    echo "starting str2diff"

    #structural to diffusion inverse
    convert_xfm -omat diffusion.bedpostX/xfms/str2diff.mat -inverse diffusion.bedpostX/xfms/diff2str.mat

    echo "starting flirt affine"

    #structural to standard affine
    flirt -in structural.anat/T1_biascorr_brain.nii.gz -ref ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz -omat diffusion.bedpostX/xfms/str2standard.mat -dof 12

    echo "starting inverse affine"

    #standard to structural affine inverse
    convert_xfm -omat diffusion.bedpostX/xfms/standard2str.mat -inverse diffusion.bedpostX/xfms/str2standard.mat

    echo "starting diff2standard.mat"

    #diffusion to standard (6 & 12 DOF)
    convert_xfm -omat diffusion.bedpostX/xfms/diff2standard.mat -concat diffusion.bedpostX/xfms/str2standard.mat diffusion.bedpostX/xfms/diff2str.mat

    echo "starting standard2diff.mat"

    #standard to diffusion (12 & 6 DOF)
    convert_xfm -omat diffusion.bedpostX/xfms/standard2diff.mat -inverse diffusion.bedpostX/xfms/diff2standard.mat

    echo "starting fnirt"

    #structural to standard: non-linear
    fnirt --in=structural.anat/T1_biascorr.nii.gz --aff=diffusion.bedpostX/xfms/str2standard.mat --cout=diffusion.bedpostX/xfms/str2standard_warp --config=T1_2_MNI152_2mm

    echo "starting inv_warp"

    #standard to structural: non-linear
    invwarp -w diffusion.bedpostX/xfms/str2standard_warp -o diffusion.bedpostX/xfms/standard2str_warp -r structural.anat/T1_biascorr_brain.nii.gz

    echo "starting diff2standard"

    #diffusion to standard: non-linear
    convertwarp -o diffusion.bedpostX/xfms/diff2standard -r ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz --premat=diffusion.bedpostX/xfms/diff2str.mat --warp1=diffusion.bedpostX/xfms/str2standard_warp

    echo "starting standard2diff"

    #standard to diffusion: non-linear
    convertwarp -o diffusion.bedpostX/xfms/standard2diff -r nodif_brain.nii.gz --warp1=diffusion.bedpostX/xfms/standard2str_warp --postmat=diffusion.bedpostX/xfms/str2diff.mat

    #check images
    
    mkdir diffusion.bedpostX/xfms/reg_check
    
    #diffusion to structural
    
    echo "starting diff2str check"

    #flirt
    flirt -in nodif_brain.nii.gz -ref structural.anat/T1_biascorr_brain.nii.gz -init diffusion.bedpostX/xfms/diff2str.mat -out diffusion.bedpostX/xfms/reg_check/diff2str_check.nii.gz
    
    slicer structural.anat/T1_biascorr_brain.nii.gz diffusion.bedpostX/xfms/reg_check/diff2str_check.nii.gz -a diffusion.bedpostX/xfms/reg_check/diff2str_check.ppm

    echo "starting epi_reg check"

    #epi_reg
    flirt -in nodif_brain.nii.gz -ref structural.anat/T1_biascorr_brain.nii.gz -init diffusion.bedpostX/xfms/epi2str.mat -out diffusion.bedpostX/xfms/reg_check/epi2str_check.nii.gz
    
    slicer structural.anat/T1_biascorr_brain.nii.gz diffusion.bedpostX/xfms/reg_check/epi2str.nii.gz -a diffusion.bedpostX/xfms/reg_check/epi2str_check.ppm

    echo "starting str2standard check"

    #structural to standard
    applywarp --in=structural.anat/T1_biascorr_brain.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz --warp=diffusion.bedpostX/xfms/str2standard_warp --out=str2standard_check.nii.gz
    
    slicer ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz diffusion.bedpostX/xfms/reg_check/str2standard_check.nii.gz -a diffusion.bedpostX/xfms/reg_check/str2standard_check.ppm
    
    echo "starting diff2standard check"

    #diffusion to standard: warp & premat
    applywarp --in=nodif_brain.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz --warp=diffusion.bedpostX/xfms/str2standard_warp --premat=diffusion.bedpostX/xfms/diff2str.mat --out=diff2standard_check.nii.gz
    
    slicer ${FSLDIR}/data/standard/MNI152_T1_2mm_brain diffusion.bedpostX/xfms/reg_check/diff2standard_check.nii.gz -a diffusion.bedpostX/xfms/reg_check/diff2standard_check.ppm
    
    echo "starting convert warp check"

    #diffusion to standard with convertwarp: diff2standard as used in XTRACT
    applywarp --in=nodif_brain.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain --warp=diffusion.bedpostX/xfms/diff2standard --out=diffusion.bedpostX/xfms/reg_check/diff2standard_check_applywarp.nii.gz

    slicer ${FSLDIR}/data/standard/MNI152_T1_2mm_brain diffusion.bedpostX/xfms/reg_check/diff2standard_check_applywarp.nii.gz -a diffusion.bedpostX/xfms/reg_check/diff2standard_check_appywarp.ppm


    echo "starting ants"


    #ANTS pipeline

    ants_brains.sh -s ${structural}

    ants_diff2struct.sh -d nodif_brain.nii.gz -s ants_brains/BrainExtractionBrain.nii.gz

    ants_struct2stand.sh -s ants_brains/BrainExtractionBrain.nii.gz

    ants_regcheck.sh -d nodif_brain.nii.gz -w ants_struct2stand/structural2standard.nii.gz -i ants_struct2stand/standard2structural.nii.gz -r ants_diff2struct/rigid0GenericAffine.mat

    
    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with registration" >> $log
    echo "" >> $log


    ##########

    #8. XTRACT

    ##########


    echo "" >> $log
    echo $(date) >> $log
    echo "8. Starting XTRACT" >> $log


    #temporarily dissable for testing
    #XTRACT
    #xtract -bpx diffusion.bedpostX -out myxtract -species HUMAN

    #xtract_stats
    #xtract_stats -d ${tempdir}/dti_ -xtract myxtract -w diffusion.bedpostX/xfms/standard2diff -keepfiles
    
    #xtract_viewer
    #xtract_viewer -dir myxtract -species HUMAN
    
    
    #DBS XTRACT
    xtract -bpx diffusion.bedpostX/ -out dbsxtract -str ${codedir}/dbsxtract/structureList -p ${codedir}/dbsxtract/
    
    #xtract_stats
    #xtract_stats -d ${tempdir}/dti_ -xtract dbsxtract -w diffusion.bedpostX/xfms/standard2diff -keepfiles
    
    #xtract_viewer
    #xtract_viewer -dir dbsxtract -species HUMAN


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
    
    
    mkdir -p ${tempdir}/hardsegmentation
    
    #Define atlas
    if [ $(imtest ${atlas}) == 1 ];
    then
        echo "${atlas} dataset ok"
    else
        atlas="${codedir}/templates/HarvardOxford.nii.gz"
        echo "No atlas for segmentation has been supplied - using HarvardOxford"
    fi
    
    echo "Atlas for hard segmentation is: ${atlas}" >> $log
    
    #Split atlas into individual ROI files
    deparcellator.sh ${atlas}
    outname=`basename ${atlas} .nii.gz` #for parsing output to probtrackx below
    mv ${outname}_seeds segmentation_${outname}_seeds

    #Thalamus

    echo "Running segmentation of thalamus"
    echo "Starting thalamic segmentation" >> $log

    #Right thalamus
    
    #Move individual nucleus (seed) to be segmentated to standard space (i.e. same as target parcellation / atlas)
    applywarp --in=${tempdir}/first_segmentation/first-R_Thal_first.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain --warp=${tempdir}/diffusion.bedpostX/xfms/str2standard_warp --out=${tempdir}/hardsegmentation/thalamus_right_MNI.nii.gz

    fslmaths ${tempdir}/hardsegmentation/thalamus_right_MNI.nii.gz -bin ${tempdir}/hardsegmentation/thalamus_right_MNI.nii.gz


    #Seed to target
    probtrackx2 --samples=${tempdir}/diffusion.bedpostX/merged \
    --mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
    --xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
    --invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
    --seedref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
    --seed=${tempdir}/hardsegmentation/thalamus_right_MNI.nii.gz \
    --targetmasks=segmentation_${outname}_seeds/seeds_targets_list.txt \
    --dir=thalamus2cortex_right \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --os2t \
    --nsamples=500
           
    #hard segmentation
    find_the_biggest thalamus2cortex_right/seeds_to_* thalamus2cortex_right/biggest_segmentation

    #Alternative segmentation method (hypothesis free): requires subsequent Matlab run for kmeans segmentation

    #Make GM cortical mask in MNI space
    applywarp --in=${tempdir}/structural.anat/T1_fast_pve_1.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain --warp=${tempdir}/diffusion.bedpostX/xfms/str2standard_warp --out=${tempdir}/hardsegmentation/GM_mask_MNI

    fslmaths ${tempdir}/hardsegmentation/GM_mask_MNI -thr 0.95 ${tempdir}/hardsegmentation/GM_mask_MNI

    fslmaths ${tempdir}/hardsegmentation/GM_mask_MNI -bin ${tempdir}/hardsegmentation/GM_mask_MNI

    #omatrix2
    probtrackx2 --omatrix2 \
    --samples=${tempdir}/diffusion.bedpostX/merged \
    --mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
    --xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
    --invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
    --seed=${tempdir}/hardsegmentation/thalamus_right_MNI.nii.gz \
    --target2=${tempdir}/hardsegmentation/GM_mask_MNI.nii.gz \
    --dir=thalamus2cortex_right_omatrix2 \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --nsamples=500


    #Left thalamus
    
    #Move individual nucleus (seed) to be segmentated to standard space (i.e. same as target parcellation / atlas)
    applywarp --in=${tempdir}/first_segmentation/first-L_Thal_first.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain --warp=${tempdir}/diffusion.bedpostX/xfms/str2standard_warp --out=${tempdir}/hardsegmentation/thalamus_left_MNI.nii.gz

    fslmaths ${tempdir}/hardsegmentation/thalamus_left_MNI.nii.gz -bin ${tempdir}/hardsegmentation/thalamus_left_MNI.nii.gz

    #Seed to target
    probtrackx2 --samples=${tempdir}/diffusion.bedpostX/merged \
    --mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
    --xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
    --invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
    --seedref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
    --seed=${tempdir}/hardsegmentation/thalamus_left_MNI.nii.gz \
    --targetmasks=segmentation_${outname}_seeds/seeds_targets_list.txt \
    --dir=thalamus2cortex_left \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --os2t \
    --nsamples=500
           
    #hard segmentation
    find_the_biggest thalamus2cortex_left/seeds_to_* thalamus2cortex_left/biggest_segmentation

    #omatrix2
    probtrackx2 --omatrix2 \
    --samples=${tempdir}/diffusion.bedpostX/merged \
    --mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
    --xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
    --invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
    --seed=${tempdir}/hardsegmentation/thalamus_left_MNI.nii.gz \
    --target2=${tempdir}/hardsegmentation/GM_mask_MNI.nii.gz \
    --dir=thalamus2cortex_left_omatrix2 \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --nsamples=500


    #Pallidum

    echo "Running segmentation of pallidum"
    echo "Starting pallidum segmentation" >> $log

    #Right pallidum
    
    #Move individual nucleus (seed) to be segmentated to standard space (i.e. same as target parcellation / atlas)
    applywarp --in=${tempdir}/first_segmentation/first-R_Pall_first.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain --warp=${tempdir}/diffusion.bedpostX/xfms/str2standard_warp --out=${tempdir}/hardsegmentation/pallidum_right_MNI.nii.gz

    fslmaths ${tempdir}/hardsegmentation/pallidum_right_MNI.nii.gz -bin ${tempdir}/hardsegmentation/pallidum_right_MNI.nii.gz


    #Seed to target
    probtrackx2 --samples=${tempdir}/diffusion.bedpostX/merged \
    --mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
    --xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
    --invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
    --seedref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
    --seed=${tempdir}/hardsegmentation/pallidum_right_MNI.nii.gz \
    --targetmasks=segmentation_${outname}_seeds/seeds_targets_list.txt \
    --dir=pallidum2cortex_right \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --os2t \
    --nsamples=500
           
    #hard segmentation
    find_the_biggest pallidum2cortex_right/seeds_to_* pallidum2cortex_right/biggest_segmentation

    #Alternative segmentation method (hypothesis free): requires subsequent Matlab run for kmeans segmentation

    #omatrix2
    probtrackx2 --omatrix2 \
    --samples=${tempdir}/diffusion.bedpostX/merged \
    --mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
    --xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
    --invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
    --seed=${tempdir}/hardsegmentation/pallidum_right_MNI.nii.gz \
    --target2=${tempdir}/hardsegmentation/GM_mask_MNI.nii.gz \
    --dir=thalamus2cortex_right_omatrix2 \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --nsamples=500


    #Left pallidum
    
    #Move individual nucleus (seed) to be segmentated to standard space (i.e. same as target parcellation / atlas)
    applywarp --in=${tempdir}/first_segmentation/first-L_Pall_first.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain --warp=${tempdir}/diffusion.bedpostX/xfms/str2standard_warp --out=${tempdir}/hardsegmentation/pallidum_left_MNI.nii.gz

    fslmaths ${tempdir}/hardsegmentation/pallidum_left_MNI.nii.gz -bin ${tempdir}/hardsegmentation/pallidum_left_MNI.nii.gz

    #Seed to target
    probtrackx2 --samples=${tempdir}/diffusion.bedpostX/merged \
    --mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
    --xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
    --invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
    --seedref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
    --seed=${tempdir}/hardsegmentation/pallidum_left_MNI.nii.gz \
    --targetmasks=segmentation_${outname}_seeds/seeds_targets_list.txt \
    --dir=pallidum2cortex_left \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --os2t \
    --nsamples=500
           
    #hard segmentation
    find_the_biggest pallidum2cortex_left/seeds_to_* pallidum2cortex_left/biggest_segmentation

    #omatrix2
    probtrackx2 --omatrix2 \
    --samples=${tempdir}/diffusion.bedpostX/merged \
    --mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
    --xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
    --invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
    --seed=${tempdir}/hardsegmentation/pallidum_left_MNI.nii.gz \
    --target2=${tempdir}/hardsegmentation/GM_mask_MNI.nii.gz \
    --dir=pallidum2cortex_left_omatrix2 \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --nsamples=500
    
    
    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with segmentation" >> $log
    echo "" >> $log


    #################

    #10. Connectomics

    #################


    echo "" >> $log
    echo $(date) >> $log
    echo "10. Starting connectomics ProbTrackX" >> $log
    
    
    if [ $(imtest ${template}) == 1 ];
    then
        echo "${template} dataset for connectomics ok"
    else
        template="${codedir}/templates/HarvardOxford.nii.gz"
        echo "No parcellation template for connectomics has been supplied - using HarvardOxford"
    fi

    deparcellator.sh ${template}
    outname=`basename ${template} .nii.gz` #for parsing output to probtrackx below
    mv ${outname}_seeds connectome_${outname}_seeds

    echo "Starting connectome --network option"

    probtrackx2 \
    --network \
    --samples=${tempdir}/diffusion.bedpostX/merged \
    --mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
    --xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
    --invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
    --dir=connectome_${outname} \
    --seed=connectome_${outname}_seeds/seeds_targets_list.txt \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --nsamples=500
    
    
    echo "" >> $log
    echo $(date) >> $log
    echo "Finished with connectomics" >> $log
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
