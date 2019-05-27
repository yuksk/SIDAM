# SIDAM

Spectroscopic imaging data analysis macro for Igor Pro.


## Description

Noteworthy features of this macro are strong supports for analyzing 3D map data.
- Flexible viewer: interactively show spectra at a mouse cursor, an Igor Pro cursor, or along a line on an image, which can be a topograph, a conductance map, or any other image of your analysis.
- Powerful synchronization: layers of 3D map data, axis ranges of multiple images, and cursor locations of multiple images.
- Attentive layer support: adjust color range, update an annotation text, and save a movie of layers.

Of course, basic features (Subtraction, Line profile, Fourier transform, Fourier filter, Symmetrize Fourier transform, Correlation, Histogram, etc.) also included.

## Requirement

Igor Pro 8 or later, and Git (Git for Windows or WSL).

## Install/Update

### Install

The following 3 steps:
1. With cmd.exe or WSL, move to a directory where SIDAM files will be stored.  
e.g. `C:\Users\yourname\Documents\WaveMetrics\Igor Pro 8 User Files`
2. Clone SIDAM into the directory, and you will find `SIDAM` in the directory.
3. Run `install.bat` in `SIDAM`, and symbolic links will be created in the Igor Pro folder.
If SIDAM is already installed, add an option `/f` to `install.bat`.
Otherwise, SIDAM files will be updated instead of creating the symbolick links.

The commands for the above 3 steps are as follows.  
~~~Shell:cmd.exe
cmd.exe
> cd /d yourfavoritepath
> git clone -b master git@gitlab.com:ThnJYSZq/SIDAM.git
> cd SIDAM
> install.bat /f
~~~
~~~Shell:WSL
WSL
$ cd yourfavoritepath
$ git clone -b master git@gitlab.com:ThnJYSZq/SIDAM.git
$ cd SIDAM
$ cmd.exe /c install.bat /f
~~~

### Update

1. Run `install.bat` in `SIDAM`.
If a newer file(s) is available, the file(s) will be updated with git.
2. Start the macro to update the file list.

