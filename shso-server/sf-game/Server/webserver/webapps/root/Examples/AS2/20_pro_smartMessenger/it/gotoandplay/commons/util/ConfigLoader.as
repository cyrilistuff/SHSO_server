/**
* 
* ConfigLoader Class
* version 1.0.0
* 
* (c) 2005 gotoAndPlay()
* 
*/

dynamic class it.gotoandplay.commons.util.ConfigLoader extends XML
{
	// Public event handlers
	public var onConfigLoaded:Function
	public var onLoadError:Function
	
	
	// Private memebers
	private var __arrayTags__:Array
	public var xmlObj:Object
	
	
	
	//---------------------------------------------------------------------
	// Default constructor
	//---------------------------------------------------------------------
	function ConfigLoader()
	{
		super()
		this.ignoreWhite = true
		this.xmlObj = {}
		this.__arrayTags__ = []
		
		this.ipAddress = "127.0.0.1"
		this.port = 9339
		this.zone = ""	
	}
	
	
	
	//---------------------------------------------------------------------
	// load config file
	//---------------------------------------------------------------------
	public function loadCfg(cfgFile:String)
	{
		this.load(cfgFile)
	}
	
	
	
	//---------------------------------------------------------------------
	// Event fired when xml has been parsed
	//---------------------------------------------------------------------
	private function configReady()
	{
		this.onConfigLoaded()
	}
	
	
	
	//---------------------------------------------------------------------
	// check if file was loaded successfully and start parsing
	//---------------------------------------------------------------------
	function onLoad(ok)
	{
		if (ok)
		{
			xml2Obj(this.childNodes, this.xmlObj)
			configReady()
		}
		else
		{
			this.onLoadError()
		}
	}
	
	
	
	//---------------------------------------------------------------------
	// return the xml object
	//---------------------------------------------------------------------
	public function getXmlObject():Object
	{
		return this.xmlObj
	}
	
	
	
	//---------------------------------------------------------------------
	// Parse XML and transform it in an Object
	//---------------------------------------------------------------------
	private function xml2Obj(xmlNodes, parentObj)
	{
		// counter
		var i = 0
		var currObj = null
	
		while(i < xmlNodes.length)
		{
			// get first child inside XML object
			var node		= xmlNodes[i]
			var nodeName	= node.nodeName //trace("tag: " + nodeName);
			var nodeValue	= node.nodeValue
	
			// Check if parent object is an Array or an Object
			if (parentObj instanceof Array)
			{
				currObj = new Object()
				parentObj.push(currObj)
				currObj = parentObj[parentObj.length - 1]
	
			}
			else
			{
				parentObj[nodeName] = new Object()
				currObj = parentObj[nodeName]
			}
	
			//-------------------------------------------
			// Save attributes
			//-------------------------------------------
			for (var j in node.attributes)
			{
				if (typeof currObj.attributes == "undefined")
				{
					currObj.attributes = new Object();
				}
	
				var attVal = node.attributes[j];
	
				// Check if it's number
				if (!isNaN(attVal))
				{
					attVal = Number(attVal);
				}
	
				// Check if it's a boolean
				if (attVal.toLowerCase() == "true")
				{
					attVal = true
				}
				else if (attVal.toLowerCase() == "false")
				{
					attVal = false
				}
	
				// Store the attribute
				currObj.attributes[j] = attVal
			}
	
			// If this node is present in the arrayTag Object
			// then a new Array() is created to hold its memebers
			if (__arrayTags__[nodeName])
			{
				currObj[nodeName] = new Array()
				var currObj = currObj[nodeName]
			}
	
			// Check if we have more subnodes
			if (node.hasChildNodes() && node.firstChild.nodeValue == undefined)
			{
				// Call this function recursively until node has no more children
				var subNodes = node.childNodes
				xml2Obj(subNodes, currObj)
			}
			else
			{
				var nodeValue = node.firstChild.nodeValue
	
				if (!isNaN(nodeValue))
					nodeValue = Number(nodeValue)
	
				currObj.value = nodeValue
			}
	
			i++
		}
	
	}
}