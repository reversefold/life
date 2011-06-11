package com.reversefold.json {

    public class JSONObjectDecoder extends JSONValueDecoder {
        public function JSONObjectDecoder(t : JSONTokenizer) {
            super(t);
			
			_value = parseObject();
			_done = true;
        }


        /**
         * Attempt to parse an object.
         */
        private final function parseObject() : Object {
            // create the object internally that we're going to
            // attempt to parse from the tokenizer
            var o : Object = new Object();

            // store the string part of an object member so
            // that we can assign it a value in the object
            var key : String

            // grab the next token from the tokenizer
            nextValidToken();

            // check to see if we have an empty object
            if (token.type == JSONTokenType.RIGHT_BRACE) {
                // we're done reading the object, so return it
                return o;
            }
            // in non-strict mode an empty object is also a comma
            // followed by a right bracket
            else if (!tokenizer.strict && token.type == JSONTokenType.COMMA) {
                // move past the comma
                nextValidToken();

                // check to see if we're reached the end of the object
                if (token.type == JSONTokenType.RIGHT_BRACE) {
                    return o;
                } else {
                    tokenizer.parseError("Leading commas are not supported.  Expecting '}' but found " + token.value);
                }
            }

            // deal with members of the object, and use an "infinite"
            // loop because we could have any amount of members
            while (true) {
                if (token.type == JSONTokenType.STRING) {
                    // the string value we read is the key for the object
                    key = String(token.value);

                    // move past the string to see what's next
                    nextValidToken();

                    // after the string there should be a :
                    if (token.type == JSONTokenType.COLON) {
                        // move past the : and read/assign a value for the key
                        o[key] = parseValue(token, tokenizer);

                        // move past the value to see what's next
                        nextValidToken();

                        // after the value there's either a } or a ,
                        if (token.type == JSONTokenType.RIGHT_BRACE) {
                            // we're done reading the object, so return it
                            return o;
                        } else if (token.type == JSONTokenType.COMMA) {
                            // skip past the comma and read another member
                            nextToken();

                            // Allow objects to have a comma after the last member
                            // if the decoder is not in strict mode
                            if (!tokenizer.strict) {
                                checkValidToken(token, tokenizer);

                                // Reached ",}" as the end of the object, so return it
                                if (token.type == JSONTokenType.RIGHT_BRACE) {
                                    return o;
                                }
                            }
                        } else {
                            tokenizer.parseError("Expecting } or , but found " + token.value);
                        }
                    } else {
                        tokenizer.parseError("Expecting : but found " + token.value);
                    }
                } else {
                    tokenizer.parseError("Expecting string but found " + token.value);
                }
            }
            return null;
        }
    }
}
