%% Load data

% Check if the protocol exist
iProtocol = bst_get('Protocol', ProtocolName);

if isempty(iProtocol)
    gui_brainstorm('CreateProtocol', ProtocolName, 0, 0); % If the protocol does not exist create a new one.
else
    gui_brainstorm('SetCurrentProtocol', iProtocol); % If the protocol exist, use the current protocol.
end

sFiles = [];

% Start a new report
bst_report('Start', sFiles);

% Process: Create link to raw file
sFiles = bst_process('CallProcess', 'process_import_data_raw', sFiles, [], ...
    'subjectname',    SubjectNames{1}, ...
    'datafile',       {RawFiles{1}, 'EEG-MAT'}, ...
    'channelreplace', 1, ...
    'channelalign',   1, ...
    'evtmode',        'value');

%% Preprocessing

% Process: Notch filter: 60Hz 120Hz 180Hz
sFiles = bst_process('CallProcess', 'process_notch', sFiles, [], ...
    'sensortypes', 'MEG, EEG', ...
    'freqlist',    [60, 120, 180], ...  % Frequency parameter (e.g., [60, 120, 180] = 60Hz, 120Hz, 180Hz
    'cutoffW',     1, ...
    'useold',      0, ...
    'read_all',    0);

% Process: Band-pass:0.1Hz-60Hz
sFiles = bst_process('CallProcess', 'process_bandpass', sFiles, [], ...
    'sensortypes', 'MEG, EEG', ...
    'highpass',    0.1, ... % Highpass frequency
    'lowpass',     60, ...  % Lowpass frequency
    'tranband',    0, ...
    'attenuation', 'strict', ...  % 60dB
    'ver',         '2019', ...  % 2019
    'mirror',      0, ...
    'read_all',    0);

% Process: DC offset correction: [0.000s,300.031s]
sFiles = bst_process('CallProcess', 'process_baseline', sFiles, [], ...
    'baseline',    [0, 300.031], ... % Set baseline period (time-window)
    'sensortypes', 'MEG, EEG', ...
    'method',      'bl', ...  % DC offset correction:    x_std = x - &mu;
    'read_all',    0);

% Process: Remove linear trend: [0.000s,300.031s]
sFiles = bst_process('CallProcess', 'process_detrend', sFiles, [], ...
    'timewindow',  [0, 300.031], ...    % Set time-window
    'sensortypes', 'MEG, EEG', ...
    'read_all',    0);

% Process: Re-reference EEG
sFiles = bst_process('CallProcess', 'process_eegref', sFiles, [], ...
    'eegref',...
    'AVERAGE', ...  % Reference (e.g., 1. AVERAGE = Average of all channels, 2. Channel name (Fz1): Set the specified channel as a reference)
    'sensortypes', 'EEG');

% Process: Detect eye blinks
sFiles = bst_process('CallProcess', 'process_evt_detect_eog', sFiles, [], ...
    'channelname', 'E02', ...   % Select reference channels to detect eye blinks
    'timewindow',  [], ...
    'eventname',   'blink');

% Process: SSP EOG: blink
sFiles = bst_process('CallProcess', 'process_ssp_eog', sFiles, [], ...
    'eventname',   'blink', ...
    'sensortypes', '', ...
    'usessp',      1, ...
    'select',      1);

% Process: Import MEG/EEG: Time
sFiles = bst_process('CallProcess', 'process_import_data_time', sFiles, [], ...
    'subjectname',   SubjectNames{1}, ...
    'condition',     '', ...
    'timewindow',    [], ...
    'split',         2, ... % Epoch time-window in seconds (e.g., 1 = 1 second)
    'ignoreshort',   1, ...
    'usectfcomp',    1, ...
    'usessp',        1, ...
    'freq',          [], ...
    'baseline',      [], ...
    'blsensortypes', 'MEG, EEG');

% Process: Hilbert transform
sFiles2 = bst_process('CallProcess', 'process_hilbert', sFiles, [], ...
    'sensortypes',   'MEG, EEG', ...
    'edit',          struct(...
         'Comment',         'Power', ...
         'TimeBands',       [], ...
         'Freqs',           {{'delta', '0.5, 4', 'mean'; 'theta', '5, 7', 'mean'; 'alpha', '8, 12', 'mean'; 'beta', '15, 29', 'mean'; 'gamma1', '30, 59', 'mean'; 'gamma2', '60, 90', 'mean'}}, ... % Specify frequency band ranges
         'ClusterFuncTime', 'none', ...
         'Measure',         'power', ...
         'Output',          'all', ...
         'SaveKernel',      0), ...
    'normalize2020', 0, ...
    'normalize',     'none', ...  % None: Save non-standardized time-frequency maps
    'mirror',        0);

%% Saving data

bst_db_dir = 'C:\Users\Jay\Desktop\Data\BrainStorm\brainstorm_db\'; % File directory

Result.EEG = []; Result.Time = []; Result.Power = []; Result.Frequency = [];

for i = 1:size(sFiles,2)    
    
    file = [bst_db_dir, '\',ProtocolName,'\',sFiles(i).FileType,'\', sFiles(i).FileName];   % Preprocessed EEG file name
    tmp_eeg = load(file);
    
    file2 = [bst_db_dir, '\',ProtocolName,'\',sFiles(i).FileType,'\', sFiles2(i).FileName]; % Average power (Hilbert transform) file name
    tmp_power = load(file2);
    
    if i == 1
        fileChan = [bst_db_dir, '\',ProtocolName,'\',sFiles(i).FileType,'\', sFiles(i).ChannelFile];
        load(fileChan)
        Result.channel = Channel;   % Channel information
        
        Result.Frequency = tmp_power.Freqs; % Frequency band information
    else
    end

    Result.EEG = cat(3, Result.EEG, F); % channel x time x epoch
    Result.Time = [Result.Time; Time];  % epoch x time
    Result.Power = cat(4, Result.Power, tmp_power.TF);  % channel x time x frequency x epoch
end

save([path,name,'_preprocessed.mat'],'Result','-v7.3');