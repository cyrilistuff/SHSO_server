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


package it.gotoandplay.games
{
	import flash.display.Sprite;
	import it.gotoandplay.smartfoxserver.SmartFoxClient;
	import it.gotoandplay.smartfoxserver.data.*;
	import flash.text.TextField;
	import flash.display.MovieClip;
	import flash.events.MouseEvent;
	import it.gotoandplay.smartfoxserver.SFSEvent;
	

	public class TrisGame extends Sprite
	{
		[Embed(source="../../../../gameAssets/assets.swf", symbol="mainStage")]
		private var MainStage:Class;
		
		private var mainMC:Sprite;
		private var sfs:SmartFoxClient;
		private var container:Object
		private var extensionName:String;
		private var statusTF:TextField;
		private var board:MovieClip;
		private var myOpponent:User			// My opponent user object
		private var player1Id:int			// Id of player 1
		private var player2Id:int		// Id of player 2
		private var player1Name:String		// Name of player 1
		private var player2Name:String		// Name of player 2
		private var whoseTurn:int
		private var gameStarted:Boolean
		private var iAmSpectator:Boolean
		private var myPlayerID:int
		private var ballColors:Array
		

		
		public function TrisGame()
		{
			mainMC = new MainStage()
			extensionName = "tris"
		}
		
		/**
		 * Initialize the game
		 */
		public function initGame(params:Object = null):void
		{
			if (params != null)
			{
				container = params.container
				gameStarted = false
				
				ballColors = []
				ballColors[1] = "green"
				ballColors[2] = "red"
				
				// Register to SmartFox events
				sfs = params.sfs
				sfs.addEventListener(SFSEvent.onExtensionResponse, onExtensionResponse)
				sfs.addEventListener(SFSEvent.onSpectatorSwitched, onSpectatorSwitched)
				
				// Show stage
				addChild(mainMC)
				statusTF = mainMC.getChildByName("gameStatus") as TextField
				board = mainMC.getChildByName("board") as MovieClip
				
				resetGameBoard()
				
				// Setup my properties
				myPlayerID = sfs.playerId
				iAmSpectator = (myPlayerID == -1)
				
				// Show "wait" message
				var message:String = "Waiting for player " + ((myPlayerID == 1) ? "2" : "1")
				
				if (!iAmSpectator)
					container.showPopup("wait", message, null)
				
				// Tell extension I'm ready to play
				sfs.sendXtMessage(extensionName, "ready", null)
			}
		}
		
		/**
		 * Destroy the game instance
		 */
		public function destroyGame(params:Object = null):void
		{
			sfs.removeEventListener(SFSEvent.onExtensionResponse, onExtensionResponse)
			sfs.removeEventListener(SFSEvent.onSpectatorSwitched, onSpectatorSwitched)
		}
		
		/**
		 * Start the game
		 */
		private function startGame(params:Object):void
		{
			whoseTurn = params.t
			player1Id = params.p1i
			player2Id = params.p2i
			player1Name = params.p1n
			player2Name = params.p2n
						
			resetGameBoard()
			
			container.removePopup()
			
			var p1NameMC:MovieClip = mainMC.getChildByName("player1") as MovieClip
			var tf1:TextField = p1NameMC.playerName as TextField
			tf1.text = player1Name
			
			var p2NameMC:MovieClip = mainMC.getChildByName("player2") as MovieClip
			var tf2:TextField = p2NameMC.playerName as TextField
			tf2.text = player2Name
			
			setTurn()
			enableBoard()
				
			gameStarted = true
		}
		
		/**
		 * Set the "Player's turn" status message
		 */
		private function setTurn():void
		{
			if(!iAmSpectator)
				statusTF.text = (myPlayerID == whoseTurn) ? "It's your turn" : "It's your opponent's turn"
			else
				statusTF.text = "It's " + this["player" + whoseTurn + "Name"] + " turn"
		}
		
		/**
		 * Clear the game board
		 */
		private function resetGameBoard():void
		{
			for (var i:int = 1; i <= 3; i++)
			{
				for (var j:int = 1; j <= 3; j++)
				{
					var square:MovieClip = board["sq_" + i + "_" + j] as MovieClip
					var ball:MovieClip = square.ball as MovieClip
					ball.gotoAndStop("off")
				}
			}
		}
		
		/**
		 * Enable board click
		 */
		private function enableBoard(enable:Boolean = true):void
		{
			if (!iAmSpectator && myPlayerID == whoseTurn)
			{
				for (var i:int = 1; i <= 3; i++)
				{
					for (var j:int = 1; j <= 3; j++)
					{
						var square:MovieClip = board["sq_" + i + "_" + j] as MovieClip;
						var ball:MovieClip = square.ball as MovieClip;
						
						if (ball.currentFrame == 1)
						{
							square.buttonMode = enable;
							
							if (enable)
								square.addEventListener(MouseEvent.CLICK, makeMove)
							else
								square.removeEventListener(MouseEvent.CLICK, makeMove)
						}
					}
				}
			}
		}
		
		/**
		 * On board click, send move to other players
		 */
		private function makeMove(evt:MouseEvent):void
		{
			var square:MovieClip = evt.target as MovieClip
			square.ball.gotoAndStop(ballColors[myPlayerID])
			square.buttonMode = false;
			square.removeEventListener(MouseEvent.CLICK, makeMove)
			
			enableBoard(false)
			
			var x:int = parseInt(square.name.substr(3,1))
			var y:int = parseInt(square.name.substr(5,1))
			
			var obj:Object = {}
			obj.x = x
			obj.y = y
			
			sfs.sendXtMessage(extensionName, "move", obj)
		}
		
		/**
		 * Handle the opponent move
		 */
		private function moveReceived(params:Object):void
		{
			var movingPlayer:int = params.t
			whoseTurn = (movingPlayer == 1) ? 2 : 1
		
			if (movingPlayer != myPlayerID)
			{
				var square:MovieClip = board["sq_" + params.x + "_" + params.y] as MovieClip
				var ball:MovieClip = square.ball as MovieClip
				ball.gotoAndStop(ballColors[movingPlayer])
			}
			
			setTurn()
			enableBoard()
		}
		
		/**
		 * Declare game winner
		 */
		private function showWinner(params:Object):void
		{
			gameStarted = false
			statusTF.text = ""
			var message:String = ""
			
			var cmd:String = params._cmd
			
			if (cmd == "win")
			{
				if (iAmSpectator)
				{
					var pNameMC:MovieClip = mainMC.getChildByName("player" + params.w) as MovieClip
					var tf:TextField = pNameMC.playerName as TextField
					message = tf.text + " is the WINNER"
				}
				else
				{
					if (myPlayerID == params.w)
					{
						// I WON! In the next match, it will be my turn first
						message = "You are the WINNER!"
					}
					else
					{
						// I've LOST! Next match I will be the second to move
						message = "Sorry, you've LOST!"
					}
				}
			}
			else if (cmd == "tie")
			{
				message = "It's a TIE!"
			}
			
			// Show "winner" message
			if (iAmSpectator)
			{
				container.showPopup("endSpec", message, null)
			}
			else
			{
				container.showPopup("end", message, restartGame)
			}
		}
		
		/**
		 * Restart the game
		 */
		private function restartGame():void
		{
			container.removePopup()
			sfs.sendXtMessage(extensionName, "restart", null)
		}
		
		/**
		 * One of the players left the game
		 */
		private function userLeft():void
		{
			gameStarted = false
			statusTF.text = ""
			var message:String = ""
			
			// Show "wait" message
			if (!iAmSpectator)
			{
				message = "Your opponent left the game" + "\n" + "Waiting for a new player"
				container.showPopup("wait", message, null)
			}
			else
			{
				message = "A player left the game" + "\n" + "Press the Join button to play"
				container.showPopup("waitSpec", message, spectatorJoinGame)
			}
		}
		
		/**
		 * Spectator receives board update. If match isn't started yet,
		 * a message is displayed and he can click the join button
		 */
		private function setSpectatorBoard(params:Object):void
		{
			container.removePopup()
			
			whoseTurn = params.t
			player1Id = params.p1i
			player2Id = params.p2i
			player1Name = params.p1n
			player2Name = params.p2n
			
			gameStarted = params.status
			
			if (player1Id > -1 && player2Id > -1)
			{
				var p1NameMC:MovieClip = mainMC.getChildByName("player1") as MovieClip
				var tf1:TextField = p1NameMC.playerName as TextField
				tf1.text = player1Name
				
				var p2NameMC:MovieClip = mainMC.getChildByName("player2") as MovieClip
				var tf2:TextField = p2NameMC.playerName as TextField
				tf2.text = player2Name
			
				setTurn()
			}
			
			// Draw board
			if (params.board != undefined)
			{
				for (var i:int = 1; i <= 3; i++)
				{
					for (var j:int = 1; j <= 3; j++)
					{
						var square:MovieClip = board["sq_" + i + "_" + j] as MovieClip
						var ball:MovieClip = square.ball as MovieClip
						ball.gotoAndStop(ballColors[params.board[j][i]])
					}
				}
			}
			
			if (!gameStarted)
			{
				var message:String = "Waiting for game to start" + "\n" + "Press the Join button to play"
				container.showPopup("waitSpec", message, spectatorJoinGame)
			}
		}
		 
		 /**
		 * If a spectator enters the game room and the match isn't started yet,
		 * he can click the join button
		 */
		 private function spectatorJoinGame():void
		 {
		 	sfs.switchSpectator()
		 }
		
		//------------------------------------------------------------------------------------
		
		public function onExtensionResponse(evt:SFSEvent):void
		{
			var params:Object = evt.params.dataObj
			var cmd:String = params._cmd
			
			switch(cmd)
			{
				case "start":
					startGame(params)
					break
				
				case "stop":
					userLeft()
					break
				
				case "move":
					moveReceived(params)
					break
				
				case "specStatus":
					setSpectatorBoard(params)
					break
				
				case "win":
				case "tie":
					showWinner(params)
					break
			}
		}
		
		public function onSpectatorSwitched(evt:SFSEvent):void
		{
			if (evt.params.success)
			{
				myPlayerID = sfs.playerId
				iAmSpectator = false
				
				// Show "wait" message
				container.removePopup()
				var message:String = "Waiting for player " + ((myPlayerID == 1) ? "2" : "1")
				container.showPopup("wait", message, null)
			}
		}
	}
}
