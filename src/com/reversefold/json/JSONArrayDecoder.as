package com.reversefold.json {

    public class JSONArrayDecoder extends JSONValueDecoder {
        public function JSONArrayDecoder(t : JSONTokenizer) {
            super(t);
			
			_value = parseArray();
			_done = true;
        }

        /**
         * Attempt to parse an array.
         */
        private final function parseArray() : Array {
            // create an array internally that we're going to attempt
            // to parse from the tokenizer
            var a : Array = new Array();

            // grab the next token from the tokenizer to move
            // past the opening [
            nextValidToken();

            // check to see if we have an empty array
            if (token.type == JSONTokenType.RIGHT_BRACKET) {
                // we're done reading the array, so return it
                return a;
            }
            // in non-strict mode an empty array is also a comma
            // followed by a right bracket
            else if (!tokenizer.strict && token.type == JSONTokenType.COMMA) {
                // move past the comma
                nextValidToken();

                // check to see if we're reached the end of the array
                if (token.type == JSONTokenType.RIGHT_BRACKET) {
                    return a;
                } else {
                    tokenizer.parseError("Leading commas are not supported.  Expecting ']' but found " + token.value);
                }
            }

            // deal with elements of the array, and use an "infinite"
            // loop because we could have any amount of elements
            while (true) {
                // read in the value and add it to the array
                a.push(parseValue(token, tokenizer));

                // after the value there should be a ] or a ,
                nextValidToken();

                if (token.type == JSONTokenType.RIGHT_BRACKET) {
                    // we're done reading the array, so return it
                    return a;
                } else if (token.type == JSONTokenType.COMMA) {
                    // move past the comma and read another value
                    nextToken();

                    // Allow arrays to have a comma after the last element
                    // if the decoder is not in strict mode
                    if (!tokenizer.strict) {
                        checkValidToken(token, tokenizer);

                        // Reached ",]" as the end of the array, so return it
                        if (token.type == JSONTokenType.RIGHT_BRACKET) {
                            return a;
                        }
                    }
                } else {
                    tokenizer.parseError("Expecting ] or , but found " + token.value);
                }
            }

            return null;
        }

    }
}
