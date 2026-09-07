/**
* 
* SmartMessenger v. 1.1.0
* Instant Messagges with SmartFoxServer - Example app -
*
* @author Lapo - Marco Lapi
* @version 1.1.0
* 
* (c) 2005-2007 gotoAndPlay()
* www.smartfoxserver.com
* www.gotoandplay.it
* 
*/
import it.gotoandplay.commons.util.ConfigLoader;
import it.gotoandplay.commons.util.TimeController;
import it.gotoandplay.smartfoxserver.*;

import mx.managers.PopUpManager;
import mx.containers.Window;
import mx.controls.List;
import mx.controls.Alert;
import mx.utils.Delegate;
import mx.managers.FocusManager;

class it.gotoandplay.smartfoxserver.smartmessenger.Messenger
{
	private static var STATUS_AVAILABLE:String = "light_green";
	private static var STATUS_OFFLINE:String = "light_offline";
	private static var STATUS_BRB:String = "light_yellow";
	private static var STATUS_BUSY:String = "light_red";
	private static var TOKEN:String = "$$$";
	
	private var _ip:String;
	private var _zone:String;
	private var _port:Number;
	private var _xtName:String;
	
	private var _cfgXml:XML;
	private var _stageW:Number;
	private var _stageH:Number;
	private var _tl:MovieClip;
	private var _tc:TimeController;
	private var _sfs:SmartFoxClient;
	private var _cfg:ConfigLoader;
	
	private var _loginWin:MovieClip;
	private var _contactWin:MovieClip;
	private var _browseWin:MovieClip;
	
	private var _curBrowseId:Number;
	private var _buddyLoaded:Boolean;
	private var _myName:String;
	private var _myID:Number;
	private var _chatList:Array;
	private var _lastWindowID:String;
	
	/**
	* Constructor
	*/
	function Messenger(timeLine:MovieClip)  
	{	
		_tc = new TimeController();
		
		if (timeLine == null)
			_tl = _root;
		else
			_tl = timeLine;
		
		// Set the background 1 frame later
		_tc.wait1Frame(Delegate.create(this, setBg));
		
		this._cfg = new ConfigLoader();
		loadConfig();	
	} 
	
	/**
	* Load configuration from external XML file
	*/
	private function loadConfig()
	{
		this._cfg.onConfigLoaded = Delegate.create(this, cfgOK);
		this._cfg.onLoadError = Delegate.create(this, cfgKO);
		
		this._cfg.loadCfg("cfg.xml");
	}
	
	/**
	* Handle successfull config loading
	*/
	private function cfgOK()
	{
		var cfg:Object = this._cfg.xmlObj["messenger"];

		this._ip = cfg.addr.value;
		this._port = Number(cfg.port.value);
		this._zone = cfg.zone.value;
		this._xtName = cfg.xtName.value;
		
		init();
	}
	
	/**
	* Ouch! XML config file loading problems
	*/
	private function cfgKO()
	{
		var a:Alert = Alert.show("Can't load XML config file! Quitting.", "Fatal Error", null, null, Delegate.create(this, click_resumeLoginError));
		a.setStyle("themeColor", "haloOrange");
		a.setSize(300, 100);
	}
	
	
	/**
	* Initialize application
	*/
	private function init()
	{
		// Setup server
		this._sfs = new SmartFoxClient();
		
		// Setup server handlers
		this._sfs.onConnection 			= Delegate.create(this, sfs_handleConnection);
		this._sfs.onJoinRoom 			= Delegate.create(this, sfs_handleJoin);
		this._sfs.onRoomListUpdate 		= Delegate.create(this, sfs_handleRoomList);
		this._sfs.onExtensionResponse	= Delegate.create(this, sfs_handleXtResponse);
		this._sfs.onBuddyList			= Delegate.create(this, sfs_handleBuddyList);
		this._sfs.onBuddyListUpdate		= Delegate.create(this, sfs_handleBuddyListUpdate);
		this._sfs.onPrivateMessage		= Delegate.create(this, sfs_handlePM);
		this._sfs.onConnectionLost		= Delegate.create(this, sfs_handleDisconnection);
		this._curBrowseId = -1;
		this._buddyLoaded = false;
		this._chatList = [];
		
		showLogin();
	}
	
	/**
	* Setup the background
	*/
	private function setBg():Void
	{
		_tl.attachMovie("bg", "bg", 0);
	}
	
	private function showLogin():Void
	{
		this._loginWin = PopUpManager.createPopUp(_tl, Window, true, {contentPath:"win_login"})
		this._loginWin.setSize(305, 150);
		this._loginWin.title = "Connection and login";
		
		centerMc(this._loginWin, null, 350);
		
		System.security.loadPolicyFile("xmlsocket://" + this._ip +":" + this._port)
		this._sfs.connect(this._ip, this._port);	
	}
	
	
	
	/**
	* Center an mc on screen
	* 
	* @param	mc			the mc
	* @param	centerW		force x pos
	* @param	centerH		force y pos
	*/
	private function centerMc(mc:MovieClip, centerW:Number, centerH:Number):Void
	{
		if (centerW == undefined)
			mc._x = (Stage.width - mc._width) / 2;
		else
			mc._x = centerW;
			
		if (centerH == undefined)
			mc._y = (Stage.height - mc._height) / 2;
		else
			mc._y = centerH;
	}
	
	/**
	* Initialize the main application screen
	*/
	private function initMainScreen()
	{
		this._browseWin = PopUpManager.createPopUp(_tl, Window, false, {contentPath:"win_browse"})
		this._browseWin.setSize(405, 292);
		this._browseWin.title = "Browse members";

		centerMc(this._browseWin, null, 330);
		
		this._contactWin = PopUpManager.createPopUp(_tl, Window, false, {contentPath:"win_contacts"})
		this._contactWin.setSize(194, 612);
		this._contactWin.title = this._myName + "'s contact list";
		this._contactWin.closeButton = false;
		
		
		centerMc(this._contactWin, 700);
		
		// Wait the next frame to attach button listener
		this._tc.wait1Frame(Delegate.create
							(
								this, 
								function() 
								{
									this._browseWin.content["bt_prev"].addEventListener("click", Delegate.create(this, this.click_browsePrev));
									this._browseWin.content["bt_next"].addEventListener("click", Delegate.create(this, this.click_browseNext));
									this._browseWin.content["bt_add"].addEventListener("click", Delegate.create(this, this.click_browseAdd));
									
									this._contactWin.content["bt_message"].addEventListener("click", Delegate.create(this, this.click_contactsMessage));
									this._contactWin.content["bt_remove"].addEventListener("click", Delegate.create(this, this.click_contactsRemove));
									this._contactWin.content["status_cb"].swapDepths(20);
									this._contactWin.content["status_cb"].invalidate();

									this._contactWin.content["statusGroup"].addEventListener("click", Delegate.create(this, this.click_contactsStatus));
								}
							));
	}
	
	/**
	* Load the buddy list
	*/
	private function loadBuddyList():Void
	{
		if (!this._buddyLoaded)
		{
			this._sfs.loadBuddyList();
		}
	}
	
	/**
	* Request the next user
	*/
	public function requestNextUser()
	{
		this._sfs.sendXtMessage(this._xtName, "nextU", {id:this._curBrowseId});
	}
	
	/**
	* Request the previous user
	*/
	public function requestPrevUser()
	{
		this._sfs.sendXtMessage(this._xtName, "prevU", {id:this._curBrowseId});
	}
	
	/**
	* Create a new chat session with a member of the contact list
	* 
	* @param	nick	the nick name
	* @param	uid		the user id
	*/
	private function newPrivateChat(nick:String, uid:Number)
	{	
		if (uid > -1)
		{
			// Create new one on one chat window
			if (this._chatList[nick] == undefined)
			{
				var win:MovieClip = PopUpManager.createPopUp(_tl, Window, false, {contentPath:"win_chat"})
				win.setSize(352, 250);
				win.title = "Private chat with " + nick;
				win.closeButton = true;
				win.addEventListener("click", Delegate.create(this, this.click_closeChatWin));
				
				centerMc(win, null, 10);
				
				this._chatList[nick] = win
				
				// Wait the next frame to attach button listener
				this._tc.wait1Frame(Delegate.create
									(
										this, 
										function(mc:MovieClip, uid:Number, nick:String) 
										{
											mc.content.uid = uid;
											mc.content.nick = nick;
											mc.content["bt_send"].addEventListener("click", Delegate.create(this, this.click_chatSend));
										}
									),
									[win, uid, nick]
									);
			}			
		}
	}
	
	/**
	* The user we were chatting with is gone.
	* Disable the controls in this window
	* 
	* @param	nick	the user nickname
	*/
	private function invalidateChatWindow(nick:String)
	{
		if (this._chatList[nick] != undefined)
		{
			var mc:MovieClip = this._chatList[nick].content
			mc.offline = true;
			mc.chat_txt.text += "<br>" + mc.nick + " is offline!<br>";
			mc.chat_txt.vPosition = mc.chat_txt.maxVPosition;
			
			mc.bt_send.enabled = false;
			mc.message_txt.enabled = false;
		}
	}
	
	/**
	* Enable a chat window
	* 
	* @param	nick	the user nickname
	*/
	private function enableWindow(nick:String)
	{
		var mc:MovieClip = this._chatList[nick].content;
		
		if (mc != undefined)
		{
			mc.offline = false;
			mc.nick = nick;
			mc.uid = this.getBuddyId(nick);
			
			mc.bt_send.enabled = true;
			mc.message_txt.enabled = true;
		}
	}
	
	/**
	* Find a buddy ID
	* 
	* @param	nick	the buddy nick
	* @return	the buddy id
	*/
	private function getBuddyId(nick:String):Number
	{
		var b:Array = this._sfs.buddyList;
		var id:Number = null;
		
		for (var i:String in b)
		{
			if (b[i].name == nick)
			{
				id = b[i].id;
				break;
			}
		}
		 
		 return id;
	}
	
	/**
	* Find the buddy name
	* 
	* @param	id	the buddy id
	* @return	the buddy name
	*/
	private function getBuddyName(id:Number):String
	{
		var name:String = null;
		
		for (var i:String in this._sfs.buddyList)
		{			
			if (this._sfs.buddyList[i].id == id)
			{
				name = this._sfs.buddyList[i].name;
				break;
			}
		}
		 
		 return name;
	}
	
	//-------------------------------------------------------------------------------
	// UI EventListeners
	//-------------------------------------------------------------------------------

	// Handle login button
	public function click_loginWin(o:Object)
	{
		var nick:String  = this._loginWin.content["nick_txt"].text;
		
		if (nick.length > 0)
		{
			this._loginWin.content.gotoAndStop(1);
			this._loginWin.content.title_txt.text = "Loggin in...";
			
			this._sfs.login(this._zone, nick, "");
		}
	}
	
	// Login retry
	public function click_loginWin_retry(o:Object)
	{
		this._loginWin.deletePopUp();
		showLogin();
	}
	
	// next user selection
	public function click_browseNext(o:Object)
	{
		this.requestNextUser();
	}
	
	// previous user selection
	public function click_browsePrev(o:Object)
	{
		this.requestPrevUser();
	}
	
	// Add a new buddy to the list
	public function click_browseAdd(o:Object)
	{
		var nick:String = this._browseWin.content.nick_txt.text;
		
		if (nick != this._myName)
			this._sfs.addBuddy(nick)
	}
	
	// open a PM window
	public function click_contactsMessage()
	{
		var nick:String = this._contactWin.content.contacts_lb.selectedItem.label;
		var id:Number = this._contactWin.content.contacts_lb.selectedItem.id;
		
		newPrivateChat(nick, id);
	}
	
	// remove contact from list
	public function click_contactsRemove()
	{
		var nick:String = this._contactWin.content.contacts_lb.selectedItem.label;
		this._sfs.removeBuddy(nick);
	}
	
	// resum after login error
	public function click_resumeLoginError()
	{
		sfs_handleConnection(true);
	}
	
	// resume after connection lost
	public function click_resumeConnLost()
	{
		// Restart the application
		init();
	}
	
	// contact list change
	public function change_contactsList(o:Object)
	{
		var sel:String = o.target.selectedItem.data;
	}
	
	// Change user status
	public function click_contactsStatus(o:Object)
	{
		var st:Number = o.target.selectedData;
		
		_sfs.setBuddyVariables({st:st});
	}
	
	// send PM message
	public function click_chatSend(o:Object)
	{		
		var mc:MovieClip = o.target._parent;
		this._lastWindowID = mc.nick;
		
		// Send PM
		if (!mc.offline)
		{
			this._sfs.sendPrivateMessage(this._myID + TOKEN + mc.message_txt.text, mc.uid);
			mc.message_txt.text = "";
		}
	}
	
	// Close a PM window
	public function click_closeChatWin(o:Object)
	{
		var mc:MovieClip = o.target;
		delete this._chatList[mc.content.nick];
		mc.deletePopUp();	
	}
	
	//-------------------------------------------------------------------------------
	// SmartFoxClient EventListeners
	//-------------------------------------------------------------------------------	
	public function sfs_handleConnection(ok:Boolean)
	{
		// Connection OK
		if (ok)
		{
			this._tc.wait1Frame(Delegate.create
								(
									this, 
									function() 
									{
										this._loginWin.content.gotoAndStop("login");
									}
								));
			
			
			// Wait the next frame to attach button listener
			this._tc.waitFrames(2, Delegate.create
								(
									this, 
									function() 
									{
										this._loginWin.content["bt_login"].addEventListener("click", Delegate.create(this, this.click_loginWin));
									}
								));
		}
		
		// Connection KO
		else
		{
			this._loginWin.content.gotoAndStop("fail");
			
			// Wait the next frame to attach button listener
			this._tc.wait1Frame(Delegate.create
								(
									this, 
									function() 
									{
										this._loginWin.content["bt_retry"].addEventListener("click", Delegate.create(this, this.click_loginWin_retry));
									}
								));
		}
	}
	
	// Handle room join
	public function sfs_handleJoin(rObj:Room)
	{
		this._loginWin.deletePopUp();
		
		initMainScreen();
		
		// Wait 1 frame for the component to initialize
		this._tc.wait1Frame(Delegate.create(this, function() { loadBuddyList(); requestNextUser(); }))
	}
	
	// Handle room list
	public function sfs_handleRoomList(list:Object)
	{
		//
	}
	
	// Handle a PM
	public function sfs_handlePM(msg:String)
	{
		if (msg.indexOf(TOKEN) > 0)
		{
			var data:Array = msg.split(TOKEN);
			
			var senderId:Number = Number(data[0]);
			var message:String = data[1];
			
			var sender:String;
			var win:MovieClip;

			if (senderId != this._myID)
			{
				sender = this.getBuddyName(senderId);
				
				// Check if chat window exist
				if (this._chatList[sender] == undefined)
					this.newPrivateChat(sender, this.getBuddyId(sender));
	
				win = this._chatList[sender];
				
			}
			
			else
			{
				win = this._chatList[this._lastWindowID];
				sender = this._myName;
			}
		
			this._tc.wait1Frame(Delegate.create
								(
									this, 
									function(win:MovieClip) 
									{ 
										win.content.chat_txt.text += "<b><font color='#cc0000'>" + sender + ": </font></b>" + message;
										win.content.chat_txt.vPosition = win.content.chat_txt.maxVPosition;
									}
								),
								[win]
							);
			

		}
	}
	
	// Handle extension responses
	public function sfs_handleXtResponse(o:Object, t:String)
	{
		var cmd:String
		
		if (t == "xml")
		{
			cmd = o["_cmd"];
			
			if (cmd == "logOK")
			{
				this._myID = o.id;
				this._myName = o.name;
				
				this._sfs.autoJoin();
			}
			
			else if (cmd == "logKO")
			{
				var a:Alert = Alert.show(o.err, "Login error!", Alert.OK, null, Delegate.create(this, click_resumeLoginError));
				a.setStyle("themeColor", "haloOrange");
				a.setSize(300, 150);
			}
			
			else if (cmd == "usr")
			{
				var mc:MovieClip = this._browseWin.content;
				
				this._curBrowseId = o.id
				
				mc["nick_txt"].text = o["usr"].nick
				mc["age_txt"].text = o["usr"].age
				mc["location_txt"].text = o["usr"].location
				mc["email_txt"].text = o["usr"].email
				mc["interest_txt"].text = o["usr"].interest
			}
		}
		
		else if (t == "str")
		{
			cmd = o[0];
			
			if (cmd == "stat")
			{
				changeUserStatus(o[2], o[3]);
			}
		}
	}
	
	/**
	* Handle disconnection
	*/
	public function sfs_handleDisconnection()
	{
		this._browseWin.deletePopUp();
		this._contactWin.swapDepths(100);
		this._contactWin.removeMovieClip();
		
		for (var i:String in this._chatList)
		{
			this._chatList[i].deletePopUp();
		}
		
		var a:Alert = Alert.show("Connection with the server was lost", "Connection error!", Alert.OK, null, Delegate.create(this, click_resumeConnLost));
		a.setStyle("themeColor", "haloOrange");
		a.setSize(300, 150);
	}
	
	/**
	* A user status change was received
	* Let's update the GUI
	* 
	* @param	uName	the user name	
	* @param	stat	the user status
	*/
	public function changeUserStatus(uName:String, stat:String)
	{
		var list:List = this._contactWin.content.contacts_lb;
		var item:Object;
		var icon:String;
		
		switch(Number(stat))
		{
			case 0:
				icon = STATUS_AVAILABLE;
				break;
			
			case 1:
				icon = STATUS_BRB;
				break;
				
			case 2:
				icon = STATUS_BUSY;
				break;
		}
		
		
		for (var i:Number = 0; i < list.getLength(); i++)
		{
			item = list.getItemAt(i);

			if (item.label == uName)
			{
				item.icon = icon
				break;
			}
		}
		
		list.updateControl();
	}
	
	/**
	* Populate the buddy list
	* @param	list	the list of my buddies
	*/
	public function sfs_handleBuddyList(bList:Array)
	{
		
		var list:List = this._contactWin.content.contacts_lb;

		list.removeAll();
		
		for (var b:String in bList)
		{
			var o:Object = {};
			o.label = bList[b].name;
			//o.icon = bList[b].isOnline ? STATUS_AVAILABLE : STATUS_OFFLINE;
			
			if (bList[b].isOnline)
			{
				if (bList[b].variables.st == 1)
					o.icon = STATUS_BRB;
				else if (bList[b].variables.st == 2)
					o.icon = STATUS_BUSY;
				else
					o.icon = STATUS_AVAILABLE;
			}
			else
				o.icon = STATUS_OFFLINE;
			
			o.id = bList[b].id;
			
			list.addItem(o);	
			
		}
		list.sortItemsBy("label");
		
		this._contactWin.content.contacts_lb.iconField = "icon";
	}
	
	// Handle buddy list updates
	public function sfs_handleBuddyListUpdate(b:Object)
	{
		var list:List = this._contactWin.content.contacts_lb;

		for (var i:Number = 0; i < list.getLength(); i++)
		{
			var o:Object = list.getItemAt(i);
			
			if (o.label == b.name)
			{
				if (b.isOnline)
				{
					if (b.variables.st == 1)
						o.icon = STATUS_BRB;
					else if (b.variables.st == 2)
						o.icon = STATUS_BUSY;
					else
						o.icon = STATUS_AVAILABLE;
				}
				else
					o.icon = STATUS_OFFLINE;
				
				o.id = b.id;
				list.updateControl();
				
				if (b.id == -1)
					invalidateChatWindow(b.name);
				else
					enableWindow(b.name);
				
				break;
			}
		}
	}
}
