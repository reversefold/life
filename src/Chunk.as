package {
	import flash.utils.describeType;
	
	public class Chunk extends Object {
		public function Chunk(o : Object = null) {
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
		
		public function toString() : String {
			var v : Vector.<String> = new Vector.<String>();
			for each (var n : String in describeType(this).variable.@name) {
				v.push('"' + n + '": ' + (this[n] is Vector.<uint> ? "[" + this[n] + "]" : this[n]));
			}
			return "{" + v.join(",") + "}";
		}
	}
}
