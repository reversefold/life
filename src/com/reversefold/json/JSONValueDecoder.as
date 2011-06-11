package com.reversefold.json {

    public class JSONValueDecoder {
        protected var tokenizer : JSONTokenizer;
        protected var _value : *;
        protected var _done : Boolean = false;

        /** The current token from the tokenizer */
        protected var token : JSONToken;

        public function JSONValueDecoder(t : JSONTokenizer) {
            tokenizer = t;
        }

        public function get value() : * {
            if (!done) {
                throw new Error("Not done yet");
            }
            return _value;
        }

        public function get done() : Boolean {
            return _done;
        }

        public function next() : Boolean {
            return !done;
        }

        /**
         * Returns the next token from the tokenzier reading
         * the JSON string
         */
        protected final function nextToken() : JSONToken {
            return token = tokenizer.getNextToken();
        }

        /**
         * Returns the next token from the tokenizer reading
         * the JSON string and verifies that the token is valid.
         */
        protected final function nextValidToken() : JSONToken {
            token = tokenizer.getNextToken();
            checkValidToken(token, tokenizer);

            return token;
        }

        /**
         * Verifies that the token is valid.
         */
        protected static function checkValidToken(token : JSONToken, tokenizer : JSONTokenizer) : void {
            // Catch errors when the input stream ends abruptly
            if (token == null) {
                tokenizer.parseError("Unexpected end of input");
            }
        }

        /**
         * Attempt to parse a value
         */
        public static function parseValue(token : JSONToken, tokenizer : JSONTokenizer) : Object {
            checkValidToken(token, tokenizer);

            switch (token.type) {
                case JSONTokenType.LEFT_BRACE:  {
                    return new JSONObjectDecoder(tokenizer).value;
                }

                case JSONTokenType.LEFT_BRACKET:  {
                    return new JSONArrayDecoder(tokenizer).value;
                }

                case JSONTokenType.STRING:
                case JSONTokenType.NUMBER:
                case JSONTokenType.TRUE:
                case JSONTokenType.FALSE:
                case JSONTokenType.NULL:  {
                    return token.value;
                }

                case JSONTokenType.NAN:  {
                    if (!tokenizer.strict) {
                        return token.value;
                    } else {
                        tokenizer.parseError("Unexpected " + token.value);
                    }
                }

                default:  {
                    tokenizer.parseError("Unexpected " + token.value);
                }

            }

            return null;
        }
    }
}
