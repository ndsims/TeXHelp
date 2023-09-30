# Installing

Download the .dmg file:

<a id="raw-url" href="https://github.com/ndsims/TeXHelp/releases/download/v1.1.5/TeXHelp.dmg">TeXHelp.dmg</a>

Alternatively, compile from source using XCode


# About TeXHelp

TeXHelp is a MacOS application that provides a user-friendly interface to the comprehensive help documents packaged with TeXLive:

<img src="UserGuide/HelpDoc.jpg" width="600px" align="center"> 

TeXHelp can also index all the pdf files in the TeXLive documentation, to try to identify individual LaTeX commands that are used in each document. This means that searches within TeXHelp can look for individual LaTeX commands, as well as the pdf title and the accompanying TeXLive package information:

<img src="UserGuide/AdvancedSearch.jpg" width="600px" align="center"> 

However, it can take TeXHelp a few hours to index the database when first installed.


# File locations
TEXHelp stores its database in the user’s Library/Containers/com.TeXHelp.TeXHelp folder. This appears as Library/Containers/TeXHelp in Finder. Within an Application Support sub-folder, an sqlite database is generated. For the default settings on TEXLive 2023, this requires about 370MB of storage. Within a Preferences subfolder, three plist files are used to save the configuration. All other files are within the TeXHelp.app.

# Uninstalling

1. Open TeXHelp, and then select
   
    TeXHelp > Settings....
   
   from the menu.
   Select 'Delete Database'.
   After the database is deleted, select 'Quit' from the new menu that appears.

   This step ensures that the Spotlight Index is fully removed, so that the system-wide spotlight search (e.g. CMD+spacebar searching) is not contaminated with spurious 'TeXHelp' entries. If this step is skipped, then the spurious entries are deleted by the system after 30 days.

3. Move TeXHelp.app to the bin.
  
4. Delete the user’s Library/Containers/com.TeXHelp.TeXHelp folder.

   
