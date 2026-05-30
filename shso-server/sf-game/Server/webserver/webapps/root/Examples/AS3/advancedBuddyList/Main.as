package
{
	import flash.display.MovieClip
	import it.gotoandplay.smartfoxserver.SmartFoxClient
	import it.gotoandplay.smartfoxserver.SFSEvent
	import flash.events.*
	import fl.events.ListEvent
	import fl.data.DataProvider
	import flash.text.TextField
	import flash.utils.*
	
	public class Main extends MovieClip
	{
		private var sfs:SmartFoxClient
		
		init()
		
		function Main() : void
		{
			mc_alert.visible = false
			init()
		}
		
		function init() : void
		{
			setTimeout(toggleUI, 50, false)
			
			sfs = new SmartFoxClient()

			// Register for SFS events
			sfs.addEventListener( SFSEvent.onConnection, onConnection )
			sfs.addEventListener( SFSEvent.onConnectionLost, onConnectionLost )
			sfs.addEventListener( SFSEvent.onLogin, onLogin )
			sfs.addEventListener( SFSEvent.onRoomListUpdate, onRoomListUpdate )
			sfs.addEventListener( SFSEvent.onJoinRoom, onJoinRoom )
			sfs.addEventListener( SFSEvent.onJoinRoomError, onJoinRoomError )
			sfs.addEventListener( SFSEvent.onConfigLoadFailure, onConfigLoadFailure )
			sfs.addEventListener( SFSEvent.onBuddyList, onBuddyList )
			sfs.addEventListener( SFSEvent.onBuddyListUpdate, onBuddyListUpdate )
			sfs.addEventListener( SFSEvent.onBuddyPermissionRequest, onBuddyPermissionRequest )
			sfs.addEventListener( SFSEvent.onPrivateMessage, onPrivateMessage )
			
			// Register for generic errors
			sfs.addEventListener( SecurityErrorEvent.SECURITY_ERROR, onSecurityError )
			sfs.addEventListener( IOErrorEvent.IO_ERROR, onIOError )

			bt_connect.addEventListener( MouseEvent.CLICK, bt_connect_click )
			bt_addBuddy.addEventListener( MouseEvent.CLICK, bt_addBuddy_click )
			bt_removeBuddy.addEventListener( MouseEvent.CLICK, bt_removeBuddy_click )
			bt_blockBuddy.addEventListener( MouseEvent.CLICK, bt_blockBuddy_click )
			bt_unblockBuddy.addEventListener( MouseEvent.CLICK, bt_unblockBuddy_click )
			bt_setVariable.addEventListener( MouseEvent.CLICK, bt_setVariable_click )
			bt_disconnect.addEventListener( MouseEvent.CLICK, bt_disconnect_click )
			bt_send.addEventListener( MouseEvent.CLICK, bt_send_click )
			
			mc_alert.bt_grant.addEventListener ( MouseEvent.CLICK, bt_grant_click )
			mc_alert.bt_refuse.addEventListener ( MouseEvent.CLICK, bt_refuse_click )
			
			// Initialize datagrids components
			dg_buddies.columns = ["name", "online", "X"]
			dg_vars.columns = ["key", "value"]
			
			dg_buddies.getColumnAt(0).width = 80
			dg_buddies.getColumnAt(2).width = 25
			
			dg_buddies.addEventListener(ListEvent.ITEM_CLICK, dg_buddies_click)
			
			debugTrace( "API Version: " + sfs.getVersion() )
			debugTrace( "Click the CONNECT button to start" )
		}
		
	
		
		/* ::::::::::::::::::::::::::::::::::::::::::::::::::::::::
		 *	Button Handlers
		 * ::::::::::::::::::::::::::::::::::::::::::::::::::::::::
		 */
		function bt_connect_click(evt:Event):void
		{
			if ( !sfs.isConnected && tf_connect.text != "" )
				sfs.loadConfig()
				
			else
				debugTrace("You are already connected!")
		}
		
		function bt_addBuddy_click(evt:Event):void
		{
			if ( tf_buddyName.text != "" )
			{
				sfs.addBuddy( tf_buddyName.text )
				tf_buddyName.text = ""
			}
				
		}
		
		function bt_removeBuddy_click(evt:Event):void
		{
			if ( dg_buddies.selectedItem != null )
			{
				sfs.removeBuddy( dg_buddies.selectedItem.name )
			}
				
		}
		
		function bt_blockBuddy_click(evt:Event):void
		{
			if ( dg_buddies.selectedItem != null )
				sfs.setBuddyBlockStatus( dg_buddies.selectedItem.name, true )
		}
		
		function bt_unblockBuddy_click(evt:Event):void
		{
			if ( dg_buddies.selectedItem != null )
				sfs.setBuddyBlockStatus( dg_buddies.selectedItem.name, false )
		}
		
		function bt_setVariable_click(evt:Event):void
		{
			if ( tf_varKey.text != "" && tf_varValue.text != "" )
			{
				var vars:Array = []
				vars[tf_varKey.text] = tf_varValue.text
				
				sfs.setBuddyVariables( vars )
			}
		}
		
		function bt_grant_click(evt:Event):void
		{
			sendBuddyPermissionResponse( true )
		}
		
		function bt_refuse_click(evt:Event):void
		{
			sendBuddyPermissionResponse( false )
		}
		
		function bt_disconnect_click(evt:Event):void
		{
			sfs.disconnect()
		}
		
		function bt_send_click(evt:Event):void
		{
			if ( dg_buddies.selectedItem != null && tf_chat.text != "" )
			{
				var buddy = sfs.getBuddyByName( dg_buddies.selectedItem.name )
				
				if ( buddy.isOnline)
				{
					sfs.sendPrivateMessage( tf_chat.text, buddy.id )
					tf_chat.text = ""
				}
			}
		}
		
		function sendBuddyPermissionResponse( b:Boolean ):void
		{
			sfs.sendBuddyPermissionResponse( b, mc_alert.lb_name.text )
			mc_alert.lb_name.text = ""
			mc_alert.visible = false
		}
		
		/* ::::::::::::::::::::::::::::::::::::::::::::::::::::::::
		 *	Datagrid Handlers
		 * ::::::::::::::::::::::::::::::::::::::::::::::::::::::::
		 */
		
		function dg_buddies_click( evt:ListEvent ) : void
		{
			var buddy:Object = sfs.getBuddyByName( evt.item.name )
			refreshBuddyVariables( buddy )
		}
		
		function toggleUI(b:Boolean):void
		{
			tf_connect.enabled = !b
			bt_connect.enabled = !b
			
			tf_buddyName.enabled = b
			tf_varKey.enabled = b
			tf_varValue.enabled = b
			tf_chat.enabled = b
			ta_chat.enabled = b
			
			bt_disconnect.enabled = b
			bt_removeBuddy.enabled = b
			bt_blockBuddy.enabled = b
			bt_unblockBuddy.enabled = b
			bt_setVariable.enabled = b
			bt_addBuddy.enabled = b
			
			dg_vars.enabled = b
			dg_buddies.enabled = b
		}
		
		/* ::::::::::::::::::::::::::::::::::::::::::::::::::::::::
		 *	SmartFoxServer Handlers
		 * ::::::::::::::::::::::::::::::::::::::::::::::::::::::::
		 */
		
		/**
		 * Handle connection
		 */
		function onConnection(evt:SFSEvent):void
		{
			var success:Boolean = evt.params.success
			
			if (success)
			{
				debugTrace("Connection successfull!")
				tf_conn.text = "Connected"
				mc_conn.gotoAndStop(2)
				
				toggleUI( true )
				
				sfs.login(sfs.defaultZone, tf_connect.text, "")
			}
			else
			{
				debugTrace("Connection failed!")	
			}
		}
		
		/**
		* Handle configuration load failure
		*/
		function onConfigLoadFailure(evt:SFSEvent):void
		{
			debugTrace("Failed loading config file: " + evt.params.message)
		}

		/**
		 * Handle connection lost
		 */
		function onConnectionLost(evt:SFSEvent):void
		{
			debugTrace("Connection lost!")
			
			tf_conn.text = "Not Connected"
			mc_conn.gotoAndStop(1)

			ta_chat.text = ""
			tf_connect.text = ""
			
			dg_buddies.dataProvider = new DataProvider([])
			dg_vars.dataProvider = new DataProvider([])
			
			toggleUI( false )
		}

		/**
		 * Handle login response
		 */
		function onLogin(evt:SFSEvent):void
		{
			if (evt.params.success)
			{
				debugTrace("Successfully logged in -> " + evt.params.name)
			}
			else
			{
				debugTrace("Login failed. Reason: " + evt.params.error)
			}
		}

		/**
		 * Handle room list
		 */
		function onRoomListUpdate(evt:SFSEvent):void
		{
			debugTrace("Room list received")

			// Tell the server to auto-join us in the default room for this Zone
			sfs.autoJoin()
		}

		/**
		 * Handle successfull join
		 */
		function onJoinRoom(evt:SFSEvent):void
		{
			debugTrace("Successfully joined room: " + evt.params.room.getName())
			sfs.loadBuddyList()
		}

		/**
		 * Handle problems with join
		 */
		function onJoinRoomError(evt:SFSEvent):void
		{
			debugTrace("Problems joining default room. Reason: " + evt.params.error)	
		}
		
		/**
		* Handle buddy list
		*/
		function onBuddyList(evt:SFSEvent):void
		{
			refreshBuddyList()
			for (var i:String in sfs.myBuddyVars )
			{
				trace(i + " >> " + sfs.myBuddyVars[i])
			}
		}
		
		function onBuddyListUpdate(evt:SFSEvent):void
		{
			var isSameItem:Boolean = dg_buddies.selectedItem != null && dg_buddies.selectedItem.name == evt.params.buddy.name
			refreshBuddyList()
			
			if ( isSameItem )
				refreshBuddyVariables( evt.params.buddy )
		}
		
		function onBuddyPermissionRequest(evt:SFSEvent):void
		{
			mc_alert.lb_name.text = evt.params.sender
			mc_alert.visible = true
		}
		
		function onPrivateMessage(evt:SFSEvent):void
		{
			var userName:String
			
			if ( evt.params.userId == sfs.myUserId )
				userName = "me"
			else
			{
			 	var buddy:Object = sfs.getBuddyById( int(evt.params.userId) )
				
				if ( buddy != null )
					userName = buddy.name
				else
					userName = "Unknown"
			}
			
			debugTrace("[ " + userName + " ] " + evt.params.message)
		}
		
		private function refreshBuddyList()
		{
			var dp:Array = []
			
			for each ( var buddy:Object in sfs.buddyList )
			{
				dp.push( 
							{ 
								name:buddy.name, 
								online: buddy.isOnline ? "Y" : "N",
								X:buddy.isBlocked ? "Y" : "N" 
							} 
						)
			}
			
			dg_buddies.dataProvider = new DataProvider( dp )
		}
		
		
		function refreshBuddyVariables( buddy:Object ) : void
		{
			if ( buddy != null )
			{
				var dp:Array = []
			
				for ( var key:String in buddy.variables )
				{
					dp.push( { key:key, value:buddy.variables[key] } )
				}
			
				dg_vars.dataProvider = new DataProvider( dp )
			}
		}

		/**
		 * Handle a Security Error
		 */
		function onSecurityError(evt:SecurityErrorEvent):void
		{
			debugTrace("Security error: " + evt.text)
		}

		/**
		 * Handle an I/O Error
		 */
		function onIOError(evt:IOErrorEvent):void
		{
			debugTrace("I/O Error: " + evt.text)
		}

		/**
		 * Trace messages to the debug text area
		 */
		function debugTrace(msg:String):void
		{
			ta_chat.text += "{ LOG } " + msg + "\n"
		}
		
	}

	

	
	
	
}