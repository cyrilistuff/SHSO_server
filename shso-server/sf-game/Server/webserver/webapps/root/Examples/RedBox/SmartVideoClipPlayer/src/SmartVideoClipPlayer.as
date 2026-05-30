import flash.events.Event;
import flash.net.NetStream;
import flash.events.NetStatusEvent;
import flash.media.Camera;
import mx.collections.ArrayCollection;
import mx.collections.IViewCursor;

import it.gotoandplay.smartfoxserver.SmartFoxClient;
import it.gotoandplay.smartfoxserver.SFSEvent;
import it.gotoandplay.smartfoxserver.data.Room;
import it.gotoandplay.smartfoxserver.data.User;

import com.smartfoxserver.redbox.AVClipManager;
import com.smartfoxserver.redbox.events.RedBoxClipEvent;
import com.smartfoxserver.redbox.data.Clip;
import com.smartfoxserver.redbox.exceptions.NoAVConnectionException;
import com.smartfoxserver.redbox.exceptions.ClipActionNotAllowedException;


private var smartFox:SmartFoxClient;
private var red5IpAddress:String;
private var avClipMan:AVClipManager;
private var inited:Boolean;

[Bindable]
private var clipsDP:ArrayCollection;

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
	smartFox.addEventListener(SFSEvent.onJoinRoom, onJoinRoom)
	smartFox.addEventListener(SFSEvent.onJoinRoomError, onJoinRoomError)
	smartFox.addEventListener(SFSEvent.onRoomListUpdate, onRoomListUpdate)
	smartFox.addEventListener(SFSEvent.onPublicMessage, onPublicMessage)
	smartFox.addEventListener(SFSEvent.onUserEnterRoom, onUserEnterRoom)
	smartFox.addEventListener(SFSEvent.onUserLeaveRoom, onUserLeaveRoom)
	smartFox.addEventListener(SFSEvent.onConnectionLost, onConnectionLost)
	
	// Set login panel state and label
	loginPanel.currentState = "connection"
	loginPanel.tf_connection.text = "Loading client configuration..."
	
	// Load SmartFoxServer client configuration
	smartFox.loadConfig("config.xml", false)
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
 * Called by the loginPanel component after the last transition has been completed
 */
public function onLoginCompleted():void
{
	// Move to main application view
	viewstack1.selectedChild = view_main
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
 * Send a public message to all users
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
 * Called by the datagrid component when the selected item changes
 */
public function onClipSelected():void
{
	// Get the selected clip id
	var clipId:String = dg_clips.selectedItem.id
	
	// Request a stream object to AVClipManager instance
	try
	{
		var stream:NetStream = avClipMan.getStream()
		
		// Add event listeners to stream
		stream.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus)
		stream.client = this // this is required in order to handle the onMetaData, onCuePoint and onPlayStatus events
		
		// Play stream
		videoPlayer.reset()
		videoPlayer.playStream(stream, clipId)
		
		tb_title.text = dg_clips.selectedItem.title
		tb_author.text = dg_clips.selectedItem.author
		
		// Enable buttons
		bt_delete.enabled = true
		bt_update.enabled = true
	}
	catch (err:NoAVConnectionException)
	{
		trace ("ERROR -", err.message)
	}
}

/**
 * Delete the selected clip
 */
public function bt_delete_click():void
{
	// Get the selected clip id
	var clipId:String = dg_clips.selectedItem.id
	
	try
	{
		avClipMan.deleteClip(clipId)
	}
	catch (err:ClipActionNotAllowedException)
	{
		trace ("ERROR -", err.message)
	}
}

/**
 * Update the selected clip's properties
 */
public function bt_update_click():void
{
	// Get the selected clip id
	var clipId:String = dg_clips.selectedItem.id
	
	try
	{
		var clipProperties:Object = {}
		clipProperties.title = tb_title.text
		clipProperties.author = tb_author.text
		
		avClipMan.updateClipProperties(clipId, clipProperties)
	}
	catch (err:ClipActionNotAllowedException)
	{
		trace ("ERROR -", err.message)
	}
}

/**
 * Called when the accordion view changes
 */
public function onAccordionViewChange():void
{
	resetPlayBackInterface()
	resetRecordingInterface()
}

/**
 * Start recording a new clip
 */
public function bt_record_click():void
{
	avClipMan.startClipRecording(true, true)
}

/**
 * Stop clip recording
 */
public function bt_stop_click():void
{
	avClipMan.stopClipRecording()
	
	// Clear video container
	sv_video.video.attachCamera(null)
}

/**
 * Cancel clip recording
 */
public function bt_cancel_click():void
{
	// Reset a/v clip recording interface (recording is cancelled too)
	resetRecordingInterface()
	
	// Go back to playback section
	accordion.selectedIndex = 0
}

/**
 * Preview recorded clip
 */
public function bt_preview_click():void
{
	var stream:NetStream = avClipMan.previewRecordedClip()
	sv_video.video.attachNetStream(stream)
}

/**
 * Submit recorded clip
 */
public function bt_submit_click():void
{
	var clipProperties:Object = {}
	clipProperties.title = tb_titleRec.text
	clipProperties.author = tb_authorRec.text
	
	avClipMan.submitRecordedClip(clipProperties)
	
	bt_cancel_click()
}

//---------------------------------------------------------------------
// Private methods
//---------------------------------------------------------------------

private function initializeAV():void
{
	// Init clips datagrid's dataprovider
	clipsDP = new ArrayCollection()
	
	red5IpAddress = smartFox.ipAddress
	
	// Create AVClipManager instance
	avClipMan = new AVClipManager(smartFox, red5IpAddress, true)
	
	avClipMan.addEventListener(RedBoxClipEvent.onAVConnectionInited, onAVConnectionInited)
	avClipMan.addEventListener(RedBoxClipEvent.onAVConnectionError, onAVConnectionError)
	avClipMan.addEventListener(RedBoxClipEvent.onClipList, onAVClipList)
	avClipMan.addEventListener(RedBoxClipEvent.onClipSubmissionFailed, onClipSubmissionFailed)
	avClipMan.addEventListener(RedBoxClipEvent.onClipAdded, onClipAdded)
	avClipMan.addEventListener(RedBoxClipEvent.onClipRecordingStarted, onClipRecordingStarted)
	avClipMan.addEventListener(RedBoxClipEvent.onClipDeleted, onClipDeleted)
	avClipMan.addEventListener(RedBoxClipEvent.onClipUpdated, onClipUpdated)
	
	// Retrieve clips list
	avClipMan.getClipList()
	
	inited = true
}

private function addClipToList(clip:Clip):void
{
	var tmpObj:Object = {}
	tmpObj.id = clip.id
	tmpObj.rtmp = clip.rtmpURL
	tmpObj.submitter = clip.username
	tmpObj.size = Math.round(clip.size / 1000) + " Kb"
	tmpObj.published = clip.lastModified
	tmpObj.title = clip.properties.title
	tmpObj.author = clip.properties.author
	
	clipsDP.addItem(tmpObj)
}

private function resetPlayBackInterface():void
{
	// Reset video player
	videoPlayer.reset()
	
	// Reset datagrid
	dg_clips.selectedIndex = -1
	
	// Disable delete/update buttons
	bt_delete.enabled = false
	bt_update.enabled = false
	
	// Reset textfields
	lb_duration.text = "---"
	lb_framerate.text = "---"
	lb_size.text = "---"
	tb_title.text = ""
	tb_author.text = ""
}

private function resetRecordingInterface():void
{
	// Cancel recording (in case it's in progress)
	avClipMan.cancelClipRecording()
	
	// Reset textfields
	tb_titleRec.text = ""
	tb_authorRec.text = ""
	
	// Clear video container in recording section
	sv_video.video.attachNetStream(null)
	sv_video.video.attachCamera(null)
	sv_video.video.clear() // <-- NOT WORKING (possible Flash Player bug: only 1 pixel in the top left corner is cleared)
	
	sv_video.reset() // As the previous statement doesn't work, we reset the video container
}

/**
 * Search the clips dataprovider and return the item index
 */
private function searchClipsList(clipId:String):int
{
	// Declare a cursor
	var cursor:IViewCursor = clipsDP.createCursor()
	
	// Use cursor to search for clip id
	while (!cursor.afterLast)
	{
		if (cursor.current.id == clipId)
			return cursor.bookmark.getViewIndex()
		
		cursor.moveNext()
	}
	
	return -1
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
	smartFox.autoJoin()
}

public function onJoinRoom(evt:SFSEvent):void
{
	// Set login panel state
	loginPanel.currentState = "logged"
	
	// Initialize AVClipManager
	initializeAV()
}

public function onJoinRoomError(evt:SFSEvent):void
{
	// Set login panel state and label
	loginPanel.currentState = "login_error"
	loginPanel.tf_error.text = evt.params.error
	
	smartFox.logout()
}

public function onPublicMessage(evt:SFSEvent):void
{
	var message:String = evt.params.message
	var sender:User = evt.params.sender
	
	ta_chat.htmlText += "<b>[" + sender.getName() + "]:</b> " + message +"<br>"
	ta_chat.verticalScrollPosition = ta_chat.maxVerticalScrollPosition
}

public function onUserEnterRoom(evt:SFSEvent):void
{
	var user:User = evt.params.user
	
	ta_chat.htmlText += "<i>" + user.getName() + " entered the chat</i>"
	ta_chat.verticalScrollPosition = ta_chat.maxVerticalScrollPosition
}

public function onUserLeaveRoom(evt:SFSEvent):void
{
	var userName:String = evt.params.userName
	
	ta_chat.htmlText += "<i>" + userName + " left the chat</i>"
	ta_chat.verticalScrollPosition = ta_chat.maxVerticalScrollPosition
}

public function onConnectionLost(evt:SFSEvent):void
{
	if (inited)
	{
		// Reset a/v clip playback interface
		resetPlayBackInterface()
		
		// Reset a/v clip recording interface
		resetRecordingInterface()
		
		// Reset chat area
		ta_chat.htmlText = ""
		ta_chat.verticalScrollPosition = ta_chat.maxVerticalScrollPosition
		
		// Remove listeners added to AVClipManager instance
		avClipMan.removeEventListener(RedBoxClipEvent.onAVConnectionInited, onAVConnectionInited)
		avClipMan.removeEventListener(RedBoxClipEvent.onAVConnectionError, onAVConnectionError)
		avClipMan.removeEventListener(RedBoxClipEvent.onClipList, onAVClipList)
		avClipMan.removeEventListener(RedBoxClipEvent.onClipSubmissionFailed, onClipSubmissionFailed)
		avClipMan.removeEventListener(RedBoxClipEvent.onClipAdded, onClipAdded)
		avClipMan.removeEventListener(RedBoxClipEvent.onClipRecordingStarted, onClipRecordingStarted)
		avClipMan.removeEventListener(RedBoxClipEvent.onClipDeleted, onClipDeleted)
		avClipMan.removeEventListener(RedBoxClipEvent.onClipUpdated, onClipUpdated)
		avClipMan = null
	}
	
	// Show disconnection box
	viewstack1.selectedChild = view_login
	loginPanel.currentState = "disconnection"
}

//---------------------------------------------------------------------
// RedBox AVClipManager event handlers
//---------------------------------------------------------------------

public function onAVConnectionInited(evt:RedBoxClipEvent):void
{
	// Nothing to do. Usually we should wait this event before enabling the a/v recording/playback related interface elements.
}

public function onAVConnectionError(evt:RedBoxClipEvent):void
{
	trace("AV connection error:", evt.params.errorCode)
	
	// We should now display an error message, or simply try to re-establish a connection calling the AVClipManager.initAVConnection() method.
}

public function onAVClipList(evt:RedBoxClipEvent):void
{
	clipsDP.removeAll()
	
	for each (var clip:Clip in evt.params.clipList)
		addClipToList(clip)
}

public function onClipSubmissionFailed(evt:RedBoxClipEvent):void
{
	trace("AV clip submission error:", evt.params.error)
}

public function onClipAdded(evt:RedBoxClipEvent):void
{
	// Update clips list
	addClipToList(evt.params.clip)
}

public function onClipRecordingStarted(evt:RedBoxClipEvent):void
{
	// Attach camera stream to video container on the stage
	sv_video.video.attachCamera(Camera.getCamera())
}

public function onClipDeleted(evt:RedBoxClipEvent):void
{
	// Update clips list
	var i:int = searchClipsList(evt.params.clip.id)
	
	if (dg_clips.selectedItem.id == evt.params.clip.id)
		resetPlayBackInterface()
	
	if (i > -1)
		clipsDP.removeItemAt(i)
}

public function onClipUpdated(evt:RedBoxClipEvent):void
{
	// Update clips list
	var clip:Clip = evt.params.clip
	var i:int = searchClipsList(clip.id)
	
	if (i > -1)
	{
		var item:Object = clipsDP.getItemAt(i)
		item.title = clip.properties.title
		item.author = clip.properties.author
		
		clipsDP.refresh()
		
		if (dg_clips.selectedItem.id == clip.id)
		{
			tb_author.text = clip.properties.author
			tb_title.text = clip.properties.title
		}
	}
}

//---------------------------------------------------------------------
// NetStream event handlers
//---------------------------------------------------------------------

public function onNetStatus(evt:NetStatusEvent):void
{
	trace ("--- onNetStatus event")
	trace ("\tLevel: " + evt.info.level)
	trace ("\tCode: " + evt.info.code)
}

public function onMetaData(info:Object):void
{
	trace ("--- onMetaData Event")
	trace ("\tDuration: " + info.duration)
	trace ("\tFramerate: " + info.framerate)
	trace ("\tWidth: " + info.width)
	trace ("\tHeight: " + info.height)
	trace ("\tCue points: " + info.cuePoints)
	
	// Set clip duration (to enable seek bar)
	if (info.duration > 0)
		videoPlayer.setDuration(info.duration)
	
	// Set clip aspect ratio
	if (info.width != undefined && info.height != undefined)
		videoPlayer.setAspectRatio(info.width / info.height)
	
	// Display metadata
	lb_duration.text = (info.duration > 0 ? (Math.round(info.duration) + " seconds") : "unknown")
	lb_framerate.text = (info.framerate != undefined ? (Math.round(info.framerate) + " fps") : "unknown")
	lb_size.text = ((info.width != undefined && info.height != undefined) ? (info.width + "x" + info.height + " pixels") : "unknown")
}

public function onCuePoint(info:Object):void
{
	trace ("--- onCuePoint event")
	trace ("\tName: " + info.name)
	trace ("\tParameters: " + info.parameters)
	trace ("\tTime: " + info.time)
	trace ("\tType: " + info.type)
}

public function onPlayStatus(info:Object):void
{
	trace ("--- onPlayStatus event")
	trace ("\tLevel: " + info.level)
	trace ("\tCode: " + info.code)
	
	// Reset video upon clip completion
	if (info.code == "NetStream.Play.Complete")
		videoPlayer.stopStream()
}

public function onLastSecond(info:Object):void
{
	trace ("--- onLastSecond event")
	
	// Some streams also fire this event
}