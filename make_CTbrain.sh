#!/bin/bash
set -e

#define directories

codedir=${HOME}/bin
basedir=$(pwd)

#make usage function

usage()
{
cat<<EOF
usage: $0 options

===========================================================================

make_CTbrain.sh

Optimal method for skull stripping CT scans with FSL
Adapted from Muschelli et al 2015

Example:

make_CTbrain.sh -i CT.nii.gz

Options:

-h  show this help
-i  input CT
-o  overwrite output directory
-v  verbose

Version:    1.0

History:    no amendments

(c) Michael Hart, St George's University of London, May 2022


============================================================================

EOF
}


###################
# Standard checks #
###################

CT=

#initialise options

while getopts "hi:ov" OPTION
do
    case $OPTION in
    h)
        usage
        exit 1
        ;;
    i)
        CT=$OPTARG
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

if [[ -z $CT ]]
then
    echo "usage incorrect" >&2
    usage
    exit 1
fi

echo "options ok"

# final check of files

echo "checking CT data"

CT=`readlink -f ${CT}`

if [ $(imtest $CT) == 1 ];
then
    echo "CT data ok"
else
    echo "Cannot locate file $CT. Please ensure the $CT dataset is in this directory"
    exit 1
fi

echo "files ok"

#make output directory

if [ ! -d ${basedir}/CT_brain ];
then
    echo "making output directory"
    mkdir ${basedir}/CT_brain
else
    echo "output directory already exists"
    if [ "$overwrite" == 1 ]
    then
        mkdir -p ${basedir}/CT_brain
    else
        echo "no overwrite permission to make new output directory"
    exit 1
    fi
fi

outdir=${basedir}/CT_brain

cd "${outdir}"

#start logfile

touch CT_bet_logfile.txt
log=CT_bet_logfile.txt

echo $(date) >> ${log}
echo "${0}" >> ${log}
echo "${@}" >> ${log}


##################
# Main programme #
##################

# With pre-smoothing (recommended)
intensity=0.01
outfile="Head_Image_1_SS_0.01"
tmpfile=`mktemp`

# Thresholding Image to 0-100
fslmaths "${CT}" -thr 0.000000 -uthr 100.000000  "${outfile}"

# Creating 0 - 100 mask to remask after filling
fslmaths "${outfile}"  -bin   "${tmpfile}";
fslmaths "${tmpfile}.nii.gz" -bin -fillh "${tmpfile}"

# Presmoothing image
fslmaths "${outfile}"  -s 1 "${outfile}";

# Remasking Smoothed Image
fslmaths "${outfile}" -mas "${tmpfile}"  "${outfile}"

# Running bet2
bet2 "${outfile}" "${outfile}" -f ${intensity} -v

# Using fslfill to fill in any holes in mask
fslmaths "${outfile}" -bin -fillh "${outfile}_Mask"

# Using the filled mask to mask original image
fslmaths "${CT}" -mas "${outfile}_Mask"  "${outfile}"

# If no pre-smoothing
outfile_nosmooth="Head_Image_1_SS_0.01_nopresmooth"
fslmaths "${CT}" -thr 0.000000 -uthr 100.000000  "${outfile_nosmooth}"

# Creating 0 - 100 mask to remask after filling
fslmaths "${outfile_nosmooth}"  -bin   "${tmpfile}";
fslmaths "${tmpfile}" -bin -fillh "${tmpfile}"

# Running bet2
bet2 "${outfile_nosmooth}" "${outfile_nosmooth}" -f ${intensity} -v

# Using fslfill to fill in any holes in mask
fslmaths "${outfile_nosmooth}" -bin -fillh "${outfile_nosmooth}_Mask"

# Using the filled mask to mask original image
fslmaths "${CT}" -mas "${outfile_nosmooth}_Mask"  "${outfile_nosmooth}"
