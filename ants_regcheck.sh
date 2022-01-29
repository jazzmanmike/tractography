#!/bin/bash
set -e

#ants_regcheck.sh
#
#
#Michael Hart, University of Cambridge, 13 April 2016 (c)

#define directories

codedir=${HOME}/Dropbox/Github/tractography
basedir="$(pwd -P)"

#make usage function

usage()
{
cat<<EOF
usage: $0 options

===========================================================================

ants_regcheck.sh

(c) Michael Hart, University of Cambridge, 2016

Warps diffusion volume to standard space, generates transforms (e.g. for use in XTRACT), + generates quality control images

Example:

ants_regcheck.sh -d diffusion.nii.gz -w warp.nii.gz -i inverse_warp.nii.gz -r rigid.mat

Options:

-h  show this help
-d  diffusion
-w  warp (contactenated transform e.g. ants_struct2stand.sh output)
-i  inverse warp (concatenated transform e.g. ants_struct2stand.sh output)
-r  rigid transform directory (e.g. ants_diff2struct.sh output)
-t  standard space template (optional: default = MNI
-o  overwrite
-v  verbose

Version:    1.2

History:    amended for github tractography repository

============================================================================

EOF
}


###################
# Standard checks #
###################


#initialise options

diffusion=
warp=
rigid=
template=

while getopts "hd:w:i:r:t:ov" OPTION
do
    case $OPTION in
    h)
        usage
        exit 1
        ;;
    d)
        diffusion=$OPTARG
        ;;
    w)
        warp=$OPTARG
        ;;
    i)
        inverse=$OPTARG
        ;;
    r)
        rigid=$OPTARG
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

if [[ -z $diffusion ]] || [[ -z $warp ]] || [[ -z $inverse ]] || [[ -z $rigid ]]
then
    echo "usage incorrect"
    usage
    exit 1
fi

echo "options ok"

# final check of files

echo "Checking diffusion and structural data"

#diffusion=${basedir}/${diffusion}

if [ $(imtest $diffusion) == 1 ];
then
    echo "$diffusion dataset ok"
else
    echo "Cannot locate file $diffusion. Please ensure the $diffusion dataset is in this directory"
    exit 1
fi


#warp=${basedir}/${warp}

if [ $(imtest $warp) == 1 ];
then
    echo "$warp dataset ok"
else
    echo "Cannot locate file $warp. Please ensure the $warp dataset is in this directory"
    exit 1
fi


#inverse=${basedir}/${inverse}

if [ $(imtest $inverse) == 1 ];
then
    echo "$inverse dataset ok"
else
    echo "Cannot locate file $inverse. Please ensure the $inverse dataset is in this directory"
    exit 1
fi


#rigid=${basedir}/${rigid}

if [ -f $rigid ];
then
    echo "$rigid dataset ok"
else
    echo "Cannot locate file $rigid. Please ensure the $rigid dataset is in this directory"
    exit 1
fi


echo "files ok"

if [ $(imtest $template) == 1 ];
then
    echo "$template dataset ok"
    template=${basedir}/${template}
else
    template=${codedir}/ANTS_templates/MNI152_T1_2mm_brain.nii.gz
    echo "No template supplied - using MNI152_T1_2mm_brain"
fi

#make output directory

if [ ! -d ${basedir}/ants_reg ];
then
    echo "making output directory"
    mkdir ${basedir}/ants_reg
else
    echo "output directory already exists"
    if [ "$overwrite" == 1 ]
    then
        echo "overwriting output directory"
        mkdir -p ${basedir}/ants_reg
    else
        echo "no overwrite permission to make new output directory"
    exit 1
    fi
fi

outdir=${basedir}/ants_reg
cd "${outdir}"

#start logfile

touch ${outdir}/ants_reg_logfile.txt
log=${outdir}/ants_reg_logfile.txt

echo $(date) >> ${log}
echo "${@}" >> ${log}


##################
# Main programme #
##################


function ARC(){

    #1. concatentate transforms

    #diffusion to standard
    antsApplyTransforms \
    -d 3 \
    -t ${warp} \
    -t ${rigid} \
    -o [diff2standard.nii.gz, 1] \
    -r ${template}

    #standard to diffusion: ?outout inverse too
    antsApplyTransforms \
    -d 3 \
    -t [${rigid}, 1] \
    -t ${inverse} \
    -o [standard2diff.nii.gz, 1] \
    -r ${template}

    #2. apply tranform

    echo "applying transforms: diffusion-to-template"

    antsApplyTransforms \
    -d 3 \
    -o diffusion_MNI.nii.gz \
    -t diff2standard.nii.gz \
    -r ${template} \
    -i ${diffusion}

    #3. generate summary images

    slicer ${template} diffusion_MNI.nii.gz -a diff2standard.ppm

}


#call function

ARC

#cleanup
rm -Rf MNI_replicated.nii.gz diff4DCollapsedWarp.nii.gz
cd ${basedir}

#close up
echo "all done" >> ${log}
echo $(date) >> ${log}
