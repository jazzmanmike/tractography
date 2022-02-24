%% Electrode Autoreconstruction
%
% Performs a variety of electrode analyses including:
%   PaCER electrode localisation
%   DiODE directionality
%   FastField VAT analysis
%
% Michael Hart, St George's University of London, February 2022

%% Loadup data

cd 
load("ea_reconstruction.mat");


%% 1. Electrode Localisation

SETUP_PACER
POSTOPCT_FILENAME = 'postop_ct.nii'; 
niiCT = NiftiMod(POSTOPCT_FILENAME);
elecModels = PaCER(niiCT); 


%% 2. DiODE directionality

ctpath = '/home/michaelhart/Documents/DBS_analyses/lead_test/postop_ct.nii';

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

% Path to the fastfield directory
dir_fastfield='/home/michaelhart/Documents/MATLAB/toolboxes/FastField-master';
% Path to the patient directory
dir_patient = '/home/michaelhart/Documents/DBS_analyses/lead_test';

%features
perc = [0 100 0 0 0 0 0 0];
amp=1;
side = 1; % Right is 1,  Left is 2
Electrode_type = 'boston_vercise'; %'boston_vercise_directed'; %'medtronic_3389'; % 'boston_vercise';'medtronic_3387';
conductivity = 0.1;
Threshold = 200; % the treshold for Efield visualisation
plot_choice = 'vta';%vta_efield
amp_mode = 'V'; %'mA'; % 'V'
impedence = 1000; % only needed if the amp_mode= 'V' otherwise it can be empty = [];

% load resources
[standard_efield,grid_vec,electrode,electrode_patient,atlases,electrode_native] = load_files(dir_fastfield,dir_patient,Electrode_type);

% get the Efield
[Efield,xg,yg,zg,elfv,trans_mat] = fastfield_main(standard_efield,grid_vec,electrode,electrode_patient,perc,amp,side,conductivity,amp_mode,impedence);


%% Saveup

filename = 'electrode_autoreconstruction';
save(filename);
