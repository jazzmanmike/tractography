#!/bin/bash
set -e

#Michael Hart, University of Cambridge, 19 April 2016 (c)

#define directories

codedir=${HOME}/code/github/tractography
basedir="$(pwd -P)"

#make usage function

usage()
{
cat<<EOF
usage: $0 options

===========================================================================

ants_struct2stand.sh

(c) Michael Hart, University of Cambridge, 2016

Structural to standard space (e.g. MNI) registration

Example:

ants_struct2stand.sh -s mprage_brain.nii.gz

Options:

-h  show this help
-s  anatomical (mandatory: brain extracted, moving image)
-t  template (brain extracted, fixed image - optional: default=MNI)
-o  overwrite
-v  verbose

Version:    1.3

History:    amended for github tractography repository

============================================================================

EOF
}


###################
# Standard checks #
###################


#initialise options

structural=
template=
while getopts "hs:t:ov" OPTION
do
    case $OPTION in
    h)
        usage
        exit 1
        ;;
    s)
        structural=$OPTARG
        ;;
    t)
        template=$OPTARG
        ;;
    o)
        overwrite=1
        ;;
    v)
        verbose=1
        ;;
    ?)
        usage
        exit
        ;;
    esac
done


#set verbose option

if [ "$verbose" == 1 ]
then
    set -x verbose
fi

#check usage

if [[ -z $structural ]] 
then
    echo "usage incorrect"
    usage
    exit 1
fi

echo "options ok"

# final check of files

echo "Checking structural data"

structural=${basedir}/${structural}
structural_name=`basename ${structural} .nii.gz`

if [ $(imtest $structural) == 1 ];
then
    echo "${structural} dataset ok"
else
    echo "Cannot locate file ${structural}. Please ensure the ${structural} dataset is in this directory"
    exit 1
fi

echo 'template:'$template

if [ $(imtest $template) == 1 ];
then
    echo "$template dataset ok"
else

    template="${codedir}/ANTS_templates/MNI152_T1_2mm_brain.nii.gz"
    echo "No template supplied - using MNI152_T1_2mm_brain"

fi

template_name=`basename ${template}.nii.gz`

echo "files ok"
#make output director

if [ ! -d ${basedir}/ants_struct2stand ];
then
    echo "making output directory"
    mkdir ${basedir}/ants_struct2stand
else
    echo "output directory already exists"
    if [ "$overwrite" == 1 ]
    then
        mkdir -p ${basedir}/ants_struct2stand
    else
        echo "no overwrite permission to make new output directory"
    exit 1
    fi
fi

outdir="${basedir}/ants_struct2stand"

#make temporary directory

tempdir="$(mktemp -t -d temp.XXXXXXXX)"
cd "${tempdir}"

#start logfile

touch ants_struct2stand_logfile.txt
log=ants_struct2stand_logfile.txt

echo $(date) >> ${log}
echo "${@}" >> ${log}


##################
# Main programme #
##################


function antsS2S() {


    #1. Create registration
    #note structural is fixed (with mask) and moving is MNI

    antsRegistrationSyN.sh \
    -d 3 \
    -m ${structural} \
    -f ${template} \
    -o S2S

    #2. Apply transforms to mprage (to put in MNI): check order of transforms*

    antsApplyTransforms \
    -d 3 \
    -i ${structural} \
    -o ${structural_name}_MNI.nii.gz \
    -r ${template} \
    -t S2S0GenericAffine.mat \
    -t S2S1Warp.nii.gz \
    -n NearestNeighbor \
    --float 1

    #3. Quality control registration output
    slicer ${structural_name}_MNI.nii.gz ${template} -a S2S_check.ppm

    #4. Concatenate transforms

    #structural2standard (natural order, warp first then affine - opposite to FSL)
    antsApplyTransforms \
    -d 3 \
    -o [structural2standard.nii.gz,1] \
    -t S2S1Warp.nii.gz \
    -t S2S0GenericAffine.mat \
    -r ${template}

    #standard2structural (inverse order, inverse affine then inverse warp)
    antsApplyTransforms \
    -d 3 \
    -o [standard2structural.nii.gz,1] \
    -t [S2S0GenericAffine.mat, 1] \
    -t S2S1InverseWarp.nii.gz \
    -r ${structural}

}

# call function

antsS2S

# perform cleanup
cp -fpR . "${outdir}"
cd "${outdir}"

# complete log

echo "all done with ants_struct2stand.sh" >> ${log}
echo $(date) >> ${log}
