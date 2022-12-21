---
title: "Getting started"
layout: single
sidebar:
    nav: "top"
---
## Install

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

If you use Igor Pro 8, you need an extension file. See issue [#37](
https://github.com/yuksk/SIDAM/issues/37).

## Launch SIDAM
Launch Igor Pro, choose *Menubar > Macros > SIDAM* in Igor Pro, and you will
find a new menu item *SIDAM* in the menu bar. If Igor Pro is already running,
you need to restart it after installing SIDAM.

## Load data file
Choose *Menubar > SIDAM > Load Data... > from a File...*. Alternatively,
you can drag and drop data files into the window of Igor Pro.
Supported files are Nanonis files (.dat, .sxm, .3ds, .nsp).

## Show data
Choose a wave(s) you want to show in the Data Browser and
choose *Menubar > SIDAM > Display... > Display Selected Waves*.
Alternatively, you can press F3 after choosing a wave(s) you want to show in
the Data Browser.

## Subsequent analysis
Click ☰ in the control bar of a window and you will find menu items of
analysis available for the data shown in the window.
