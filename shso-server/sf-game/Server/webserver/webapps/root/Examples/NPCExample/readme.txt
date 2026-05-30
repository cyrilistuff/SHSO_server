::::::::::::::::::::::::::::::::::::::::::::::::::::
:: SmartFoxServer PRO 1.6.6 - update -            ::
:: April 2009                                     ::
:: (c) gotoAndPlay() - All rights reserved        ::
:: .............................................. ::
:: www.smartfoxserver.com                         ::
:: www.gotoandplay.it                             ::
::::::::::::::::::::::::::::::::::::::::::::::::::::

The sample extension uses the AvatarChat example client (See Examples/AS2/04_avatarChat) and adds a new room with an NPC that moves around and sends public messages to the people in that same room.

The extension is written in Java, it is very simple and fully commented.

How to test it:
Copy the it/gotoandplay/extensions/examples/npc package to the javaExtensions/ folder.

Open your config.xml, locate the simpleChat Zone and add the extension like this:

<Extensions>   
   <extension name="npcExt" className="it.gotoandplay.extensions.examples.npc.NpcAvatarExample2" type="java" />
</Extensions>

Finally restart the SmartFoxServer and launch the provided client example (04_avatarChat folder). You will find a new room with a user already inside that interacts with the other real users.

