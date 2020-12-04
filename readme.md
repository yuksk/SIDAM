# SIDAM

Spectroscopic imaging data analysis macro for Igor Pro.


## Description

Noteworthy features of this macro are strong supports for analyzing 3D map data.
- Flexible viewer: interactively show spectra at a mouse cursor, an Igor Pro
cursor, or along a line on an image, which can be a topograph, a conductance
map, or any other image of your analysis.
- Powerful synchronization: layers of 3D map data, axis ranges of multiple
images, and cursor locations of multiple images.
- Attentive layer support: adjust color range, update an annotation text,
and save a movie of layers.

Of course, basic features (Subtraction, Line profile, Fourier transform,
Fourier filter, Symmetrize Fourier transform, Correlation, Histogram, etc.)
also included.

## Requirement

Igor Pro 8 or later.

## Install/Update/Uninstall

### Install

Copy the macro files to the designated folders.

1. Copy `src/SIDAM.ipf` and `src/SIDAM` to the Igor Procedures folder and the
User Procedures folder, respectively. If you don't know where the folders are,
choose `Help > Show Igor Pro User Files` in Igor Pro.

2. Restart Igor Pro, and choose `Macros > SIDAM` in Igor Pro to start SIDAM.

Instead of copying the file and folder, you can also make shortcuts or
symbolic links of them in the designated folders.

### Update

Renew the macro files as follows.

1. Remove the SIDAM folder in the User Procedures folder. If you have added
your own file in the extension folder, do not forget to keep them and move
them back after 2.
2. Overwrite SIDAM.ipf in the Igor Procedures and copy new SIDAM folder to the
User Procedures folder. Do not overwrite the SIDAM folder because old files
may be left and cause a compile error.
3. Start the macro to update the file list. If you forget this and open an
existing experiment file, a compile error may occur. In this case, stop
opening the experiment file and start the macro in a new experiment file.

For git users: you can just pull. You don't need to do 1 and 2, but still
need to do 3.

### Uninstall

Remove all the files you copied when you installed.
