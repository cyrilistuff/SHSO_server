/**
 * SmartFoxTris Example Application for SmartFoxServer PRO
 * Flex 2 / Actionscript 3.0 version
 * 
 * version 1.0.0
 * (c) gotoAndPlay() 2007
 * 
 * www.smartfoxserver.com
 * www.gotoandplay.it
 */

import mx.containers.TitleWindow;
import mx.collections.ArrayCollection;
import mx.collections.SortField;
import mx.collections.Sort;
import mx.managers.PopUpManager
import mx.core.IFlexDisplayObject
import mx.controls.TextInput
import mx.controls.TextArea

import it.gotoandplay.smartfoxserver.SmartFoxClient
import it.gotoandplay.smartfoxserver.SFSEvent
import it.gotoandplay.smartfoxserver.data.Room
import it.gotoandplay.smartfoxserver.data.User

import it.gotoandplay.games.TrisGame

import components.*

import flash.display.Sprite;
import com.gskinner.ui.DisplayObjectWrapper;
import mx.charts.renderers.TriangleItemRenderer;

private var sfs:SmartFoxClient
private var roomListEvent:SFSEvent
private var createGameWin:TitleWindow
private var joinGameWin:TitleWindow
private var pmWindow:TitleWindow
private var pmUserId:int
private var chatViewInited:Boolean
private var gameViewInited:Boolean
private var gameMsg:GameMessage
private var gameInstance:TrisGame

private var serverIp:String
private var serverPort:int
private var serverZone:String
private var xtName:String
private var xtScript:String
private var defaultRoomName:String

private const configFile:String = "./config.xml"


	
/**
* Application start
*/
public function initApp():void
{
	pmUserId = -1
	chatViewInited = false
	gameViewInited = false
	
	// Create server instance
	sfs = new SmartFoxClient(true)
	
	// Add event listeners
	sfs.addEventListener(SFSEvent.onConnection, onConnection)
	sfs.addEventListener(SFSEvent.onLogin, onLogin)
	sfs.addEventListener(SFSEvent.onRoomListUpdate, onRoomListUpdate)
	sfs.addEventListener(SFSEvent.onUserCountChange, onUserCountChange)
	sfs.addEventListener(SFSEvent.onJoinRoom, onJoinRoom)
	sfs.addEventListener(SFSEvent.onJoinRoomError, onJoinRoomError)
	sfs.addEventListener(SFSEvent.onRoomAdded, onRoomAdded)
	sfs.addEventListener(SFSEvent.onRoomDeleted, onRoomDeleted)
	sfs.addEventListener(SFSEvent.onCreateRoomError, onCreateRoomError)
	sfs.addEventListener(SFSEvent.onPublicMessage, onPublicMessage)
	sfs.addEventListener(SFSEvent.onPrivateMessage, onPrivateMessage)
	sfs.addEventListener(SFSEvent.onUserEnterRoom, onUserEnterRoom)
	sfs.addEventListener(SFSEvent.onUserLeaveRoom, onUserLeaveRoom)
	sfs.addEventListener(SFSEvent.onConnectionLost, onConnectionLost)
	
	// Load configuration file
	loadConfigData()		
}


/*
* Load xml configuration file
*/
private function loadConfigData():void
{
	var loader:URLLoader = new URLLoader()
	loader.addEventListener(Event.COMPLETE, onConfigLoaded)
	loader.addEventListener(IOErrorEvent.IO_ERROR, onConfigLoadFailed)
	
	loader.load(new URLRequest(configFile))
}

/*
* Handles the successfull loading of the config file
*/
public function onConfigLoaded(evt:Event):void
{
	var loader:URLLoader = evt.target as URLLoader
	var xmlDoc:XML = new XML(loader.data)
	
	serverIp = xmlDoc.ip
	serverPort = int(xmlDoc.port)
	serverZone = xmlDoc.zone 
	defaultRoomName = xmlDoc.defaultRoom
	xtName = xmlDoc.xtName
	xtScript = xmlDoc.xtScript
	
	// Connect to server
	connect()
}

/*
* Establish connection with the server
*/
public function connect():void
{
	sfs.connect(serverIp, serverPort)
}

/*
* Handles configuration load failure
*/
public function onConfigLoadFailed(evt:Event):void
{
	lb_connStatus.text = "Failed loading configuration file"
}


//---------------------------------------------------------------------
// SmartFoxClient Event Handlers
//---------------------------------------------------------------------

/*
* Handler Server connection
*/
public function onConnection(evt:SFSEvent):void
{
	var ok:Boolean = evt.params.success
	
	if (ok)
	{
		viewstack.selectedChild = view_login
	}
	else
	{
		lb_connStatus.text = "Failed connecting to " + serverIp + ":" + serverPort 
	}
}

/*
* Handler login event
*/
public function onLogin(evt:SFSEvent):void
{
	var ok:Boolean = evt.params.success

	if (!ok)
	{
		lb_errorMsg.text = evt.params.error
	}
}

/*
* Handler the room list
* 
* Before we can use the components in the "view_chat" screen of the viewstack
* we have to wait for them to initialize.
*
* This happens once only, so we keep a flag called "chatViewInited" to check
* if this is the first time we show the chat screen
*
* The populateRoomList method is automatically called by the view_chat Canvas component
* when it fires the creationComplete event
*/
public function onRoomListUpdate(evt:SFSEvent):void
{
	roomListEvent = evt
	viewstack.selectedChild = view_chat
	
	if (chatViewInited)
		populateRoomList()
}

/*
* Handler a join room event
*
* For game rooms, efore we can use the components in the "view_game" screen 
* of the viewstack we have to wait for them to initialize.
*
* This happens once only, so we keep a flag called "gameViewInited" to check
* if this is the first time we show the game screen
*
* The initGame method is automatically called by the view_cgame Canvas component
* when it fires the creationComplete event
*/
public function onJoinRoom(evt:SFSEvent):void
{
	var room:Room = evt.params.room as Room
	
	if (!room.isGame())
	{
		var provider:ArrayCollection = new ArrayCollection()
		
		// Set the selection in the room list component
		setRoomListSelection(room)
		
		// Cycle through all users in the list and add them to the provider
		for each(var u:User in room.getUserList())
		{
			provider.addItem( {label:u.getName(), data:u.getId()} )
		}
		
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
	else
	{
		viewstack.selectedChild = view_game
		
		if (gameViewInited)
			initGame()
		
	}
}

/*
* Handle error while joining a room
*/
public function onJoinRoomError(evt:SFSEvent):void
{
	var warning:WarningWindow = PopUpManager.createPopUp(this, WarningWindow, true) as WarningWindow
	warning.setWarning("Room join error:\n" + evt.params.error)
	
	// Remove the selection in the room list component
	roomList.selectedIndex = -1
}

/*
* Handle an error while creating a room
*/
public function onCreateRoomError(evt:SFSEvent):void
{
	var warning:WarningWindow = PopUpManager.createPopUp(this, WarningWindow, true) as WarningWindow
	warning.setWarning("Room creation error:\n" + evt.params.error)		
}

/*
* Handle a new room in the room list
*/
public function onRoomAdded(evt:SFSEvent):void
{
	var room:Room = evt.params.room
	
	// Update view (only if room is game)
	if (room.isGame())
	{
		var provider:ArrayCollection = roomList.dataProvider as ArrayCollection
		var txt:String = setRoomLabel(room)
		
		provider.addItem( {label:txt, data:room.getId()} )
		provider.refresh()				
		
		roomList.invalidateList()
	}
}

/*
* Handle a room that was removed
*/
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

/*
* Handle a count change in one room of the zone
*/
public function onUserCountChange(evt:SFSEvent):void
{
	var r:Room = evt.params.room as Room
	var id:int = r.getId()
	
	// Cycle through all rooms in the list and find the one that changed
	for each (var o:Object in roomList.dataProvider)
	{
		if (o.data == id)
		{
			o.label = setRoomLabel(r)
			break
		}
	}
	
	roomList.invalidateList()
}

/*
* Handle a public message
*/
public function onPublicMessage(evt:SFSEvent):void
{
	var message:String = evt.params.message
	var sender:User = evt.params.sender
	
	var ta:TextArea
	
	if (viewstack.selectedChild.name != view_game.name)
		ta = ta_chat
	else
		ta = ta_chat1
	
	ta.htmlText += "<b>[" + sender.getName() + "]:</b> " + message +"<br>"
	ta.verticalScrollPosition = ta.maxVerticalScrollPosition
}

/*
* Handle a private message
*/
public function onPrivateMessage(evt:SFSEvent):void
{
	var message:String = evt.params.message
	var sender:User = evt.params.sender
	
	ta_chat.htmlText += "<b><font color='#550000'>[PM - " + sender.getName() + "]:</font></b> " + message +"<br>"
}

/*
* Handle a new user that just entered the current room
*/
public function onUserEnterRoom(evt:SFSEvent):void
{
	var roomId:int = evt.params.room as int
	var user:User = evt.params.user as User
	
	var provider:ArrayCollection = userList.dataProvider as ArrayCollection

	provider.addItem( {label:user.getName(), data:user.getId()} )
	provider.refresh()				
	
	userList.invalidateList()
}

/*
* Handle a user who left the room
*/
public function onUserLeaveRoom(evt:SFSEvent):void
{
	var roomId:int = evt.params.roomId as int
	var userId:int = evt.params.userId as int
	
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
} 

/*
* Handle disconnection
*/
public function onConnectionLost(evt:SFSEvent):void
{
	removePopup()
	viewstack.selectedChild = view_logout
}


//---------------------------------------------------------------------
// GUI Event Handlers
//---------------------------------------------------------------------
public function bt_login_click():void
{
	if (tf_name.text.length > 0)
	{
		// Send login
		sfs.login(serverZone, tf_name.text, "")
	}
}

/*
* Launch the create room window
*/
public function bt_create_click():void
{
	createGameWin = PopUpManager.createPopUp(this, CreateGameWindow, true) as TitleWindow
	createGameWin["bt_create"].addEventListener("click", handleCreateRoom)
}

/*
* Log the user out and close connection
*/
public function bt_logout_click():void
{
	sfs.disconnect()
	viewstack.selectedChild = view_logout
}

/*
* Join a new room when an item is selected in the room list component
*/
public function roomList_change():void
{
	var roomId:int = int(roomList.selectedItem.data)
	var roomIsPrivate:Boolean = sfs.getRoom(roomId).isPrivate()
	
	joinGameWin = PopUpManager.createPopUp(this, JoinGameWindow, true) as TitleWindow
	joinGameWin["bt_join"].addEventListener("click", handleJoinRoom)
	
	if (!roomIsPrivate)
		joinGameWin.currentState = "noPwd"
}

/*
* Send a public message to all users in the room
*/
public function bt_send_click(ti:TextInput):void
{
	if (ti.text.length > 0)
	{
		sfs.sendPublicMessage(ti.text)
		ti.text = ""
	}
}

/*
* Exit a game room
*/
public function bt_exitGame_click():void
{
	gameInstance.destroyGame()
	removePopup()
	viewstack.selectedChild = view_chat
	
	sfs.getRoomList()
}

/*
* Show the private message dialogue
*/
public function userList_change():void
{
	pmUserId = userList.selectedItem.data
	
	if (pmUserId != sfs.myUserId)
	{	
		pmWindow = PopUpManager.createPopUp(this, PmWindow, true) as TitleWindow
		pmWindow["bt_send"].addEventListener("click", handleSendPm)
	}
}

/*
* Send the create room request to the server
*/
public function handleCreateRoom(evt:Event):void
{
	var roomName:String = createGameWin["tf_roomName"].text
	var roomPwd:String = createGameWin["tf_roomPwd"].text
	var roomMaxS:int = createGameWin["ns_maxSpectators"].value	
	
	if (roomName.length > 0)
	{
		// Set room properties
		var roomObj:Object = {}
		roomObj.name = roomName
		roomObj.isGame = true
		roomObj.password = roomPwd
		roomObj.maxUsers = 2
		roomObj.maxSpectators = roomMaxS
		
		var xt:Object = {}
		xt.name = xtName
		xt.script = xtScript
		
		roomObj.extension = xt
		
		// Create the room!
		sfs.createRoom(roomObj)
	}		
}

/*
* Send the join game room request to the server
*/
public function handleJoinRoom(evt:Event):void
{
	var roomId:int = int(roomList.selectedItem.data)
	var roomPwd:String = (sfs.getRoom(roomId).isPrivate() ? joinGameWin["tf_roomPwd"].text : "")
	var isSpectator:Boolean = joinGameWin["rb_isSpectator"].selected
	trace("isSpectator: " + isSpectator)
	sfs.joinRoom(roomId, roomPwd, isSpectator)	
}

/*
* Send the private message
*/
public function handleSendPm(evt:Event):void
{
	var message:String = pmWindow["tf_message"].text
	
	if (message.length > 0 && pmUserId > 0)
	{
		sfs.sendPrivateMessage(message, pmUserId)
		pmUserId = -1
		
		// Remove window
		PopUpManager.removePopUp(pmWindow)
	}
}

/*
* From the logout screen start a new connection
*/
public function backToLoginScreen():void
{
	viewstack.selectedChild = view_connecting
	
	connect()
}

/*
* Populate the list of rooms
*/
public function populateRoomList():void
{
	if (!chatViewInited)
		chatViewInited = true
		
	var rList:Array = roomListEvent.params.roomList as Array
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
	
	// Populate the data provider with list of game rooms only
	for each(var r:Room in rList)
	{
		if (r.isGame())
		{
			var txt:String = setRoomLabel(r)
			provider.addItem( {label:txt, data:r.getId()} )
		}
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
	
	// Join the default room
	sfs.joinRoom(defaultRoomName, "")
}

// Set room label in rooms list
private function setRoomLabel(r:Room):String
{
	var txt:String = r.getName() + " (" + r.getUserCount() + "/" + r.getMaxUsers() + ")"
	txt += "-(" + r.getSpectatorCount() + "/" + r.getMaxSpectators() + ")"
		
	return txt
}

// Set the passed room as the selected item in the room list component
public function setRoomListSelection(room:Room):void
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


/*
* Init game
*/
public function initGame():void
{
	trace("Game view creation completed")
	if (!gameViewInited)
		gameViewInited = true
	
	gameInstance = new TrisGame()
	
	var dow:DisplayObjectWrapper = new DisplayObjectWrapper()
	dow.content = gameInstance
	gameContainer.addChild(dow)
	
	var params:Object = {}
	params.sfs = sfs
	params.container = this
	
	gameInstance.initGame(params)
}

/*
* Show in-game message
*/
public function showPopup(type:String, msg:String, callback:Function):void
{
	removePopup()
	
	gameMsg = PopUpManager.createPopUp(gameContainer, GameMessage, false) as GameMessage
	gameMsg.currentState = type
	gameMsg.message = msg
	gameMsg.callBack = callback
	
	gameContainer.enabled = false
}

/*
* Remove in-game message
*/
public function removePopup():void
{
	if (gameMsg != null)
	{
		PopUpManager.removePopUp(gameMsg)
		gameContainer.enabled = true
	}
}