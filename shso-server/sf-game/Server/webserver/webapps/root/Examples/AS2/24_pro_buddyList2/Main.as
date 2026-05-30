import it.gotoandplay.smartfoxserver.SmartFoxClient
import it.gotoandplay.smartfoxbits.events.*
import com.metaliq.managers.FocusManager


var DEFAULT_STYLE:Object =	{
								fontFamily: "Verdana",
								fontWeight: "normal",
								fontStyle: "normal",
								fontSize: 11,
								fontColor: 0x000000,
								embedFonts: false
							}

var sfs:SmartFoxClient



// Initialize application
init()



function init():Void
{
	// Get reference to SmartFoxClient instance
	sfs = bit_connector.connection
	
	// Set components styles to match SmartFoxBits' one
	setComponentsStyle()
	
	// Set UI initial status
	toggleUI(false)
	
	// Register for SFS events
	bit_connector.addEventListener( SFSEvent.onConnection, onConnection )
	bit_connector.addEventListener( SFSEvent.onConnectionLost, onConnectionLost )
	bit_connector.addEventListener( SFSEvent.onLogin, onLogin )
	bit_connector.addEventListener( SFSEvent.onRoomListUpdate, onRoomListUpdate )
	bit_connector.addEventListener( SFSEvent.onJoinRoom, onJoinRoom )
	bit_connector.addEventListener( SFSEvent.onJoinRoomError, onJoinRoomError )
	bit_connector.addEventListener( SFSEvent.onBuddyList, onBuddyList )
	bit_connector.addEventListener( SFSEvent.onBuddyListUpdate, onBuddyListUpdate )
	bit_connector.addEventListener( SFSEvent.onPrivateMessage, onPrivateMessage ) // This listener is required to handle private messages coming from a buddy not yet selected
	sfs.onBuddyPermissionRequest = onBuddyPermissionRequest // This event is not yet available in the current SmartFoxBits version, so we have to register directly on the sfs instance
	
	// Register for components events
	bt_logout.addEventListener( "click", bt_logout_click )
	bt_addBuddy.addEventListener( "click", bt_addBuddy_click )
	bt_removeBuddy.addEventListener( "click", bt_removeBuddy_click )
	bt_blockBuddy.addEventListener( "click", bt_blockBuddy_click )
	bt_unblockBuddy.addEventListener( "click", bt_unblockBuddy_click )
	bt_setVariable.addEventListener( "click", bt_setVariable_click )
	mc_alert.bt_grant.addEventListener ( "click", bt_grant_click )
	mc_alert.bt_refuse.addEventListener ( "click", bt_refuse_click )
	
	// Setup datagrids
	setupDatagrids()
	
	debugTrace( "API Version: " + sfs.getVersion() )
}

/**
 * Trace messages to the chat text area
 */
function debugTrace(msg:String):Void
{
	bit_chatbox.chatTextArea.text += "<font color='#000000'>[LOG] " + msg + "</font><br>"
}

function setComponentsStyle():Void
{
	// Remove components' focus rectangle
	bt_logout.bg.useFocusRect = true
	bt_removeBuddy.bg.useFocusRect = true
	bt_blockBuddy.bg.useFocusRect = true
	bt_unblockBuddy.bg.useFocusRect = true
	bt_addBuddy.bg.useFocusRect = true
	tf_buddyName.bg.useFocusRect = true
	tf_varKey.bg.useFocusRect = true
	tf_varValue.bg.useFocusRect = true
	bt_setVariable.bg.useFocusRect = true
	mc_alert.bt_grant.bg.useFocusRect = true
	mc_alert.bt_refuse.bg.useFocusRect = true
	
	FocusManager.focusRect = ""
	
	// Set components' default style
	for (var s:String in DEFAULT_STYLE)
	{
		bt_logout.setInstanceStyle(s, DEFAULT_STYLE[s])
		
		bt_removeBuddy.setInstanceStyle(s, DEFAULT_STYLE[s])
		bt_blockBuddy.setInstanceStyle(s, DEFAULT_STYLE[s])
		bt_unblockBuddy.setInstanceStyle(s, DEFAULT_STYLE[s])
		bt_addBuddy.setInstanceStyle(s, DEFAULT_STYLE[s])
		tf_buddyName.setInstanceStyle(s, DEFAULT_STYLE[s])
		
		tf_varKey.setInstanceStyle(s, DEFAULT_STYLE[s])
		tf_varValue.setInstanceStyle(s, DEFAULT_STYLE[s])
		bt_setVariable.setInstanceStyle(s, DEFAULT_STYLE[s])
		
		mc_alert.bt_grant.setInstanceStyle(s, DEFAULT_STYLE[s])
		mc_alert.bt_refuse.setInstanceStyle(s, DEFAULT_STYLE[s])
		
		dg_buddies.setStyle(s, DEFAULT_STYLE[s])
		dg_vars.setStyle(s, DEFAULT_STYLE[s])
	}
}

function setupDatagrids():Void
{
	// Initialize datagrids components
	dg_buddies.addColumn("name")
	dg_buddies.addColumn("online")
	dg_buddies.addColumn("X")	
	dg_buddies.getColumnAt(0).width = 70
	dg_buddies.getColumnAt(2).width = 25
	dg_buddies.vScrollPolicy = "auto"
	
	// Create listener object
	var dgListener:Object = new Object()
	dgListener.change = dg_buddies_click
	dg_buddies.addEventListener("change", dgListener)
	
	dg_vars.addColumn("key")
	dg_vars.addColumn("value")
	dg_vars.vScrollPolicy = "auto"
}

function toggleUI(b:Boolean):Void
{
	bt_logout.enabled = b
	
	bt_removeBuddy.enabled = b
	bt_blockBuddy.enabled = b
	bt_unblockBuddy.enabled = b
	bt_addBuddy.enabled = b
	tf_buddyName.enabled = b
	
	tf_varKey.enabled = b
	tf_varValue.enabled = b
	bt_setVariable.enabled = b
	
	dg_vars.enabled = b
	dg_buddies.enabled = b
	
	if (!b)
		mc_alert._visible = false
}

function refreshBuddyList():Void
{
	var dp:Array = []
	
	for ( var s:String in sfs.buddyList )
	{
		var buddy:Object = sfs.buddyList[s]
		
		dp.push( 
					{ 
						name:buddy.name, 
						online: buddy.isOnline ? "Y" : "N",
						X:buddy.isBlocked ? "Y" : "N" 
					} 
				)
	}
	
	dg_buddies.dataProvider = dp
	
	refreshBuddyVariables()
}

function refreshBuddyVariables(buddy:Object):Void
{
	if ( buddy != null )
	{
		var dp:Array = []
	
		for ( var key:String in buddy.variables )
		{
			dp.push( { key:key, value:buddy.variables[key] } )
		}
	
		dg_vars.dataProvider = dp
	}
}

function sendBuddyPermissionResponse(b:Boolean):Void
{
	sfs.sendBuddyPermissionResponse( b, mc_alert.lb_name.text )
	mc_alert.lb_name.text = ""
	mc_alert._visible = false
}


/* ::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 *	Button Handlers
 * ::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 */
function bt_logout_click():Void
{
	sfs.logout()
	toggleUI(false)
	
	dg_buddies.dataProvider = []
	dg_vars.dataProvider = []
}

function bt_addBuddy_click():Void
{
	if ( tf_buddyName.text != "" )
	{
		sfs.addBuddy( tf_buddyName.text )
		tf_buddyName.text = ""
	}
}

function dg_buddies_click(evt:Object):Void
{
	var buddyName:String = evt.target.selectedItem.name
	var buddy:Object = sfs.getBuddyByName( buddyName )
	var buddyId:Number = buddy.id
	
	refreshBuddyVariables( buddy )
	
	bit_chatbox.setPrivateChatUserId( buddyId )
}

function bt_grant_click():Void
{
	sendBuddyPermissionResponse( true )
}

function bt_refuse_click():Void
{
	sendBuddyPermissionResponse( false )
}

function bt_removeBuddy_click():Void
{
	if ( dg_buddies.selectedItem != null )
		sfs.removeBuddy( dg_buddies.selectedItem.name )
}

function bt_blockBuddy_click():Void
{
	if ( dg_buddies.selectedItem != null )
		sfs.setBuddyBlockStatus( dg_buddies.selectedItem.name, true )
}

function bt_unblockBuddy_click():Void
{
	if ( dg_buddies.selectedItem != null )
		sfs.setBuddyBlockStatus( dg_buddies.selectedItem.name, false )
}

function bt_setVariable_click():Void
{
	if ( tf_varKey.text != "" && tf_varValue.text != "" )
	{
		var vars:Array = []
		vars[tf_varKey.text] = tf_varValue.text
		
		sfs.setBuddyVariables( vars )
	}
}


/* ::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 *	SmartFoxServer Handlers
 * ::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 */

/**
 * Handle connection
 */
function onConnection(evt:SFSEvent):Void
{
	var success:Boolean = evt.params.success
	
	if (success)
	{
		debugTrace("Connection successfull!")
		debugTrace("Click the LOGIN button to start")
	}
	else
	{
		debugTrace("Connection failed!")	
	}
}

/**
 * Handle connection lost
 */
function onConnectionLost(evt:SFSEvent):Void
{
	debugTrace("Connection lost!")
	
	toggleUI( false )
	
	dg_buddies.dataProvider = []
	dg_vars.dataProvider = []
}

/**
 * Handle login response
 */
function onLogin(evt:SFSEvent):Void
{
	if (evt.params.resObj.success)
	{
		debugTrace("Successfully logged in -> " + evt.params.resObj.name)
	}
	else
	{
		debugTrace("Login failed. Reason: " + evt.params.resObj.error)
	}
}

/**
 * Handle room list
 */
function onRoomListUpdate(evt:SFSEvent):Void
{
	debugTrace("Room list received")

	// Tell the server to auto-join us in the default room for this Zone
	sfs.autoJoin()
}

/**
 * Handle successfull join
 */
function onJoinRoom(evt:SFSEvent):Void
{
	// Enable UI
	toggleUI( true )
	
	// Load buddy list
	sfs.loadBuddyList()
}

/**
 * Handle problems with join
 */
function onJoinRoomError(evt:SFSEvent):Void
{
	debugTrace("Problems joining default room. Reason: " + evt.params.error)	
}

/**
* Handle a private message
*/
function onPrivateMessage(evt:SFSEvent):Void
{
	// If the private message is coming from one of my buddies, but he is not selected in the datagrid,
	// select him and pass the message to the chatbox instance;
	// otherwise the private message will be handled by the chatbox itself
	
	var senderId:Number = evt.params.userId
	var message:String = evt.params.message.split(String.fromCharCode(1))[0] // Private messages sent through the chatbox component contain also the sender's username & id in the message body; a separator is used to handle them
	
	var buddy:Object = sfs.getBuddyById( senderId )
	
	if (senderId != sfs.myUserId)
	{
		if ( buddy != null )
		{
			if (dg_buddies.selectedItem.name != buddy.name)
			{
				// Enable private chat with this buddy
				bit_chatbox.setPrivateChatUserId(senderId, [{userId: senderId, userName: buddy.name, text: message}])
			
				// Select buddy in datagrid
				for (var i:Number = 0; i < dg_buddies.dataProvider.length; i++)
				{
					if (dg_buddies.getItemAt(i).name == buddy.name)
					{
						dg_buddies.selectedIndex = i
						break
					}
				}
			}
		}
		else
			debugTrace("Message from unknown user: " + message)
	}
}

/**
* Handle buddy list events
*/
function onBuddyList(evt:SFSEvent):Void
{
	dg_buddies.dataProvider = []
	dg_vars.dataProvider = []
	
	refreshBuddyList()
}

function onBuddyListUpdate(evt:SFSEvent):Void
{
	var isSameItem:Boolean = dg_buddies.selectedItem != null && dg_buddies.selectedItem.name == evt.params.buddy.name
	refreshBuddyList()
	bit_chatbox.setPrivateChatUserId(-1)
	
	if ( isSameItem )
		refreshBuddyVariables( evt.params.buddy )
}

function onBuddyPermissionRequest(sender:String, message:String):Void
{
	mc_alert.lb_name.text = sender
	mc_alert._visible = true
}