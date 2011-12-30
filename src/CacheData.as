package {
    import flash.net.FileReference;
    import flash.utils.ByteArray;
    import flash.utils.describeType;

    import mx.utils.StringUtil;

    public class CacheData {
        public static const ALIVE_PIXEL : uint = 0xFF000000;
        public static const DEAD_PIXEL : uint = 0xFFFFFFFF;

        public var CACHE_WIDTH : uint;
        public var CACHE_HEIGHT : uint;

        public var FULL_CACHE_WIDTH : uint;
        public var FULL_CACHE_HEIGHT : uint;

        public var CACHE_VECTOR_LENGTH : uint;
        public var INNER_CACHE_VECTOR_LENGTH : uint;
        public var NUM_CACHE_PERMUTATIONS : uint;

        public var masks : Chunk;
        public var maskOffsets : Chunk;
        public var maskNeighborOffsets : Chunk;
        public var maskNeighborOffsetNegative : Chunk;
        public var maskNames : Vector.<String> = new Vector.<String>();

        public var cache : Vector.<uint>;
        public var states : Vector.<Chunk>;

        //shoudn't really be here, only while generating
        public var currentStates : Vector.<uint>;
        public var nextStates : Vector.<uint>;
        public var cacheIdx : uint = 0;
        public var full : uint;
        public var inner : uint;

        public function CacheData(inWidth : uint, inHeight : uint) {
            CACHE_WIDTH = inWidth;
            CACHE_HEIGHT = inHeight;
            FULL_CACHE_WIDTH = CACHE_WIDTH + 2;
            FULL_CACHE_HEIGHT = CACHE_HEIGHT + 2;
            CACHE_VECTOR_LENGTH = FULL_CACHE_WIDTH * FULL_CACHE_HEIGHT;
            INNER_CACHE_VECTOR_LENGTH = CACHE_WIDTH * CACHE_HEIGHT;
            NUM_CACHE_PERMUTATIONS = Math.pow(2, CACHE_VECTOR_LENGTH);

            cache = new Vector.<uint>(NUM_CACHE_PERMUTATIONS, true);
            states = new Vector.<Chunk>(Math.pow(2, CACHE_VECTOR_LENGTH - FULL_CACHE_WIDTH - 1), true);
            
            masks = new Chunk(CACHE_WIDTH, CACHE_HEIGHT);
            maskOffsets = new Chunk(CACHE_WIDTH, CACHE_HEIGHT);
            maskNeighborOffsets = new Chunk(CACHE_WIDTH, CACHE_HEIGHT);
            maskNeighborOffsetNegative = new Chunk(CACHE_WIDTH, CACHE_HEIGHT);

            currentStates = new Vector.<uint>(CACHE_VECTOR_LENGTH, true);
            nextStates = new Vector.<uint>(CACHE_VECTOR_LENGTH, true);


            for each (var maskName : String in describeType(masks).variable.@name) {
                if (maskName == "vector" || maskName == "bitmapData") {
                    continue;
                }
                maskNames.push(maskName);
            }

            maskOffsets.topLeft = maskOffsets.top = maskOffsets.left = (1 + FULL_CACHE_WIDTH);
            maskOffsets.topRight = maskOffsets.right = (2 * FULL_CACHE_WIDTH - 2);
            maskOffsets.bottomLeft = maskOffsets.bottom = (CACHE_VECTOR_LENGTH - 2 * FULL_CACHE_WIDTH + 1);
            maskOffsets.bottomRight = (CACHE_VECTOR_LENGTH - FULL_CACHE_WIDTH - 2);

            masks.topLeft = masks.topRight = masks.bottomLeft = masks.bottomRight = 1;
            for (var x : uint = 0; x < CACHE_WIDTH; ++x) {
                masks.top |= 1 << x;
            }
            masks.bottom = masks.top;

            var i : uint = 0;
            for (var y : uint = 0; y < CACHE_HEIGHT; ++y, i += FULL_CACHE_WIDTH) {
                masks.left |= 1 << i;
            }
            masks.right = masks.left;

            for each (maskName in maskNames) {
                masks[maskName] <<= maskOffsets[maskName];
            }

            i = 0;
            for (y = 0; y < CACHE_HEIGHT; ++y, i += FULL_CACHE_WIDTH) {
                masks.inner |= masks.top << i;
            }

            maskNeighborOffsets.bottomRight
                = maskNeighborOffsets.topLeft = maskOffsets.bottomRight - maskOffsets.topLeft + FULL_CACHE_WIDTH + 1;
            maskNeighborOffsets.bottomLeft
                = maskNeighborOffsets.topRight = maskOffsets.bottomLeft - maskOffsets.topRight + FULL_CACHE_WIDTH - 1;
            maskNeighborOffsets.bottom
                = maskNeighborOffsets.top = maskOffsets.bottom - maskOffsets.top + FULL_CACHE_WIDTH;
            maskNeighborOffsets.right
                = maskNeighborOffsets.left = maskOffsets.right - maskOffsets.left + 1;
            maskNeighborOffsetNegative.bottomRight = maskNeighborOffsetNegative.bottomLeft
                = maskNeighborOffsetNegative.bottom = maskNeighborOffsetNegative.right = 1;
        /*
        for each (maskName in maskNames) {
        traceMask(maskName);
        }
        */
        }

        public function calculateNext() : Boolean {
            uintToVec(cacheIdx, currentStates);
            nextFromPrev(currentStates, nextStates, FULL_CACHE_WIDTH, FULL_CACHE_HEIGHT);
            full = vecToUint(nextStates);

            if (cacheIdx > 1000000) {
                var topFlip : uint = 0;
                var ROW_MASK : uint = 0;
                for (i = 0; i < FULL_CACHE_WIDTH; ++i) {
                    ROW_MASK |= 1 << i;
                }
                trace("cacheIdx");
                _traceMask(cacheIdx);
                var i : uint;
                for (i = 0; i < CACHE_VECTOR_LENGTH; i += FULL_CACHE_WIDTH) {
                    var flipBits : int = (CACHE_VECTOR_LENGTH - 2 * i - FULL_CACHE_WIDTH);
                    if (flipBits >= 0) {
                        topFlip |= (cacheIdx & (ROW_MASK << i)) << flipBits;
                    } else {
                        topFlip |= (cacheIdx & (ROW_MASK << i)) >> -flipBits;
                    }
                }
                trace("topFlip");
                _traceMask(topFlip);
            }

            inner = full & masks.inner;
            if (states[inner] == null) {
                var innerVector : Vector.<uint> = new Vector.<uint>(INNER_CACHE_VECTOR_LENGTH, true);
                i = 0;
                for (var y : uint = 1; y <= CACHE_HEIGHT; ++y) {
                    var yo : uint = y * FULL_CACHE_WIDTH;
                    for (var x : uint = 1; x <= CACHE_WIDTH; ++x) {
                        innerVector[i] = (full & (1 << x + yo)) ? ALIVE_PIXEL : DEAD_PIXEL;
                        ++i;
                    }
                }
                var state : Chunk = new Chunk(CACHE_WIDTH, CACHE_HEIGHT);
                state.setVector(innerVector);
                for each (var maskName : String in maskNames) {
                    state[maskName] = (masks[maskName] & full); // & inner would be the same since the masks are all for the inner rect
                    //precalculate moving this masked bit to the place it needs to be for neighbor use
                    if (maskNeighborOffsetNegative[maskName] == 1) {
                        state[maskName] >>= maskNeighborOffsets[maskName]
                    } else {
                        state[maskName] <<= maskNeighborOffsets[maskName];
                    }
                }
                states[inner] = state;
            }
            cache[cacheIdx] = inner;
            ++cacheIdx;

            return cacheIdx < NUM_CACHE_PERMUTATIONS;
        }

        private function traceMask(maskName : String) : void {
            trace(maskName);
            _traceMask(masks[maskName]);
        }

        private function _traceMask(mask : uint) : void {
            var str : String = mask.toString(2);
            trace((StringUtil.repeat("0", FULL_CACHE_WIDTH * FULL_CACHE_HEIGHT - str.length) + str)
                  .split('')
                  .reverse()
                  .join(" ")
                  .split(new RegExp("(" + StringUtil.repeat(". ", FULL_CACHE_WIDTH) + ")"))
                  .join("\n ")
                  .replace(/\n \n/g, "\n")
                  .substr(1));
            /*
            var line : String = maskName;
            for (var i : uint = 0; i < len; ++i) {
                if (i % fw == 0) {
                    trace(line);
                    line = "";
                }
                line += " " + ((mask >> i) & 1);
            }
            trace(line);
            */
        }


        public static function nextFromPrev(c : Vector.<uint>, n : Vector.<uint>, W : uint, H : uint) : void {
            for (var x : uint = 0; x < W; ++x) {
                for (var y : uint = 0; y < H; ++y) {
                    var na : uint = 0;

                    var mx : uint = Math.min(W, x + 2);
                    var my : uint = Math.min(H, y + 2);

                    check: for (var yi : uint = Math.max(0, y - 1); yi < my; ++yi) {
                        var yo : uint = yi * W;
                        for (var xi : uint = Math.max(0, x - 1); xi < mx; ++xi) {
                            if ((xi != x || yi != y) && c[xi + yo] == ALIVE_PIXEL) {
                                ++na;
                                if (na == 4) {
                                    break check;
                                }
                            }
                        }
                    }

                    switch (na) {
                        case 0:
                        case 1:
                        case 4:  {
                            n[x + y * W] = Life.DEAD_PIXEL;
                            break;
                        }
                        case 2:  {
                            var i : uint = x + y * W;
                            n[i] = c[i];
                            break;
                        }
                        case 3:  {
                            n[x + y * W] = Life.ALIVE_PIXEL;
                            break;
                        }
                    }
                }
            }
        }

        public static function uintToVec(i : uint, vec : Vector.<uint>) : void {
            for (var idx : uint = 0; idx < vec.length; ++idx) {
                vec[idx] = ((i >> idx) & 0x1) == 0x1 ? ALIVE_PIXEL : DEAD_PIXEL;
            }
        }

        public static function vecToUint(vec : Vector.<uint>) : uint {
            var i : uint = 0;
            for (var idx : uint = 0; idx < vec.length; ++idx) {
                if (vec[idx] == ALIVE_PIXEL) {
                    i += 0x1 << idx;
                }
            }
            return i;
        }
    }
}
