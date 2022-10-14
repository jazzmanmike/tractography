#!/bin/bash
set -e

# make_diffusiondenoies.sh data reversePE bvecs bvals
#
#
# Michael Hart, St George's University of London, January 2022 (c)

#define
codedir=${HOME}/Dropbox/Github/tractography
basedir="$(pwd -P)"
FSLOUTPUTTYPE=NIFTI_GZ #occassionally not set as standard
data=$1
reversePE=$2
bvecs=$3
bvals=$4
#acqp=$5

touch diffusiondenoise.log
log="${basedir}"/diffusiondenoise.log
date >> "${log}"
echo "Doing make_diffusiondenoise.sh"
echo "Doing make_diffusiondenoise.sh" >> "${log}"
echo "" >> "${log}"


#########

#1. TopUp

#########

date >> "${log}"
echo "Doing TopUp"
echo "Doing TopUp" >> "${log}"
echo "" >> "${log}"

#Notes
#Not explictly stated in protocol or header (text of FSLEyes)
#In viewer
#Data = P >> A 0 1 0 PA positive blips
#Rev = A >> P 0 -1 0 AP negative blips

mkdir -pv topup
cd topup

#check these are the different phase encode direction B0 volumes
echo "making blip files"
fslroi "${data}" blip_up 0 1
fslroi "${reversePE}" blip_down 0 1
fslmerge -t blip_UpDown blip_up blip_down

#option to set custom acqusition parameters if required, otherwise will use default
echo "setting acqparams.txt"
if [ -f ${basedir}/acqparams.txt ] ; then
    echo "acqparams.txt file found"
    cp ${basedir}/acqparams.txt .
#elif [ -f ${basedir}/acqparams.txt ] ; then
#    cp ${basedir}/acqparams.txt .

else
    #printf "0 -1 0 0.0646\n0 1 0 0.0646" > acqparams.txt
    printf "0 1 0 0.0802\n0 -1 0 0.0802" > acqparams.txt #Philips SGUL
fi

#main topup command: 7 mins
echo "running main topup command"
topup --imain=blip_UpDown --datain=acqparams.txt --config=b02b0.cnf --out=my_topup_results --iout=my_hifi_b0 --fout=my_field
echo "running applytopup"
applytopup --imain=blip_up,blip_down --inindex=1,2 --datain=acqparams.txt --topup=my_topup_results --out=my_applytopup_check

cd ../

date >> "${log}"
echo "Finished TopUp" >> "${log}"
echo "" >> "${log}"


########

#2. Eddy

########


date >> "${log}"
echo "Doing eddy"
echo "Doing eddy" >> "${log}"
echo "" >> "${log}"

mkdir -pv eddy
cd eddy
cp "${basedir}"/topup/acqparams.txt .

#create files
echo "making brain mask"
fslmaths "${basedir}"/topup/my_hifi_b0 -Tmean my_hifi_b0 #output from TopUp
bet my_hifi_b0 my_hifi_b0_brain -m -f 0.2 #add fractional intensity to prevent brain being cut

#option to set custom index file if required, otherwise will use default for SGUL (32dirs)
echo "setting index.txt"
if [ -f ${basedir}/index.txt ] ; then
   echo "index.txt file found"
   cp "${basedir}"/index.txt index.txt
else
   indx=""
   for ((i=1; i<=33; i+=1));
   do
      indx="$indx 1";
   done
   echo ${indx} > index.txt
fi


#main eddy command: 10 mins
date >> "${log}"
echo "Main eddy command"
echo "Main eddy command" >> "${log}"
echo "" >> "${log}"

eddy_openmp --imain="${data}" \
--mask=my_hifi_b0_brain_mask \
--acqp=acqparams.txt \
--index=index.txt \
--bvecs="${bvecs}" \
--bvals="${bvals}" \
--topup="${basedir}"/topup/my_topup_results \
--out=eddy_corrected_data

#to add --cnr_maps --repol --mporder


#alternative eddy command for high movement population: 28 mins
date >> "${log}"
echo "Alternative eddy command"
echo "Alternative eddy command" >> "${log}"
echo "" >> "${log}"

eddy_openmp --imain="${data}" \
--mask=my_hifi_b0_brain_mask \
--acqp=acqparams.txt \
--index=index.txt \
--bvecs="${bvecs}" \
--bvals="${bvals}" \
--topup="${basedir}"/topup/my_topup_results \
--out=my_hifi_data \
--niter=8 \
--fwhm=10,6,4,2,0,0,0,0 \
--repol \
--mporder=8 \
--s2v_niter=8 \
--cnr_maps
#6 added options
#--ol_type=both \
#--slspec=my_slspec.txt

date >> "${log}"
echo "Finishing eddy"
echo "Finishing eddy" >> "${log}"
echo "" >> "${log}"

cd ../


###################

#3. Quality control

###################


date >> "${log}"
echo "Doing QC"
echo "Doing QC" >> "${log}"
echo "" >> "${log}"


#Slices of various important files
slicer "${basedir}"/topup/blip_up -a "${basedir}"/QC/check_blipup.ppm
slicer "${basedir}"/topup/blip_down -a "${basedir}"/QC/check_blipdown.ppm
slicer "${basedir}"/topup/my_hifi_b0 -a "${basedir}"/QC/check_topup.ppm
slicer "${basedir}"/eddy/my_hifi_b0_brain -a "${basedir}"/QC/check_topup_brain.ppm
slicer "${basedir}"/eddy/eddy_corrected_data.nii.gz -a "${basedir}"/QC/check_eddy_corrected.ppm


#EddyQC
eddy_quad "${basedir}"/eddy/my_hifi_data \
-idx "${basedir}"/eddy/index.txt \
-par "${basedir}"/eddy/acqparams.txt \
-m "${basedir}"/eddy/my_hifi_b0_brain_mask \
-b "${bvals}" \
-g "${bvecs}" \
-v
#bug with -f option in FSL version 6


date >> "${log}"
echo "Finishing QC"
echo "Finishing QC" >> "${log}"
echo "" >> "${log}"

cd ../
