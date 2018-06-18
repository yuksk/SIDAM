# Requirement

Igor Pro 7 is required. Practically, however, Igor Pro 8 is recommended because the macro is developed with Igor Pro 8 and not tested with Igor Pro 7. Since no functions of Igor Pro 8 have been used so far, the macro is expected to work in Igor Pro 7 but not guaranteed.


# How to install

Move the macro files to the designated folders as follows.
The way in the braket [] is recommended for git users.

1. Download the macro file and unzip it.
[Pull a branch from the repository.]

2. Find Igor Pro User Files Folder (UserFiles). You can find it by selecting Igor Pro menu, Misc > Miscellaneous Settings > Igor User Files.
(e.g.) C:\Users\(yourname)\Documents\WaveMetrics\Igor Pro 8 User Files

3. Move SIDAM.ipf to \UserFiles\Igor Procedures.
[Make a shortcut or a symbolic link of SIDAM.ipf in \UserFiles\Igor Procedures.]

4. Move SIDAM folder to \UserFiles\User Procedures. 
[Make a shortcut of a symbolic link of SIDAM folder in \UserFiles\User Procedures.]

Windows user: if you have not changed the location of \UserFiles, install.bat in the Utilities folder is also available to copy the file and folder to the designated folders.


# How to update

Remove old files and move new ones.
Git user: if you follow the above recommendation in installing the macro, you can just pull a branch from the repository instead of #1-#3 below. Even in this case, do not forget #4.

1. Download the macro file and unzip it.
2. Remove old macro files except those in the extension folder if you added.
3. Install new files as above.
4. Start the macro (alternatively open SIDAM.itx in the Utilities folder).

If you skip #4 and open an existing experiment file, a compile error may occur.

Windows user: if you have not changed the location of \UserFiles, update.bat in the Utilities folder is available as an alternative of #2 and #3. You still need #4.


# How to uninstall

Remove all installed files.