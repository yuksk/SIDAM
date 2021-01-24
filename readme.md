# SIDAM

``SIDAM`` is a **s**pectroscopic **i**maging **d**ata **a**nalysis **m**acro written in Igor Pro.
``SIDAM`` is designed so that you can easily perform basic analyses and can concentrate on searching something new.
You can use ``SIDAM`` via both GUI and CUI.
You do not have to remember each command, but at the same time you can incorporate SIDAM functions into your scripts.

Here is a list of frequently used basic features:
- Flexible interactive viewer
  - A spectrum or an image
  - A spectrum or spectra along a line from a map
  - A layer of map
  - Line profiles
  - Synchronize multiple images (axis range, layer index, and cursor position)
- Color range adjustment (both fixed and flexible values)
- Color table selection (more than 100 tables are imported from outside)
- Background subtraction
- Fourier analysis
  - Fourier transform
  - Fourier filter
  - Symmetrize Fourier transform
- Correlation
- Histogram
- Work function

## Requirement

Igor Pro 8 or later.

## Install/Update/Uninstall

### Install

After cloning or downloading the macro files, copy them to the designated folders.
```
SIDAM/
├ src/
│  ├ SIDAM.ipf -> Copy to Igor Procedures
│  └ SIDAM/ -> Copy to User Procedures
├ script/
└ LICENSE/
```

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

### Uninstall

Remove all the files you copied when you installed.
