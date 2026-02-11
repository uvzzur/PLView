classdef PLView < matlab.apps.AppBase
   % Properties that correspond to app components
   properties (Access = public)
       UIFigure                     matlab.ui.Figure
       GridLayout                   matlab.ui.container.GridLayout
       LeftPanel                    matlab.ui.container.Panel
       GridLayout2                  matlab.ui.container.GridLayout
       TestConditionDropDownLabel   matlab.ui.control.Label
       SelectedElectrodeFrequencyLabel  matlab.ui.control.Label
       ElectrodesLabelsSwitchLabel  matlab.ui.control.Label
       Logo                         matlab.ui.control.Image
       ConditionDropDown            matlab.ui.control.DropDown
       Freq1DropDown                matlab.ui.control.DropDown
       Freq2DropDown                matlab.ui.control.DropDown
       SelectedElectrodeRole        matlab.ui.container.ButtonGroup
       AmpButton                    matlab.ui.control.RadioButton
       PhaseButton                  matlab.ui.control.RadioButton
       ShowElectrodesLabelsSwitch   matlab.ui.control.Switch
       UploadMATFileButton          matlab.ui.control.Button
       CenterPanel                  matlab.ui.container.Panel
       GridLayout3                  matlab.ui.container.GridLayout
       ProcessingLabel              matlab.ui.control.Label
       DataLoadLamp                 matlab.ui.control.Lamp
       BrainAxes                    matlab.ui.control.UIAxes
       RightPanel                   matlab.ui.container.Panel
       GridLayout4                  matlab.ui.container.GridLayout
       CircleAxes                   matlab.ui.control.UIAxes
   end
   % Properties that correspond to apps with auto-reflow
   properties (Access = private)
       onePanelWidth = 576;
       twoPanelWidth = 768;
   end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% PROPERTIES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   % Public properties (might need external access)
   properties (Access = private)
       % PUBLIC DATA
       PatientData          % Raw loaded .mat file data
       PatientName          % String: current subject identifier (example: "2017_02")
       CurrentConditionData % Processed ECoG data for the current test condition
       PLVMatrix            % Computed PLV connectivity matrix
       % ELECTRODE CONFIGURATION
       ElectrodeCoords     % Nx3 matrix: 3D electrode positions (x,y,z)
       NumElectrodes       % Integer: number of electrodes
      
       % PROCESSING PARAMETERS
       SamplingFrequency   % [Hz], default: 2000
      
       % VISUALIZATION STATE
       ShowLabels          % Boolean: electrode labels on/off
       ElectrodeRole       % Boolean: selected electrode role (phase / amp)
   end
  
   % Private properties
   properties (Access = private)
       % ELECTRODES LAB'S DATABASE
       % ↳ Should remain static in the lab's drive and updated for new patients.
       ElectrodesData = load("/mnt/jane_data/DataFromMoataz/Elecs_n79_w_network.mat"); % Table
       % ELECTRODES DATA
       ElectrodeInfo          % Struct: containing all electrode information
       NetworkColorMap        % Dictionary (containers.map object): color mapping for different networks
       SelectedElectrodeIdx   % Integer: index of currently selected electrode (0 = none)
       InfoPanel              % Handle: to information panel
       InfoText               % Handle: to information text
       InfoPanelVisible       % Boolean: tracks if floating info panel is visible
      
       % PROCESSING FLAGS
       IsDataLoaded           % Boolean: tracks if valid data is available
       NeedsReprocessing      % Boolean: tracks if PLV needs recalculation
       IsProcessing           % Boolean: tracks if processing is in progress
       LoadingTimer           % Array: timer for rotating brain animation
      
       % 2D VISUALIZATION HANDLES
       CircleElectrodeCoords   % 2D coordinates for circular layout
       CircleLinesHandles      % Graphics handles for 2D connectivity lines
       CircleElectrodeHandles  % Graphics handles for 2D electrode points
       CircleElectrodeLabels   % Graphics handles for 2D electrode text labels
       % 3D VISUALIZATION HANDLES 
       BrainModelHandle        % Graphics handle for 3D brain surface
       BrainElectrodeHandles   % Graphics handles for 3D electrode points
       BrainLinesHandles       % Graphics handles for 3D connectivity lines
       BrainBackgroundLines    % Graphics handles for persistent grey background lines
       BrainSelectedLines      % Graphics handles for selected electrode lines
       BrainStrongestLine      % Graphics handle for strongest connection highlight
       BrainElectrodeLabels    % Graphics handles for 3D electrode text labels 
      
       % VISUAL STYLING
       cmap                    % Custom colormap for PLV visualization
       ElectrodeColors         % Current color matrix for electrodes
       ColorbarMax             % Maximum value for colorbar scaling (120% of max PLV)
      
   end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% FUNCTIONS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   methods (Access = private)
      
       %%%%%%%%%%%%%%%%%%%% Graphics %%%%%%%%%%%%%%%%%%%%
       % Custom gradient colormap
       function customColormap(app)
           try
               % Number of colors
               numColors = 256; % Default size
              
               % RGB gradient colors (from blue to white)
               blue    = [0.05, 0.05, 0.6];    % dark blue
               purple  = [0.5, 0.0, 0.6];      % deep purple
               red     = [0.8, 0.0, 0.1];      % red
               orange  = [1.0, 0.5, 0.0];      % orange
               white   = [1.0, 1.0, 1.0];      % white
              
               % Positions of these colors along the gradient (0 to 1)
               positions = [0, 0.35, 0.6, 0.85, 1];
              
               % Color order
               colors = [blue; purple; red; orange; white];
              
               % Interpolate each RGB channel over numColors points
               xInterp = linspace(0, 1, numColors);
               rInterp = interp1(positions, colors(:,1), xInterp, 'pchip');
               gInterp = interp1(positions, colors(:,2), xInterp, 'pchip');
               bInterp = interp1(positions, colors(:,3), xInterp, 'pchip');
              
               % Combine into final colormap
               app.cmap = [rInterp(:), gInterp(:), bInterp(:)];
           catch
               app.cmap = parula(256); % Alternative colormap
           end
       end
       % Create networks colormap
       function createNetworkColorMap(app)
           % Get unique networks
           uniqueNetworks = unique(app.ElectrodeInfo.Networks, 'stable');
           numNetworks = length(uniqueNetworks);
          
           % Create distinct colors for each network
           if numNetworks <= 10
               % Predefined distinct colors
               distinctColors = [
                   1.0, 0.0, 0.0;    % Red
                   0.0, 0.8, 0.0;    % Green
                   0.0, 0.0, 1.0;    % Blue
                   1.0, 0.65, 0.0;   % Orange
                   0.8, 0.0, 0.8;    % Magenta
                   0.0, 0.8, 0.8;    % Cyan
                   1.0, 1.0, 0.0;    % Yellow
                   0.5, 0.0, 1.0;    % Purple
                   0.0, 0.5, 0.0;    % Dark Green
                   0.8, 0.4, 0.0;    % Brown
               ];
               networkColors = distinctColors(1:numNetworks, :);
           else
               % If many networks
               networkColors = hsv(numNetworks);
           end
          
           % Create mapping dictionary
           app.NetworkColorMap = containers.Map();
           for i = 1:numNetworks
               app.NetworkColorMap(uniqueNetworks{i}) = networkColors(i, :);
           end
       end
       % Replace the automatic layout behavior
       function customLayoutControl(app, src, evt)
           % Only allow responsive layout changes if data is loaded
           if app.IsDataLoaded
               % Call the original auto-generated updateAppLayout method
               app.updateAppLayout(evt);
           else
               % Keep 2-column layout during startup
               app.GridLayout.ColumnWidth = {200, '1x', 0};
               drawnow;
           end
       end
       % Setup loading animation UI changes
       function setupLoadingAnimation(app)
           app.IsProcessing = true;
          
           % Hide UI controls during processing
           app.RightPanel.Visible = 'off';  % Hide the right panel
           app.ConditionDropDown.Enable = 'off';
           app.Freq1DropDown.Enable = 'off';
           app.Freq2DropDown.Enable = 'off';
           app.SelectedElectrodeRole.Enable = 'off';
           app.ShowElectrodesLabelsSwitch.Enable = 'off';
          
           % Show processing status
           app.DataLoadLamp.Color = 'yellow';
           app.ProcessingLabel.FontColor = 'yellow';
           app.ProcessingLabel.Text = "   Processing...";
          
           % Clear any existing electrodes and connections
           if ~isempty(app.BrainElectrodeHandles)
               delete(app.BrainElectrodeHandles);
               app.BrainElectrodeHandles = gobjects(0);
           end
           if ~isempty(app.BrainLinesHandles)
               delete(app.BrainLinesHandles);
               app.BrainLinesHandles = gobjects(0);
           end
           app.updateBrainModel();
           drawnow;
       end
       % Process data with background animation
       function processDataWithAnimation(app, filePath, file)
           % Start rotation timer
           app.LoadingTimer = timer('ExecutionMode', 'fixedRate', 'Period', 0.05, ...
                                   'TimerFcn', @(~,~) app.continuousRotation());
           start(app.LoadingTimer);
          
           try
               % Data processing
               app.PatientData = load(filePath);
               file = char(file); % convert to char array
               app.PatientName = file(end-10:end-4); % example: "2017_02"
               app.createElectrodeInfo();
               app.updateCurrentConditionData();
               % Only proceed if data is valid
               if ~isempty(app.CurrentConditionData)
                   app.processAndDisplayData();
                  
                   % Processing complete - stop animation
                   app.stopLoadingAnimation();
  
                   % Switch to 3-column layout
                   app.IsDataLoaded = true;
                   app.RightPanel.Visible = 'on';
                   app.GridLayout.ColumnWidth = {200, '1x', '0.5x'}; % Show right panel (2D)
  
                   % Success messages
                   uialert(app.UIFigure, 'Data loaded successfully!', 'Success', 'Icon', 'success');
                   app.setInfoPanelVisible(true);  % Show info panel
                   app.updateInfoPanel(0);         % (0) = General info
               else
                   app.stopLoadingAnimation();
                   uialert(app.UIFigure, 'Data loaded but no valid ECoG data found. Check data structure.', 'Warning', 'Icon', 'warning');
               end
              
           catch ME
               app.stopLoadingAnimation();
               rethrow(ME);
           end
       end
       % Continuous rotation function for timer
       function continuousRotation(app)
           persistent rotationAngle;
           if isempty(rotationAngle)
               rotationAngle = 0;
           end
          
           if isvalid(app.BrainAxes) && app.IsProcessing
               view(app.BrainAxes, rotationAngle, 20);
               rotationAngle = rotationAngle + 3; % 3 degrees per 50ms
               if rotationAngle >= 360
                   rotationAngle = 0;
               end
               drawnow limitrate;
           end
       end
       % Stop loading animation
       function stopLoadingAnimation(app)
           app.IsProcessing = false;
          
           % Stop timer
           if ~isempty(app.LoadingTimer) && isvalid(app.LoadingTimer)
               stop(app.LoadingTimer);
               delete(app.LoadingTimer);
               app.LoadingTimer = [];
           end
          
           % Re-enable UI controls
           app.ConditionDropDown.Enable = 'on';
           app.Freq1DropDown.Enable = 'on';
           app.Freq2DropDown.Enable = 'on';
           app.SelectedElectrodeRole.Enable = 'on';
           app.ShowElectrodesLabelsSwitch.Enable = 'on';
           app.DataLoadLamp.Color = 'green';
           app.ProcessingLabel.Text = "";
       end
       % Convert RGB values to hex color string for HTML
       function hexColor = rgbToHex(app, rgbColor)
           % Convert RGB [0-1] to hex string
           rgbColor = max(0, min(1, rgbColor)); % Clamp to [0,1]
           r = round(rgbColor(1) * 255);
           g = round(rgbColor(2) * 255);
           b = round(rgbColor(3) * 255);
           hexColor = sprintf('#%02X%02X%02X', r, g, b);
       end
      
       % Get colorbar color for a PLV value
       function hexColor = getPLVColor(app, plvValue)
           if isempty(app.PLVMatrix) || isnan(plvValue)
               hexColor = '#696969'; % Grey for invalid values
               return;
           end
          
           % Normalize PLV value to the colorbar range (0 to maxPLV * 1.2)
           normVal = plvValue / app.ColorbarMax; % This will give values 0 to ~0.83 for real PLV scores
           normVal = max(0, min(1, normVal)); % Clamp to [0,1]
          
           % Map to colormap index
           colorIdx = max(1, round(normVal * (size(app.cmap, 1) - 1)) + 1);
           colorIdx = min(colorIdx, size(app.cmap, 1));
          
           % Convert to hex
           hexColor = app.rgbToHex(app.cmap(colorIdx, :));
       end
      
       % Get network color as hex
       function hexColor = getNetworkColor(app, networkName)
           if isKey(app.NetworkColorMap, networkName)
               rgbColor = app.NetworkColorMap(networkName);
               hexColor = app.rgbToHex(rgbColor);
           else
               hexColor = '#808080'; % Gray for unknown networks
           end
       end
       %%%%%%%%%%%%%%%%%%%% Processing %%%%%%%%%%%%%%%%%%%%
       % Setup electrode data structure
       % ↳ Cotaining: Names, Coordinates, Network (+Color), Stronggest Connection
       function createElectrodeInfo(app)
          
           % Initialize electrode info structure
           app.ElectrodeInfo = struct();
          
           % Get selected patient name from uploaded .mat file
           patientName = app.PatientName;
      
           try
               % Access table data
               electrodeData = app.ElectrodesData.elecs_n79;
               if ismember('subject', electrodeData.Properties.VariableNames)
                   subjectData = electrodeData.subject;
                  
                   % Create patient mask
                   if iscell(subjectData)
                       patientMask = strcmp(subjectData, patientName);
                   else
                       patientMask = string(subjectData) == string(patientName);
                   end
               else
                   error('subject column not found in elecs_n79 table');
               end
              
               % Check if any electrodes were found for the subject
               if ~any(patientMask)
                   error('No electrodes found for patient "%s". Check available subjects above.', patientName);
               end
                  
               % Filter out reference channels (contact == 4) early
               if ismember('contact', electrodeData.Properties.VariableNames)
                   contacts = electrodeData.contact(patientMask);
                   if iscell(contacts)
                       nonRefMask = cellfun(@(x) x ~= 4, contacts);
                   else
                       nonRefMask = contacts ~= 4;
                   end
               else
                   % If no contact column, assume all are valid
                   nonRefMask = true(sum(patientMask), 1);
               end
              
               % Combine masks: patient AND non-reference
               combinedMask = false(size(patientMask));
               combinedMask(patientMask) = nonRefMask;
               % Extract coordinates
               x = electrodeData.x_MNI_coord(combinedMask);
               y = electrodeData.y_MNI_coord(combinedMask);
               z = electrodeData.z_MNI_coord(combinedMask);
              
               % Extract electrode names
               if ismember('channel', electrodeData.Properties.VariableNames)
                   channelData = electrodeData.channel(combinedMask);
               elseif ismember('elec_name', electrodeData.Properties.VariableNames)
                   channelData = electrodeData.elec_name(combinedMask);
               else
                   % Generate default names
                   channelData = cell(sum(combinedMask), 1);
                   for i = 1:sum(combinedMask)
                       channelData{i} = sprintf('E%d', i);
                   end
               end
               % Ensure names are in cell array format
               if iscell(channelData)
                   app.ElectrodeInfo.Names = channelData;
               else
                   app.ElectrodeInfo.Names = cellstr(string(channelData));
               end
              
               % Extract networks
               if ismember('Network', electrodeData.Properties.VariableNames)
                   networkData = electrodeData.Network(combinedMask);
               else
                   % Generate default networks
                   networkData = cell(sum(combinedMask), 1);
                   for i = 1:sum(combinedMask)
                       networkData{i} = 'Unknown';
                   end
               end
               % Ensure networks are in cell array format
               if iscell(networkData)
                   app.ElectrodeInfo.Networks = networkData;
               else
                   app.ElectrodeInfo.Networks = cellstr(string(networkData));
               end
      
               % Store coordinates
               app.ElectrodeCoords = [x, y, z];
               app.NumElectrodes = size(app.ElectrodeCoords, 1);
              
               % Initialize electrode strongest connection structure
               app.ElectrodeInfo.StrongestConnections = struct(...
                   'PLVScore', num2cell(zeros(app.NumElectrodes, 1)), ...
                   'PairIdx', num2cell(zeros(app.NumElectrodes, 1)), ...
                   'PairName', cell(app.NumElectrodes, 1), ...
                   'PairNetwork', cell(app.NumElectrodes, 1));
               % Assign colors to electrodes based on their networks
               app.ElectrodeInfo.NetworkColors = zeros(app.NumElectrodes, 3);
               app.createNetworkColorMap();
               for i = 1:app.NumElectrodes
                   networkName = app.ElectrodeInfo.Networks{i};
                   if isKey(app.NetworkColorMap, networkName)
                       app.ElectrodeInfo.NetworkColors(i, :) = app.NetworkColorMap(networkName);
                   else
                       app.ElectrodeInfo.NetworkColors(i, :) = [0.5, 0.5, 0.5]; % Gray for unknown
                   end
               end
              
           catch ME
               fprintf('Error in createElectrodeInfo: %s\n', ME.message);
               rethrow(ME);
           end
       end
       % Prepare the current test condition data
       function updateCurrentConditionData(app)
           if isempty(app.PatientData)
               return;
           end
           currentCondition = app.ConditionDropDown.Value;
           dataField = '';
           % Determine how many samples to trim (from Lab's instructions)
           switch currentCondition
               case 'Rest'
                   dataField = 'all_rest';
                   trimStartSamples = app.SamplingFrequency * 1; % 1 second from start
                   trimEndSamples = app.SamplingFrequency * 1;   % 1 second from end
               case 'Easy Task (CountF)'
                   dataField = 'all_countF';
                   trimStartSamples = app.SamplingFrequency * 1; % 1 second from start
                   trimEndSamples = app.SamplingFrequency * 1;   % 1 second from end
               case 'Hard Task (Alt)'
                   dataField = 'all_alt';
                   trimStartSamples = app.SamplingFrequency * 3; % 3 seconds from start
                   trimEndSamples = app.SamplingFrequency * 1;   % 1 second from end
           end
          
           if isfield(app.PatientData.data_all, dataField)
               trialsData = app.PatientData.data_all.(dataField);
              
               % Combine trials into one 'long' trial
               % Assuming each trial is n_electrodes x time:
               %
               %                  EL1 [ trial           trial ]
               %   combinedData = ... [  1     + ... +    n   ]
               %                  ELn [ data            data  ]
               %
               combinedData = [];
              
               % Check data type
               if iscell(trialsData)
                   % Original cell array approach
                   for i = 1:numel(trialsData)
                       trial = trialsData{i};
                       % Only trim if trial is long enough
                       if size(trial, 2) > (trimStartSamples + trimEndSamples)
                           trial = trial(:, trimStartSamples+1:end-trimEndSamples);
                       end
                       combinedData = [combinedData, trial];
                   end
               elseif isnumeric(trialsData)
                   % Direct numeric array
                   combinedData = trialsData;
               else
                   error('Unexpected data structure type: %s', class(trialsData));
               end
               % Filter data to include only valid electrodes based on ElectrodesData
               % Extract channel information to map raw data indices
               try
                   electrodeData = app.ElectrodesData.elecs_n79;
                  
                   % Create patient mask for current patient
                   if iscell(electrodeData.subject)
                       patientMask = strcmp(electrodeData.subject, app.PatientName);
                   else
                       patientMask = string(electrodeData.subject) == string(app.PatientName);
                   end
                  
                   % Get contact information (position within stripe, 1-4)
                   if ismember('contact', electrodeData.Properties.VariableNames)
                       allContacts = electrodeData.contact(patientMask);
                   else
                       % If no contact info, assume all are valid (not reference)
                       allContacts = ones(sum(patientMask), 1);
                   end
                  
                   % Get channel indices for mapping to raw data
                   if ismember('channel', electrodeData.Properties.VariableNames)
                       allChannels = electrodeData.channel(patientMask);
                   else
                       % Fallback: use sequential indices
                       allChannels = (1:sum(patientMask))';
                   end
                  
                   % Filter out reference channels (contact == 4)
                   validMask = true(size(allContacts));
                   for i = 1:length(allContacts)
                       contact = allContacts(i);
                       if iscell(allContacts)
                           contact = contact{1};
                       end
                       if contact == 4
                           validMask(i) = false;
                       end
                   end
                  
                   % Get valid channel indices for data extraction
                   validChannels = allChannels(validMask);
                   if iscell(validChannels)
                       validChannels = cell2mat(validChannels);
                   end
                  
                   % Extract only valid (non-reference) channels from raw data
                   if ~isempty(validChannels) && max(validChannels) <= size(combinedData, 1)
                       app.CurrentConditionData = combinedData(validChannels, :);
                   else
                       app.CurrentConditionData = combinedData;
                       warning('Could not map electrode channels, using all data');
                   end
               catch ME
                   warning(ME.identifier, 'Error filtering electrode data: %s. Using all channels.', ME.message);
                   app.CurrentConditionData = combinedData;
               end
           else
               app.CurrentConditionData = [];
               uialert(app.UIFigure, ['No data found for ' currentCondition '.'], 'Warning', 'Icon', 'warning');
           end
       end
       % Start processing and update display
       function processAndDisplayData(app)
           % Step 1: Process data (frequency filtering, PLV computation)
           app.processECOGData(app.CurrentConditionData, ...
               app.Freq1DropDown.Value, ...
               app.Freq2DropDown.Value);
      
           % Step 2: Update the graphs
           app.updateBrainModel();
           app.updateCircularGraph();
          
           % Step 3: Update info panel
           app.updateInfoPanel(0); % (0) = Show general patient info
  
       end
       % ECoG Data Processing and PLV Calculation
       function processECOGData(app, ecogData, freqBand1Str, freqBand2Str)
           % Get sampling frequency from app properties
           Fs = app.SamplingFrequency;
          
           numElectrodes = app.NumElectrodes;
           % Initiate plvMatrix
           plvMatrix = zeros(numElectrodes, numElectrodes);
           % Convert string frequency band names to numerical ranges [low_freq, high_freq]
           [band1_low, band1_high] = app.getFrequencyBandLimits(freqBand1Str);
           [band2_low, band2_high] = app.getFrequencyBandLimits(freqBand2Str);
           % If Freq2 is lower than Freq1, automatically swap them
           if band2_low < band1_low
               % Change the labels order in left menu
               temp = app.Freq1DropDown.Value;
               app.Freq1DropDown.Value = app.Freq2DropDown.Value;
               app.Freq2DropDown.Value = temp;
               % Switch values
               temp = band1_low;
               band1_low = band2_low;
               band2_low = temp;
               temp = band1_high;
               band1_high = band2_high;
               band2_high = temp;
               % Notify the user
               uialert(app.UIFigure, 'Frequencies automatically swapped to maintain lower→higher order', 'Info', 'Icon', 'info');
           end
           % Loop through all electrode pairs to compute connectivity strength (PLV)
           for electrode1 = 1:numElectrodes
               for electrode2 = 1:numElectrodes
                   if electrode1 ~= electrode2
                       % Extract signals for current electrode pair
                       phase_signal = ecogData(electrode1, :); % Electrode 1 Phase frequency
                       amp_signal = ecogData(electrode2, :);   % Electrode 2 Amplitude envelope
                       % 1. Phase frequency - Filter signal for freqBand1 (LOWER frequency band)
                       try
                           % Apply bandpass filter
                           filtered_signal_band1_phase = bandpass(phase_signal, [band1_low band1_high], Fs);
                       catch ME
                           try
                               warning('ECOGAnalysisApp:FilterErrorBand1', 'Error filtering signal for band 1 (%s): %s. Using butter() and filtfilt().', freqBand1Str, ME.message);
                               [b, a] = butter(4, [band1_low band1_high]/(Fs/2), 'bandpass'); % Order 4: -24 dB per octave
                               filtered_signal_band1_phase = filtfilt(b, a, phase_signal);
                           catch ME
                               warning('ECOGAnalysisApp:FilterErrorBand1', 'Error filtering signal for band 1 (%s): %s.', freqBand1Str, ME.message);
                               uialert(app.UIFigure, 'Signal Processing Toolbox is missing. Please install and re-run the program.', 'Warning', 'Icon', 'warning');
                               return;
                           end
                       end
                       % 2. Amplitude envelope - Filter signal for freqBand2 (HIGHER frequency band)
                       try
                           filtered_signal_band2_amp = bandpass(amp_signal, [band2_low band2_high], Fs);
                       catch ME
                           try
                               warning('ECOGAnalysisApp:FilterErrorBand2', 'Error filtering signal for band 2 (%s): %s. Using butter() and filtfilt().', freqBand2Str, ME.message);
                               [b, a] = butter(4, [band2_low band2_high]/(Fs/2), 'bandpass');
                               filtered_signal_band2_amp = filtfilt(b, a, amp_signal);
                           catch ME
                               warning('ECOGAnalysisApp:FilterErrorBand2', 'Error filtering signal for band 2 (%s): %s.', freqBand2Str, ME.message);
                               uialert(app.UIFigure, 'Signal Processing Toolbox is missing. Please install and re-run the program.', 'Warning', 'Icon', 'warning');
                               return;
                           end
                       end
                       % Ensure signals are not empty after filtering
                       if isempty(filtered_signal_band1_phase) || isempty(filtered_signal_band2_amp)
                           plvMatrix(electrode1, electrode2) = NaN;
                           continue;
                       end
                       % Compute Phase of the signal from freqBand1
                       % Phase of low frequency signal
                       try
                           hilbert_signal_band1 = hilbert(filtered_signal_band1_phase);
                       catch
                           % Manual hilbert function if 'Signal Processing Toolbox' is not installed
                           hilbert_signal_band1 = hilbert_alt(app, filtered_signal_band1_phase);
                       end
                       low_phase = angle(hilbert_signal_band1);
                       % Compute Amplitude Envelope of the signal from freqBand2
                       % Amplitude of high frequency signal
                       try
                           hilbert_signal_band2_complex = hilbert(filtered_signal_band2_amp);
                       catch
                           hilbert_signal_band2_complex = hilbert_alt(app, filtered_signal_band2_amp);
                       end
                       high_amp = abs(hilbert_signal_band2_complex); % Amplitude envelope
                       % Compute Phase of the high frequency Amplitude Envelope
                       % This involves applying the Hilbert transform to the amplitude envelope itself.
                       try
                           hilbert_high_amp_envelope = hilbert(high_amp);
                       catch
                           hilbert_high_amp_envelope = hilbert_alt(app, high_amp);
                       end
                       high_phase_from_amp_envelope = angle(hilbert_high_amp_envelope);
                       % Phase Difference: between phase of band1 and phase of band2's amplitude envelope
                       phaseDiff = high_phase_from_amp_envelope - low_phase;
                       % Calculate the PLV (Phase Locking Value)
                       PLV_result = abs(mean(exp(1i * phaseDiff), 'omitnan')); % Use 'omitnan' to ignore NaNs if any
                      
                       % Save result in matrix
                       plvMatrix(electrode1, electrode2) = PLV_result;
                   else
                       plvMatrix(electrode1, electrode2) = NaN; % PLV with self is undefined or 0
                   end
               end
           end
          
           % Store PLV Matrix in global variable
           app.PLVMatrix = plvMatrix;
          
           % The PLV Matrix structure:
           %
           %   p = Phase frequency (LOWER frequency band)
           %   a = Amplitude envelope (HIGHER frequency band)
           %
           %       E1      E2      E3      E4
           %   E1  x       1p-2a   1p-3a   1p-4a
           %   E2  2p-1a   x       2p-3a   2p-4a
           %   E3  3p-1a   3p-2a   x       3p-4a
           %   E4  4p-1a   4p-2a   4p-3a   x
           %
          
           % Get maximum PLV for consistent scaling
           maxPLV = max(app.PLVMatrix(:), [], 'omitnan');
           if ~isnan(maxPLV) && maxPLV > 0
               app.ColorbarMax = maxPLV * 1.2;
           else
               app.ColorbarMax = 1; % Default value
           end
           % Calculate strongest connections for each electrode (done after PLV calculation)
           app.calculateStrongestConnections();
          
       end
       % Manual hilbert function if 'Signal Processing Toolbox' is not installed
       function y = hilbert_alt(app, x)
           N = length(x);
           X = fft(x);
           h = zeros(1, N);
           if mod(N,2) == 0
               h([1 N/2+1]) = 1;
               h(2:N/2) = 2;
           else
               h(1) = 1;
               h(2:(N+1)/2) = 2;
           end
           y = ifft(X .* h);
       end
       % Convert frequency band limits from string to numeric
       function [low_freq, high_freq] = getFrequencyBandLimits(app, bandName)
           switch bandName            
               case 'Delta (0.5-4 Hz)'
                   low_freq = 0.5;
                   high_freq = 4;
               case 'Theta (4-8 Hz)'
                   low_freq = 4;
                   high_freq = 8;
               case 'Alpha (8-12 Hz)'
                   low_freq = 8;
                   high_freq = 12;
               case 'Beta (12-30 Hz)'
                   low_freq = 12;
                   high_freq = 30;
               case 'Gamma (30-70 Hz)'
                   low_freq = 30;
                   high_freq = 70;
               case 'High Gamma (70-250 Hz)'
                   low_freq = 70;
                   high_freq = 250;
           end
       end
       % Calculate strongest connections for each electrode
       function calculateStrongestConnections(app)
           if isempty(app.PLVMatrix)
               return;
           end
          
           % Find strongest connection for each electrode
           for i = 1:app.NumElectrodes
               % Get PLV scores for current electrode (exclude self-connection)
               plvScores = app.PLVMatrix(i, :);
               plvScores(i) = NaN; % Exclude self
              
               % Find maximum PLV
               [maxPLV, maxIdx] = max(plvScores, [], 'omitnan');
              
               % Store result
               if ~isnan(maxPLV)
                   app.ElectrodeInfo.StrongestConnections(i).PLVScore = maxPLV;
                   app.ElectrodeInfo.StrongestConnections(i).PairIdx = maxIdx;
                   app.ElectrodeInfo.StrongestConnections(i).PairName = app.ElectrodeInfo.Names{maxIdx};
                   app.ElectrodeInfo.StrongestConnections(i).PairNetwork = app.ElectrodeInfo.Networks{maxIdx};
               end
           end
       end
       %%%%%%%%%%%%%%%%%%%% Info Panel %%%%%%%%%%%%%%%%%%%%
       % Create information panel
       function createInfoPanel(app)
           % Create a container panel for row 2
           infoPanelContainer = uipanel(app.GridLayout4,"BackgroundColor",[0.25 0.25 0.25]);
           infoPanelContainer.Layout.Row = 2;
           infoPanelContainer.Layout.Column = 1;
           infoPanelContainer.BorderType = 'none';
          
           % Create grid inside the container with padding column
           infoSubGrid = uigridlayout(infoPanelContainer);
           infoSubGrid.BackgroundColor = [0.25 0.25 0.25];
           infoSubGrid.ColumnWidth = {15, '1x'}; % 20px left padding + content
           infoSubGrid.RowHeight = {'1x'};
           infoSubGrid.Padding = [0 0 0 0]; % No extra padding from grid
  
           % Create a uilabel for text display
           app.InfoPanel = uilabel(infoSubGrid, ...
               'Text', '', ...
               'FontSize', 16, ...
               'FontColor', 'white', ...
               'BackgroundColor', 'none', ...  % No background
               'HorizontalAlignment', 'left', ...
               'VerticalAlignment', 'top', ...
               'WordWrap', 'on', ...
               'Interpreter', 'html', ...      % Enable HTML interpretation
               'Visible', 'off');
          
           % Position it in the info panel's sub grid
           app.InfoPanel.Layout.Row = 1;
           app.InfoPanel.Layout.Column = 2; % Use content column
           % Initialize visibility flag
           app.InfoPanelVisible = false;
       end
       % Update information panel
       function updateInfoPanel(app, selectedElectrodeIdx)
           if isempty(app.ElectrodeInfo)
               return;
           end
          
           % Generate info text content
           if app.ElectrodeRole == 0
                   elec1Freq = "phase";
                   elec2Freq = "amp";
               else
                   elec1Freq = "amp";
                   elec2Freq = "phase";
           end
           if nargin < 2 || selectedElectrodeIdx == 0
               % Show general patient information
               [globalMaxPLV, globalMaxIdx] = max(app.PLVMatrix(:), [], 'omitnan');
               [row, col] = ind2sub(size(app.PLVMatrix), globalMaxIdx);
              
               if ~isnan(globalMaxPLV)
                   elec1Name = app.ElectrodeInfo.Names{row};
                   elec2Name = app.ElectrodeInfo.Names{col};
                   elec1Network = app.ElectrodeInfo.Networks{row};
                   elec2Network = app.ElectrodeInfo.Networks{col};
                  
                   % Get dynamic colors
                   plvColor = app.getPLVColor(globalMaxPLV);
                   network1Color = app.getNetworkColor(elec1Network);
                   network2Color = app.getNetworkColor(elec2Network);
                  
                   infoText = sprintf(['<font color="white"><b>PATIENT INFO</b></font><br>' ...
                                      '<font color="white">───────────────────</font><br>' ...
                                      '<font color="white">Patient: </font><font color="cyan">%s</font><br>' ...
                                      '<font color="white">Electrodes: </font><font color="cyan">%d</font><br><br>' ...
                                      '<font color="white"><b>STRONGEST CONNECTION</b></font><br>' ...
                                      '<font color="white">───────────────────</font><br>' ...
                                      '<font color="white">PLV: </font><font color="%s">%.4f</font><br>' ...
                                      '<font color="white">%s (%s) ↔ %s (%s)</font><br>' ...
                                      '<font color="%s">%s</font><font color="white"> ↔ </font><font color="%s">%s</font>'], ...
                                      app.PatientName, app.NumElectrodes, ...
                                      plvColor, globalMaxPLV, elec1Name, elec1Freq, elec2Name, elec2Freq, ...
                                      network1Color, elec1Network, network2Color, elec2Network);
               else
                   infoText = sprintf(['<font color="white"><b>PATIENT INFO</b></font><br>' ...
                                      '<font color="white">───────────────────</font><br>' ...
                                      '<font color="white">Patient: </font><font color="cyan">%s</font><br>' ...
                                      '<font color="white">Electrodes: </font><font color="cyan">%d</font><br><br>' ...
                                      '<font color="red">No PLV data available</font>'], ...
                                      app.PatientName, app.NumElectrodes);
               end
           else
               % Show selected electrode information
               coords = app.ElectrodeCoords(selectedElectrodeIdx, :);
              
               % Dynamically find strongest connection based on current role
               if app.ElectrodeRole == 0
                   plvScores = app.PLVMatrix(selectedElectrodeIdx, :); % Row
               else
                   plvScores = app.PLVMatrix(:, selectedElectrodeIdx)'; % Column (transposed to row)
               end
               plvScores(selectedElectrodeIdx) = NaN; % Exclude self
              
               % Find maximum PLV for this electrode with current role
               [maxPLV, maxIdx] = max(plvScores, [], 'omitnan');
              
               % Get target electrode info
               if ~isnan(maxPLV)
                   targetName = app.ElectrodeInfo.Names{maxIdx};
                   targetNetwork = app.ElectrodeInfo.Networks{maxIdx};
               else
                   targetName = 'None';
                   targetNetwork = 'None';
                   maxPLV = 0;
               end
              
               % Get dynamic colors
               selectedNetwork = app.ElectrodeInfo.Networks{selectedElectrodeIdx};
               plvColor = app.getPLVColor(maxPLV);
               selectedNetworkColor = app.getNetworkColor(selectedNetwork);
               targetNetworkColor = app.getNetworkColor(targetNetwork);
              
               infoText = sprintf(['<font color="white"><b>SELECTED ELECTRODE</b></font><br>' ...
                                  '<font color="white">───────────────────</font><br>' ...
                                  '<font color="white">Name: </font><font color="yellow">%s</font><br>' ...
                                  '<font color="white">Network: </font><font color="%s">%s</font><br>' ...
                                  '<font color="white">Coords:</font><br>' ...
                                  '<font color="white">  X: </font><font color="white">%.1f</font><br>' ...
                                  '<font color="white">  Y: </font><font color="white">%.1f</font><br>' ...
                                  '<font color="white">  Z: </font><font color="white">%.1f</font><br><br>' ...
                                  '<font color="white"><b>STRONGEST CONNECTION</b></font><br>' ...
                                  '<font color="white">───────────────────</font><br>' ...
                                  '<font color="white">PLV: </font><font color="%s">%.4f</font><br>' ...
                                  '<font color="white">To: </font><font color="white">%s (%s)</font><br>' ...
                                  '<font color="white">Network: </font><font color="%s">%s</font>'], ...
                                  app.ElectrodeInfo.Names{selectedElectrodeIdx}, ...
                                  selectedNetworkColor, selectedNetwork, ...
                                  coords(1), coords(2), coords(3), ...
                                  plvColor, maxPLV, targetName, elec2Freq, ...
                                  targetNetworkColor, targetNetwork);
           end
          
           % Update text content directly on the label
           if ~isempty(app.InfoPanel) && isvalid(app.InfoPanel)
               app.InfoPanel.Text = infoText;
           end
       end
       % Method to show/hide the floating info panel
       function setInfoPanelVisible(app, visible)
           app.InfoPanelVisible = visible;
          
           if ~isempty(app.InfoPanel) && isvalid(app.InfoPanel)
               if visible
                   app.InfoPanel.Visible = 'on';
               else
                   app.InfoPanel.Visible = 'off';
               end
           end
       end
       %%%%%%%%%%%%%%%%%%%% Main Graphs %%%%%%%%%%%%%%%%%%%%
       % Update 3D Brain Model visualization
       function updateBrainModel(app)
          
           % Complete reset
           cla(app.BrainAxes, 'reset');
           % Set background to black to prevent white axes flash
           app.BrainAxes.Color = [0 0 0]; % Black background
           rotate3d(app.BrainAxes,'on'); % Enable free mouse rotating
           %app.BrainAxes.Toolbar.Visible = 'off';  % Hide toolbar
  
           hold(app.BrainAxes, 'on');
      
           % Load and plot brain model
           try
               % Try multiple possible locations for the brain model
               meshFile = [];
              
               % Option 1: Try relative to the app file
               try
                   meshFile = fullfile(fileparts(mfilename('fullpath')), 'head3d.mat');
               catch
               end
              
               % Option 2: Try in the resources folder for packaged apps
               if isempty(meshFile) || ~exist(meshFile, 'file')
                   try
                       meshFile = fullfile(ctfroot, 'head3d.mat');
                   catch
                   end
               end
              
               % Option 3: Try to find it anywhere on the path
               if isempty(meshFile) || ~exist(meshFile, 'file')
                   meshFile = which('head3d.mat');
               end
               % Load the brain model if found
               if ~isempty(meshFile) && exist(meshFile, 'file')
                   data3d = load('-mat', meshFile);
                   cortexMesh = data3d.head3d.cortex.mesh;
                  
                   % Save brain handle
                   app.BrainModelHandle = patch(app.BrainAxes, ...
                       'Vertices', cortexMesh.vertices, ...
                       'Faces', cortexMesh.faces, ...
                       'FaceColor', [0.9 0.9 0.9], ...
                       'EdgeColor', 'none', ...
                       'FaceLighting', 'gouraud', ...
                       'AmbientStrength', 0.3, ...
                       'FaceAlpha', 0.1);
               else
                   % Plot a 3D sphere if the brain model is unavailable
                   [x,y,z] = sphere(20);
                   app.BrainModelHandle = surf(app.BrainAxes, 50*x, 50*y, 50*z, ...
                       'FaceColor', [0.9 0.9 0.9], 'EdgeColor', 'none', ...
                       'FaceLighting', 'gouraud', 'AmbientStrength', 0.3, 'FaceAlpha', 0.1);
               end
           catch
               [x,y,z] = sphere(20);
               app.BrainModelHandle = surf(app.BrainAxes, 50*x, 50*y, 50*z, ...
                   'FaceColor', [0.9 0.9 0.9], 'EdgeColor', 'none', ...
                   'FaceLighting', 'gouraud', 'AmbientStrength', 0.3, 'FaceAlpha', 0.1);
           end
          
           % Axes settings
           axis(app.BrainAxes, 'equal');
           axis(app.BrainAxes, 'off');
           view(app.BrainAxes, 3);
           camlight(app.BrainAxes, 'right');
          
           % Only add electrodes if data is loaded
           if app.NumElectrodes > 0 && ~isempty(app.ElectrodeCoords)
              
               % Use network-based coloring
               if ~isempty(app.ElectrodeInfo)
                   app.ElectrodeColors = app.ElectrodeInfo.NetworkColors;
               else % Blue
                   app.ElectrodeColors = repmat([0 0 1], app.NumElectrodes, 1);
               end
              
               % Plot connectivity lines
               if ~isempty(app.PLVMatrix)
                   if app.SelectedElectrodeIdx == 0
                       % No electrode selected: draw background lines + highlight strongest
                       app.drawBackgroundLines3D();
                       app.drawStrongestConnection3D();
                   else
                       % Electrode selected: draw background lines + selected electrode lines
                       app.drawBackgroundLines3D();
                       app.drawSelectedElectrodeLines3D();
                   end
               end
              
               % Plot electrodes with click functionality
               app.BrainElectrodeHandles = gobjects(app.NumElectrodes,1);
               app.BrainElectrodeLabels = gobjects(app.NumElectrodes,1);
              
               % Electrodes and Labels
               for i = 1:app.NumElectrodes
                   if i == app.SelectedElectrodeIdx
                       markerSize = 300;
                       edgeColor = 'yellow'; % Highlight selected
                       lineWidth = 3;
                   else
                       markerSize = 200;
                       edgeColor = 'black';
                       lineWidth = 1;
                   end
                  
                   % Create electrodes
                   app.BrainElectrodeHandles(i) = scatter3(app.BrainAxes, ...
                       app.ElectrodeCoords(i,1), app.ElectrodeCoords(i,2), app.ElectrodeCoords(i,3), ...
                       markerSize, app.ElectrodeColors(i,:), 'filled', ...
                       'MarkerEdgeColor', edgeColor, 'LineWidth', lineWidth, ...
                       'DisplayName', ['Electrode ' num2str(i)], ...
                       'ButtonDownFcn', @(src, event) app.onElectrodeClicked(src, event), ...
                       'PickableParts', 'all', ... % Ensure clickable
                       'HitTest', 'on', 'UserData', i);
                  
                   % Create electrode labels
                   app.BrainElectrodeLabels(i) = text(app.BrainAxes, ...
                       app.ElectrodeCoords(i,1)*1.15, app.ElectrodeCoords(i,2)*1.15, app.ElectrodeCoords(i,3)*1.15, ...
                       app.ElectrodeInfo.Names{i}, 'FontSize', 14, 'FontWeight', 'normal', ...
                       'Color', 'white', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', ...
                       'Visible', app.ShowElectrodesLabelsSwitch.Value);
               end
           end
          
           hold(app.BrainAxes, 'off');
          
           % Refresh info panel overlay if it should be visible
           if app.InfoPanelVisible & ~isempty(app.ElectrodeInfo)
               app.updateInfoPanel(app.SelectedElectrodeIdx);
           end
              
       end
       % Update 2D Circular Network visualization
       function updateCircularGraph(app)
          
           % Complete reset to remove axes
           cla(app.CircleAxes, 'reset');
           hold(app.CircleAxes, 'on');
           % Only proceed if we have electrode data
           if app.NumElectrodes == 0 || isempty(app.ElectrodeCoords)
               return;
           end
      
           % Places electrodes evenly around a circle
           angles = linspace(0, 2*pi, app.NumElectrodes + 1);
           angles(end) = [];
      
           % Compute coordinates
           radius = 0.7;
           x = radius * cos(angles);
           y = radius * sin(angles);
           app.CircleElectrodeCoords = [x(:), y(:)];
           % Plot connectivity lines FIRST (so they appear behind the electrodes)
           if ~isempty(app.PLVMatrix)
               app.plotConnectivityLines2D();
           end
          
           % Plot electrodes
           if ~isempty(app.ElectrodeInfo)
               % Use network colors
               electrodeColors = app.ElectrodeInfo.NetworkColors;
              
               app.CircleElectrodeHandles = gobjects(app.NumElectrodes, 1);
               app.CircleElectrodeLabels = gobjects(app.NumElectrodes, 1);
              
               for i = 1:app.NumElectrodes
                   % Determine marker size based on selection
                   if i == app.SelectedElectrodeIdx
                       markerSize = 18;
                       edgeColor = 'yellow';
                       lineWidth = 3;
                       labelColor = 'yellow';
                   else
                       markerSize = 14;
                       edgeColor = 'black';
                       lineWidth = 1;
                       labelColor = 'white';
                   end
                  
                   % Create electrodes
                   app.CircleElectrodeHandles(i) = plot(app.CircleAxes, ...
                       app.CircleElectrodeCoords(i,1), app.CircleElectrodeCoords(i,2), 'o', ...
                       'MarkerSize', markerSize, 'MarkerFaceColor', electrodeColors(i,:), ...
                       'MarkerEdgeColor', edgeColor, 'LineWidth', lineWidth, ...
                       'ButtonDownFcn', @(src, event) app.onElectrodeClicked(src, event), ...
                       'PickableParts', 'visible', ...
                       'HitTest', 'on', 'UserData', i);
                  
                   % Create electrode labels
                   app.CircleElectrodeLabels(i) = text(app.CircleAxes, ...
                           app.CircleElectrodeCoords(i,1)*1.2, app.CircleElectrodeCoords(i,2)*1.2, ...
                           app.ElectrodeInfo.Names{i}, 'FontSize', 14, 'FontWeight', 'normal', ...
                           'Color', labelColor, 'HorizontalAlignment', 'center', ...
                           'Visible', app.ShowElectrodesLabelsSwitch.Value);
               end
           end
      
           % Completely hide axes
           axis(app.CircleAxes, 'equal');
           axis(app.CircleAxes, 'off');
           xlim(app.CircleAxes, [-1.2, 1.2]); % Add padding around the circle
           ylim(app.CircleAxes, [-1.2, 1.2]);
           hold(app.CircleAxes, 'off');
           % Plot colorbar
           colormap(app.CircleAxes, app.cmap);
           c = colorbar(app.CircleAxes, 'southoutside', 'Color', 'white');
           c.Label.String = 'PLV Score';
           c.Label.Color = 'white';
           % Set colorbar range
           try
               clim(app.CircleAxes, [0, app.ColorbarMax]); % MATLAB 2024b
           catch
               caxis(app.CircleAxes, [0, app.ColorbarMax]); % MATLAB 2022b
           end
          
           % Refresh info panel overlay if it should be visible
           if app.InfoPanelVisible && ~isempty(app.ElectrodeInfo)
               app.updateInfoPanel(app.SelectedElectrodeIdx);
           end
  
       end
       %%%%%%%%%%%%%%%%%%%% Electrodes & Lines %%%%%%%%%%%%%%%%%%%%
       % Draw all connections in grey for 3D
       % (called once when no electrode is selected)
       function drawBackgroundLines3D(app)
           % Clear any existing background lines
           if ~isempty(app.BrainBackgroundLines)
               for i = 1:length(app.BrainBackgroundLines)
                   if isvalid(app.BrainBackgroundLines(i))
                       delete(app.BrainBackgroundLines(i));
                   end
               end
           end
          
           if isempty(app.PLVMatrix)
               app.BrainBackgroundLines = gobjects(0);
               return;
           end
          
           % Ensure we're working with the correct axes
           hold(app.BrainAxes, 'on');
          
           % Initialize parameters
           connMatrix = app.PLVMatrix;
           numElectrodes = app.NumElectrodes;
           lineHandles = gobjects(numElectrodes^2, 1);
           idx = 1;
          
           % Draw all connections in grey with arched lines
           for i = 1:numElectrodes
               for j = i+1:numElectrodes
                   val = connMatrix(i,j);
                  
                   if ~isnan(val) && val > 0
                       % Create 3D arched path
                       point1 = app.ElectrodeCoords(i,:);
                       point2 = app.ElectrodeCoords(j,:);
                      
                       % Use different arch heights based on distance for variety
                       distance = norm(point2 - point1);
                       archHeight = 0.2 + 0.1 * (distance / 100); % Scale arch with distance
                      
                       [xArch, yArch, zArch] = app.create3DArch(point1, point2, 30, archHeight);
                      
                       lineHandles(idx) = plot3(app.BrainAxes, xArch, yArch, zArch, ...
                           'Color', [0.5, 0.5, 0.5], 'LineWidth', 0.2, 'LineSmoothing', 'on');
                       idx = idx + 1;
                   end
               end
           end
          
           % Store handles
           app.BrainBackgroundLines = lineHandles(1:idx-1);
       end
      
       % Draw strongest connection highlight for 3D
       function drawStrongestConnection3D(app)
           % Clear previous strongest line
           if ~isempty(app.BrainStrongestLine) && isvalid(app.BrainStrongestLine)
               delete(app.BrainStrongestLine);
           end
          
           if isempty(app.PLVMatrix)
               app.BrainStrongestLine = gobjects(0);
               return;
           end
          
           % Ensure we're working with the correct axes
           hold(app.BrainAxes, 'on');
          
           % Find global strongest connection
           [globalMaxPLV, globalMaxIdx] = max(app.PLVMatrix(:), [], 'omitnan');
           [strongestRow, strongestCol] = ind2sub(size(app.PLVMatrix), globalMaxIdx);
          
           if ~isnan(globalMaxPLV)
               minWidth = 0.2;
               maxWidth = 3;
              
               % Dynamic color and width for strongest connection
               normVal = globalMaxPLV / app.ColorbarMax;
               normVal = max(0, min(1, normVal));
               colorIdx = max(1, round(normVal * (size(app.cmap, 1) - 1)) + 1);
               colorIdx = min(colorIdx, size(app.cmap, 1));
               colorLine = app.cmap(colorIdx, :);
               maxPLV = max(app.PLVMatrix(:), [], 'omitnan');
               lineWidthNorm = globalMaxPLV / maxPLV;
               lineWidth = minWidth + lineWidthNorm * (maxWidth - minWidth);
              
               % Create 3D arched path for strongest connection
               point1 = app.ElectrodeCoords(strongestRow,:);
               point2 = app.ElectrodeCoords(strongestCol,:);
              
               % Make strongest connection more prominent with higher arch
               [xArch, yArch, zArch] = app.create3DArch(point1, point2, 50, 0.5);
              
               app.BrainStrongestLine = plot3(app.BrainAxes, xArch, yArch, zArch, ...
                   'Color', colorLine, 'LineWidth', lineWidth, 'LineSmoothing', 'on');
           end
       end
      
       % Draw only selected electrode connections for 3D
       function drawSelectedElectrodeLines3D(app)
           % Clear previous selected lines
           if ~isempty(app.BrainSelectedLines)
               for i = 1:length(app.BrainSelectedLines)
                   if isvalid(app.BrainSelectedLines(i))
                       delete(app.BrainSelectedLines(i));
                   end
               end
           end
          
           if isempty(app.PLVMatrix) || app.SelectedElectrodeIdx == 0
               app.BrainSelectedLines = gobjects(0);
               return;
           end
          
           % Ensure we're working with the correct axes
           hold(app.BrainAxes, 'on');
          
           % Initialize parameters
           connMatrix = app.PLVMatrix;
           numElectrodes = app.NumElectrodes;
           selectedElec = app.SelectedElectrodeIdx;
           minWidth = 0.2;
           maxWidth = 3;
          
           lineHandles = gobjects(numElectrodes, 1);
           idx = 1;
          
           % Draw selected electrode connections with arched lines
           for j = 1:numElectrodes
               if j ~= selectedElec
                   % Get PLV value based on selected electrode role
                   if app.ElectrodeRole == 0
                       val = connMatrix(selectedElec, j);
                   else
                       val = connMatrix(j, selectedElec);
                   end
                  
                   if ~isnan(val) && val > 0
                       % Dynamic color and width
                       normVal = val / app.ColorbarMax;
                       normVal = max(0, min(1, normVal));
                       colorIdx = max(1, round(normVal * (size(app.cmap, 1) - 1)) + 1);
                       colorIdx = min(colorIdx, size(app.cmap, 1));
                       colorLine = app.cmap(colorIdx, :);
                       maxPLV = max(connMatrix(:), [], 'omitnan');
                       lineWidthNorm = val / maxPLV;
                       lineWidth = minWidth + lineWidthNorm * (maxWidth - minWidth);
                      
                       % Create 3D arched path
                       point1 = app.ElectrodeCoords(selectedElec,:);
                       point2 = app.ElectrodeCoords(j,:);
                      
                       % Vary arch height based on PLV strength for visual hierarchy
                       archHeight = 0.2 + 0.3 * lineWidthNorm; % Higher PLV = higher arch
                      
                       [xArch, yArch, zArch] = app.create3DArch(point1, point2, 40, archHeight);
                      
                       lineHandles(idx) = plot3(app.BrainAxes, xArch, yArch, zArch, ...
                           'Color', colorLine, 'LineWidth', lineWidth, 'LineSmoothing', 'on');
                       idx = idx + 1;
                   end
               end
           end
          
           % Store handles
           app.BrainSelectedLines = lineHandles(1:idx-1);
       end
       % Separate function for 2D connectivity lines
       function plotConnectivityLines2D(app)
           % Clear previous connectivity lines
           if ~isempty(app.CircleLinesHandles)
               for i = 1:length(app.CircleLinesHandles)
                   if isvalid(app.CircleLinesHandles(i))
                       delete(app.CircleLinesHandles(i));
                   end
               end
           end
          
           if isempty(app.PLVMatrix)
               app.CircleLinesHandles = gobjects(0);
               return;
           end
  
           connMatrix = app.PLVMatrix;
           numElectrodes = app.NumElectrodes;
          
           % Get maximum PLV for scaling
           maxPLV = max(connMatrix(:), [], 'omitnan');
           if isnan(maxPLV) || maxPLV == 0
               app.CircleLinesHandles = gobjects(0);
               return;
           end
          
           minWidth = 0.2;
           maxWidth = 4;
          
           lineHandles = gobjects(numElectrodes^2, 1);
           idx = 1;
          
           if app.SelectedElectrodeIdx == 0
               % NO ELECTRODE SELECTED: Show all connections in grey + global strongest connection highlighted
              
               % Find global strongest connection (ALWAYS from original matrix, ignore selected electrode role)
               [globalMaxPLV, globalMaxIdx] = max(app.PLVMatrix(:), [], 'omitnan');
               [strongestRow, strongestCol] = ind2sub(size(app.PLVMatrix), globalMaxIdx);
              
               % Plot all connections
               for i = 1:numElectrodes
                   for j = i+1:numElectrodes
                       % For display purposes, choose connection value based on selected electrode role
                       if app.ElectrodeRole == 0
                           val = connMatrix(i,j);
                       else
                           val = connMatrix(j,i);
                       end
                      
                       if ~isnan(val) && val > 0
                           % Check if this is the strongest connection (based on original matrix position)
                           isStrongest = (i == strongestRow && j == strongestCol) || ...
                                        (i == strongestCol && j == strongestRow);
                          
                           if isStrongest
                               % Highlight strongest connection with its ORIGINAL PLV value and dynamic color
                               originalPLV = app.PLVMatrix(strongestRow, strongestCol);
                               normVal = originalPLV / app.ColorbarMax;
                               normVal = max(0, min(1, normVal));
                               colorIdx = max(1, round(normVal * (size(app.cmap, 1) - 1)) + 1);
                               colorIdx = min(colorIdx, size(app.cmap, 1));
                               colorLine = app.cmap(colorIdx, :);
                               lineWidthNorm = originalPLV / maxPLV;
                               lineWidth = minWidth + lineWidthNorm * (maxWidth - minWidth);
                           else
                               % All other connections in grey with min width
                               colorLine = [0.5, 0.5, 0.5]; % Grey
                               lineWidth = minWidth;
                           end
                          
                           % Get 2D coordinates and plot
                           x = [app.CircleElectrodeCoords(i,1), app.CircleElectrodeCoords(j,1)];
                           y = [app.CircleElectrodeCoords(i,2), app.CircleElectrodeCoords(j,2)];
                          
                           lineHandles(idx) = plot(app.CircleAxes, x, y, ...
                               'Color', colorLine, 'LineWidth', lineWidth, 'LineStyle', '-');
                           idx = idx + 1;
                       end
                   end
               end
              
           else
               % ELECTRODE SELECTED: Show selected electrode connections + background connections
               selectedElec = app.SelectedElectrodeIdx;
              
               % First, plot all background connections between unselected electrodes in grey
               for i = 1:numElectrodes
                   for j = i+1:numElectrodes
                       % Skip connections involving the selected electrode
                       if i ~= selectedElec && j ~= selectedElec
                           % Use original matrix values for background connections (ignore selected electrode role)
                           val = connMatrix(i,j);
                          
                           if ~isnan(val) && val > 0
                               % Grey background connections with minimum width
                               colorLine = [0.5, 0.5, 0.5];
                               lineWidth = minWidth;
                              
                               % Get 2D coordinates and plot
                               x = [app.CircleElectrodeCoords(i,1), app.CircleElectrodeCoords(j,1)];
                               y = [app.CircleElectrodeCoords(i,2), app.CircleElectrodeCoords(j,2)];
                              
                               lineHandles(idx) = plot(app.CircleAxes, x, y, ...
                                   'Color', colorLine, 'LineWidth', lineWidth, 'LineStyle', '-');
                               idx = idx + 1;
                           end
                       end
                   end
               end
              
               % Then, plot selected electrode connections with dynamic colors/widths
               for j = 1:numElectrodes
                   if j ~= selectedElec
                       % Get PLV value based on selected electrode role
                       if app.ElectrodeRole == 0
                           val = connMatrix(selectedElec, j); % Row selectedElec
                       else
                           val = connMatrix(j, selectedElec); % Column selectedElec
                       end
                      
                       if ~isnan(val) && val > 0
                           % Dynamic color and width based on PLV value
                           normVal = val / app.ColorbarMax;
                           normVal = max(0, min(1, normVal));
                           colorIdx = max(1, round(normVal * (size(app.cmap, 1) - 1)) + 1);
                           colorIdx = min(colorIdx, size(app.cmap, 1));
                           colorLine = app.cmap(colorIdx, :);
                          
                           lineWidthNorm = val / maxPLV;
                           lineWidth = minWidth + lineWidthNorm * (maxWidth - minWidth);
                          
                           % Get 2D coordinates and plot
                           x = [app.CircleElectrodeCoords(selectedElec,1), app.CircleElectrodeCoords(j,1)];
                           y = [app.CircleElectrodeCoords(selectedElec,2), app.CircleElectrodeCoords(j,2)];
                          
                           lineHandles(idx) = plot(app.CircleAxes, x, y, ...
                               'Color', colorLine, 'LineWidth', lineWidth, 'LineStyle', '-');
                           idx = idx + 1;
                       end
                   end
               end
           end
          
           app.CircleLinesHandles = lineHandles(1:idx-1);
       end
       % Create 3D arched path between two points
       function [xArch, yArch, zArch] = create3DArch(app, point1, point2, numPoints, archHeight)
           % Create a smooth 3D arch between two electrode points
           %
           % Inputs:
           %   point1, point2: [x, y, z] coordinates of start and end points
           %   numPoints: number of points along the arch (default: 50)
           %   archHeight: relative height of the arch (default: 0.3)
          
           if nargin < 4
               numPoints = 50;
           end
           if nargin < 5
               archHeight = 0.3; % 30% of distance between points
           end
          
           % Calculate the midpoint and distance
           midpoint = (point1 + point2) / 2;
           distance = norm(point2 - point1);
          
           % Create arch in local coordinate system
           t = linspace(0, 1, numPoints);
          
           % Find a vector perpendicular to the line (pointing outward from brain center)
           brainCenter = [0, 0, 0]; % Assuming brain is centered at origin
           toCenter = midpoint - brainCenter;
           if norm(toCenter) > 0
               outwardDir = toCenter / norm(toCenter);
           else
               % Fallback: use z-direction
               outwardDir = [0, 0, 1];
           end
          
           % Create arch points
           xArch = zeros(1, numPoints);
           yArch = zeros(1, numPoints);
           zArch = zeros(1, numPoints);
          
           for i = 1:numPoints
               % Linear interpolation along the direct path
               basePoint = point1 + t(i) * (point2 - point1);
              
               % Add parabolic offset in outward direction
               archOffset = 4 * t(i) * (1 - t(i)) * archHeight * distance * outwardDir;
              
               archPoint = basePoint + archOffset;
               xArch(i) = archPoint(1);
               yArch(i) = archPoint(2);
               zArch(i) = archPoint(3);
           end
       end
       % Handle electrode selection
       function onElectrodeClicked(app, src, ~)
          
           % Find which electrode was clicked
           clickedElectrodeIdx = 0;
           % First check for UserData
           if isprop(src, 'UserData') && ~isempty(src.UserData)
               clickedElectrodeIdx = src.UserData;
           else
               % Search through 3D electrodes
               for i = 1:length(app.BrainElectrodeHandles)
                   if isvalid(app.BrainElectrodeHandles(i)) && src == app.BrainElectrodeHandles(i)
                       clickedElectrodeIdx = i;
                       break;
                   end
               end
              
               % If not found in 3D, search through 2D electrodes
               if clickedElectrodeIdx == 0
                   for i = 1:length(app.CircleElectrodeHandles)
                       if isvalid(app.CircleElectrodeHandles(i)) && src == app.CircleElectrodeHandles(i)
                           clickedElectrodeIdx = i;
                           break;
                       end
                   end
               end
           end
          
           if clickedElectrodeIdx > 0
               % Toggle selection
               if app.SelectedElectrodeIdx == clickedElectrodeIdx
                   app.SelectedElectrodeIdx = 0;
                   app.updateInfoPanel(0);
               else
                   app.SelectedElectrodeIdx = clickedElectrodeIdx;
                   app.updateInfoPanel(clickedElectrodeIdx);
               end
              
               % Update electrode appearance for both 3D and 2D views
               app.updateElectrodeAppearance();
              
               % Update 3D connectivity lines efficiently with proper axes state
               hold(app.BrainAxes, 'on');  % Ensure we don't clear existing graphics
              
               if app.SelectedElectrodeIdx == 0
                   app.drawBackgroundLines3D();
                   app.drawStrongestConnection3D();
                   if ~isempty(app.BrainSelectedLines)
                       for i = 1:length(app.BrainSelectedLines)
                           if isvalid(app.BrainSelectedLines(i))
                               delete(app.BrainSelectedLines(i));
                           end
                       end
                       app.BrainSelectedLines = gobjects(0);
                   end
               else
                   if isempty(app.BrainBackgroundLines)
                       app.drawBackgroundLines3D();
                   end
                   if ~isempty(app.BrainStrongestLine) && isvalid(app.BrainStrongestLine)
                       delete(app.BrainStrongestLine);
                       app.BrainStrongestLine = gobjects(0);
                   end
                   app.drawSelectedElectrodeLines3D();
               end
              
               hold(app.BrainAxes, 'off');  % Reset hold state
               % For 2D: complete redraw
               app.updateCircularGraph();
           end
       end
       % Update electrode appearance without full graph redraw
       function updateElectrodeAppearance(app)
           % Update 3D electrode appearance
           if ~isempty(app.BrainElectrodeHandles)
               for i = 1:length(app.BrainElectrodeHandles)
                   if isvalid(app.BrainElectrodeHandles(i))
                       if i == app.SelectedElectrodeIdx
                           % Highlight selected electrode
                           app.BrainElectrodeHandles(i).SizeData = 300;
                           app.BrainElectrodeHandles(i).MarkerEdgeColor = 'yellow';
                           app.BrainElectrodeHandles(i).LineWidth = 3;
                           if ~isempty(app.BrainElectrodeLabels) && isvalid(app.BrainElectrodeLabels(i))
                               app.BrainElectrodeLabels(i).Color = 'yellow';
                           end
                       else
                           % Normal appearance
                           app.BrainElectrodeHandles(i).SizeData = 200;
                           app.BrainElectrodeHandles(i).MarkerEdgeColor = 'black';
                           app.BrainElectrodeHandles(i).LineWidth = 1;
                           if ~isempty(app.BrainElectrodeLabels) && isvalid(app.BrainElectrodeLabels(i))
                               app.BrainElectrodeLabels(i).Color = 'white';
                           end
                       end
                   end
               end
           end
      
           % Update 2D electrode appearance
           if ~isempty(app.CircleElectrodeHandles)
               for i = 1:length(app.CircleElectrodeHandles)
                   if isvalid(app.CircleElectrodeHandles(i))
                       if i == app.SelectedElectrodeIdx
                           % Highlight selected electrode
                           app.CircleElectrodeHandles(i).MarkerSize = 18;
                           app.CircleElectrodeHandles(i).MarkerEdgeColor = 'yellow';
                           app.CircleElectrodeHandles(i).LineWidth = 3;
                           if ~isempty(app.CircleElectrodeLabels) && isvalid(app.CircleElectrodeLabels(i))
                               app.CircleElectrodeLabels(i).Color = 'yellow';
                           end
                       else
                           % Normal appearance
                           app.CircleElectrodeHandles(i).MarkerSize = 14;
                           app.CircleElectrodeHandles(i).MarkerEdgeColor = 'black';
                           app.CircleElectrodeHandles(i).LineWidth = 1;
                           if ~isempty(app.CircleElectrodeLabels) && isvalid(app.CircleElectrodeLabels(i))
                               app.CircleElectrodeLabels(i).Color = 'white';
                           end
                       end
                   end
               end
           end
       end
   end
  
   % Callbacks that handle component events
   methods (Access = private)
       % Code that executes after component creation
       function startupFcn(app)
           % Set default values
           app.ProcessingLabel.Text = '   No data';
           app.ConditionDropDown.Value = 'Rest';
           app.Freq1DropDown.Value = 'Beta (12-30 Hz)';
           app.Freq2DropDown.Value = 'High Gamma (70-250 Hz)';
           app.ElectrodeRole = 0;
           app.ShowElectrodesLabelsSwitch.Value = 'On';
           app.NumElectrodes = 0;
           app.ElectrodeRole = 0;             % Phase vs Amplitude
           app.SelectedElectrodeIdx = 0;   % No selected electrode
           app.SamplingFrequency = 2000;
           % Initialize loading animation properties
           app.IsDataLoaded = false;
           app.NeedsReprocessing = false;
           app.LoadingTimer = [];
           app.IsProcessing = false;
           % Hide right panel on staratup
           % OVERRIDE the SizeChangedFcn to control layout behavior
           app.UIFigure.SizeChangedFcn = @(src,evt) app.customLayoutControl(src,evt);
          
           % Initialize graphics handle arrays
           app.CircleLinesHandles = gobjects(0);
           app.BrainLinesHandles = gobjects(0);
           app.BrainElectrodeLabels = gobjects(0);
           app.CircleElectrodeLabels = gobjects(0);
          
           % Initialize custom colormap
           app.customColormap();
          
           % Initialize brain model
           app.updateBrainModel();
           rotate3d(app.BrainAxes,'on'); % Enable free mouse rotating
          
           % Create the info panel
           app.createInfoPanel();
           app.InfoPanelVisible = false;   % Show info panel only after processing
       end
       % Button pushed function: UploadMATFileButton
       function UploadMATFileButtonPushed(app, event)
           % Hide the main window
           app.UIFigure.Visible = 'off';
          
           % Open file dialog to select .mat file
           [file, path] = uigetfile('*.mat', 'Select ECoG Data .mat File');
      
           % Restore main window
           app.UIFigure.Visible = 'on';
           drawnow;
           figure(app.UIFigure); % Gives it focus again
           if isequal(file, 0) % If user cancelled
               return;
           end
      
           filePath = fullfile(path, file);
           try
               % Setup loading animation
               app.setupLoadingAnimation();
              
               % Start the processing with background animation
               app.processDataWithAnimation(filePath, file);
              
           catch ME
               % Stop loading animation on error
               app.stopLoadingAnimation();
          
               % Error indicators
               uialert(app.UIFigure, ['Error loading file: ' ME.message], 'Error');
               app.DataLoadLamp.Color = 'red';
               app.ProcessingLabel.FontColor = 'red';
               app.ProcessingLabel.Text = "   Error";
              
               if ~isempty(app.InfoPanel)
                   app.setInfoPanelVisible(false); % Hide info panel
               end
           end
       end
       % Value changed function: ShowElectrodesLabelsSwitch
       function ShowElectrodeLabelsSwitchValueChanged(app, event)
           % Control 3D labels
           if ~isempty(app.BrainElectrodeLabels)
               for i = 1:numel(app.BrainElectrodeLabels)
                   if isvalid(app.BrainElectrodeLabels(i))
                       app.BrainElectrodeLabels(i).Visible = app.ShowElectrodesLabelsSwitch.Value;
                   end
               end
           end
          
           % Control 2D labels 
           if ~isempty(app.CircleElectrodeLabels)
               for i = 1:numel(app.CircleElectrodeLabels)
                   if isvalid(app.CircleElectrodeLabels(i))
                       app.CircleElectrodeLabels(i).Visible = app.ShowElectrodesLabelsSwitch.Value;
                   end
               end
           end
       end
       % Value changed function: ConditionDropDown
       function ConditionDropDownValueChanged(app, event)
           % Only process if data is already loaded
           if isempty(app.PatientData)
               return;
           end
          
           % Set lamp to yellow during processing
           app.DataLoadLamp.Color = 'yellow';
           app.ProcessingLabel.FontColor = 'yellow';
           app.ProcessingLabel.Text = "   Processing...";
           drawnow; % Force UI update to show yellow immediately
          
           try
               % Update current condition data based on drop-down selection
               app.updateCurrentConditionData();
      
               % Proceed to process and update visualization
               app.processAndDisplayData();
              
               % Set lamp back to green when done
               app.DataLoadLamp.Color = 'green';
               app.ProcessingLabel.Text = "";
              
           catch ME
               % Set lamp to red on error
               app.DataLoadLamp.Color = 'red';
               app.ProcessingLabel.FontColor = 'red';
               app.ProcessingLabel.Text = "   Error";
               uialert(app.UIFigure, ['Error processing condition change: ' ME.message], 'Error');
           end
       end
       % Value changed function: Freq1DropDown
       function Freq1DropDownValueChanged(app, event)
           % Only process if data is already loaded
           if isempty(app.PatientData)
               return;
           end
          
           % Set lamp to yellow during processing
           app.DataLoadLamp.Color = 'yellow';
           app.ProcessingLabel.FontColor = 'yellow';
           app.ProcessingLabel.Text = "   Processing...";
           drawnow;
          
           try
               % Process and update visualization
               app.processAndDisplayData();
              
               % Set lamp back to green when done
               app.DataLoadLamp.Color = 'green';
               app.ProcessingLabel.Text = "";
              
           catch ME
               app.DataLoadLamp.Color = 'red';
               app.ProcessingLabel.FontColor = 'red';
               app.ProcessingLabel.Text = "   Error";
               uialert(app.UIFigure, ['Error processing frequency change: ' ME.message], 'Error');
           end
       end
       % Value changed function: Freq2DropDown
       function Freq2DropDownValueChanged(app, event)
           % Only process if data is already loaded
           if isempty(app.PatientData)
               return;
           end
          
           % Set lamp to yellow during processing
           app.DataLoadLamp.Color = 'yellow';
           app.ProcessingLabel.FontColor = 'yellow';
           app.ProcessingLabel.Text = "   Processing...";
           drawnow;
          
           try
               % Process and update visualization
               app.processAndDisplayData();
              
               % Set lamp back to green when done
               app.DataLoadLamp.Color = 'green';
               app.ProcessingLabel.Text = "";
              
           catch ME
               app.DataLoadLamp.Color = 'red';
               app.ProcessingLabel.FontColor = 'red';
               app.ProcessingLabel.Text = "   Error";
               uialert(app.UIFigure, ['Error processing frequency change: ' ME.message], 'Error');
           end
       end
       % Selection changed function: SelectedElectrodeRole
       function ElectrodeRoleChanged(app, event)
           selectedButton = app.SelectedElectrodeRole.SelectedObject;
          
           if selectedButton == app.PhaseButton
               app.ElectrodeRole = 0;
           else  % selectedButton == app.AmpButton
               app.ElectrodeRole = 1;
           end
      
           % Update visualization for current view mode
           if isempty(app.CurrentConditionData)
               uialert(app.UIFigure, 'No ECoG data available for processing. Please load data first.', 'Warning', 'Icon', 'warning');
               return;
           end
           % Set lamp to yellow during processing
           app.DataLoadLamp.Color = 'yellow';
           app.ProcessingLabel.FontColor = 'yellow';
           app.ProcessingLabel.Text = "   Processing...";
           drawnow;
          
           try
               % Update the graphs
               app.updateBrainModel();
               app.updateCircularGraph();
              
               % Update info panel only if an electrode is selected (global info shouldn't change)
               if app.InfoPanelVisible && ~isempty(app.ElectrodeInfo) && app.SelectedElectrodeIdx > 0
                   app.updateInfoPanel(app.SelectedElectrodeIdx);
               end
              
               % Set lamp back to green when done
               app.DataLoadLamp.Color = 'green';
               app.ProcessingLabel.Text = "";
              
           catch ME
               app.DataLoadLamp.Color = 'red';
               app.ProcessingLabel.FontColor = 'red';
               app.ProcessingLabel.Text = "   Error";
               uialert(app.UIFigure, ['Error changing selected electrode role: ' ME.message], 'Error');
           end
       end
       % Changes arrangement of the app based on UIFigure width
       function updateAppLayout(app, event)
           currentFigureWidth = app.UIFigure.Position(3);
           if(currentFigureWidth <= app.onePanelWidth)
               % Change to a 3x1 grid
               app.GridLayout.RowHeight = {587, 587, 587};
               app.GridLayout.ColumnWidth = {'1x'};
               app.CenterPanel.Layout.Row = 1;
               app.CenterPanel.Layout.Column = 1;
               app.LeftPanel.Layout.Row = 2;
               app.LeftPanel.Layout.Column = 1;
               app.RightPanel.Layout.Row = 3;
               app.RightPanel.Layout.Column = 1;
           elseif (currentFigureWidth > app.onePanelWidth && currentFigureWidth <= app.twoPanelWidth)
               % Change to a 2x2 grid
               app.GridLayout.RowHeight = {587, 587};
               app.GridLayout.ColumnWidth = {'1x', '1x'};
               app.CenterPanel.Layout.Row = 1;
               app.CenterPanel.Layout.Column = [1,2];
               app.LeftPanel.Layout.Row = 2;
               app.LeftPanel.Layout.Column = 1;
               app.RightPanel.Layout.Row = 2;
               app.RightPanel.Layout.Column = 2;
           else
               % Change to a 1x3 grid
               app.GridLayout.RowHeight = {'1x'};
               app.GridLayout.ColumnWidth = {222, '1x', 324};
               app.LeftPanel.Layout.Row = 1;
               app.LeftPanel.Layout.Column = 1;
               app.CenterPanel.Layout.Row = 1;
               app.CenterPanel.Layout.Column = 2;
               app.RightPanel.Layout.Row = 1;
               app.RightPanel.Layout.Column = 3;
           end
       end
   end
   % Component initialization
   methods (Access = private)
       % Create UIFigure and components
       function createComponents(app)
           % Get the file path for locating images
           pathToMLAPP = fileparts(mfilename('fullpath'));
           % Create UIFigure and hide until all components are created
           app.UIFigure = uifigure('Visible', 'off');
           app.UIFigure.AutoResizeChildren = 'off';
           app.UIFigure.Position = [100 100 1146 587];
           app.UIFigure.Name = 'MATLAB App';
           app.UIFigure.Icon = fullfile(pathToMLAPP, 'PLView_icon.png');
           app.UIFigure.SizeChangedFcn = createCallbackFcn(app, @updateAppLayout, true);
           app.UIFigure.WindowState = 'maximized';
           % Create GridLayout
           app.GridLayout = uigridlayout(app.UIFigure);
           app.GridLayout.ColumnWidth = {222, '1x', 324};
           app.GridLayout.RowHeight = {'1x'};
           app.GridLayout.ColumnSpacing = 0;
           app.GridLayout.RowSpacing = 0;
           app.GridLayout.Padding = [0 0 0 0];
           app.GridLayout.Scrollable = 'on';
           % Create LeftPanel
           app.LeftPanel = uipanel(app.GridLayout);
           app.LeftPanel.Layout.Row = 1;
           app.LeftPanel.Layout.Column = 1;
           % Create GridLayout2
           app.GridLayout2 = uigridlayout(app.LeftPanel);
           app.GridLayout2.ColumnWidth = {'0.15x'};
           app.GridLayout2.RowHeight = {30, 100, '1x', 30, 30, 30, 30, 30, 65, 30, 30, '1x', 30};
           % Create UploadMATFileButton
           app.UploadMATFileButton = uibutton(app.GridLayout2, 'push');
           app.UploadMATFileButton.ButtonPushedFcn = createCallbackFcn(app, @UploadMATFileButtonPushed, true);
           app.UploadMATFileButton.Icon = fullfile(pathToMLAPP, 'upload.png');
           app.UploadMATFileButton.Layout.Row = 13;
           app.UploadMATFileButton.Layout.Column = 1;
           app.UploadMATFileButton.Text = 'Upload (.mat file)';
           % Create ShowElectrodesLabelsSwitch
           app.ShowElectrodesLabelsSwitch = uiswitch(app.GridLayout2, 'slider');
           app.ShowElectrodesLabelsSwitch.ValueChangedFcn = createCallbackFcn(app, @ShowElectrodeLabelsSwitchValueChanged, true);
           app.ShowElectrodesLabelsSwitch.Layout.Row = 11;
           app.ShowElectrodesLabelsSwitch.Layout.Column = 1;
           % Create SelectedElectrodeRole
           app.SelectedElectrodeRole = uibuttongroup(app.GridLayout2);
           app.SelectedElectrodeRole.SelectionChangedFcn = createCallbackFcn(app, @ElectrodeRoleChanged, true);
           app.SelectedElectrodeRole.BorderType = 'none';
           app.SelectedElectrodeRole.Title = 'Selected Electrode Role:';
           app.SelectedElectrodeRole.Layout.Row = 9;
           app.SelectedElectrodeRole.Layout.Column = 1;
           % Create PhaseButton
           app.PhaseButton = uiradiobutton(app.SelectedElectrodeRole);
           app.PhaseButton.Text = 'Phase        (Low frequency)';
           app.PhaseButton.Position = [11 19 169 22];
           app.PhaseButton.Value = true;
           % Create AmpButton
           app.AmpButton = uiradiobutton(app.SelectedElectrodeRole);
           app.AmpButton.Text = 'Amplitude  (High frequency)';
           app.AmpButton.Position = [11 -3 171 22];
           % Create Freq2DropDown
           app.Freq2DropDown = uidropdown(app.GridLayout2);
           app.Freq2DropDown.Items = {'Delta (0.5-4 Hz)', 'Theta (4-8 Hz)', 'Alpha (8-12 Hz)', 'Beta (12-30 Hz)', 'Gamma (30-70 Hz)', 'High Gamma (70-250 Hz)'};
           app.Freq2DropDown.ValueChangedFcn = createCallbackFcn(app, @Freq2DropDownValueChanged, true);
           app.Freq2DropDown.Layout.Row = 8;
           app.Freq2DropDown.Layout.Column = 1;
           app.Freq2DropDown.Value = 'High Gamma (70-250 Hz)';
           % Create Freq1DropDown
           app.Freq1DropDown = uidropdown(app.GridLayout2);
           app.Freq1DropDown.Items = {'Delta (0.5-4 Hz)', 'Theta (4-8 Hz)', 'Alpha (8-12 Hz)', 'Beta (12-30 Hz)', 'Gamma (30-70 Hz)', 'High Gamma (70-250 Hz)'};
           app.Freq1DropDown.ValueChangedFcn = createCallbackFcn(app, @Freq1DropDownValueChanged, true);
           app.Freq1DropDown.Layout.Row = 7;
           app.Freq1DropDown.Layout.Column = 1;
           app.Freq1DropDown.Value = 'Beta (12-30 Hz)';
           % Create ConditionDropDown
           app.ConditionDropDown = uidropdown(app.GridLayout2);
           app.ConditionDropDown.Items = {'Rest', 'Easy Task (CountF)', 'Hard Task (Alt)'};
           app.ConditionDropDown.ValueChangedFcn = createCallbackFcn(app, @ConditionDropDownValueChanged, true);
           app.ConditionDropDown.Layout.Row = 5;
           app.ConditionDropDown.Layout.Column = 1;
           app.ConditionDropDown.Value = 'Rest';
           % Create Logo
           app.Logo = uiimage(app.GridLayout2);
           app.Logo.Layout.Row = 2;
           app.Logo.Layout.Column = 1;
           app.Logo.ImageSource = fullfile(pathToMLAPP, 'PLView_logo.png');
           % Create ElectrodesLabelsSwitchLabel
           app.ElectrodesLabelsSwitchLabel = uilabel(app.GridLayout2);
           app.ElectrodesLabelsSwitchLabel.VerticalAlignment = 'bottom';
           app.ElectrodesLabelsSwitchLabel.Layout.Row = 10;
           app.ElectrodesLabelsSwitchLabel.Layout.Column = 1;
           app.ElectrodesLabelsSwitchLabel.Text = 'Electrodes Labels:';
           % Create SelectedElectrodeFrequencyLabel
           app.SelectedElectrodeFrequencyLabel = uilabel(app.GridLayout2);
           app.SelectedElectrodeFrequencyLabel.VerticalAlignment = 'bottom';
           app.SelectedElectrodeFrequencyLabel.Layout.Row = 6;
           app.SelectedElectrodeFrequencyLabel.Layout.Column = 1;
           app.SelectedElectrodeFrequencyLabel.Text = 'Phase and Amp Frequencies:';
           % Create TestConditionDropDownLabel
           app.TestConditionDropDownLabel = uilabel(app.GridLayout2);
           app.TestConditionDropDownLabel.VerticalAlignment = 'bottom';
           app.TestConditionDropDownLabel.Layout.Row = 4;
           app.TestConditionDropDownLabel.Layout.Column = 1;
           app.TestConditionDropDownLabel.Text = 'Test Condition:';
           % Create CenterPanel
           app.CenterPanel = uipanel(app.GridLayout);
           app.CenterPanel.BackgroundColor = [0 0 0];
           app.CenterPanel.Layout.Row = 1;
           app.CenterPanel.Layout.Column = 2;
           % Create GridLayout3
           app.GridLayout3 = uigridlayout(app.CenterPanel);
           app.GridLayout3.ColumnWidth = {15, '1x', 15};
           app.GridLayout3.RowHeight = {15, '3x', 15};
           app.GridLayout3.ColumnSpacing = 0;
           app.GridLayout3.RowSpacing = 0;
           app.GridLayout3.BackgroundColor = [0 0 0];
           % Create BrainAxes
           app.BrainAxes = uiaxes(app.GridLayout3);
           title(app.BrainAxes, 'Title')
           xlabel(app.BrainAxes, 'X')
           ylabel(app.BrainAxes, 'Y')
           zlabel(app.BrainAxes, 'Z')
           app.BrainAxes.GridAlpha = 0;
           app.BrainAxes.Layout.Row = 2;
           app.BrainAxes.Layout.Column = 2;
           % Create DataLoadLamp
           app.DataLoadLamp = uilamp(app.GridLayout3);
           app.DataLoadLamp.Layout.Row = 3;
           app.DataLoadLamp.Layout.Column = 1;
           app.DataLoadLamp.Color = [0.902 0.902 0.902];
           % Create ProcessingLabel
           app.ProcessingLabel = uilabel(app.GridLayout3);
           app.ProcessingLabel.FontColor = [1 1 1];
           app.ProcessingLabel.Layout.Row = 3;
           app.ProcessingLabel.Layout.Column = 2;
           % Create RightPanel
           app.RightPanel = uipanel(app.GridLayout);
           app.RightPanel.Layout.Row = 1;
           app.RightPanel.Layout.Column = 3;
           % Create GridLayout4
           app.GridLayout4 = uigridlayout(app.RightPanel);
           app.GridLayout4.ColumnWidth = {'0.5x', 15};
           app.GridLayout4.RowHeight = {'2x', '1x'};
           app.GridLayout4.ColumnSpacing = 0;
           app.GridLayout4.RowSpacing = 0;
           app.GridLayout4.HandleVisibility = 'off';
           app.GridLayout4.BackgroundColor = [0.251 0.251 0.251];
           % Create CircleAxes
           app.CircleAxes = uiaxes(app.GridLayout4);
           title(app.CircleAxes, 'Title')
           xlabel(app.CircleAxes, 'X')
           ylabel(app.CircleAxes, 'Y')
           zlabel(app.CircleAxes, 'Z')
           app.CircleAxes.Toolbar.Visible = 'off';
           app.CircleAxes.Layout.Row = 1;
           app.CircleAxes.Layout.Column = 1;
           % Show the figure after all components are created
           app.UIFigure.Visible = 'on';
       end
   end
   % App creation and deletion
   methods (Access = public)
       % Construct app
       function app = PLView
           % Create UIFigure and components
           createComponents(app)
           % Register the app with App Designer
           registerApp(app, app.UIFigure)
           % Execute the startup function
           runStartupFcn(app, @startupFcn)
           if nargout == 0
               clear app
           end
       end
       % Code that executes before app deletion
       function delete(app)
           % Delete UIFigure when app is deleted
           delete(app.UIFigure)
       end
   end
end
