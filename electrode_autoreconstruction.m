%% Electrode Autoreconstruction
%
% Performs a variety of electrode analyses including:
%   PaCER electrode localisation
%   DiODE directionality
%   FastField VAT analysis
%
%   NB: set to BSC Octode as standard
%   NNB: works in lead_data directory
%
% Michael Hart, St George's University of London, February 2022

%% Loadup data

load("ea_reconstruction.mat");


%% 1. Electrode Localisation

SETUP_PACER
POSTOPCT_FILENAME = 'postop_ct.nii'; 
niiCT = NiftiMod(POSTOPCT_FILENAME);
elecModels = PaCER(niiCT); 
XYZ_right = elecModels{1}.getContactPositions3D();
XYZ_left = elecModels{2}.getContactPositions3D();


%% 2. DiODE directionality

ctpath = '/home/michaelhart/Documents/DBS_analyses/newsubject/lead_test/postop_ct.nii';

%right
head_mm = elecModels{1}.getEstTipPos;
tail_mm = [14 -7 8]; %estimated
myside = 1;
elmodel = 'Boston Scientific Vercise Directed';
[roll_y_right,y_right,roll_y_deg_right] = diode_standalone(ctpath, head_mm, tail_mm, myside, elmodel);

%left
head_mm = elecModels{2}.getEstTipPos;
tail_mm = [-14 -7 8];
[roll_y_left,y_left,roll_y_deg_left] = diode_standalone(ctpath, head_mm, tail_mm, myside, elmodel);


%% 3. FastField VAT analysis

%Path to the fastfield directory
dir_fastfield='/home/michaelhart/Documents/MATLAB/toolboxes/FastField-master';

%Path to the patient directory
dir_patient = '/home/michaelhart/Documents/DBS_analyses/newsubject/lead_data';

%features
perc = [0 100 0 0 0 0 0 0];
amp = 1;
Electrode_type = 'boston_vercise'; %'boston_vercise_directed'; %'medtronic_3389'; % 'boston_vercise';'medtronic_3387';
conductivity = 0.1;
Threshold = 200; %the treshold for Efield visualisation
plot_choice = 'vta'; %vta_efield
amp_mode = 'V'; %'mA'; % 'V'
impedence = 1000; %only needed if the amp_mode= 'V' otherwise it can be empty = [];

%load resources
[standard_efield,grid_vec,electrode,electrode_patient,atlases,electrode_native] = load_files(dir_fastfield,dir_patient,Electrode_type);

%get the Efield
side = 1; %Right is 1, Left is 2
[Efield_right,xg_right,yg_right,zg_right,elfv_right,trans_mat_right] = fastfield_main(standard_efield,grid_vec,electrode,electrode_patient,perc,amp,side,conductivity,amp_mode,impedence);

side = 2; %Right is 1, Left is 2
[Efield_left,xg_left,yg_left,zg_left,elfv_left,trans_mat_left] = fastfield_main(standard_efield,grid_vec,electrode,electrode_patient,perc,amp,side,conductivity,amp_mode,impedence);


%% Saveup

filename = 'electrode_autoreconstruction';
save(filename);
