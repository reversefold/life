package {
	import flash.display.BitmapData;
	import flash.utils.ByteArray;
	import flash.utils.describeType;
	
	public class Chunk extends Object {
		public function Chunk(w : uint, h : uint, o : Object = null) {
			this.w = w;
			this.h = h;
			if (o == null) {
				return;
			}
			for each (var n : String in describeType(this).variable.@name) {
				if (n == "vector") {
					this[n] = Vector.<uint>(o[n]);
				} else {
					this[n] = o[n];
				}
			}
		}
		private var w : uint;
		private var h : uint;
		
		public var inner : uint;
		public var top : uint;
		public var bottom : uint;
		public var left : uint;
		public var right : uint;
		public var topRight : uint;
		public var topLeft : uint;
		public var bottomRight : uint;
		public var bottomLeft : uint;
		public var vector : Vector.<uint>;
		public var bitmapData : BitmapData;
		public function setVector(inVector : Vector.<uint>) : void {
			vector = inVector;
			bitmapData = new BitmapData(w, h);
			bitmapData.setVector(bitmapData.rect, vector);
		}
		
		public function toString() : String {
			var v : Vector.<String> = new Vector.<String>();
			for each (var n : String in describeType(this).variable.@name) {
				v.push(
					'"' +
					n +
					'"' +
					': ' +
					(this[n] is Vector.<uint> ? "[" + this[n] + "]" : this[n]));
			}
			return "{" + v.join(",") + "}";
		}
		
		public function write(ba : ByteArray) : void {
			ba.writeUnsignedInt(inner);
			/*
			ba.writeUnsignedInt(top);
			ba.writeUnsignedInt(bottom);
			ba.writeUnsignedInt(left);
			ba.writeUnsignedInt(right);
			ba.writeUnsignedInt(topRight);
			ba.writeUnsignedInt(topLeft);
			ba.writeUnsignedInt(bottomRight);
			ba.writeUnsignedInt(bottomLeft);
			ba.writeUnsignedInt(vector.length);
			for (var i : uint = 0; i < vector.length; ++i) {
				ba.writeUnsignedInt(vector[i]);
			}
			*/
		}
		
		private static var innerVector : Vector.<uint>;
		private static var i : uint;
		private static var maskName : String;
		public static function read(ba : ByteArray, w : uint, h : uint, cacheData : CacheData) : Chunk {
			var c : Chunk = new Chunk(w, h);
			c.inner = ba.readUnsignedInt();
			
			innerVector = new Vector.<uint>(cacheData.INNER_CACHE_VECTOR_LENGTH, true);
			i = 0;
			for (var y : uint = 1; y <= cacheData.CACHE_HEIGHT; ++y) {
				var yo : uint = y * cacheData.FULL_CACHE_WIDTH;
				for (var x : uint = 1; x <= cacheData.CACHE_WIDTH; ++x) {
					innerVector[i] = (c.inner & (1 << x + yo)) ? Life.ALIVE_PIXEL : Life.DEAD_PIXEL;
					++i;
				}
			}
			//state = new Chunk(CACHE_WIDTH, CACHE_HEIGHT);
			//state.setVector(innerVector);
			c.setVector(innerVector);
			for each (maskName in cacheData.maskNames) {
				c[maskName] = (cacheData.masks[maskName] & c.inner); // & inner would be the same since the masks are all for the inner rect
				//precalculate moving this masked bit to the place it needs to be for neighbor use
				if (cacheData.maskNeighborOffsetNegative[maskName] == 1) {
					c[maskName] >>= cacheData.maskNeighborOffsets[maskName]
				} else {
					c[maskName] <<= cacheData.maskNeighborOffsets[maskName];
				}
			}

			/*
			c.top = ba.readUnsignedInt();
			c.bottom = ba.readUnsignedInt();
			c.left = ba.readUnsignedInt();
			c.right = ba.readUnsignedInt();
			c.topRight = ba.readUnsignedInt();
			c.topLeft = ba.readUnsignedInt();
			c.bottomRight = ba.readUnsignedInt();
			c.bottomLeft = ba.readUnsignedInt();
			var v : Vector.<uint> = new Vector.<uint>(ba.readUnsignedInt(), true);
			for (var i : uint = 0; i < v.length; ++i) {
				v[i] = ba.readUnsignedInt();
			}
			c.setVector(v);
			*/
			return c;
		}
	}
}
