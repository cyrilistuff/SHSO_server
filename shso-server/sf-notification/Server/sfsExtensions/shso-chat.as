/*
* SmartFoxServer PRO
* Simple Extension Example
* v 1.0.0
* 
*
* Extensions Overview:
* -----------------------------------------------------------------
* Every extension must implement four basic methods:
* 
* init(), destroy(), handleRequest(), handleInternalEvent()
* 
* init()			It's the initialization point of the extension
* 				This method is invoked by the server on the extension as soon as it is loaded
* 				You can put here all your initialization code.
* 
* destroy()			This method is called by the server when the extension is going to be destroyed
* 				You should always put in this method the necessary code to release the resources
* 				you were using like setInterval(s), database connections etc...
* 
* handleRequest()		This method receives the client requests
* 
* handleInternalEvent()		Handles internal server events. Events are:
* 
* 				userJoin	when a user joins the room / zone
* 				userExit	when a user exits a room
* 				userLost	when a user disconnects
* 				newRoom		a new room was created in the zone
* 				roomLost	a room was destroyed in the zone
* 				loginRequest	a custom login request arrived	
*  
*/


var dbManager


/* 
* Initializion point:
* 
* this function is called as soon as the extension
* is loaded in the server.
* 
* You can add here all the initialization code
* 
*/

function init()
{

	// Using trace will send data to the server console
	trace("shso-chat init() called!")
		
	dbManager = _server.getDatabaseManager()
}



/*
* This method is called by the server when an extension
* is being removed / destroyed.
* 
* Always make sure to release resources like setInterval(s)
* open files etc in this method.
* 
* In this case we delete the reference to the databaseManager
*/
function destroy()
{
	trace("Bye bye!")
		// Release the reference to the dbase manager
	delete dbManager
}

/*
* Handles the client request
* 
* cmd 		contains the request name
* params 	is an object containing data sent by the client
* user 		is the User object of the sender
* fromRoom	the id of the room where the request was sent from
* protocol	"xml" or "raw"
*/


function handleRequest(cmd, params, user, fromRoom, protocol)
{
	trace("handleRequest cmd=" + cmd + " protocol=" + protocol)

	if (protocol == "xml")
	{
		switch (cmd)
		{
			case "send_room_message":
				handleSendRoomMsg(params, user, fromRoom)
			break
		}
	}
	else
	{
		switch(cmd)
		{
						
				
		}
	}


}


/*
* This method handles internal events
* Internal events are dispactched by the Zone or Room where the extension is attached to
* 
* the (evt) object
*/
function handleInternalEvent(evt)
{
	// Simply print the name of the event that was received
	trace("Event received: " + evt.name)	
}

function handleSendRoomMsg(params, user, room)
{
	trace("handleSendRoomMsg() called!");	
	var sender_player_id = params.sender_player_id  //.toString()
	var room_name = params.room_name
	var message= params.message  // this will be base64 encoded
	var uid = user.getUserId()

	trace("sender_player_id = " + sender_player_id)
	trace("room_name = " + room_name)
	trace("message = " + message)

	var currentZone = _server.getCurrentZone()
	var curRoom = currentZone.getRoom(room)
	//var cnt = curRoom.getUserCount();
	//trace("curRoom.getUserCnt() = " + cnt)
	var users = curRoom.getAllUsers()

	var res = {}
	res._cmd = "notification"
	res.message_type = "receive_room_message"
	res.message = message
	res.sender_player_id = parseInt(sender_player_id)

	message_clean = base64Decode(message).replace(/\s+/g, '').toLowerCase()
	trace("Original message: " + message_clean);
	if (message_clean.indexOf("israel") != -1 || (message_clean.indexOf("isreal") != -1 && message_clean.indexOf("isreally") == -1) || message_clean.indexOf("isral") != -1|| message_clean.indexOf("fromhamas") != -1 || message_clean.indexOf("fromkham") != -1 || message_clean.indexOf("fromkkkham") != -1 || message_clean.indexOf("fromkkham") != -1 || message_clean.indexOf("fromhummus") != -1) {
		res.message = base64Encode("FREE PALESTINE!");
	}
	
	_server.sendResponse(res, -1, null, users, "xml")
	var sql = "insert into chat (zone, user, message) values ('" + _server.escapeQuotes(room_name) + "', (SELECT Username FROM shso.user where ID =(SELECT ShsoUserID FROM shso.active_players where SfUserID =" + sender_player_id + ")), (SELECT CONVERT(FROM_BASE64('" + message + "') using UTF8MB3)));"
	var success = dbManager.executeCommand(sql);

	if (success)
		trace("Record inserted!")
	else
		trace("Ouch, record insertion failed")

	// logMessage = "[" + room_name + "] " + sender_player_id + ": " + Base64.decode64(message);
	// _server.writeFile("/home/shsoadmin/chat.txt", logMessage, True);
	//_server.sendResponse(res, -1, null, [user], "xml")

}



// Base64 alphabet
var BASE64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

// Encode string to Base64
function base64Encode(input) {
    var output = "";
    var i = 0;

    while (i < input.length) {
        var chr1 = input.charCodeAt(i++);
        var chr2 = input.charCodeAt(i++);
        var chr3 = input.charCodeAt(i++);

        var enc1 = chr1 >> 2;
        var enc2 = ((chr1 & 3) << 4) | (chr2 >> 4);
        var enc3 = ((chr2 & 15) << 2) | (chr3 >> 6);
        var enc4 = chr3 & 63;

        if (isNaN(chr2)) {
            enc3 = enc4 = 64;
        } else if (isNaN(chr3)) {
            enc4 = 64;
        }

        output += BASE64_CHARS.charAt(enc1);
        output += BASE64_CHARS.charAt(enc2);
        output += (enc3 != 64) ? BASE64_CHARS.charAt(enc3) : "=";
        output += (enc4 != 64) ? BASE64_CHARS.charAt(enc4) : "=";
    }
    return output;
}

// Decode Base64 to string
function base64Decode(input) {
    var output = "";
    var i = 0;

    input = input.replace(/[^A-Za-z0-9\+\/\=]/g, "");

    while (i < input.length) {
        var enc1 = BASE64_CHARS.indexOf(input.charAt(i++));
        var enc2 = BASE64_CHARS.indexOf(input.charAt(i++));
        var enc3 = BASE64_CHARS.indexOf(input.charAt(i++));
        var enc4 = BASE64_CHARS.indexOf(input.charAt(i++));

        var chr1 = (enc1 << 2) | (enc2 >> 4);
        var chr2 = ((enc2 & 15) << 4) | (enc3 >> 2);
        var chr3 = ((enc3 & 3) << 6) | enc4;

        output += String.fromCharCode(chr1);

        if (enc3 != 64) {
            output += String.fromCharCode(chr2);
        }
        if (enc4 != 64) {
            output += String.fromCharCode(chr3);
        }
    }
    return output;
}
