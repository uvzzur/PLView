# Dependencies and Hardcoded Paths

This document summarizes external dependencies and path references in the PLView app. **No code changes are made to the app;** these are documented so users can satisfy them in their environment.

## From PLView_code_snapshot.m

### Electrode metadata (hardcoded absolute path)

- **File:** `PLView_code_snapshot.m`, **line 58**
- **Code:** `ElectrodesData = load("/mnt/jane_data/DataFromMoataz/Elecs_n79_w_network.mat");`
- **Meaning:** The app loads the electrode database from this path at startup. The loaded struct must contain table **elecs_n79** (subject, contact, x_MNI_coord, y_MNI_coord, z_MNI_coord, channel or elec_name, Network).
- **User action:** Place a copy of the electrode metadata file at `/mnt/jane_data/DataFromMoataz/Elecs_n79_w_network.mat`, or create a symlink. Alternatively, modify the app (line 58) to point to your file—only if you are allowed to change the source.

### head3d.mat (same folder or path)

- **File:** `PLView_code_snapshot.m`, **lines 926–940, 944**
- **Code:** The app tries, in order:  
  (1) `fullfile(fileparts(mfilename('fullpath')), 'head3d.mat')`  
  (2) `fullfile(ctfroot, 'head3d.mat')`  
  (3) `which('head3d.mat')`
- **Required contents:** `head3d.cortex.mesh` with `.vertices` and `.faces`.
- **User action:** Keep `head3d.mat` in the same folder as `PLView.mlapp`, or ensure it is on the MATLAB path (e.g. when running from source).

### App icons and logo (same folder as .mlapp)

- **File:** `PLView_code_snapshot.m`, **lines 1891, 1897, 1919, 1969**
- **Code:** `pathToMLAPP = fileparts(mfilename('fullpath'));` then `fullfile(pathToMLAPP, 'PLView_icon.png')`, `'upload.png'`, `'PLView_logo.png'`.
- **Meaning:** These three image files must be in the same directory as the running app (.mlapp or packaged app).
- **User action:** Do not move `PLView_icon.png`, `upload.png`, or `PLView_logo.png` out of the app folder.

## From PLView.prj (deployment project)

- **File:** `PLView.prj`, **lines 2, 43–44, 47**
- **Paths:** Project location `D:\לימודים\פרויקט\MATLAB app\final`; MATLAB root `D:\Program Files\MATLAB`.
- **Meaning:** These are deployment/build paths for the project file. They do not affect runtime unless you open the .prj in MATLAB.
- **User action:** If you open the project, repoint the project root and MATLAB root to your machine if needed.

## Ignored (not part of app code)

- **dummy data/untitled.m:** Contains its own paths and load/save calls; not used by the app. Ignored per project rules.
