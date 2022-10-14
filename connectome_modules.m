function connectome_modules(template)
% CONNECTOME_MODULES Connectome module finder
%
% Dependencies:     BCT 2019_03_03, versatility
%
% Inputs:           patientID,  directory of patient
%                   template,   connectome parcellation (must be MNI space)
%
% Outputs:          nifti files of connectome modules
%                   stats file of cross correlation with sensorimotor seeds
%
% Version: 1.0
%
% Michael Hart, University of British Columbia, May 2021

%% Set up FSL

%fsldir = '/Volumes/LaCie/fsl/';
%fsldirmpath = sprintf('%s/etc/matlab',fsldir);
%setenv('FSLDIR', fsldir);
%setenv('FSLOUTPUTTYPE', 'NIFTI_GZ');
%path(path, fsldirmpath);
%clear fsldir fsldirmpath;

%setenv('PATH', [getenv('PATH') ':/Volumes/LaCie/fsl/bin']);

%% A: Load data & setup

%This should be the only part required to be set manually

%Directory: run from analysis directory
directory = pwd;

%Patient path
%patient = strcat(directory, '/', patientID, '/');
%template = 'AAL90';
data = strcat(template, '/fdt_network_matrix');

%Load data
%data_path = strcat(template)
%data_path = strcat(patient, 'diffusion/probtrackx/', template, '/connectome/');
%data = strcat(patient, 'diffusion/probtrackx/', template, '/connectome/connectivity_strlines.csv');
CIJ = load(data);

%Load co-ordinates
%xyz = load(strcat(patient, 'diffusion/', template, '_seeds/xyz.txt'));

%Load labels
%parcels = readtable(strcat(patient, 'diffusion/', template, '_seeds/parcelnames.txt'));

%cd into directory to save figures
%cd(data_path);

%code path
%code = what('connectome_tractography');


%Nodes
nNodes = size(CIJ, 1); %parcels
% Make symmetric
CIJ = max(CIJ, CIJ');
% Zero negatives
CIJ(CIJ<0) = 0;
% Set diagonals to 1
CIJ(eye(nNodes)>0) = 1;
% Zero nans
CIJ(isnan(CIJ)) = 0;


%% B. Modularity analysis

%Can set manually or see full connectome analysis for principles of setting
gamma = 2.5;
M = ct_modularity_consensus_fun(CIJ, gamma, 10);

%% C: Create module IDs

%make list of moduleIDs in text files
%mkdir(strcat('connectome_modules_', template))
cd(strcat('connectome_modules_', template))

for iModule = 1:max(M)
    ID = find(M==iModule);
    filename = sprintf('module_%g.txt', iModule);
    fileID=fopen(filename, 'w');
    fprintf(fileID, '%d\n', ID);
    fclose(fileID);
end


%% All done
