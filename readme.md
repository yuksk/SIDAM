# SIDAM

*SIDAM* is written in Igor Pro and developed for analyzing 3D data (x, y,
and energy) of spectroscopic-imaging scanning tunneling microscopy.
*SIDAM* provides both a graphical user interface and a command line interface,
offering users flexibility and convenience to unlock insights from data
while maintaining reproducible analyses.

Frequently used features ([gif movies](#Gif-movies)):

- Interactive viewers
- Background subtraction
- Fourier analysis
  - Fourier transform
  - Fourier filter
  - Symmetrize Fourier transform
- Correlation
- Histogram
- Work function

## Requirement

Igor Pro 9 or later is required.

## Getting started

### Install

After cloning or downloading the macro files, copy them to the designated folders.

    SIDAM/
    ├ LICENSE
    ├ readme.md
    ├ docs/
    ├ script/
    └ src/
        ├ SIDAM.ipf -> Copy to Igor Procedures
        └ SIDAM/    -> Copy to User Procedures

Copy `src/SIDAM.ipf` and `src/SIDAM` to the Igor Procedures folder and the
User Procedures folder, respectively. If you don't know where the folders are,
choose *Menubar > Help > Show Igor Pro User Files* in Igor Pro.

Instead of copying the file and folder, you can also make shortcuts or
symbolic links to them in the designated folders. This would be useful for
updating SIDAM in the future if you clone the files.

### Launch SIDAM
Launch Igor Pro, choose *Menubar > Macros > SIDAM* in Igor Pro, and you will
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
Click ☰ in the control bar of a window and you will find menu items of
analysis available for the data shown in the window.

## Document
https://yuksk.github.io/SIDAM/

## Papers
<details>
<summary>Expand to see a list of papers in which figures were made using SIDAM.</summary>

- [Phys. Rev. B 105, 064507 (2022)](https://doi.org/10.1103/PhysRevB.105.064507)
- [Rev. Sci. Instrum. 92, 033702 (2021)](https://doi.org/10.1063/5.0038852j)
- [Nat. Commun. 11, 5925 (2020)](https://doi.org/10.1038/s41467-020-19751-4)
- [Nat. Mater. 18, 811 (2019)](https://doi.org/10.1038/s41563-019-0397-1)
- [Phys. Rev. Lett. 122, 077001 (2019)](https://doi.org/10.1103/PhysRevLett.122.077001)
- [Rev. Sci. Instrum. 89, 093707 (2018)](https://doi.org/10.1063/1.5049619)
- [Sci. Adv. 4, eaar6419 (2018)](https://doi.org/10.1126/sciadv.aar6419)
- [Nat. Commun. 8, 976 (2017)](https://doi.org/10.1038/s41467-017-01209-9)
- [Phys. Rev. B 96, 075206 (2017)](https://doi.org/10.1103/PhysRevB.96.075206)
- [Phys. Rev. B 95, 115307 (2017)](https://doi.org/10.1103/PhysRevB.95.115307)
- [Nat. Commum. 7, 11747 (2016)](https://doi.org/10.1038/ncomms11747)
- [Phys. Rev. X 5, 031022 (2015)](https://doi.org/10.1103/PhysRevX.5.031022)
- [Phys. Rev. B 91, 245312 (2015)](https://doi.org/10.1103/PhysRevB.91.245312)
- [Proc. Natl. Acad. Sci. 111, 16309 (2014)](https://doi.org/10.1073/pnas.1413477111)
- [Phys. Rev. B 85, 214505 (2012)](https://doi.org/10.1103/PhysRevB.85.214505)
- [Nat. Phys. 8, 534 (2012)](https://doi.org/10.1038/Nphys2321)
- [Phys. Rev. B 82, 081305(R) (2010)](https://doi.org/10.1103/PhysRevB.82.081305)
- [Science 328, 474 (2010)](https://doi.org/10.1126/science.1187399)
- [Science 323, 923 (2009)](https://doi.org/10.1126/science.1166138)
- [Nature 454, 1072 (2008)](https://doi.org/10.1038/nature07243)
- [Nat. Phys. 3, 865 (2007)](https://doi.org/10.1038/nphys753)
- [Phys. Rev. Lett. 99, 057208 (2007)](https://doi.org/10.1103/PhysRevLett.99.057208)
- [Science 315, 1380 (2007)](https://doi.org/10.1126/science.1138584)
- [Phys. Rev. B 70, 161103 (2004)](https://doi.org/10.1103/PhysRevB.70.161103)
- [Phys. Rev. Lett. 93, 097004 (2004)](https://doi.org/10.1103/PhysRevLett.93.097004)
</details>

## Gif movies

### Color tables
More than 200 color tables, which are scientifically derived, are imported.

<img src="https://raw.githubusercontent.com/yuksk/SIDAM/main/docs/assets/images/color.png" width="441px" height="264px" alt="color">

### Auto color range adjustment
The color range is adjusted to statistical values such as 3&#963; below and above the average of the shown image.

<img src="https://raw.githubusercontent.com/yuksk/SIDAM/main/docs/assets/images/autorange.gif" width="262px" height="182px" alt="autorange">

### Spectrum viewer
The interactive viewer of a spectrum or spectra.
Positions of spectra can be acquired from any image, e.g., a simultaneous topograph.

<img src="https://raw.githubusercontent.com/yuksk/SIDAM/main/docs/assets/images/spectrum.gif" width="381px" height="160px" alt="spectrum">

<img src="https://raw.githubusercontent.com/yuksk/SIDAM/main/docs/assets/images/linespectra.gif" width="278px" height="286px" alt="linespectra">

### Line profile
Line profiles for 2D and 3D waves.
Both waterfall and intensity plots are available for 3D waves.

<img src="https://raw.githubusercontent.com/yuksk/SIDAM/main/docs/assets/images/lineprofile.gif" width="277px" height="160px" alt="lineprofile">

### Synchronize layer, axis range, cursor
Synchronize the layer index, ranges of axes, and cursor positions of multiple images.

<img src="https://raw.githubusercontent.com/yuksk/SIDAM/main/docs/assets/images/synclayer.gif" width="260px" height="160px" alt="synclayer">  
<img src="https://raw.githubusercontent.com/yuksk/SIDAM/main/docs/assets/images/syncaxisrange.gif" width="260px" height="160px" alt="syncaxisrange">  
<img src="https://raw.githubusercontent.com/yuksk/SIDAM/main/docs/assets/images/synccursor.gif" width="260px" height="160px" alt="synccursor">

### Position recorder
Record positions you click in a wave. For example, if you click on impurities, the dimension of the resultant wave gives the number of impurities.

<img src="https://raw.githubusercontent.com/yuksk/SIDAM/main/docs/assets/images/position_recorder.gif" width="249px" height="148px" alt="synclayer">


Data: BiTeI, https://doi.org/10.1103/PhysRevB.91.245312

