package it.gotoandplay.extensions.examples.npc;

import java.util.HashMap;
import java.util.Map;
import java.util.Random;

import it.gotoandplay.smartfoxserver.data.Room;
import it.gotoandplay.smartfoxserver.data.User;
import it.gotoandplay.smartfoxserver.data.UserVariable;
import it.gotoandplay.smartfoxserver.data.Zone;
import it.gotoandplay.smartfoxserver.events.InternalEventObject;
import it.gotoandplay.smartfoxserver.exceptions.ExtensionHelperException;
import it.gotoandplay.smartfoxserver.extensions.AbstractExtension;
import it.gotoandplay.smartfoxserver.extensions.ExtensionHelper;
import it.gotoandplay.smartfoxserver.lib.ActionscriptObject;
import it.gotoandplay.smartfoxserver.util.scheduling.ITaskHandler;
import it.gotoandplay.smartfoxserver.util.scheduling.Scheduler;
import it.gotoandplay.smartfoxserver.util.scheduling.Task;

/**
 * Simple NPC Example
 * based on the AvatarChat Example provided with SmartFoxServer official documentation
 * 
 * This extensions can be added to the 'simpleChat' Zone to add a new special room called "NpcRoom" in the chat
 * In that room you will find an NpcUser which will move around automatically and send public messages. 
 * 
 * @author Lapo
 *
 */
public class NpcAvatarExample2 extends AbstractExtension
{
	private static final String NPC_ROOM_NAME = "Npc Room";
	private static final String NPC_USER_NAME = "NpcUser"; 
	
	// These are the max X and Y coordinates that an avatar can move to
	private static final int MAX_XPOS = 479;
	private static final int MAX_YPOS = 278;
	
	Zone currentZone;
	ExtensionHelper api;
	Scheduler scheduler;
	
	Room npcRoom = null;
	User npcUser;
	
	Random rnd;
	
	@Override
	public void init()
	{
		rnd = new Random();
		scheduler = new Scheduler();
		api = ExtensionHelper.instance();
		currentZone = api.getZone(getOwnerZone());
	}
	
	/**
	 * Initialize the Npc Room and Npc User
	 */
	void prepareNpcs()
	{
		try
        {
	        initNpcRoom();
	        initNpcUsers();
        }
        catch (ExtensionHelperException e)
        {
	        e.printStackTrace();
        }
	}
	
	
	/**
	 * Initialize room
	 */
	void initNpcRoom() throws ExtensionHelperException
	{
		// Create NPC Room if it doesn't exists
		npcRoom = currentZone.getRoomByName(NPC_ROOM_NAME);
		
		if (npcRoom == null)
		{
			Map<String, String> params = new HashMap<String, String>();
			params.put("name", NPC_ROOM_NAME);
			params.put("maxU", "20");
			params.put("isGame", "false");
			
			npcRoom = api.createRoom(	currentZone, 
										params, 
										null, 
										true, 
										false
									);
			
			trace("NpcRoom created.");
		}
	}
	
	/**
	 * Create the Npc User
	 */
	void initNpcUsers() throws ExtensionHelperException
	{
		if (npcRoom == null)
			throw new IllegalStateException("Can't initialize NPC users, the NPC Room doesn't exist!");

		if (npcUser == null)
		{
			npcUser = api.createNPC(NPC_USER_NAME, "127.0.0.1", 9339, getOwnerZone());
			setupUser(npcUser);
				
			/*
			 * Setup a new Scheduler task that moves the avatar every 7 seconds to a random screen location
			 */
			scheduler.addScheduledTask(	new Task("move"), 
										7, 
										true, 
										new ITaskHandler()
										{
											public void doTask(Task task) throws Exception
											{
												if (task.id.equals("move"))
												{
													int px = rnd.nextInt(MAX_XPOS);
													int py = rnd.nextInt(MAX_YPOS);
													
													String message = String.format("Moving to %s, %s", px, py);
													api.dispatchPublicMessage(message, npcRoom, npcUser);
													
													// Set the following UserVariables --> px, py, init
													HashMap<String, UserVariable> vars = new HashMap<String, UserVariable>();
													vars.put("px", new UserVariable(String.valueOf(px), UserVariable.TYPE_NUMBER));
													vars.put("py", new UserVariable(String.valueOf(py), UserVariable.TYPE_NUMBER));
													vars.put("init", new UserVariable("false", UserVariable.TYPE_BOOLEAN));
													
													api.setUserVariables(npcUser, vars, true);
												}
											}
										}
									);
		}
		
		trace("Npc created and joined.");
	}
	
	/**
	 * Set up the avatar, by setting the initial x and y position and the avatar color
	 */
	private void setupUser(User u) throws ExtensionHelperException
	{
		// join the user
		api.joinRoom(u, -1, npcRoom.getId(), false, "", false, true);
		
		// set the avatar color and position
		int col = 1 + rnd.nextInt(8); 
		int px = rnd.nextInt(MAX_XPOS);
		int py = rnd.nextInt(MAX_YPOS);
		
		// Set the following UserVariables --> px, py, col, init
		HashMap<String, UserVariable> vars = new HashMap<String, UserVariable>();
		vars.put("px", new UserVariable(String.valueOf(px), UserVariable.TYPE_NUMBER));
		vars.put("py", new UserVariable(String.valueOf(py), UserVariable.TYPE_NUMBER));
		vars.put("col", new UserVariable(String.valueOf(col), UserVariable.TYPE_NUMBER));
		vars.put("init", new UserVariable("true", UserVariable.TYPE_BOOLEAN));
		
		api.setUserVariables(u, vars, true);
	}
	
	
	@Override
	public void destroy()
	{
		api.disconnectUser(npcUser);
	}
	
	
	// We don't handle any events in this example
	public void handleInternalEvent(InternalEventObject event)
	{ 
		if (event.getEventName().equals(InternalEventObject.EVENT_SERVER_READY))
		{
			System.out.println("-----> SERVER READY <-----");
			prepareNpcs();
		}		
	}
	
	// Request handlers, not used in this example
	public void handleRequest(String arg0, ActionscriptObject arg1, User arg2, int arg3) { }
	public void handleRequest(String arg0, String[] arg1, User arg2, int arg3) { }
}
