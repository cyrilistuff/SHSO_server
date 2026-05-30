import flash.events.Event;
import mx.managers.PopUpManager;
import mx.controls.RadioButton;
import mx.controls.Button;
import mx.controls.Alert;
import mx.collections.ArrayCollection;
import mx.collections.Sort;
import mx.collections.SortField;

import components.ChatWindow;

import it.gotoandplay.smartfoxserver.SmartFoxClient;
import it.gotoandplay.smartfoxserver.SFSEvent;
import it.gotoandplay.smartfoxserver.data.Room;
import it.gotoandplay.smartfoxserver.data.User;

import com.smartfoxserver.redbox.AVChatManager;
import com.smartfoxserver.redbox.events.RedBoxChatEvent;
import com.smartfoxserver.redbox.data.ChatSession;


private const XT_NAME:String = "smsg";
private const TOKEN:String = "$$$";

[Embed(source="images/light_grey.png")]
private static var STATUS_OFFLINE:Class;

[Embed(source="images/light_green.png")]
private static var STATUS_AVAILABLE:Class;

[Embed(source="images/light_yellow.png")]
private static var STATUS_BRB:Class;

[Embed(source="images/light_red.png")]
private static var STATUS_BUSY:Class;


private var smartFox:SmartFoxClient;
private var red5IpAddress:String;
private var avChatMan:AVChatManager;
private var inited:Boolean;
private var componentsReady:Boolean;
private var curBrowserId:int;
private var chatWindowList:Array;
private var lastFocusedChatWindow:ChatWindow;


//---------------------------------------------------------------------
// Public methods
//---------------------------------------------------------------------

public function init():void
{
	// Create SmartFoxServer instance
	smartFox = new SmartFoxClient()
	smartFox.addEventListener(SFSEvent.onConfigLoadSuccess, onConfigLoadSuccess)
	smartFox.addEventListener(SFSEvent.onConfigLoadFailure, onConfigLoadFailure)
	smartFox.addEventListener(SFSEvent.onConnection, onConnection)
	smartFox.addEventListener(SFSEvent.onExtensionResponse, onExtensionResponse)
	smartFox.addEventListener(SFSEvent.onJoinRoom, onJoinRoom)
	smartFox.addEventListener(SFSEvent.onRoomListUpdate, onRoomListUpdate)
	smartFox.addEventListener(SFSEvent.onBuddyList, onBuddyList)
	smartFox.addEventListener(SFSEvent.onBuddyListError, onBuddyListError)
	smartFox.addEventListener(SFSEvent.onBuddyListUpdate, onBuddyListUpdate)
	smartFox.addEventListener(SFSEvent.onPrivateMessage, onPrivateMessage)
	smartFox.addEventListener(SFSEvent.onConnectionLost, onConnectionLost)
	
	// Set login panel state and label
	loginPanel.currentState = "connection"
	loginPanel.tf_connection.text = "Loading client configuration..."
	
	// Load SmartFoxServer client configuration
	smartFox.loadConfig("config.xml", false)
	
	chatWindowList = new Array()
}

//---------------------------------------------------------------------
// Interface components event handlers
//---------------------------------------------------------------------

/**
 * Called by the loginPanel component when the login button is clicked
 */
public function onLoginBtClick():void
{
	// Set login panel state
	loginPanel.currentState = "login_progress"
	
	// Login to SmartFoxServer zone
	smartFox.login(smartFox.defaultZone, loginPanel.tf_username.text, "")
}

/**
 * Called by the loginPanel component when the return button is clicked
 */
public function onReturnBtClick():void
{
	// Set login panel state
	loginPanel.currentState = "connection"
	
	// Repeat connection
	onConfigLoadSuccess(null)
}

/**
 * Handle click on the exit button: log the user out and close connection
 */
public function bt_logout_click():void
{
	// Disconnect from sfs
	smartFox.disconnect()
}

/**
 * Event is fired when the messenger view is ready
 */
public function onMessengerViewReady():void
{
	componentsReady = true
	
	cList.rb_available.selected = true
	cList.title = smartFox.myUserName + "'s Buddy List"	
	
	// Load the buddy list
	smartFox.loadBuddyList()
	
	// Init the members browser
	requestNextUser()
}

/**
 * Handle click on the "Add to buddy list"
 */
public function bt_add_buddy():void
{
	var buddyName:String = uBrowser.tf_nick.text
	
	if (smartFox.myUserName != buddyName)
		smartFox.addBuddy(buddyName)
}

/**
 * Handle click on the "Remove" button
 */
public function bt_remove_buddy():void
{
	if (cList.list_buddies.selectedItem != null)
	{
		var buddyName:String = cList.list_buddies.selectedItem.data.name
		smartFox.removeBuddy(buddyName)	
	}
}

/**
 * Handle click on the "Message" button
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
 * Handle click on the "Send" button in the chat window
 */
public function bt_send_message(evt:Event):void
{
	var window:ChatWindow = (evt.target as Button).parentDocument as ChatWindow
	
	if (window.tf_message.text.length > 0)
	{
		smartFox.sendPrivateMessage(smartFox.myUserId + TOKEN + window.tf_message.text, window.buddy.id)
		window.tf_message.text = ""
		
		lastFocusedChatWindow = window
	}
}

/**
 * Handle click on the "X" button in the Chat Window
 */
public function bt_close_chat(evt:Event):void
{
	var window:ChatWindow = evt.target as ChatWindow
	var buddy:Object = window.buddy
	
	// Stop A/V chats
	if (window.incomingSessionId != null)
		avChatMan.stopChat(window.incomingSessionId)
	if (window.outgoingSessionId != null)
		avChatMan.stopChat(window.outgoingSessionId)
	
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
	
	smartFox.setBuddyVariables(bvars)
}

/**
* Request the next user
*/
public function requestNextUser():void
{
	smartFox.sendXtMessage(XT_NAME, "nextU", {id:curBrowserId})
}

/**
* Request the previous user
*/
public function requestPrevUser():void
{
	smartFox.sendXtMessage(XT_NAME, "prevU", {id:curBrowserId})
}

/**
 * Handle the icon in the buddy list (mx:List component)
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
 * Handle click on the "Start chat" button in the chat window
 */
public function startAVChat(win:ChatWindow, t:String):void
{
	var buddyId:int = win.buddy.id
	var type:String
	
	switch (t)
	{
		case "snd":
			type = AVChatManager.REQ_TYPE_SEND
			break
		
		case "rcv":
			type = AVChatManager.REQ_TYPE_RECEIVE
			break
	}
	
	var session:ChatSession = avChatMan.sendChatRequest(type, buddyId, true, true)
	
	if (session != null) // session is null if the same request to the same recipient has already been submitted before (and is still valid)
	{
		var txt:String
		
		// Set proper session id in the chat window, to handle the recipient's response properly:
		// "outgoingSessionId" is set when a SEND request is made (I would like to send my video stream to my buddy)
		// "incomingSessionId" is set when a RECEIVE request is made (I would like to receive the video stream of my buddy)
		if (type == AVChatManager.REQ_TYPE_SEND)
		{
			win.outgoingSessionId = session.id
			txt = "You have invited your buddy to watch your webcam stream"
			win.showMyVideo(Camera.getCamera())
			enableStartMyCamButton(win, false)
		}
		else if (type == AVChatManager.REQ_TYPE_RECEIVE)
		{
			win.incomingSessionId = session.id
			txt = "You have invited your buddy to start his webcam"
			enableStartBuddyCamButton(win, false)
		}
		
		displaySystemMessage(win, txt)
	}
}

/**
 * Handle click on the "Refuse" button in the chat window
 */
public function declineRequest(win:ChatWindow, id:String):void
{
	try
	{
		// Send refusal
		avChatMan.refuseChatRequest(id)
		
		var txt:String
		
		// Re-enable proper a/v buttons and display system message in chat box
		if (id == win.incomingSessionId)
		{
			win.buddyAVButtonsCont.enabled = true
			txt = "You have refused to receive your buddy's webcam stream"
		}
		else if (id == win.outgoingSessionId)
		{
			win.myAVButtonsCont.enabled = true
			txt = "You have refused to send your webcam stream to your buddy"
		}
			
		displaySystemMessage(win, txt)
		
		// Reset the chat window current status (to hide proper invitation)
		resetWinStatus(win, id)
	}
	catch (e:Error)
	{
		trace (e.message)
	}
}

/**
 * Handle click on the "Accept" button in the chat window
 */
public function acceptRequest(win:ChatWindow, id:String):void
{
	try
	{
		// Send acceptance
		avChatMan.acceptChatRequest(id)
		
		var txt:String
		
		// Disable proper a/v buttons and display system message in chat box
		if (id == win.incomingSessionId)
		{
			win.buddyAVButtonsCont.enabled = true
			enableStartBuddyCamButton(win, false)
			txt = "You have accepted to receive your buddy's webcam stream"
		}
		else if (id == win.outgoingSessionId)
		{
			win.myAVButtonsCont.enabled = true
			enableStartMyCamButton(win, false)
			txt = "You have accepted to send your webcam stream to your buddy"
		}
		
		displaySystemMessage(win, txt)
		
		// Reset the chat window current status (to hide proper invitation)
		resetWinStatus(win, id)
	}
	catch (e:Error)
	{
		trace (e.message)
	}
}

/**
 * Handle click on the "Stop" button in the chat window
 */
public function stopAVChat(win:ChatWindow, id:String):void
{
	trace("Stopping AV chat - id:", id)
	
	// Send stop request
	avChatMan.stopChat(id)
	
	var txt:String
	
	// Re-enable proper a/v buttons, remove my video if necessary and display system message in chat box
	if (id == win.incomingSessionId)
	{
		win.stopBuddyVideo()
		enableStartBuddyCamButton(win, true)
		txt = "You have stopped your buddy's webcam stream"
	}
	else if (id == win.outgoingSessionId)
	{
		win.stopMyVideo()
		enableStartMyCamButton(win, true)
		txt = "You have stopped your webcam stream"
	}
	
	displaySystemMessage(win, txt)
}

//---------------------------------------------------------------------
// Private methods
//---------------------------------------------------------------------

/**
 * Initialize the AVChatManager instance
 */
private function initializeAV():void
{
	red5IpAddress = smartFox.ipAddress
	
	// Create AVChatManager instance
	avChatMan = new AVChatManager(smartFox, red5IpAddress, true)
	
	avChatMan.addEventListener(RedBoxChatEvent.onAVConnectionInited, onAVConnectionInited)
	avChatMan.addEventListener(RedBoxChatEvent.onAVConnectionError, onAVConnectionError)
	avChatMan.addEventListener(RedBoxChatEvent.onDuplicateRequest, onDuplicateRequest)
	avChatMan.addEventListener(RedBoxChatEvent.onRecipientMissing, onRecipientMissing)
	avChatMan.addEventListener(RedBoxChatEvent.onChatRequest, onChatRequest)
	avChatMan.addEventListener(RedBoxChatEvent.onChatRefused, onChatRefused)
	avChatMan.addEventListener(RedBoxChatEvent.onChatStarted, onChatStarted)
	avChatMan.addEventListener(RedBoxChatEvent.onChatStopped, onChatStopped)
	
	inited = true
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
* Find the buddy name
* 
* @param	id	the buddy id
* @return	the buddy name
*/
private function getBuddy(id:int):Object
{
	var b:Object = null
	
	for each (var buddy:Object in smartFox.buddyList)
	{			
		if (buddy.id == id)
		{
			b = buddy
			break
		}
	}
	 
	 return b
}

private function displaySystemMessage(win:ChatWindow, txt:String):void
{
	win.ta_chat.htmlText += "<i><font color='#666666'>" + txt + "</font></i>\n"
	win.ta_chat.verticalScrollPosition = win.ta_chat.maxVerticalScrollPosition
}

private function enableStartMyCamButton(win:ChatWindow, enable:Boolean):void
{
	win.bt_startMyCam.enabled = enable
	win.bt_stopMyCam.enabled = !enable
}

private function enableStartBuddyCamButton(win:ChatWindow, enable:Boolean):void
{
	win.bt_startBuddyCam.enabled = enable
	win.bt_stopBuddyCam.enabled = !enable
}

private function resetWinStatus(win:ChatWindow, id:String):void
{
	if (win.currentState != "invitation_both")
		win.currentState = ""
	else
	{
		if (id == win.incomingSessionId)
			win.currentState = "invitation_send"
		if (id == win.outgoingSessionId)
			win.currentState = "invitation_receive"
	}
}

//---------------------------------------------------------------------
// SmartFoxServer event handlers
//---------------------------------------------------------------------

public function onConfigLoadSuccess(evt:SFSEvent):void
{
	// Set login panel state
	loginPanel.tf_connection.text = "Connecting to SmartFoxServer..."
	
	// Establish connection to SmartFoxServer
	smartFox.connect(smartFox.ipAddress, smartFox.port)
}

public function onConfigLoadFailure(evt:SFSEvent):void
{
	// Set login panel state and label
	loginPanel.currentState = "conn_error"
	loginPanel.tf_connection.text = "Error loading client configuration file"
}

public function onConnection(evt:SFSEvent):void
{
	if (evt.params.success)
	{
		// Set login panel state
		loginPanel.currentState = "login"
	}
	else
	{
		// Set login panel state and label
		loginPanel.currentState = "conn_error"
		
		loginPanel.tf_connection.text = "Connection failed!" + "\n"
		loginPanel.tf_connection.text += "Server IP: " + smartFox.ipAddress + "\n"
		loginPanel.tf_connection.text += "Server port: " + smartFox.port
	}
}

public function onExtensionResponse(evt:SFSEvent):void
{
	var dataObj:Object = evt.params.dataObj
	var cmd:String = dataObj._cmd
	
	// Login success
	if (cmd == "logOK")
	{
		smartFox.myUserId = dataObj.id
		smartFox.myUserName = dataObj.name
		
		smartFox.getRoomList()
	}
	
	// Login failed
	else if (cmd == "logKO")
	{
		// Set login panel state and label
		loginPanel.currentState = "login_error"
		loginPanel.tf_error.text = "Login failed: user unknown" + "\n"
		loginPanel.tf_error.text += "or username already taken"
	}
	
	// User profile loaded
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
	smartFox.autoJoin()
}

public function onJoinRoom(evt:SFSEvent):void
{
	// Move to main application view
	viewstack1.selectedChild = view_chat
	
	// Initialize AVChatManager
	initializeAV()
	
	// The onMessengerViewReady event is fired once only, when the viewstack first initialize the chat view
	// So we need to fire it manually in case we moved away from the chat view
	if (componentsReady)
		onMessengerViewReady()
}

public function onBuddyList(evt:SFSEvent):void
{
	// Populate the buddy list
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

public function onBuddyListError(evt:SFSEvent):void
{
	Alert.show("Error loading buddy list", "BuddyList Load error", Alert.OK);	
}

public function onBuddyListUpdate(evt:SFSEvent):void
{
	// Handle updates in the buddy list
	
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
		window.hbox.enabled = buddy.isOnline
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
		if (senderId != smartFox.myUserId)
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
			senderName = smartFox.myUserName
		}
		
		if (win != null)
		{
			win.ta_chat.htmlText += "<b><font color='#cc0000'>" + senderName + ": </font></b>" + message
			win.ta_chat.verticalScrollPosition = win.ta_chat.maxVerticalScrollPosition
		}
	}
}

public function onConnectionLost(evt:SFSEvent):void
{
	if (inited)
	{
		// Remove listeners added to AVClipManager instance
		avChatMan.removeEventListener(RedBoxChatEvent.onAVConnectionInited, onAVConnectionInited)
		avChatMan.removeEventListener(RedBoxChatEvent.onAVConnectionError, onAVConnectionError)
		avChatMan.removeEventListener(RedBoxChatEvent.onDuplicateRequest, onDuplicateRequest)
		avChatMan.removeEventListener(RedBoxChatEvent.onRecipientMissing, onRecipientMissing)
		avChatMan.removeEventListener(RedBoxChatEvent.onChatRequest, onChatRequest)
		avChatMan.removeEventListener(RedBoxChatEvent.onChatRefused, onChatRefused)
		avChatMan.removeEventListener(RedBoxChatEvent.onChatStarted, onChatStarted)
		avChatMan.removeEventListener(RedBoxChatEvent.onChatStopped, onChatStopped)
		avChatMan = null
	}
	
	// Close all chats
	if (chatWindowList != null)
	{
		for each (var win:ChatWindow in chatWindowList)
		{
			var buddy:Object = win.buddy
			
			PopUpManager.removePopUp(win)
			
			// Remove from list
			delete chatWindowList[buddy.name]
		}
	}
	
	// Show disconnection box
	viewstack1.selectedChild = view_login
	loginPanel.currentState = "disconnection"
}

//---------------------------------------------------------------------
// RedBox AVChatManager event handlers
//---------------------------------------------------------------------

public function onAVConnectionInited(evt:RedBoxChatEvent):void
{
	// Nothing to do. Usually we should wait this event before enabling the a/v chat related interface elements.
}

public function onAVConnectionError(evt:RedBoxChatEvent):void
{
	trace("AV connection error:", evt.params.errorCode)
	
	// Re-enable proper a/v buttons, remove my video if necessary and display system message in chat box
	for each (var win:ChatWindow in chatWindowList)
	{
		if (win.incomingSessionId != null)
		{
			win.stopBuddyVideo()
			enableStartBuddyCamButton(win, true)
			win.incomingSessionId = null
		}
		
		if (win.outgoingSessionId != null)
		{
			win.stopMyVideo()
			enableStartMyCamButton(win, true)
			win.outgoingSessionId = null
		}
		
		displaySystemMessage(win, "An a/v connection error occurred")
	}
}

public function onDuplicateRequest(evt:RedBoxChatEvent):void
{
	trace ("Request '" + evt.params.chatSession.id + "' error: a mutual request has already been sent by the recipient!")
	
	// Nothing to do: the interface should have reacted correctly when the mutual request was received
}

public function onRecipientMissing(evt:RedBoxChatEvent):void
{
	trace ("Request '" + evt.params.chatSession.id + "' error: the recipient is not available!")
	
	// Display an error message and reset the interface (this is probably not necessary, as the interface should be disabled
	// as soon as the buddy goes offline, so sending a request to a missing recipient should not be possible).
	
	var session:ChatSession = evt.params.chatSession
	var buddy:Object = getBuddy(session.mateId)
	var win:ChatWindow = chatWindowList[buddy.name]
	
	if (win != null)
	{
		if (session.requestType == AVChatManager.REQ_TYPE_SEND)
		{
			win.outgoingSessionId = null
			win.stopMyVideo()
			enableStartMyCamButton(win, true)
		}
		else if (session.requestType == AVChatManager.REQ_TYPE_RECEIVE)
		{
			win.incomingSessionId = null
			enableStartBuddyCamButton(win, true)
		}
		
		displaySystemMessage(win, "Your buddy is not available")
	}
}

public function onChatRequest(evt:RedBoxChatEvent):void
{
	var chatData:ChatSession = evt.params.chatSession
	
	trace("A/v chat request received:")
	trace(chatData)
	
	var sender:Object = getBuddy(chatData.mateId)
	
	// Check if chat window exists
	if (chatWindowList[sender.name] == null)
		startNewPrivateChat(sender)
	
	var win:ChatWindow = chatWindowList[sender.name]
	
	if (win != null)
	{
		var txt:String
		
		// Depending on the request type, set the incoming or outgoing session id in the chat window,
		// disable the proper a/v buttons container, display the proper system message in the chat box
		// and set the chat window status to show the proper invitation message and accept/decline buttons
		switch (chatData.requestType)
		{
			case AVChatManager.REQ_TYPE_RECEIVE:
				win.outgoingSessionId = chatData.id
				win.myAVButtonsCont.enabled = false
				txt = "Your buddy invited you to start your webcam"
				if (win.currentState == "invitation_receive")
					win.currentState = "invitation_both"
				else
					win.currentState = "invitation_send"
				break
			
			case AVChatManager.REQ_TYPE_SEND:
				win.incomingSessionId = chatData.id
				win.buddyAVButtonsCont.enabled = false
				txt = "Your buddy invited you to watch his/her webcam stream"
				if (win.currentState == "invitation_send")
					win.currentState = "invitation_both"
				else
					win.currentState = "invitation_receive"
				break
		}
		
		displaySystemMessage(win, txt)
	}
}

public function onChatRefused(evt:RedBoxChatEvent):void
{
	var chatData:ChatSession = evt.params.chatSession
	
	trace("A/v chat request refused:")
	trace(chatData)
	
	var buddy:Object = getBuddy(chatData.mateId)
	
	// Check if chat window exists
	var win:ChatWindow = chatWindowList[buddy.name]
	
	if (win != null)
	{
		var sessionId:String = chatData.id
		var txt:String
		
		// Write a system message in the chat box, re-enable buttons and stop my own video
		if (sessionId == win.outgoingSessionId)
		{
			win.stopMyVideo()
			enableStartMyCamButton(win, true)
			txt = "Your buddy refused to receive your webcam stream"
		}
		else if (sessionId == win.incomingSessionId)
		{
			enableStartBuddyCamButton(win, true)
			txt = "Your buddy refused to transmit his/her webcam stream"
		}
		
		displaySystemMessage(win, txt)
	}
}

public function onChatStarted(evt:RedBoxChatEvent):void
{
	var chatData:ChatSession = evt.params.chatSession
	
	trace("A/v chat started:")
	trace(chatData)
	
	var buddy:Object = getBuddy(chatData.mateId)
	
	// Check if chat window exists
	var win:ChatWindow = chatWindowList[buddy.name]
	
	if (win != null)
	{
		// If my stream is not null, I'm transmittins, so I have to show my own video
		if (chatData.myStream != null && chatData.enableCamera)
			win.showMyVideo(Camera.getCamera())
		
		// Attach my mate' stream to the video object
		if (chatData.mateStream != null && chatData.enableCamera)
			win.showBuddyVideo(chatData.mateStream)
		
		if (chatData.iAmRequester)
		{
			var sessionId:String = chatData.id
			var txt:String
			
			// Write a system message in the chat box
			if (sessionId == win.outgoingSessionId)
				txt = "Your buddy accepted to receive your webcam stream"
			else if (sessionId == win.incomingSessionId)
				txt = "Your buddy accepted to transmit his a/v stream"
			
			displaySystemMessage(win, txt)
		}
	}
}

public function onChatStopped(evt:RedBoxChatEvent):void
{
	var chatData:ChatSession = evt.params.chatSession
	
	trace("A/v chat stopped:")
	trace(chatData)
	
	var buddy:Object = getBuddy(chatData.mateId)
	
	// Check if chat window exists
	var win:ChatWindow = chatWindowList[chatData.mateName]
	
	if (win != null)
	{
		var sessionId:String = chatData.id
		var txt:String
		
		// Re-enable proper a/v buttons, remove my video if necessary and display system message in chat box
		if (sessionId == win.incomingSessionId)
		{
			if (win.currentState == "invitation_both")
				win.currentState = "invitation_send"
			else if (win.currentState == "invitation_receive")
				win.currentState = ""
			else
				win.stopBuddyVideo()
			
			win.buddyAVButtonsCont.enabled = true
			enableStartBuddyCamButton(win, true)
			txt = "Your buddy stopped his webcam stream"
		}
		else if (sessionId == win.outgoingSessionId)
		{
			if (win.currentState == "invitation_both")
				win.currentState = "invitation_receive"
			else if (win.currentState == "invitation_send")
				win.currentState = ""
			else
				win.stopMyVideo()
			
			win.myAVButtonsCont.enabled = true
			enableStartMyCamButton(win, true)
			txt = "Your buddy stopped your webcam stream"
		}
		
		displaySystemMessage(win, txt)
	}
}
