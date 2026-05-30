import mx.managers.PopUpManager;
import mx.containers.TitleWindow;
import mx.collections.ArrayCollection;
import mx.collections.Sort;
import mx.collections.SortField;
import flash.net.NetStream;
import flash.media.Camera;

import components.CreateRoomWindow;
import components.WarningWindow;
import components.VideoConferenceItem;

import it.gotoandplay.smartfoxserver.SmartFoxClient;
import it.gotoandplay.smartfoxserver.SFSEvent;
import it.gotoandplay.smartfoxserver.data.Room;
import it.gotoandplay.smartfoxserver.data.User;

import com.smartfoxserver.redbox.AVCastManager;
import com.smartfoxserver.redbox.events.RedBoxCastEvent;
import com.smartfoxserver.redbox.data.LiveCast;


private var smartFox:SmartFoxClient;
private var red5IpAddress:String;
private var avCastMan:AVCastManager;
private var inited:Boolean;
private var createRoomWin:TitleWindow
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
	smartFox.addEventListener(SFSEvent.onUserEnterRoom, onUserEnterRoom)
	smartFox.addEventListener(SFSEvent.onUserLeaveRoom, onUserLeaveRoom)
	smartFox.addEventListener(SFSEvent.onConnectionLost, onConnectionLost)
	
	// Set login panel state and label
	loginPanel.currentState = "connection"
	loginPanel.tf_connection.text = "Loading client configuration..."
	
	// Load SmartFoxServer client configuration
	smartFox.loadConfig("config.xml", false)
	
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
 * Called when the conference view is rendered
 */
public function onConfViewReady():void
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
	leaveConference()
	
	var roomId:int = int(roomList.selectedItem.data)
	
	// Join room
	smartFox.joinRoom(roomId)
}

/**
* Join video conference
*/
public function joinConference():void
{
	// Retrieve live casts already available
	for each (var liveCast:LiveCast in avCastMan.getAvailableCasts())
	{
		// Subscribe live cast and add to video container
		addLiveCast(liveCast)
	}
	
	// Publish my live cast
	var myStream:NetStream = avCastMan.publishLiveCast(true, true)
	
	if (myStream != null)
	{
		// Attach camera output 
		myVCItem.attachCamera(Camera.getCamera())
		
		bt_joinConf.enabled = false
		bt_leaveConf.enabled = true
	}
}

/**
* Leave video conference
*/
public function leaveConference():void
{
	// Stop receiveing cast publish/unpublish notification
	avCastMan.stopPublishNotification()
	
	// Retrieve live casts
	for each (var liveCast:LiveCast in avCastMan.getAvailableCasts())
	{
		// Unsubscribe cast
		avCastMan.unsubscribeLiveCast(liveCast.id)
		
		// Remove item from video container
		videoContainer.removeChild(videoContainer.getChildByName("user_" + liveCast.userId))
	}
	
	// Unpublish my live cast
	avCastMan.unpublishLiveCast()
	
	// Stop camera output
	myVCItem.reset(smartFox.myUserName + " (me)")
	
	bt_joinConf.enabled = true
	bt_leaveConf.enabled = false
}

//---------------------------------------------------------------------
// Private methods
//---------------------------------------------------------------------

/**
 * Initialize the AVCastManager instance
 */
private function initializeAV():void
{
	red5IpAddress = smartFox.ipAddress
	
	// Create AVCastManager instance
	avCastMan = new AVCastManager(smartFox, red5IpAddress, true)
	
	avCastMan.addEventListener(RedBoxCastEvent.onAVConnectionInited, onAVConnectionInited)
	avCastMan.addEventListener(RedBoxCastEvent.onAVConnectionError, onAVConnectionError)
	avCastMan.addEventListener(RedBoxCastEvent.onLiveCastPublished, onLiveCastPublished)
	avCastMan.addEventListener(RedBoxCastEvent.onLiveCastUnpublished, onLiveCastUnpublished)
	
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
 * Add live cast to video container
 */
private function addLiveCast(liveCast:LiveCast):void
{
	// Subscribe cast
	var stream:NetStream = avCastMan.subscribeLiveCast(liveCast.id)
	
	if (stream != null)
	{
		// Add item to video container
		var item:VideoConferenceItem = new VideoConferenceItem()
		item.name = "user_" + liveCast.userId
		
		videoContainer.addChild(item)
		
		// Attach stream to item
		item.setLabelText(liveCast.username)
		item.attachStream(stream)
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
	viewstack1.selectedChild = view_conf
	
	// Initialize AVCastManager
	initializeAV()
	
	// Call "onConfViewReady", causing the room list to be populated and the default room to be joined
	if (componentsReady)
		onConfViewReady()
}

public function onJoinRoom(evt:SFSEvent):void
{
	var room:Room = evt.params.room as Room						
	//var provider:ArrayCollection = new ArrayCollection()
	
	// Set the selection in the room list component
	setRoomListSelection(room)
	
	// Set my name
	myVCItem.reset(smartFox.myUserName + " (me)")
	
	ta_chat.htmlText = "<font color='#cc0000'>{ Room <b>" + room.getName() + "</b> joined }</font><br>"
}

public function onJoinRoomError(evt:SFSEvent):void
{
	if (viewstack1.selectedChild != view_conf)
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
}

public function onUserLeaveRoom(evt:SFSEvent):void
{
	var userName:String = evt.params.userName
	var roomId:int = evt.params.roomId as int
	var userId:int = evt.params.userId as int
	
	ta_chat.htmlText += "<i><font color='#666666'>" + userName + " left the room</font></i>\n"
	ta_chat.verticalScrollPosition = ta_chat.maxVerticalScrollPosition
}

public function onConnectionLost(evt:SFSEvent):void
{
	if (inited)
	{
		// Remove listeners added to AVCastManager instance
		avCastMan.removeEventListener(RedBoxCastEvent.onAVConnectionInited, onAVConnectionInited)
		avCastMan.removeEventListener(RedBoxCastEvent.onAVConnectionError, onAVConnectionError)
		avCastMan.removeEventListener(RedBoxCastEvent.onLiveCastPublished, onLiveCastPublished)
		avCastMan.removeEventListener(RedBoxCastEvent.onLiveCastUnpublished, onLiveCastUnpublished)
		avCastMan = null
	}
	
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
public function onAVConnectionInited(evt:RedBoxCastEvent):void
{
	// Nothing to do. Usually we should wait this event before enabling the a/v chat related interface elements.
}

/**
 * Handle A/V connection error
 */
public function onAVConnectionError(evt:RedBoxCastEvent):void
{
	trace ("A/V CONNECTION ERROR: " + evt.params.errorCode)
}

/**
 * Handle new live cast published by user
 */
public function onLiveCastPublished(evt:RedBoxCastEvent):void
{
	var liveCast:LiveCast = evt.params.liveCast
	
	trace ("User " + liveCast.username + " published his live cast")
	
	// Subscribe live cast and add to video container
	addLiveCast(liveCast)
}

/**
 * Handle live cast unpublished by user
 */
public function onLiveCastUnpublished(evt:RedBoxCastEvent):void
{
	var liveCast:LiveCast = evt.params.liveCast
	
	trace ("User " + liveCast.username + " unpublished his live cast")
	
	// When a user unpublishes his live cast, the AVCastManager instance automatically unsubscribes
	// that cast for the current user, so we just have to remove his video from the stage
	// Remove item from video container
	
	videoContainer.removeChild(videoContainer.getChildByName("user_" + liveCast.userId))
}