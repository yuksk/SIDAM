# SIDAM

Spectroscopic imaging data analysis macro for Igor Pro.


## Description

Noteworthy features of this macro are strong supports for analyzing 3D map data.
- Flexible viewer: interactively show spectra at a mouse cursor, an Igor Pro cursor, or along a line on an image, which can be a topograph, a conductance map, or any other image of your analysis.
- Powerful synchronization: layers of 3D map data, axis ranges of multiple images, and cursor locations of multiple images.
- Attentive layer support: adjust color range, update an annotation text, and save a movie of layers.

Of course, basic features (Subtraction, Line profile, Fourier transform, Fourier filter, Symmetrize Fourier transform, Correlation, Histogram, etc.) also included.

## Requirement

Igor Pro 7 is required. Practically, however, Igor Pro 8 is recommended because the macro is developed with Igor Pro 8. Since no functions of Igor Pro 8 have been used so far, the macro should work in Igor Pro 7 but is not guaranteed.


## Install/Update

### Install

Copy the macro files to the designated folders.

1. Copy SIDAM.ipf and the SIDAM folder to the Igor Procedures folder and the User Procedures folder, respectively. If you don't know where the folders are, choose "Help > Show Igor Pro User Files" in Igor Pro.

2. Restart Igor Pro, and open SIDAM.itx or choose "Macros > SIDAM" in Igor Pro to start SIDAM.

An alternative way is to make symbolic links of the above file and folder rather than copying them. This is recommended for continuous users who add and/or modify the procedure files because, in combination with git, this makes updating the macro much easier. To make symbolic links in Windows, run the following commands at the SIDAM folder in the command prompt with administrator privileges.

~~~Shell
$ mklink "%USERPROFILE%/Documents/WaveMetrics/Igor Pro 8 User Files/Igor Procedures/SIDAM.ipf" "%cd%\SIDAM.ipf"
$ mklink /d "%USERPROFILE%/Documents/WaveMetrics/Igor Pro 8 User Files/User Procedures/SIDAM" "%cd%\SIDAM"
~~~

### Update

Renew the macro files as follows.

1. Remove the SIDAM folder in the User Procedures folder. If you used Kohsaka Macro, remove the KM folder.
2. Overwrite SIDAM.ipf in the Igor Procedures and copy new SIDAM folder to the User Procedures folder.
3. Start the macro to update the file list.

Some additional notes.
- Do not overwrite the SIDAM folder because old files may be left and cause a compile error.
- If you have added and/or modified procedure files, do not forget to keep them before 1 and move them back after 2.
- If you forget 3 and open an existing experiment file, a compile error may occur. In this case, stop opening the experiment file and start the macro in a new experiment file.
- If you use git and made symbolic links in installing the macro, you can just fetch & merge to renew the procedure files. (You don't need to do 1 and 2, but still need to do 3.)
