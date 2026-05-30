/* AS3
	Copyright 2007 gotoAndPlay().
*/
package
{
	import com.smartfoxserver.openspace.avatar.IAvatarMovieClip
	import com.smartfoxserver.openspace.events.AvatarEvent
	import flash.display.MovieClip
	
	public class SimpleAvatarMovieClip extends MovieClip implements IAvatarMovieClip
	{
		private var _isMyAvatar:Boolean
		private var _avatarName:String
		
		function SimpleAvatarMovieClip()
		{
			super()
			
			// Set defaults
			_isMyAvatar = false
			_avatarName = ""
		}

		public function set isMyAvatar(myAv:Boolean):void
		{
			trace ("'isMyAvatar' setter called on SimpleAvatarMovieClip")
			_isMyAvatar = myAv
		}
		
		public function set avatarName(avName:String):void
		{
			trace ("'avatarName' setter called on SimpleAvatarMovieClip")
			_avatarName = avName
		}

		public function get avatarName():String
		{
			return _avatarName
		}

		public function get skin():Object
		{
			trace ("'skin' getter called on SimpleAvatarMovieClip")
			return null
		}
		
		public function onSkinChange(evt:AvatarEvent):void
		{
			trace ("'onSkinChange' listener called on SimpleAvatarMovieClip")
		}
		
		public function onCustomAction(evt:AvatarEvent):void
		{
			trace ("'onCustomAction' listener called on SimpleAvatarMovieClip")
		}
		
		public function onMessage(evt:AvatarEvent):void
		{
			trace ("'onMessage' listener called on SimpleAvatarMovieClip")
		}
		
		public function onMovementStart(evt:AvatarEvent):void
		{
			trace ("'onMovementStart' listener called on SimpleAvatarMovieClip")
		}

		public function onMovementStop(evt:AvatarEvent):void
		{
			trace ("'onMovementStop' listener called on SimpleAvatarMovieClip")
		}
		
		public function onTileEnter(evt:AvatarEvent):void
		{
			trace ("'onTileEnter' listener called on SimpleAvatarMovieClip")
		}
		
		public function onDirectionChange(evt:AvatarEvent):void
		{
			trace ("'onDirectionChange' listener called on SimpleAvatarMovieClip")
		}
		
		public function onDestroy(evt:AvatarEvent):void
		{
			trace ("'onDestroy' listener called on SimpleAvatarMovieClip")
		}
	}
}