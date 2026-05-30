import mx.collections.ArrayCollection;
import mx.collections.Sort;
import mx.collections.SortField;
import mx.managers.PopUpManager;
import mx.containers.TitleWindow;

import components.CreateRoomWindow;
import components.ChatWindow;
import components.WarningWindow;

import it.gotoandplay.smartfoxserver.SmartFoxClient;
import it.gotoandplay.smartfoxserver.SFSEvent;
import it.gotoandplay.smartfoxserver.data.Room;
import it.gotoandplay.smartfoxserver.data.User;

import com.smartfoxserver.redbox.AVChatManager;
import com.smartfoxserver.redbox.events.RedBoxChatEvent;
import com.smartfoxserver.redbox.data.ChatSession;


private const TOKEN:String = "$$$";

private var smartFox:SmartFoxClient;
private var red5IpAddress:String;
private var avChatMan:AVChatManager;
private var inited:Boolean;
private var createRoomWin:TitleWindow
private var prvChatWindowList:Array
private var componentsReady:Boolean


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
	smartFox.addEventListener(SFSEvent.onLogin, onLogin)
	smartFox.addEventListener(SFSEvent.onRoomListUpdate, onRoomListUpdate)
	smartFox.addEventListener(SFSEvent.onUserCountChange, onUserCountChange)
	smartFox.addEventListener(SFSEvent.onJoinRoom, onJoinRoom)
	smartFox.addEventListener(SFSEvent.onJoinRoomError, onJoinRoomError)
	smartFox.addEventListener(SFSEvent.onRoomAdded, onRoomAdded)
	smartFox.addEventListener(SFSEvent.onRoomDeleted, onRoomDeleted)
	smartFox.addEventListener(SFSEvent.onCreateRoomError, onCreateRoomError)
	smartFox.addEventListener(SFSEvent.onPublicMessage, onPublicMessage)
	smartFox.addEventListener(SFSEvent.onPrivateMessage, onPrivateMessage)
	smartFox.addEventListener(SFSEvent.onUserEnterRoom, onUserEnterRoom)
	smartFox.addEventListener(SFSEvent.onUserLeaveRoom, onUserLeaveRoom)
	smartFox.addEventListener(SFSEvent.onConnectionLost, onConnectionLost)
	
	// Set login panel state and label
	loginPanel.currentState = "connection"
	loginPanel.tf_connection.text = "Loading client configuration..."
	
	// Load SmartFoxServer client configuration
	smartFox.loadConfig("config.xml", false)
	
	prvChatWindowList = []
	componentsReady = false
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
 * Log the user out and close connection
 */
public function bt_logout_click():void
{
	// Disconnect from sfs
	smartFox.disconnect()
}

/**
 * Send a public message to all users in the room
 */
public function bt_send_click():void
{
	if (tf_pubmsg.text.length > 0)
	{
		smartFox.sendPublicMessage(tf_pubmsg.text)
		tf_pubmsg.text = ""
	}
}

/**
 * Called when the chat view is rendered
 */
public function onChatViewReady():void
{
	componentsReady = true
	
	// Populate room list
	populateRoomList()
	
	// Autojoin default room
	smartFox.autoJoin()
}

/**
* Launch the create room window
*/
public function bt_create_click():void
{
	createRoomWin = PopUpManager.createPopUp(this, CreateRoomWindow, true) as TitleWindow
	createRoomWin["bt_create"].addEventListener("click", handleCreateRoom)
}

/**
* Start the private chat
*/
public function bt_prvChat_click():void
{
	if (userList.selectedItem != null)
	{
		var userId:int = userList.selectedItem.data
		var userName:String = smartFox.getActiveRoom().getUser(userId).getName()
		
		var win:ChatWindow = getPrivateChatWindow(userId, userName)
		PopUpManager.bringToFront(win)
	}
}

/**
 * Handle click on the "Send" button in the private chat window
 */
public function bt_sendPriv_click(evt:Event):void
{
	var win:ChatWindow = (evt.target as Button).parentDocument as ChatWindow
	
	if (win.tf_message.text.length > 0)
	{
		smartFox.sendPrivateMessage(win.userId + TOKEN + win.tf_message.text, win.userId)
		win.tf_message.text = ""
	}
}


/**
 * Handle click on the "X" button in the private chat window
 */
public function bt_closePriv_click(evt:Event):void
{
	var win:ChatWindow = evt.target as ChatWindow
	removePrivateChat(win)
}

/**
* Handle click in the create room window
*/
public function handleCreateRoom(evt:Event):void
{
	var roomName:String = createRoomWin["tf_roomName"].text
	var rooMaxU:int = createRoomWin["ns_maxusers"].value	
	
	if (roomName.length > 0)
	{
		// Set room properties
		var roomObj:Object = {}
		roomObj.name = roomName
		roomObj.maxUsers = rooMaxU
		
		// Create the room!
		smartFox.createRoom(roomObj)
	}		
}

/**
* Join a new room when an item is selected in the room list component
*/
public function roomList_change():void
{
	var roomId:int = int(roomList.selectedItem.data)
	
	// Join room
	smartFox.joinRoom(roomId)
}

/**
* Enable "private chat" button
*/
public function userList_change():void
{
	var pmUserId:int = userList.selectedItem.data
	
	if (userList.selectedItem != null && pmUserId != smartFox.myUserId)
		bt_prvChat.enabled = true
	else
		bt_prvChat.enabled = false
}

/**
 * Handle "star A/V chat" button click in the private chat window
 */
public function startAVChat(win:ChatWindow):void
{
	var session:ChatSession = avChatMan.sendChatRequest(AVChatManager.REQ_TYPE_SEND_RECEIVE, win.userId, true, true)
	
	if (session != null) // session is null if the same request to the same recipient has already been submitted before (and is still valid)
	{
		win.connId = session.id
		win.showMyVideo(Camera.getCamera())
		enableStartAVButton(win, false)
		displaySystemMessage(win, "You have invited " + win.userName + " to start an A/V chat")
	}
}

/**
 * Handle "stop A/V chat" button click in the private chat window
 */
public function stopAVChat(win:ChatWindow):void
{
	// Send stop request
	avChatMan.stopChat(win.connId)
	
	// Re-enable proper a/v buttons, remove my video if necessary and display system message in chat box
	win.connId = ""
	win.stopMyVideo()
	win.stopBuddyVideo()
	enableStartAVButton(win, true)
	displaySystemMessage(win, "You have stopped the current A/V chat")
}

/**
 * Handle "accept A/V chat" button click in the private chat window
 */
public function acceptRequest(win:ChatWindow):void
{
	try
	{
		// Send acceptance
		avChatMan.acceptChatRequest(win.connId)
		
		// Reset the private chat window current status (to hide invitation)
		win.currentState = ""
		
		// Get the A/V session data
		var session:ChatSession = avChatMan.getChatSession(win.connId)
		
		if (session.enableCamera)
			win.showMyVideo(Camera.getCamera())
		
		// Disable a/v buttons and display system message in chat box
		enableStartAVButton(win, false)
		displaySystemMessage(win, "You have accepted to start an A/V chat")
	}
	catch (e:Error)
	{
		trace (e.message)
	}
}

/**
 * Handle "decline A/V chat" button click in the private chat window
 */
public function declineRequest(win:ChatWindow):void
{
	try
	{
		// Send refusal
		avChatMan.refuseChatRequest(win.connId)
		
		// Reset the private chat window current status (to hide invitation)
		win.currentState = ""
		
		// Re-enable a/v buttons and display system message in chat box
		enableStartAVButton(win, true)
		displaySystemMessage(win, "You have refused to start an A/V chat")
		win.connId = ""
	}
	catch (e:Error)
	{
		trace (e.message)
	}
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
	
	// Create AVChatmanager instance
	avChatMan = new AVChatManager(smartFox, red5IpAddress, true)
	
	avChatMan.addEventListener(RedBoxChatEvent.onAVConnectionInited, onAVConnectionInited)
	avChatMan.addEventListener(RedBoxChatEvent.onAVConnectionError, onAVConnectionError)
	avChatMan.addEventListener(RedBoxChatEvent.onChatRequest, onChatRequest)
	avChatMan.addEventListener(RedBoxChatEvent.onChatRefused, onChatRefused)
	avChatMan.addEventListener(RedBoxChatEvent.onChatStarted, onChatStarted)
	avChatMan.addEventListener(RedBoxChatEvent.onChatStopped, onChatStopped)
	
	inited = true
}

/**
 * Populate the list of rooms
 */
private function populateRoomList():void
{
	var rList:Array = smartFox.getAllRooms()
	var provider:ArrayCollection
	
	// If this is not the first time we initialize the provider
	// we have to clear the old content
	if (roomList.dataProvider != null)
	{
		provider = roomList.dataProvider as ArrayCollection
		provider.removeAll()
	}
	else
	{
		provider = new ArrayCollection()
		roomList.dataProvider = provider
	}
	
	// Populate the data provider with list of rooms
	for each(var r:Room in rList)
	{
		var txt:String = r.getName() + " (" + r.getUserCount() + "/" + r.getMaxUsers() + ")"
		provider.addItem( {label:txt, data:r.getId()} )
	}

	// Sort provider
	if (provider.sort == null)
	{
		var sort:Sort = new Sort()
		sort.fields = [new SortField("label")]
		
		provider.sort = sort
	}
	
	roomList.dataProvider = provider
	roomList.invalidateList()
	
	provider.refresh()
}

/**
 * Create the private chat window
 */
private function getPrivateChatWindow(userId:int, userName:String = ""):ChatWindow
{
	// Check if private chat with existing user is already in progress
	// If yes, bring to front
	var win:ChatWindow = prvChatWindowList[userId]
	
	if (win == null)
	{
		win = new ChatWindow()
		win.userId = userId
		win.userName = userName
		win.title = "Private Chat with " + userName
		
		PopUpManager.addPopUp(win, this)
		PopUpManager.centerPopUp(win)
		
		randomMoveWindow(win)
		
		// Keep a reference to the window
		prvChatWindowList[userId] = win
	}
	
	return win
}

/**
 * Slightly alter the position of the window once centered
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
 * Set the passed room as the selected item in the room list component
 */
private function setRoomListSelection(room:Room):void
{
	var provider:ArrayCollection = roomList.dataProvider as ArrayCollection
	var id:int = room.getId()
	
	for each (var item:Object in provider)
	{
		if (item.data == id)
		{
			roomList.selectedItem = item
			break
		}
	}
}

/**
 * Remove the private chat window
 */
private function removePrivateChat(win:ChatWindow):void
{
	// Stop A/V connection
	if (win.connId != null)
		stopAVChat(win)
	
	PopUpManager.removePopUp(win)
	
	// Remove from list
	delete prvChatWindowList[win.userId]
}

/**
 * Display user message in private chat
 */
private function displayUserPrivateMessage(win:ChatWindow, senderName:String, txt:String):void
{
	win.ta_chat.htmlText += "<b><font color='#CC0000'>" + senderName + ": </font></b>" + txt
	win.ta_chat.verticalScrollPosition = win.ta_chat.maxVerticalScrollPosition
}

/**
 * Display system message in private chat
 */
private function displaySystemMessage(win:ChatWindow, txt:String):void
{
	win.ta_chat.htmlText += "<i><font color='#666666'>" + txt + "</font></i>\n"
	win.ta_chat.verticalScrollPosition = win.ta_chat.maxVerticalScrollPosition
}

/**
 * Enable/disable A/V buttons in a private chat window
 */
private function enableStartAVButton(win:ChatWindow, enable:Boolean):void
{
	win.bt_startAV.enabled = enable
	win.bt_stopAV.enabled = !enable
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

public function onLogin(evt:SFSEvent):void
{
	if (!evt.params.success)
	{
		// Set login panel state and label
		loginPanel.currentState = "login_error"
		loginPanel.tf_error.text = evt.params.error
	}
}

public function onRoomListUpdate(evt:SFSEvent):void
{
	// Move to chat view
	viewstack1.selectedChild = view_chat
	
	// Initialize AVChatManager
	initializeAV()
	
	// Call "onChatViewReady", causing the room list to be populated and the default room to be joined
	if (componentsReady)
		onChatViewReady()
}

public function onJoinRoom(evt:SFSEvent):void
{
	var room:Room = evt.params.room as Room						
	var provider:ArrayCollection = new ArrayCollection()
	
	// Set the selection in the room list component
	setRoomListSelection(room)
	
	// Cycle through all users in the list and add them to the provider
	for each(var u:User in room.getUserList())
		provider.addItem( {label:u.getName(), data:u.getId()} )
	
	// Add a sort field to the room list component. Names will be sorted alphabetically
	if (provider.sort == null)
	{
		var sort:Sort = new Sort()
		sort.fields = [new SortField("label")]
		
		provider.sort = sort
	}
	
	provider.refresh()
	userList.dataProvider = provider
	
	ta_chat.htmlText = "<font color='#cc0000'>{ Room <b>" + room.getName() + "</b> joined }</font><br>"
}

public function onJoinRoomError(evt:SFSEvent):void
{
	if (viewstack1.selectedChild != view_chat)
	{
		// Set login panel state and label
		loginPanel.currentState = "login_error"
		loginPanel.tf_error.text = evt.params.error
		
		smartFox.logout()
	}
	else
	{
		var warning:WarningWindow = PopUpManager.createPopUp(this, WarningWindow, true) as WarningWindow
		warning.setWarning("Room join error:\n" + evt.params.error)
		
		// Set the selection in the room list component
		setRoomListSelection(smartFox.getActiveRoom())
	}
}

public function onUserCountChange(evt:SFSEvent):void
{
	var r:Room = evt.params.room as Room
	var id:int = r.getId()
	
	// Cycle through all rooms in the list and find the one that changed
	for each (var o:Object in roomList.dataProvider)
	{
		if (o.data == id)
		{
			o.label = r.getName() + " (" + r.getUserCount() + "/" + r.getMaxUsers() + ")"
			break
		}
	}
	
	roomList.invalidateList()
}

public function onPublicMessage(evt:SFSEvent):void
{
	var message:String = evt.params.message
	var sender:User = evt.params.sender
	
	ta_chat.htmlText += "<b>[" + sender.getName() + "]:</b> " + message +"<br>"
	ta_chat.verticalScrollPosition = ta_chat.maxVerticalScrollPosition
}

public function onPrivateMessage(evt:SFSEvent):void
{
	var tokenMessage:String = evt.params.message
	var sender:User = evt.params.sender
	
	if (tokenMessage.indexOf(TOKEN) > 0)
	{
		var data:Array = tokenMessage.split(TOKEN)
			
		var recipientId:int = int(data[0])
		var message:String = data[1]
		
		if (data.length > 2)
		{
			for (var i:int = 2; i < data.length; i++)
				message += data[i]
		}
		
		var win:ChatWindow
		var senderId:int = (sender != null ? sender.getId() : evt.params.userId)
		var senderName:String = (sender != null ? sender.getName() : "")
		
		// Retrieve the right chat window:
		// if I'm the sender of the message, then I can use the recipientId value contained in the message body;
		// otherwise I can use the event's userId property
		if (senderId == smartFox.myUserId)
			win = getPrivateChatWindow(recipientId)
		else
		{
			win = getPrivateChatWindow(senderId, senderName)
			senderName = win.userName
		}
		
		if (win != null)
			displayUserPrivateMessage(win, senderName, message)
	}
}

public function onCreateRoomError(evt:SFSEvent):void
{
	var warning:WarningWindow = PopUpManager.createPopUp(this, WarningWindow, true) as WarningWindow
	warning.setWarning("Room creation error:\n" + evt.params.error)		
}

public function onRoomAdded(evt:SFSEvent):void
{
	var room:Room = evt.params.room
	
	// Update view
	var provider:ArrayCollection = roomList.dataProvider as ArrayCollection
	var label:String = room.getName() + " (" + room.getUserCount() + "/" + room.getMaxUsers() + ")"
	
	provider.addItem( {label:label, data:room.getId()} )
	provider.refresh()				
	
	roomList.invalidateList()
}

public function onRoomDeleted(evt:SFSEvent):void
{
	var room:Room = evt.params.room
	var roomId:int = room.getId()
	
	var provider:ArrayCollection = roomList.dataProvider as ArrayCollection
	
	for each (var o:Object in provider)
	{
		if (o.data == roomId)
		{
			provider.removeItemAt(provider.getItemIndex(o))
			break
		}
	}
	
	provider.refresh()
	roomList.invalidateList()
}

public function onUserEnterRoom(evt:SFSEvent):void
{
	var user:User = evt.params.user
	var roomId:int = evt.params.room as int
	ta_chat.htmlText += "<i><font color='#666666'>" + user.getName() + " entered the room</font></i>\n"
	ta_chat.verticalScrollPosition = ta_chat.maxVerticalScrollPosition
	
	var provider:ArrayCollection = userList.dataProvider as ArrayCollection

	provider.addItem( {label:user.getName(), data:user.getId()} )
	provider.refresh()				
	
	userList.invalidateList()
}

public function onUserLeaveRoom(evt:SFSEvent):void
{
	var userName:String = evt.params.userName
	var roomId:int = evt.params.roomId as int
	var userId:int = evt.params.userId as int
	
	ta_chat.htmlText += "<i><font color='#666666'>" + userName + " left the room</font></i>\n"
	ta_chat.verticalScrollPosition = ta_chat.maxVerticalScrollPosition
	
	var provider:ArrayCollection = userList.dataProvider as ArrayCollection
	
	for each (var o:Object in provider)
	{
		if (o.data == userId)
		{
			provider.removeItemAt(provider.getItemIndex(o))	
			break
		}
	}
	
	userList.invalidateList()
	
	bt_prvChat.enabled = false
}

public function onConnectionLost(evt:SFSEvent):void
{
	if (inited)
	{
		// Remove listeners added to AVChatManager instance
		avChatMan.removeEventListener(RedBoxChatEvent.onAVConnectionInited, onAVConnectionInited)
		avChatMan.removeEventListener(RedBoxChatEvent.onAVConnectionError, onAVConnectionError)
		avChatMan.removeEventListener(RedBoxChatEvent.onChatRequest, onChatRequest)
		avChatMan.removeEventListener(RedBoxChatEvent.onChatRefused, onChatRefused)
		avChatMan.removeEventListener(RedBoxChatEvent.onChatStarted, onChatStarted)
		avChatMan.removeEventListener(RedBoxChatEvent.onChatStopped, onChatStopped)
		avChatMan = null
	}
	
	// Remove private chat windows
	for each (var win:ChatWindow in prvChatWindowList)
		removePrivateChat(win)
	
	prvChatWindowList = []
	
	// Show disconnection box
	viewstack1.selectedChild = view_login
	loginPanel.currentState = "disconnection"
}

//---------------------------------------------------------------------
// RedBox AVChatManager event handlers
//---------------------------------------------------------------------

/**
 * Handle A/V connection initialized
 */
public function onAVConnectionInited(evt:RedBoxChatEvent):void
{
	// Nothing to do. Usually we should wait this event before enabling the a/v chat related interface elements.
}

/**
 * Handle A/V connection error
 */
public function onAVConnectionError(evt:RedBoxChatEvent):void
{
	trace ("A/V CONNECTION ERROR: " + evt.params.errorCode)
	
	// Re-enable proper a/v buttons, remove my video if necessary and display system message in chat box
	for each (var win:ChatWindow in prvChatWindowList)
	{
		// Re-enable a/v buttons, remove video and display system message in chat box
		enableStartAVButton(win, true)
		win.stopMyVideo()
		win.stopBuddyVideo()
		
		displaySystemMessage(win, "An A/V connection error occurred")
	}
}

/**
 * Handle incoming A/V chat request
 */
public function onChatRequest(evt:RedBoxChatEvent):void
{
	var chatSession:ChatSession = evt.params.chatSession
	trace("A/V CHAT REQUEST RECEIVED:")
	trace(chatSession.toString())
	
	var senderId:int = chatSession.mateId
	var senderName:String = chatSession.mateName
	
	// Retrieve the chat window
	var win:ChatWindow = getPrivateChatWindow(senderId, senderName)
	
	// Set the A/V connection id for future reference, show the invitation message and accept/refuse buttons
	win.connId = chatSession.id
	win.currentState = "invitation"
	displaySystemMessage(win, senderName + " invited you to start an A/V chat")
}

/**
 * Handle A/V chat started event
 */
public function onChatStarted(evt:RedBoxChatEvent):void
{
	trace("AV Chat started")
	
	var chatSession:ChatSession = evt.params.chatSession
	
	var userId:int = chatSession.mateId
	var userName:String = chatSession.mateName
	
	// Retrieve the chat window
	var win:ChatWindow = getPrivateChatWindow(userId, userName)
	
	// Attach the NetStream object to the video object
	if (chatSession.mateStream != null)
		win.showBuddyVideo(chatSession.mateStream)
	
	// Write a system message in the chat box (only if I'm the requester)
	if (chatSession.iAmRequester)
		displaySystemMessage(win, userName + " accepted your invitation")
}

/**
 * Handle A/V chat refused event
 */
public function onChatRefused(evt:RedBoxChatEvent):void
{
	trace("AV Connection refused")
	
	var chatSession:ChatSession = evt.params.chatSession
	var userId:int = chatSession.mateId
	
	// Retrieve the chat window
	var win:ChatWindow = getPrivateChatWindow(userId)
	
	// Write a system message in the chat box, re-enable buttons and stop my own video
	win.stopMyVideo()
	enableStartAVButton(win, true)
	win.connId = ""
	displaySystemMessage(win, "Your invitation was declined")
}

/**
 * Handle A/V chat stopped event
 */
public function onChatStopped(evt:RedBoxChatEvent):void
{
	trace("AV Connection stopped")
	
	var chatSession:ChatSession = evt.params.chatSession
	var userId:int = chatSession.mateId
	var userName:String = chatSession.mateName
	
	// Retrieve the chat window
	var win:ChatWindow = getPrivateChatWindow(userId, userName)
	
	// Write a system message in the chat box, re-enable buttons and stop my own video
	win.currentState = ""
	win.stopMyVideo()
	win.stopBuddyVideo()
	enableStartAVButton(win, true)
	win.connId = ""
	displaySystemMessage(win, userName + " stopped the A/V chat")
}