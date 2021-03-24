SIDAM
=====

*SIDAM* is a **S**\ pectroscopic **I**\ maging **D**\ ata **A**\ nalysis **M**\ acro written in Igor Pro.
*SIDAM* is designed so that you can easily perform basic analyses and can concentrate on searching something new.
You can use *SIDAM* via both GUI and CLI.
Everything can be done from the menus and subsequent panels so you do not have to remember each command.
At the same time, you can do the same thing by calling commands, meaning that you can incorporate SIDAM functions into your scripts.

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

Igor Pro 8 or later.

Install/Update/Uninstall
------------------------

Install
^^^^^^^

After cloning or downloading the macro files, copy them to the designated folders.::

   SIDAM/
   ├ LICENSE
   ├ readme.rst
   ├ script/
   └ src/
       ├ SIDAM.ipf -> Copy to Igor Procedures
       └ SIDAM/    -> Copy to User Procedures

1. Copy ``src/SIDAM.ipf`` and ``src/SIDAM`` to the Igor Procedures folder and the
   User Procedures folder, respectively. If you don't know where the folders are,
   choose ``Help > Show Igor Pro User Files`` in Igor Pro.

2. Restart Igor Pro, and choose ``Macros > SIDAM`` in Igor Pro to start SIDAM.

Instead of copying the file and folder, you can also make shortcuts or
symbolic links of them in the designated folders.

Update/Uninstall
^^^^^^^^^^^^^^^^

Remove all the files you copied when you installed, and install as above again.
If you made shortcuts or symbolic links when you installed, you can use
``git pull origin master``. to update files.

Uninstall
^^^^^^^^^^^^^^^^

Remove all the files you copied when you installed.

Documents
---------

The command help is available at https://yuksk.github.io/SIDAM/index.html
