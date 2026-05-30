import java.nio.channels.SocketChannel;
import java.util.*;

import it.gotoandplay.smartfoxserver.db.*;
import it.gotoandplay.smartfoxserver.data.*;
import it.gotoandplay.smartfoxserver.exceptions.*;
import it.gotoandplay.smartfoxserver.extensions.*;
import it.gotoandplay.smartfoxserver.lib.ActionscriptObject;
import it.gotoandplay.smartfoxserver.events.InternalEventObject;

public class ExtensionTemplate extends AbstractExtension
{
	/** 
	* Initializion point:
	* 
	* this method is called as soon as the extension
	* is loaded in the server.
	* 
	* You can add here all the initialization code
	*/
	public void init()
	{
		trace("Extension initialized");	
	}
	
	
	/**
	* This method is called by the server when an extension
	* is being removed / destroyed.
	* 
	* Always make sure to release resources like setInterval(s)
	* open files etc in this method.
	* 
	* In this case we delete the reference to the databaseManager
	*/
	public void destroy()
	{
		trace("Extension destroyed");
	}
	
	
	/**
	 * Handle Client Requests in XML format
	 * 
	 * @param cmd		the command name
	 * @param ao		the actionscript object with the request params
	 * @param u			the user who sent the request
	 * @param fromRoom	the roomId where the request was generated
	 */
	public void handleRequest(String cmd, ActionscriptObject ao, User u, int fromRoom)
	{
		// Your code here
	}
	
	
	/**
	 * Handle Client Requests in String format
	 * 
	 * @param cmd		the command name
	 * @param params	an array of String parameters
	 * @param u			the user who sent the request
	 * @param fromRoom	the roomId where the request was generated
	 */
	public void handleRequest(String cmd, String params[], User u, int fromRoom)
	{
		// Your code here
	}
	
	/**
	 * Handle Internal Server Events
	 * 
	 * @param ieo		the event object
	 */
	public void handleInternalEvent(InternalEventObject ieo)
	{
		// Your code here
	}
}