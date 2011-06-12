package com.reversefold.json {

	public class JSONValue extends JSONValueDecoder {
		public function JSONValue(v : *) {
			super(null);
			_value = v;
			_done = true;
		}
	}
}
