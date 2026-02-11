%{
% Parameters
Fs = 2000;                % Sampling rate (Hz)
trial_duration_sec = 15;   % Duration of each trial (seconds)
n_samples = Fs * trial_duration_sec; % 10,000 samples
n_channels = 4;
n_trials = 3;

% Generate dummy data
for cond = {'rest', 'countF', 'alt'}
    trials = cell(1, n_trials);
    for t = 1:n_trials
        trial = randn(n_channels, n_samples); % 4 x 10000 matrix
        trial(4, :) = 0; % Set 4th electrode (reference) to zero
        trials{t} = trial;
    end
    data_all.(['all_' cond{1}]) = trials;
end

patient_data.data_all = data_all;

% Save to .mat file
save('dummy data/dummy_ecog_data.mat', 'patient_data');


load('/Users/moragnadel/Desktop/פרויקט/MATLAB app/dummy data/dummy_ecog_data.mat');
%}

[file, path] = uigetfile('*.mat', 'Select ECoG Data .mat File');
filePath = fullfile(path, file);
PatientData = load(filePath);