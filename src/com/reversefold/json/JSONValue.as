package com.reversefold.json {

	public class JSONValue extends JSONValueDecoder {
		public function JSONValue(t : JSONTokenizer, v : *) {
			super(t);
			
			_value = v;
			_done = true;
		}
		
		override protected function reset(t : JSONTokenizer, ... args) : void {
			super.reset(t);
			_value = args[0];
			_done = true;
		}
	}
}
