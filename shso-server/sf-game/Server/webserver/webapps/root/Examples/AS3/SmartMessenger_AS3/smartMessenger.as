/**
 * SmartMessenger Example Application for SmartFoxServer PRO
 * Flex 2 / Actionscript 3.0 version
 * 
 * version 1.0.0
 * (c) gotoAndPlay() 2007
 * 
 * www.smartfoxserver.com
 * www.gotoandplay.it
 */

import it.gotoandplay.smartfoxserver.*;
  
import flash.net.URLLoader;
import flash.net.URLRequest;
import flash.events.Event;
import flash.events.IOErrorEvent;
import mx.controls.Alert;
import mx.collections.ArrayCollection;
import mx.collections.Sort;
import mx.collections.SortField;
import mx.managers.PopUpManager;
import components.ChatWindow;
import mx.core.IFlexDisplayObject;
import mx.controls.Button;
import mx.controls.RadioButton;
 
 
//--- Private members -----------------------------------------------
private var sfs:SmartFoxClient
private var serverIp:String = "127.0.0.1"
private var serverPort:int = 9339
private var serverZone:String = "messenger"
private var xtName:String = "smsg"

private var myId:int
private var myName:String
private var isLobbyJoined:Boolean = false
private var componentsReady:Boolean = false
private var curBrowserId:int
private var chatWindowList:Array
private var lastFocusedChatWindow:ChatWindow

private const configFile:String = "./config.xml";

[Embed(source="images/light_grey.png")]
private static var STATUS_OFFLINE:Class;

[Embed(source="images/light_green.png")]
private static var STATUS_AVAILABLE:Class;

[Embed(source="images/light_yellow.png")]
private static var STATUS_BRB:Class;

[Embed(source="images/light_red.png")]
private static var STATUS_BUSY:Class;

private static var TOKEN:String = "$$$"


/**
* Application init
*/
public function initApp():void
{	
	chatWindowList = []
	sfs = new SmartFoxClient(true)
	
	sfs.addEventListener(SFSEvent.onConnection, onConnection)
	sfs.addEventListener(SFSEvent.onExtensionResponse, onExtensionResponse)
	sfs.addEventListener(SFSEvent.onRoomListUpdate, onRoomListUpdate)
	sfs.addEventListener(SFSEvent.onJoinRoom, onJoinRoom)
	sfs.addEventListener(SFSEvent.onBuddyList, onBuddyList)
	sfs.addEventListener(SFSEvent.onBuddyListError, onBuddyListError)
	sfs.addEventListener(SFSEvent.onBuddyListUpdate, onBuddyListUpdate)
	sfs.addEventListener(SFSEvent.onPrivateMessage, onPrivateMessage)
	sfs.addEventListener(SFSEvent.onConnectionLost, onConnectionLost)
	sfs.addEventListener(SFSEvent.onLogout, onLogout)
	
	loadConfigData()		
}


/**
 * load xml configuration file
 */
private function loadConfigData():void
{
	var loader:URLLoader = new URLLoader()
	loader.addEventListener(Event.COMPLETE, onConfigLoaded)
	loader.addEventListener(IOErrorEvent.IO_ERROR, onConfigLoadFailed)
	
	loader.load(new URLRequest(configFile))
}


/**
 * handles the successfull loading of the config file
 */
public function onConfigLoaded(evt:Event):void
{
	var loader:URLLoader = evt.target as URLLoader
	var xmlDoc:XML = new XML(loader.data)
	
	serverIp = xmlDoc.ip
	serverPort = int(xmlDoc.port)
	serverZone = xmlDoc.zone 
	xtName = xmlDoc.xtName
	
	connect()
}

/**
* Establish connection with the server
*/
public function connect():void
{
	sfs.connect(serverIp, serverPort)
}


/**
 * Handles configuration load failure
 */
public function onConfigLoadFailed(evt:Event):void
{
	lb_connStatus.text = "Failed loading configuration file"	
}


/**
 * Handles click on the login button
 */
public function bt_login_click():void
{
	if (tf_name.text.length > 0)
	{
		sfs.login(serverZone, tf_name.text, "")
	}	
}

/**
 * Handle click on the logout button
 */
public function bt_logout_click(evt:Event):void
{
	sfs.logout();
}


/**
 * Handles click on the "Add to buddy list"
 */
public function bt_add_buddy():void
{
	var buddyName:String = uBrowser.tf_nick.text
	
	if (myName != buddyName)
		sfs.addBuddy(buddyName)
}


/**
 * Handles click on the "Remove" button
 */
public function bt_remove_buddy():void
{
	if (cList.list_buddies.selectedItem != null)
	{
		var buddyName:String = cList.list_buddies.selectedItem.data.name
		sfs.removeBuddy(buddyName)	
	}
}


/**
 * Handles click on the "Message" button
 */
public function bt_message_buddy():void
{
	if (cList.list_buddies.selectedItem != null)
	{
		var buddy:Object = cList.list_buddies.selectedItem.data
	
		startNewPrivateChat(buddy)
	}
}


/**
 * Handles click on the "Send" button in the chat window
 */
public function bt_send_message(evt:Event):void
{
	var window:ChatWindow = (evt.target as Button).parentDocument as ChatWindow
	
	if (window.tf_message.text.length > 0)
	{
		sfs.sendPrivateMessage(myId + TOKEN + window.tf_message.text, window.buddy.id)
		window.tf_message.text = ""
		
		lastFocusedChatWindow = window
	}
}


/**
 * Handles click on the "X" button in the Chat Window
 */
public function bt_close_chat(evt:Event):void
{
	var window:ChatWindow = evt.target as ChatWindow
	var buddy:Object = window.buddy
	PopUpManager.removePopUp(window)
	
	// Remove from list
	delete chatWindowList[buddy.name]	
}


/**
 * Set the IM current status
 * 0 = available
 * 1 = be right back
 * 2 = busy
 */
public function handle_status_change(evt:Event):void
{
	var radioBtn:RadioButton = evt.target as RadioButton
	var bvars:Array = []
	bvars["st"] = radioBtn.value
	
	sfs.setBuddyVariables(bvars)
}


/**
 * 
 */
public function backToLoginScreen():void
{
	viewstack.selectedChild = view_connecting
	connect()
}


/**
* Request the next user
*/
public function requestNextUser():void
{
	sfs.sendXtMessage(xtName, "nextU", {id:curBrowserId})
}

	
/**
* Request the previous user
*/
public function requestPrevUser():void
{
	sfs.sendXtMessage(xtName, "prevU", {id:curBrowserId})
}


/**
 * Start a new chat window
 */
private function startNewPrivateChat(buddy:Object):void
{
	if (buddy.isOnline)
	{
		var window:ChatWindow = new ChatWindow()
		window.title = "Private Chat with " + buddy.name
		window.buddy = buddy
		PopUpManager.addPopUp(window, this)
		PopUpManager.centerPopUp(window)
		
		randomMoveWindow(window)
		
		// keep a reference to the window
		chatWindowList[buddy.name] = window
	}
}


/**
 * Slightly alter the position of the window
 * once centered
 */
private function randomMoveWindow(win:ChatWindow):void
{
	var dx:int = int(Math.random() * 20)
	var dy:int = int(Math.random() * 20)
	var sx:int = Math.random() * 100 > 49 ? 1 : -1
	var sy:int = Math.random() * 100 > 49 ? -1 : 1
	
	win.x += dx * sx
	win.y += dy * sy
}


/**
 * Event is fired when the messenger view is ready
 */
public function onMessengerViewReady():void
{
	if (!componentsReady)
		componentsReady = true
		
	cList.rb_available.selected = true
	cList.title = myName + "'s Buddy List"	
	// Load the buddy list
	sfs.loadBuddyList()
	
	// Init the members browser
	requestNextUser()
}


/**
 * handles the icon in the buddy list (mx:List component)
 */
public function blistIconFunction(o:Object):Class
{
	var buddy:Object = o.data
	var icon:Class = STATUS_OFFLINE
	
	if (buddy.isOnline)
	{
		icon = STATUS_AVAILABLE
		
		if (buddy.variables.st != undefined)
		{
			if (buddy.variables.st == 1)
				icon = STATUS_BRB
			else if (buddy.variables.st == 2)
				icon = STATUS_BUSY
		}
		else
			icon = STATUS_AVAILABLE
	}
		
	return icon 
}


/**
* Find the buddy name
* 
* @param	id	the buddy id
* @return	the buddy name
*/
private function getBuddy(id:int):Object
{
	var b:Object = null
	
	for each (var buddy:Object in sfs.buddyList)
	{			
		if (buddy.id == id)
		{
			b = buddy
			break
		}
	}
	 
	 return b
}


//------------------------------------------------------------------------
// SmartFoxServer event handlers
//------------------------------------------------------------------------

public function onConnection(evt:SFSEvent):void
{
	var ok:Boolean = evt.params.success
				
	if (ok)
	{
		// Change view: login
		viewstack.selectedChild = view_login
	}
	else
	{
		// Show error
		lb_connStatus.text = "Failed connecting to " + serverIp + ":" + serverPort 
	}
}


public function onExtensionResponse(evt:SFSEvent):void
{
	var dataObj:Object = evt.params.dataObj
	var cmd:String = dataObj._cmd
	
	// Login success
	if (cmd == "logOK")
	{
		myId = dataObj.id
		myName = dataObj.name
		sfs.getRoomList()
	}
	
	// Login failed
	else if (cmd == "logKO")
	{
		Alert.show(dataObj.err, "Login Failed", mx.controls.Alert.OK)
	}
	
	// user profile loaded
	else if (cmd == "usr")
	{
		if (!uBrowser.bt_add.enabled)
		{
			uBrowser.bt_add.enabled = true
			uBrowser.bt_next.enabled = true
			uBrowser.bt_prev.enabled = true
		}
		
		curBrowserId = dataObj.id
		var user:Object = dataObj.usr
		
		uBrowser.tf_nick.text = user.nick
		uBrowser.tf_age.text = user.age
		uBrowser.tf_location.text = user.location
		uBrowser.tf_email.text = user.email
		uBrowser.tf_hobbies.text = user.interest
	}
}



public function onRoomListUpdate(evt:SFSEvent):void
{
	// Auto join default room
	sfs.autoJoin()
}


public function onJoinRoom(evt:SFSEvent):void
{
	if (!isLobbyJoined)
	{
		isLobbyJoined = true;
		
		// Change view, this will fire -> onMessengerViewReady()
		viewstack.selectedChild = view_chat
		
		// This event is fired once only, when the viewstack first initialize the view
		// So we need to fire it manually in case you move away from the "chat" view
		if (componentsReady)
			onMessengerViewReady()
	}
}


// Populate the buddy list
public function onBuddyList(evt:SFSEvent):void
{
	var dp:ArrayCollection = new ArrayCollection()
		
	for each (var buddy:Object in evt.params.list)
	{
		dp.addItem( {label:buddy.name, data:buddy} )
	}
	
	// Sort provider alphabetically
	var sort:Sort = new Sort()
	sort.fields = [new SortField("label")]
		
	dp.sort = sort
	dp.refresh()
	
	cList.list_buddies.dataProvider = dp
	cList.list_buddies.invalidateList()
}


// Handle errors in loading the buddylist
public function onBuddyListError(evt:SFSEvent):void
{
	Alert.show("Error loading buddy list", "BuddyList Load error", mx.controls.Alert.OK);	
}


// Handle updates in the buddy list
public function onBuddyListUpdate(evt:SFSEvent):void
{
	var buddy:Object = evt.params.buddy
	var dp:ArrayCollection = cList.list_buddies.dataProvider as ArrayCollection

	// Look for the item with the same name of the item passed to the function
	for (var i:int = 0; i < dp.length; i++)
	{
		var b:Object = dp.getItemAt(i).data

		if (buddy.name == b.name)
		{
			// Replace item
			dp.setItemAt({label:buddy.name, data:buddy}, i)
			break
		}
	}
	
	// Update list
	dp.refresh()
	cList.list_buddies.invalidateList()
	
	// Update chat window, if exist
	var window:ChatWindow = chatWindowList[buddy.name]
	
	if (window != null)
	{
		window.vbox.enabled = buddy.isOnline
		window.buddy = buddy
		
		if (!buddy.isOnline)
			window.ta_chat.htmlText += "<font color='#FF3300'>" + buddy.name + " went offline!</font>"
		else
		{
			var status:String = "available"
			if (buddy.variables.st == 1)
				status = "away"
			else if (buddy.variables.st == 2)
				status = "busy"
				
			window.ta_chat.htmlText += "<font color='#FF3300'>" + buddy.name + " is now " + status + " !</font>"
		}	
		window.ta_chat.verticalScrollPosition = window.ta_chat.maxVerticalScrollPosition
		
	}	
}


/**
 * Handles private messages
 * 
 * messages are made of two parameters:
 * senderId and message separated by a token, defined as "const" at the top of this code
 * 
 * When we get a PM, first we split the text into its 2 components
 * and then we proceed to show it in the right chat window.
 * 
 */
public function onPrivateMessage(evt:SFSEvent):void
{
	var pm:String = evt.params.message
	
	if (pm.indexOf(TOKEN) > 0)
	{
		var data:Array = pm.split(TOKEN)
			
		var senderId:int = int(data[0])
		var message:String = data[1]
		
		var sender:Object
		var senderName:String
		var win:ChatWindow
	
		/**
		 * If it's not me the one who sent the message then
		 * let's look for the right window to show this message in
		 */
		if (senderId != myId)
		{
			sender = getBuddy(senderId)
			
			if (sender != null)
			{
				// Check if chat window exist
				if (chatWindowList[sender.name] == null)
					startNewPrivateChat(sender)
					
				win = chatWindowList[sender.name]
				senderName = sender.name
			}
			
		}
		
		/**
		 * ... otherwise we can add the message
		 * to the last selected chat window
		 */
		else
		{
			win = lastFocusedChatWindow
			senderName = myName
		}
		
		win.ta_chat.htmlText += "<b><font color='#cc0000'>" + senderName + ": </font></b>" + message
		win.ta_chat.verticalScrollPosition = win.ta_chat.maxVerticalScrollPosition
	}
}


/**
 * Handle connection lost
 */ 
public function onConnectionLost(evt:SFSEvent):void
{
	resetChat()
	viewstack.selectedChild = view_logout
}

public function onLogout(evt:SFSEvent):void
{
	resetChat()
	viewstack.selectedChild = view_login
}

/**
 * Clear all chat windows
 * reset join status
 */
private function resetChat():void
{
	// reset flag
	isLobbyJoined = false
	
	// close all open chats
	for each (var win:ChatWindow in chatWindowList)
	{
		PopUpManager.removePopUp(win)
	}
	
	chatWindowList = []
}


