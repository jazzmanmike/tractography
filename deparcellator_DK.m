%% deparcellator_DK
% Splits up individual DK parcellation into single ROI's e.g. for tractography seeds / targets
% Runs with tract_van.sh
% Need to be in 'diffusion' directory & set SUBJECTS_DIR=`pwd`


% Check FSL
fsldir = '/Volumes/LaCie/fsl/'; 
fsldirmpath = sprintf('%s/etc/matlab',fsldir);
setenv('FSLDIR', fsldir);
setenv('FSLOUTPUTTYPE', 'NIFTI_GZ');
path(path, fsldirmpath);
clear fsldir fsldirmpath;

setenv('PATH', [getenv('PATH') ':/Volumes/LaCie/fsl/bin']);

% 1. First run this in terminal to change parcellation ribbon to a volume

system('mri_aparc2aseg --s FS --annot aparc') 
system('mri_convert ./FS/mri/aparc+aseg.mgz dkn_volume.nii.gz');
system('fslreorient2std dkn_volume.nii.gz dkn_volume.nii.gz');

addpath(sprintf('%s/etc/matlab',getenv('FSLDIR'))); %need to be running matlab from command line

% 2. Now run this in matlab

mkdir dkn_seeds
outdir = strcat(mysubjectpath, 'dkn_seeds');
mysubject = 'SD1';
mysubjectpath = sprintf('/Volumes/LaCie/Tractography_Vancouver/%s/diffusion/', mysubject);
parcellation_path = strcat(mysubjectpath, 'dkn_volume');
parcellation_name = 'dkn_volume';
volume = load_nifti([mysubjectpath parcellation_name, '.nii.gz']);
uvol = unique(volume.vol);
parcel = 1;
for iv = 2:numel(uvol)
    val = uvol(iv);
    system(sprintf('fslmaths %s -thr %s -uthr %s -bin %s', parcellation_path, num2str(val), num2str(val), [outdir, '/Seg_' num2str(parcel)]));
    parcel = parcel + 1
end

%Remove first 30
XYZ = XYZ(44:end, :);

