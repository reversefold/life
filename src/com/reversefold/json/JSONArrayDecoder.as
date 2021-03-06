package com.reversefold.json {

    public class JSONArrayDecoder extends JSONValueDecoder {
        public function JSONArrayDecoder(t : JSONTokenizer) {
            super(t);
			
			//_value = parseArray();
			//_done = true;
        }

		private var a : Array = null;
		private var element : JSONValueDecoder = null;		
		
		override public function loop() : Boolean {
			if (a == null) {
				//trace("init array");
				initArray();
			} else if (element != null) {
				//trace("continue element");
				continueElement();
			} else {
				//trace("next element");
				nextElement();
			}
			return done;
		}
		
		private function __done() : void {
			_value = a;
			_done = true;
		}
		
        /**
         * Attempt to parse an array.
         */
        //private final function parseArray() : Array {
		private function initArray() : void {
            // create an array internally that we're going to attempt
            // to parse from the tokenizer
            a = new Array();

            // grab the next token from the tokenizer to move
            // past the opening [
            nextValidToken();

            // check to see if we have an empty array
            if (token.type == JSONTokenType.RIGHT_BRACKET) {
                // we're done reading the array, so return it
				__done();
				return;
            }
            // in non-strict mode an empty array is also a comma
            // followed by a right bracket
            else if (!tokenizer.strict && token.type == JSONTokenType.COMMA) {
                // move past the comma
                nextValidToken();

                // check to see if we're reached the end of the array
                if (token.type == JSONTokenType.RIGHT_BRACKET) {
					__done();
					return;
                } else {
                    tokenizer.parseError("Leading commas are not supported.  Expecting ']' but found " + token.value);
                }
            }
		}
		
		private function nextElement() : void {
            // deal with elements of the array, and use an "infinite"
            // loop because we could have any amount of elements

			// read in the value and add it to the array
            element = parseValue(token, tokenizer);
		}
		
		private function continueElement() : void {
			if (!element.done && !element.loop()) {
				return;
			}
			
			a.push(element.value);
			element = null;

            // after the value there should be a ] or a ,
            nextValidToken();

            if (token.type == JSONTokenType.RIGHT_BRACKET) {
                // we're done reading the array, so return it
                __done();
				return;
            } else if (token.type == JSONTokenType.COMMA) {
                // move past the comma and read another value
                nextToken();

                // Allow arrays to have a comma after the last element
                // if the decoder is not in strict mode
                if (!tokenizer.strict) {
                    checkValidToken(token, tokenizer);

                    // Reached ",]" as the end of the array, so return it
                    if (token.type == JSONTokenType.RIGHT_BRACKET) {
                        __done();
						return;
                    }
                }
            } else {
                tokenizer.parseError("Expecting ] or , but found " + token.value);
            }
        }
    }
}
