+-----------------------------------------------------------------------
+ OpenSpace TRIAL EDITION
+ (c) 2004 - 2008 gotoAndPlay()
+
+ www.openspace-engine.com
+ www.smartfoxserver.com
+ www.gotoandplay.it
+
+  All rights reserved.
-----------------------------------------------------------------------

OPENSPACE TRIAL EDITION LIMITATIONS

This trial version of OpenSpace comes with some limitations:
- a maximum number of 20 concurrent avatars can be displayed on the same map;
- the "POWERED BY OPENSPACE" link appears at the top right corner of the OpenSpace viewport;
- the OpenSpace Editor can export maps with a maximum size of 15x15 tiles only: larger maps will be trimmed down to the maximum allowed size;
- during map loading the OpenSpace logo and link are displayed, together with a loading progress bar;
- when the skin of an avatar is changed (through the "OpenSpace.setMyAvatarSkin" method), this action is not broadcasted to the other clients;
- the following methods are not available (check the API documentation for their description): "OpenSpace.centerViewOnMyAvatar", "OpenSpace.centerViewOnTile", "OpenSpace.moveMyAvatar", "OpenSpace.teleportMyAvatar", "OpenSpace.zoomOnMyAvatar".
- the "OpenSpace.fadingParams" property to control the map fade-in and fade-out effects is missing;
- the "OpenSpaceEvent.MAP_CREATION_PROGRESS" event fired during map rendering is missing (replaced by the progress bar under the OpenSpace logo).