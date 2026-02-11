# PLView Developer Notes

Technical notes on the PLView app structure, data flow, and key functions. All line and function references are from `PLView_code_snapshot.m`.

## Entry and startup

- The app constructor runs `runStartupFcn(app, @startupFcn)`.
- **startupFcn** (line 1623): Sets default values (Condition Rest, Freq1 Beta, Freq2 High Gamma, SamplingFrequency 2000, etc.), calls `customColormap()`, `updateBrainModel()`, and `createInfoPanel()`. The right panel is hidden until data is loaded.

## Main callbacks

| Callback | Trigger | Action |
|----------|---------|--------|
| **UploadMATFileButtonPushed** (1661) | User clicks Upload | `uigetfile` → `processDataWithAnimation(filePath, file)` → load(filePath), `createElectrodeInfo`, `updateCurrentConditionData`, `processAndDisplayData`. On success, shows right panel and info panel. |
| **ConditionDropDownValueChanged** (1721) | User changes Test Condition | If data loaded: `updateCurrentConditionData`, then `processAndDisplayData`. |
| **Freq1DropDownValueChanged**, **Freq2DropDownValueChanged** | User changes frequency dropdowns | If data loaded: `processAndDisplayData` (recompute PLV with new bands). |
| **ElectrodeRoleChanged** | User toggles Phase/Amplitude role | If data loaded: `processAndDisplayData` (affects which connections are emphasized). |
| **ShowElectrodeLabelsSwitchValueChanged** (1699) | User toggles Electrodes Labels | Sets visibility of electrode text labels on BrainAxes and CircleAxes. |
| **onElectrodeClicked** (1495) | User clicks electrode in 3D or 2D | Select or deselect electrode (`SelectedElectrodeIdx`), then `updateBrainModel`, `updateInfoPanel(SelectedElectrodeIdx)`. |

## Data flow

1. **Load:** `load(filePath)` → `app.PatientData`. Patient name is parsed from the filename (e.g. last 7 characters before `.mat` → `2017_02`).
2. **Electrode info:** `createElectrodeInfo()` uses `app.ElectrodesData.elecs_n79` (from hardcoded path) to get subject, channel, coordinates, and Network for the current patient. Populates `app.ElectrodeCoords`, `app.NumElectrodes`, `app.ElectrodeInfo` (Names, Networks, StrongestConnections, NetworkColors).
3. **Condition data:** `updateCurrentConditionData()` reads `app.PatientData.data_all` (fields `all_rest`, `all_countF`, `all_alt`), trims trials, filters to valid (non-reference) channels, and sets `app.CurrentConditionData`.
4. **PLV and display:** `processAndDisplayData()` calls `processECOGData(app.CurrentConditionData, Freq1, Freq2)` → fills `app.PLVMatrix`, then `updateBrainModel()` (3D) and the CircleAxes (2D) and `updateInfoPanel()`.

## PLV computation

- **Function:** `processECOGData` (lines 562–687).
- **Per electrode pair:** Bandpass filter for Freq1 (phase band) and Freq2 (amplitude band), Hilbert transform for phase and amplitude envelope, phase of the high-frequency envelope, phase difference with low-frequency phase, then:
  - `PLV_result = abs(mean(exp(1i * phaseDiff), 'omitnan'))` (line 657).
- **Storage:** `app.PLVMatrix`; `app.ColorbarMax = max(PLV) * 1.2` for colorbar scaling.
- **Interpretation:** Row = phase electrode, column = amplitude electrode (see comment in code around lines 671–679).

## Plot updates

- **updateBrainModel** (908): Resolves `head3d.mat` (same folder as app, then ctfroot, then `which`), draws brain patch or fallback sphere, then (if data loaded) electrodes (scatter3), labels, and connectivity lines via:
  - `drawBackgroundLines3D`, `drawStrongestConnection3D` (no electrode selected), or
  - `drawSelectedElectrodeLines3D` (electrode selected).
- **CircleAxes:** Same electrode list and connectivity; colorbar label "PLV Score". Strongest connection and selected-electrode highlighting are drawn in the same update path.
- **onElectrodeClicked** calls `updateBrainModel()` and `updateInfoPanel(SelectedElectrodeIdx)` so the 3D/2D views and info panel stay in sync.

## Key functions (reference)

| Function | Role |
|----------|------|
| createElectrodeInfo | Build electrode struct from ElectrodesData.elecs_n79 for current patient |
| updateCurrentConditionData | Fill CurrentConditionData from data_all (all_rest / all_countF / all_alt) |
| processAndDisplayData | Run processECOGData then update 3D/2D and info panel |
| processECOGData | Bandpass, Hilbert, phase difference, PLV matrix |
| updateBrainModel | Load head3d, draw brain, electrodes, labels, 3D lines |
| drawBackgroundLines3D | Grey background connectivity lines |
| drawStrongestConnection3D | Highlight strongest connection in 3D |
| drawSelectedElectrodeLines3D | Highlight lines for selected electrode in 3D |
| updateCircleConnections | Redraw 2D circle graph and lines |
| createInfoPanel | Create floating info panel UI |
| updateInfoPanel | Update panel with patient info and strongest connection (global or per electrode) |
| onElectrodeClicked | Handle electrode click: select/deselect, then updateBrainModel, updateInfoPanel |
| customColormap | Build PLV color gradient (blue → purple → red → orange → white) |
| createNetworkColorMap | Map network names to colors for electrodes |
| getPLVColor | Map PLV value to hex color for info panel |
| getFrequencyBandLimits | Map frequency band label string to [low, high] Hz |
