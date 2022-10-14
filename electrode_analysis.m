%% Electrode Analysis
%
% Performs PaCER electrode localisation in CT & MNI space (both FSL & ANTS registrations)
%
%   NB: set to BSC Octode as standard
%   NNB: works in electrode_analysis directory
%
% Michael Hart, St Georges University of London, May 2022

%% Load data

%working in /structural/
datapath = pwd;
%cd electrode_analysis

%from earlier lead_dbs call
load("ea_reconstruction.mat");

%% 1. Lead-DBS co-ordinates
XYZ_right_lead = reco.mni.coords_mm{1,2};
XYZ_left_lead = reco.mni.coords_mm{1,1};
writematrix(XYZ_right_lead, 'XYZ_right_lead.txt', 'delimiter', 'tab');
writematrix(XYZ_left_lead, 'XYZ_left_lead.txt', 'delimiter', 'tab');

%% 2.PaCER in CT space

SETUP_PACER
CT = 'postop_ct.nii';
niiCT = NiftiMod(CT);
elecModels = PaCER(niiCT);
XYZ_right_CT = elecModels{1}.getContactPositions3D();
XYZ_left_CT = elecModels{2}.getContactPositions3D();
writematrix(XYZ_right_CT, 'XYZ_right_CT.txt', 'delimiter', 'tab');
writematrix(XYZ_left_CT, 'XYZ_left_CT.txt', 'delimiter', 'tab');
writecsv(XYZ_right_CT, XYZ_right_CT.csv); #header: x,y,z,t (0),label (1),comment (nan)

%% Saveup
filename = 'electrode_autoreconstruction';
save(filename);
