# PLView User Guide

This guide describes how to use the PLView MATLAB app based on the actual UI and workflow.

## UI Overview

### Left panel (controls)

- **Test Condition:** Dropdown with options:
  - Rest
  - Easy Task (CountF)
  - Hard Task (Alt)

- **Phase and Amp Frequencies:** Two dropdowns (Freq1 and Freq2), each with:
  - Delta (0.5–4 Hz)
  - Theta (4–8 Hz)
  - Alpha (8–12 Hz)
  - Beta (12–30 Hz)
  - Gamma (30–70 Hz)
  - High Gamma (70–250 Hz)

- **Selected Electrode Role:** Radio buttons:
  - Phase (Low frequency)
  - Amplitude (High frequency)

- **Electrodes Labels:** Switch (On/Off) to show or hide electrode labels on the 3D and 2D views.

- **Upload (.mat file):** Button to load an ECoG data `.mat` file.

### Center panel

- **3D brain view (BrainAxes):** Displays a 3D brain model with electrodes and connectivity lines. You can rotate the view with the mouse. Click an electrode to select it and highlight its connections.

### Right panel (when data is loaded)

- **2D connection graph (CircleAxes):** Circular layout of electrodes with lines indicating connectivity strength. A **PLV Score** colorbar (e.g. 0 to 1) shows connection strength. Click an electrode to select it.

- **Floating info panel:** Shows:
  - **Patient info:** Patient ID and number of electrodes.
  - **Strongest connection:** PLV value, the two electrodes (with phase/amplitude roles), and network label (e.g. MOTOR). When an electrode is selected, the panel shows the strongest connection for that electrode; when none is selected, it shows the global strongest connection.

## Workflow

1. **Start the app** (e.g. via MATLAB File Exchange or by opening `PLView.mlapp` in App Designer).

2. **Optional — set parameters before loading:**
   - Test Condition (Rest / Easy Task / Hard Task)
   - Phase and Amp Frequencies (Freq1, Freq2)
   - Selected Electrode Role (Phase / Amplitude)
   - Electrodes Labels (On/Off)

3. **Load data:** Click **Upload (.mat file)** and select a valid ECoG `.mat` file. The app will:
   - Load the file
   - Extract patient and electrode information
   - Filter signals and compute the PLV (Phase Locking Value) matrix
   - Display the 3D brain, 2D connection graph, and info panel

4. **Explore results:**
   - **Click an electrode** (in the 3D or 2D view) to select it; the info panel and highlighted connections update. Click the same electrode again to deselect.
   - **Change Test Condition, frequencies, or Electrode Role** to reprocess and update the visualizations (if data is already loaded).

5. **Interpret:** Use the PLV Score colorbar and the “Strongest connection” section to see which electrode pairs have the strongest phase–amplitude coupling for the chosen condition and frequency bands.
