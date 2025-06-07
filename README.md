# Godot Sound Library Browser
For Godot 4.4

A sound library browser to browse YOUR sounds and music and move them to your project with one click.


## Use Case
Don't want to manually move sounds or music from your potentially massive library to your project? This addon is for you and your team!


## Features
- Searches a given directory for sound files (.wav, .mp3 and .ogg)
- Displays the sounds in a list where you listen to each one individualy
- Allows you the search your library for keywords
- Allows you to check a box that will copy the sounds into a given directory in your project
- Once copied it allows you to copy the resource path ("res://" or uid://) to use in e.g. scripts
- Allows you to remove sounds that were copied if you change your mind


## Usage
- Navigate to the SoundLibrary Dock at the bottom of Godot
- First Time Setup: It will show a settings panel where you can enter the path to your Sound-Library as well as enter the path where you want the sounds to end up inside your project.
- After saving your settings it will search the library path for sounds (This may take some time)

![Initial Setup](/usage/SoundLibraryBrowserPluginSetup.gif)

- When finished, it will show you the first 10 sounds.
- You can now search for keywords by using the search bar at the top
- Navigate the Pages of Sounds using the arrwows at the bottom
- Preview/Listen to sounds using the play button
- You can skip forward or backward by using the "slider" next to the play button

![Search and play](/usage/SoundLibraryBrowserPluginSearchAndPlay.gif)

- Found something you like? Add it to your project by ticking the "Use in project?"-Checkbox
- Changed your mind? Remove sounds by unticking the Checkbox
- Copy res:// or uid:// paths using the respective buttons

![Add or remove](/usage/SoundLibraryBrowserPluginAddAndRemove.gif)

## Installation

### Godot Asset Library
This package is available as a plugin, meaning it can be added to an existing project. 

![Package Icon](/icon.png)

When editing an existing project:

1.  Go to the `AssetLib` tab.
2.  Search for "Sound Library Browser" (Author: RustyPrime) or click here: [Godot AssetLib](https://godotengine.org/asset-library/asset/4082)
3.  Click on the addon to show details.
4.  Click to Download.
5.  Make sure that the contents are installed to `addons/` and there are no conflicts.
6.  Click to Install.
8.  Enable the plugin from the Project Settings > Plugins tab.


### GitHub
1.  Download the latest version from [GitHub](https://github.com/RustyPrime/GodotSoundLibraryBrowser/releases/latest).  
2.  Extract the contents of the archive.
3.  Move the `addons/SoundLibraryBrowser` folder into your project's `addons/` folder.  
5.  Enable the plugin from the Project Settings > Plugins tab.  


## My Setup
- I'm using Godot 4.4.1
- Using a raspberry pi with samba as a fileshare server.
- After mapping the raspberry pi to a network drive in windows, my SO and i are able to browse sounds hosted on the raspberry within Godot,


## Using this plugin to develop a shipped game? Tell me about it, i would love to feature them here!
- A game by my SO and me, TBA
