# SIDAM

*SIDAM* (**S**pectroscopic **I**maging **D**ata **A**nalysis **M**acro) is
a software for data analysis of scanning tunneling spectroscopy.
Compared with other software for SPM data analysis such as WSxM, SPIP, or
Gwyddion, SIDAM is developed especially for 3D data (positions and energy) of
spectroscopic imaging.

Frequently used basic features:

- Flexible interactive viewers (see also [gif movies](#screen-shots))
- Background subtraction
- Fourier analysis
  - Fourier transform
  - Fourier filter
  - Symmetrize Fourier transform
- Correlation
- Histogram
- Work function

*SIDAM* is written in Igor Pro, so you can fully use the powerful visualization
of Igor Pro to make figures for your papers and talks. Moreover, SIDAM is
designed for both GUI and CLI. You can do everything from the menus and do not
have to remember commands. However, you can also do the same things by calling
commands, making it easy to repeat analyses and incorporate *SIDAM* functions
into your scripts.

## Requirement

Igor Pro 8 or 9.

## Getting started

### Install

After cloning or downloading the macro files, copy them to the designated folders.

    SIDAM/
    ├ LICENSE
    ├ readme.rst
    ├ docs/
    ├ script/
    └ src/
        ├ SIDAM.ipf -> Copy to Igor Procedures
        └ SIDAM/    -> Copy to User Procedures

Copy *src/SIDAM.ipf* and *src/SIDAM* to the Igor Procedures folder and the
User Procedures folder, respectively. If you don't know where the folders are,
choose *Menubar > Help > Show Igor Pro User Files* in Igor Pro.

Instead of copying the file and folder, you can also make shortcuts or
symbolic links of them in the designated folders. This would be useful for
updating SIDAM in future if you clone the files.

### Launch SIDAM
Lanuch Igor Pro, choose *Menubar > Macros > SIDAM* in Igor Pro, and you will
find a new menu item *SIDAM* in the menu bar. If Igor Pro is already running,
you need to restart it after installing SIDAM.

### Load data file
Choose *Menubar > SIDAM > Load Data... > from a File...*. Alternatively,
you can drag and drop data files into the window of Igor Pro.
Supported files are Nanonis files (.dat, .sxm, .3ds, .nsp).

### Show data
Choose a wave(s) you want to show in the Data Browser and
choose *Menubar > SIDAM > Display... > Display Selected Waves*.
Alternatively, you can press F3 after choosing a wave(s) you want to show in
the Data Browser.

### Subsequent analysis
Right-click the control bar shown in a window and you will find menu items of
analysis available for the data shown in the window.

## Gif movies

### Color tables
<img src="https://raw.githubusercontent.com/yuksk/SIDAM/gh-pages/docs/img/color.png" width="441px" height="262px" alt="autorange">

### Auto color range adjustment
<img src="https://raw.githubusercontent.com/yuksk/SIDAM/gh-pages/docs/img/autorange.gif" width="179px" height="160px" alt="autorange">

### Spectrum viewer
<img src="https://raw.githubusercontent.com/yuksk/SIDAM/gh-pages/docs/img/spectrum.gif" width="382px" height="160px" alt="spectrum">

<img src="https://raw.githubusercontent.com/yuksk/SIDAM/gh-pages/docs/img/linespectra.gif" width="290px" height="289px" alt="linespectra">

### Line profile
<img src="https://raw.githubusercontent.com/yuksk/SIDAM/gh-pages/docs/img/lineprofile.gif" width="290px" height="160px" alt="lineprofile">

### Synchronize layer, axis range, cursor
<img src="https://raw.githubusercontent.com/yuksk/SIDAM/gh-pages/docs/img/synclayer.gif" width="253px" height="160px" alt="synclayer">  
<img src="https://raw.githubusercontent.com/yuksk/SIDAM/gh-pages/docs/img/syncaxisrange.gif" width="255px" height="160px" alt="syncaxisrange">  
<img src="https://raw.githubusercontent.com/yuksk/SIDAM/gh-pages/docs/img/synccursor.gif" width="253px" height="160px" alt="synccursor">

### Position recorder
<img src="https://raw.githubusercontent.com/yuksk/SIDAM/gh-pages/docs/img/position_recorder.gif" width="249px" height="149px" alt="synclayer">


Data: BiTeI, https://doi.org/10.1103/PhysRevB.91.245312

## Documents
The command help is available at https://yuksk.github.io/SIDAM/index.html
