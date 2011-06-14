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
		}
		
		public static function read(ba : ByteArray, w : uint, h : uint) : Chunk {
			var c : Chunk = new Chunk(w, h);
			c.inner = ba.readUnsignedInt();
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
			return c;
		}
	}
}
