/*
  Copyright (c) 2008, Adobe Systems Incorporated
  All rights reserved.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are
  met:

  * Redistributions of source code must retain the above copyright notice,
    this list of conditions and the following disclaimer.

  * Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.

  * Neither the name of Adobe Systems Incorporated nor the names of its
    contributors may be used to endorse or promote products derived from
    this software without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
  IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

package com.reversefold.json {

    public class JSONDecoderAsync {

        /**
         * Flag indicating if the parser should be strict about the format
         * of the JSON string it is attempting to decode.
         */
        private var strict : Boolean;

        /** The tokenizer designated to read the JSON string */
        public var tokenizer : JSONTokenizer;

		private var valueDecoder : JSONValueDecoder;
		
        /**
         * Constructs a new JSONDecoder to parse a JSON string
         * into a native object.
         *
         * @param s The JSON string to be converted
         *		into a native object
         * @param strict Flag indicating if the JSON string needs to
         * 		strictly match the JSON standard or not.
         * @langversion ActionScript 3.0
         * @playerversion Flash 9.0
         * @tiptext
         */
        public function JSONDecoderAsync(s : String, strict : Boolean) {
            this.strict = strict;
            tokenizer = new JSONTokenizer(s, strict);

			valueDecoder = JSONValueDecoder.parseValue(tokenizer.getNextToken(), tokenizer);
	
	        /*
	        nextToken();
	        value = parseValue();
	
	        // Make sure the input stream is empty
	        if ( strict && nextToken() != null )
	        {
	            tokenizer.parseError( "Unexpected characters left in input stream" );
	        }
	        */
        }

		public function loop() : Boolean {
			if (!done) {
				return valueDecoder.loop();
			}
			return done;
		}
		
		public function get done() : Boolean {
			return valueDecoder.done;
		}
		
        /**
         * Gets the internal object that was created by parsing
         * the JSON string passed to the constructor.
         *
         * @return The internal object representation of the JSON
         * 		string that was passed to the constructor
         * @langversion ActionScript 3.0
         * @playerversion Flash 9.0
         * @tiptext
         */
        public function getValue() : * {
			if (!done) {
				throw new Error("Not done");
			}
            return valueDecoder.value;
        }
    }
}
