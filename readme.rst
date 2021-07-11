SIDAM
=====

*SIDAM* is a **S**\ pectroscopic **I**\ maging **D**\ ata **A**\ nalysis
**M**\ acro written in Igor Pro. *SIDAM* is designed so that you can easily
perform basic analyses and can concentrate on searching something new.
You can use *SIDAM* via both GUI and CLI. Everything can be done from the menus
and subsequent panels so you do not have to remember each command. At the same
time, you can do the same thing by calling commands, meaning that you can
incorporate SIDAM functions into your scripts.

Here is a list of frequently used basic features:

- Flexible interactive viewer

  - A spectrum or an image
  - A spectrum or spectra along a line from a map
  - A layer of map
  - Line profiles
  - Synchronize multiple images (axis range, layer index, and cursor position)

- Color range adjustment (both fixed and flexible values)
- Color table selection (more than 200 tables are imported from outside)
- Background subtraction
- Fourier analysis

  - Fourier transform
  - Fourier filter
  - Symmetrize Fourier transform

- Correlation
- Histogram
- Work function


Requirement
-----------

Igor Pro 8 or 9.

Getting started
---------------

Install
^^^^^^^

After cloning or downloading the macro files, copy them to the designated folders.
::

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

Launch SIDAM
^^^^^^^^^^^^
Lanuch Igor Pro, choose *Menubar > Macros > SIDAM* in Igor Pro, and you will
find a new menu item *SIDAM* in the menu bar. If Igor Pro is already running,
you need to restart it after installing SIDAM.

Load data file
^^^^^^^^^^^^^^
Choose *Menubar > SIDAM > Load Data... > from a File...*. Alternatively,
you can drag and drop data files into the window of Igor Pro.
Supported files are Nanonis files (.dat, .sxm, .3ds, .nsp).

Show data
^^^^^^^^^
Choose a wave(s) you want to show in the Data Browser and
choose *Menubar > SIDAM > Display... > Display Selected Waves*.
Alternatively, you can press F3 after choosing a wave(s) you want to show in
the Data Browser.

Subsequent analysis
^^^^^^^^^^^^^^^^^^^
Right-click the control bar shown in a window and you will find menu items of
analysis available for the data shown in the window.

Documents
---------

The command help is available at https://yuksk.github.io/SIDAM/index.html
