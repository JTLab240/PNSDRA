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

%% Saving data

bst_db_dir = 'C:\Users\Jay\Desktop\Data\BrainStorm\brainstorm_db\';

Result.data = []; Result.Time = [];

for i = 1:size(sFiles,2)    
    if i == 1
        fileChan = [bst_db_dir, '\',ProtocolName,'\',sFiles(i).FileType,'\', sFiles(i).ChannelFile];
        load(fileChan)
        Result.channel = Channel;
    else
    end
            
    file = [bst_db_dir, '\',ProtocolName,'\',sFiles(i).FileType,'\', sFiles(i).FileName];
    load(file);
    
    Result.data = cat(3, Result.data, F);
    Result.Time = [Result.Time; Time];
end

save([path,name,'_preprocessed.mat'],'Result','-v7.3');