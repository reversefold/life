package com.reversefold.json {
	import avmplus.getQualifiedClassName;
	
	import flash.utils.Dictionary;
	import flash.utils.getDefinitionByName;

    public class JSONValueDecoder {
		private static const CACHE_SIZE : uint = 10;
		
        protected var tokenizer : JSONTokenizer;
        protected var _value : * = null;
        protected var _done : Boolean = false;

        /** The current token from the tokenizer */
        protected var token : JSONToken = null;

		protected function reset(t : JSONTokenizer, ... args) : void {
			tokenizer = t;
			
			_value = null;
			_done = false;
			token = null;
		}
		
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
		
		private static var _cache : Dictionary = new Dictionary();
		public static function getInstance(c : Class, t : JSONTokenizer, ... args) : JSONValueDecoder {
			var instance : JSONValueDecoder;
			if (_cache[c] == null) {
				_cache[c] = [];
			}
			if (_cache[c].length > 0) {
				instance = _cache[c].pop();
				var targs : Array = [ t ].concat(args);
				instance.reset.apply(instance, targs);
			} else {
				//hack, but oh well
				if (c == JSONValue) {
					instance = new JSONValue(t, args[0]);
				} else {
					instance = new c(t);
				}
			}
			return instance;
		}
		public static function reclaimInstance(i : JSONValueDecoder) : void {
			var c : Class = Class(getDefinitionByName(getQualifiedClassName(i)));
			if (_cache[c] == null) {
				_cache[c] = [];
			}
			if (_cache[c].length < CACHE_SIZE) {
				_cache[c].push(i);
			}
		}
		public static function emptyCache() : void {
			_cache = new Dictionary();
		}

		public function loop() : Boolean {
			throw new Error("Implement me!");
		}
		
        /**
         * Attempt to parse a value
         */
        public static function parseValue(token : JSONToken, tokenizer : JSONTokenizer) : JSONValueDecoder {
            checkValidToken(token, tokenizer);

            switch (token.type) {
                case JSONTokenType.LEFT_BRACE:  {
                    return getInstance(JSONObjectDecoder, tokenizer);
                }

                case JSONTokenType.LEFT_BRACKET:  {
                    return getInstance(JSONArrayDecoder, tokenizer);
                }

                case JSONTokenType.STRING:
                case JSONTokenType.NUMBER:
                case JSONTokenType.TRUE:
                case JSONTokenType.FALSE:
                case JSONTokenType.NULL:  {
                    return getInstance(JSONValue, tokenizer, token.value);
                }

                case JSONTokenType.NAN:  {
                    if (!tokenizer.strict) {
                        return getInstance(JSONValue, tokenizer, token.value);
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
