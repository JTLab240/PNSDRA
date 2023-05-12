%% Read Intan *.rhd file

% File format
name = 'Artificial_EEG'; 

% File name in rhd format
file = [name,'.rhd'];

% EEG file directory path
path = 'C:\Users\Jay\Desktop\Data\EEG Project\Preprocessing\';

% Read *.rhd file to matlab
read_Intan_file(file,path);

% Save into .mat format
save([name,'.mat'],'amplifier_data','-v7.3');

%% Preprocessing pipeline brainstorm

% Start brainstorm with no GUI
brainstorm nogui;

% Start brainstorm with GUI
% brainstorm;

% Empty BrainStorm temporal folder (If not, it may cause errors)
gui_brainstorm('EmptyTempFolder');

% Subject name (for BrainStorm)
SubjectNames = {'Example'};

% EEG data in *.mat format (created from line 16)
RawFiles = {[path,name,'.mat']};

% Protocol name (for BrainStorm)
ProtocolName = 'Protocol';

% Call preprocessing pipelines
bst_preprocessing

% Stop BrainStorm
brainstorm stop;
