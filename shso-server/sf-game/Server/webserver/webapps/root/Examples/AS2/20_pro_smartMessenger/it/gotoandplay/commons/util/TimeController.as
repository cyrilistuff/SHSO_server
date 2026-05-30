/**
* 
*[[ gotoAndPlay() common Library classes ]]
* 
* TimeController Class
* ---------------------------------------------------------
* version 1.1.0
* September 23rd 2005
* 
* (c) 2005 gotoAndPlay
* ---------------------------------------------------------
* 
* This class allows to control asynchronous operations in the timeline
* in the Actionscript code.
* 
* The class provides methods for:
* 
* -- waiting for a movieclip playhead to reach a certain frame number
* -- waiting for a number of frames
* -- waiting for a number of milliseconds
* 
*/

dynamic class it.gotoandplay.commons.util.TimeController
{
	
	// Private constants
	private static var WAITFORFRAME:Number 	= 0
	private static var WAIT:Number 		= 1
	private static var WAITFRAMES:Number 	= 2
	private static var INSTANCE_COUNT 	= 0
	
	private var _taskList:Array
	private var _taskCount:Number
	private var _timeline:MovieClip
	private var _clip:MovieClip
	
	
	/**
	* Default Constructor
	*/
	public function TimeController(timeline:MovieClip)
	{
		if (timeline == null)
			this._timeline = _root
		else
			this._timeline = timeline
		
		this._taskList 	= []
		this._taskCount = 0
		this._clip 	= this._timeline.createEmptyMovieClip("__$waitObj" + (INSTANCE_COUNT++) +"$__", this._timeline.getNextHighestDepth())
		
		// Keep a reference to this instance in the clip
		this._clip._obj = this
		
		// Launch the main thread
		this._clip.onEnterFrame = this.mainThread
	}
	
	
	
	/**
	* Wait for a certain movieclip to reach the desired frame number
	* 
	* @param mc		the target movieclip
	* @param frame		the frame number
	* @param callback	a callback function
	* @param scope		the object (scope) containing the function
	* @param args		a list of arguments for the callback function
	* 
	*/
	public function waitForFrame(mc:MovieClip, frame:Number, callback:Function, args:Array, scope:Object):Void
	{
		var task:Object = {}
		task._mode 	= WAITFORFRAME
		
		task.target 	= mc
		task.frame	= frame
		task.callback	= callback
		task.scope	= scope
		task.args	= args
		
		this._taskList.push(task)
		this._taskCount++
	}
	
	
	
	/**
	* Wait for a number of milliseconds
	* 
	* @param delay		how much time to wait
	* @param callback	a callback function
	* @param args		a list of arguments for the callback function
	* @param scope		the object (scope) containing the function 
	*/
	public function wait(delay:Number, callback:Function, args:Array, scope:Object):Void
	{
		var task:Object = {}
		task._mode 	= WAIT
		
		task.endTime	= getTimer() + delay
		task.callback	= callback
		task.scope	= scope
		task.args	= args
		
		this._taskList.push(task)
		this._taskCount++
	}
	
	
	
	/**
	* Wait for a certain number of frames
	* 
	* @param frames		how many frames to wait
	* @param callback	a callback function
	* @param args		a list of arguments for the callback function
	* @param scope		the object (scope) containing the function 
	*/
	public function waitFrames(frames:Number, callback:Function, args:Array, scope:Object):Void
	{
		var task:Object = {}
		task._mode 	= WAITFRAMES
		
		task.counter 	= 0
		task.frames	= frames
		task.callback	= callback
		task.scope	= scope
		task.args	= args
		
		this._taskList.push(task)
		this._taskCount++
	}
	
	
	
	/**
	* The typical wait-for-one-frame utility function
	* Useful for dynamically attached components or dynamically loaded clips
	*/
	public function wait1Frame(callback:Function, args:Array, scope:Object):Void
	{
		waitFrames(1, callback, args, scope)
	}
	
	
	
	/**
	* Task Completed
	* Remove from object list
	*/
	public function taskComplete(id:Number):Void
	{
		// Get task object
		var o:Object = this._taskList[id]
		
		// Remove it from list
		delete this._taskList[id]
		
		// Decrement task counter
		this._taskCount--
		
		// Invoke callback function
		if (o.args == null)
			o.callback()
		else
			o.callback.apply(o.scope, o.args)
	}
	
	
	
	/**
	* Main Thread
	* Iterates through all the tasks in the list and update 
	*/
	public function mainThread()
	{
		if (this._obj._taskCount > 0)
		{
			var list:Array = this._obj._taskList
			
			for (var i in list)
			{
				var o:Object = list[i]
				
				if (o._mode == TimeController.WAITFORFRAME)
				{
					if (o.target._currentframe >= o.frame)
						this._obj.taskComplete(i)
				}
				
				else if (o._mode == TimeController.WAIT)
				{
					if (getTimer() >= o.endTime)
						this._obj.taskComplete(i)
				}
				
				else if (o._mode == TimeController.WAITFRAMES)
				{
					o.counter++
					
					if (o.counter >= o.frames)
						this._obj.taskComplete(i)
				}
			}
		}
	}
	
	
	
}