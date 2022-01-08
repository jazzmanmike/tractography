#!/bin/bash
set -e

# make_bedpostx.sh
#
#
# Michael Hart, St George's University of London, January 2022 (c)

#define

codedir=${HOME}/Dropbox/Github/tractography
basedir="$(pwd -P)"
FSLOUTPUTTYPE=NIFTI_GZ #occassionally not set as standard


mkdir -p ${tempdir}/diffusion

cp ${data} ${tempdir}/diffusion/data.nii.gz
cp ${bvecs} ${tempdir}/diffusion/bvecs
cp ${bvals} ${tempdir}/diffusion/bvals
cp nodif_brain_mask.nii.gz ${tempdir}/diffusion/nodif_brain_mask.nii.gz

echo "BedPostX datacheck" >> $log
bedpostx_datacheck ${tempdir}/diffusion >> $log
echo "" >> $log

#call to run with GPU

#bedpostx_gpu


#check to run in parallel

if [ "${parallel}" == 1 ] ;
then
    echo "parallel is on"
    echo "Running BedPostX in parallel" >> ${log}

    #create directory structure
    mkdir -p ${tempdir}/diffusion.bedpostX/command_files/
    mkdir -p ${tempdir}/diffusion.bedpostX/diff_slices/
    mkdir -p ${tempdir}/diffusion.bedpostX/xfms/
    mkdir -p ${tempdir}/diffusion.bedpostX/logs/monitor
    cp ${tempdir}/diffusion/* ${tempdir}/diffusion.bedpostX/

    #make slices
    fslslice diffusion/data.nii.gz diffusion/data
    fslslice diffusion/nodif_brain_mask.nii.gz diffusion/nodif_brain_mask

    nSlices=`fslval diffusion/data.nii.gz dim3`
    #nSlices=`awk '{print NF; exit}' diffusion/bvecs` #number of diffusion slices
    echo "${nSlices}"

    #1. Make single slice bedpostx files & submit to cluster
    for ((slice=0; slice<${nSlices}; slice++));
    do #change for volumes syntax starting from 0
        echo ${slice}
        touch ${tempdir}/diffusion.bedpostX/command_files/command_`printf %04d ${slice}`.sh
        echo '#!/bin/bash' >> ${tempdir}/diffusion.bedpostX/command_files/command_`printf %04d ${slice}`.sh
        printf "tempdir=%s\n" "${tempdir}" >> ${tempdir}/diffusion.bedpostX/command_files/command_`printf %04d ${slice}`.sh
        printf "slice=%s\n" "${slice}" >> ${tempdir}/diffusion.bedpostX/command_files/command_`printf %04d ${slice}`.sh
        echo 'bedpostx_single_slice.sh ${tempdir}/diffusion ${slice} --nf=3 --fudge=1 --bi=1000 --nj=1250 --se=25 --model=1 --cnonlinear' >> ${tempdir}/diffusion.bedpostX/command_files/command_`printf %04d ${slice}`.sh
        chmod 777 ${tempdir}/diffusion.bedpostX/command_files/command_`printf %04d ${slice}`.sh
        sleep 2
        echo "Step-by-step bedpostx command_files/command_`printf %04d ${slice}`.sh"
        sbatch --time=02:00:00 ${tempdir}/diffusion.bedpostX/command_files/command_`printf %04d ${slice}`.sh
        sleep 1
    done

    echo "Bedpost jobs submitted to the cluster. Set to sleep for 4 hours to allow for any Slurm queue."

    sleep 4h #sleep longer as is job quick but sometimes the queue is long

    #2. Combines individual file outputs
    #Check if all made: if not, resubmit for longer

    bedpostFinished=`(ls ${tempdir}/diffusion.bedpostX/diff_slices/data_slice_*/mean_S0samples.nii.gz 2>/dev/null | wc -l)`

    echo "Number of bedpostx jobs finished: ${bedpostFinished}. Total should be equal to the number of slices: ${nSlices}"
    echo "ls ${tempdir}/diffusion.bedpostX/diff_slices/data_slice*/mean_dsamples.nii.gz | wc -l"

    if [[ "${bedpostFinished}" -ne "${nSlices}" ]] ;
    then
        echo "bedpostFinished + nSlices do not match"
        echo "ls ${tempdir}/diffusion.bedpostX/diff_slices/data_slice*/mean_dsamples.nii.gz | wc -l"
        for ((slice=0; slice<${nSlices}; slice++));
        do
            echo ${slice}
            if [ ! -f ${tempdir}/diffusion.bedpostX/diff_slices/data_slice_`printf %04d ${slice}`/mean_S0samples.nii.gz ] ;
            then
                echo "${slice} not run: resubmitting for longer (4 hours) with a longer wait (6 hours)"
                sleep 2
                echo "Step-by-step bedpostx command_files/command_`printf %04d ${slice}`.sh"

                #remove directory if exists - if doesn't either initial call or this one will produce required files & overwrite if required
                if [ -d ${tempdir}/diffusion.bedpostX/diff_slices/data_slice_`printf %04d ${slice}` ] ;
                then
                    rm -r ${tempdir}/diffusion.bedpostX/diff_slices/data_slice_`printf %04d ${slice}`
                fi

                sbatch --time=04:00:00 ${tempdir}/diffusion.bedpostX/command_files/command_`printf %04d ${slice}`.sh
                sleep 1

            fi
        done

        sleep 6h

    fi

    bedpostFinished=`(ls ${tempdir}/diffusion.bedpostX/diff_slices/data_slice_*/mean_S0samples.nii.gz 2>/dev/null | wc -l)`

    echo "bedpostFinished: ${bedpostFinished}" >> ${log}
    echo "nSlices: ${nSlices}" >> ${log}

    #3. If all made, run bedpostx_postproc to combine
    if  [[ "${bedpostFinished}" -eq "${nSlices}" ]] ;
    then
        echo "bedpostFinished + nSlices match: running bedpostx_postproc.sh ${tempdir}/diffusion"
        echo "bedpostFinished + nSlices match: running bedpostx_postproc.sh ${tempdir}/diffusion" >> ${log}
        bedpostx_postproc.sh ${tempdir}/diffusion
    else
        echo "bedpostFinished + nSlices do not match: parallel failed, will run in serial"
        echo "bedpostFinished + nSlices do not match: parallel failed, will run in serial" >> ${log}
        rm -r diffusion.bedpostX/
        bedpostx ${tempdir}/diffusion --model=1
    fi

 else
    echo "running BedPostX in serial"
    #set to just sticks
    bedpostx ${tempdir}/diffusion --model=1
 fi
