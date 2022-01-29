#!/bin/bash
set -e

# make_diffusiondenoies.sh
#
#
# Michael Hart, St George's University of London, January 2022 (c)

#define
codedir=${HOME}/Dropbox/Github/tractography
basedir="$(pwd -P)"
FSLOUTPUTTYPE=NIFTI_GZ #occassionally not set as standard



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
elif [ -f ${basedir}/acqparams.txt ] ; then
    cp ${basedir}/acqparams.txt .
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
elif [ -f ${basedir}/index.txt ] ; then
    cp ${basedir}/index.txt .
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
