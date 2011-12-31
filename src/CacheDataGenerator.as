package {
    import mx.utils.StringUtil;

    public class CacheDataGenerator {
        public var cacheData : CacheData;

        //public var currentState : Vector.<uint>;
        //public var nextState : Vector.<uint>;
        public var cacheIdx : uint = 0;
        public var full : uint;
        public var inner : uint;

        public function CacheDataGenerator(inCacheData : CacheData) {
            cacheData = inCacheData;

            //currentState = new Vector.<uint>(cacheData.CACHE_VECTOR_LENGTH, true);
            //nextState = new Vector.<uint>(cacheData.CACHE_VECTOR_LENGTH, true);
        }

        public function calculateNextState(stateIdx : uint) : void {
            /*
            uintToVec(stateIdx, currentState);
            nextFromPrevVector(currentState, nextState, cacheData.FULL_CACHE_WIDTH, cacheData.FULL_CACHE_HEIGHT);
            full = vecToUint(nextState);
            */
            full = nextFromPrev(stateIdx, cacheData.FULL_CACHE_WIDTH, cacheData.FULL_CACHE_HEIGHT);
            
            /** /
            var i : uint;
            if (cacheIdx > 1000000) {
                var topFlip : uint = 0;
                var ROW_MASK : uint = 0;
                for (i = 0; i < cacheData.FULL_CACHE_WIDTH; ++i) {
                    ROW_MASK |= 1 << i;
                }
                trace("cacheIdx");
                _traceMask(cacheIdx);
                for (i = 0; i < cacheData.CACHE_VECTOR_LENGTH; i += cacheData.FULL_CACHE_WIDTH) {
                    var flipBits : int = (cacheData.CACHE_VECTOR_LENGTH - 2 * i - cacheData.FULL_CACHE_WIDTH);
                    if (flipBits >= 0) {
                        topFlip |= (cacheIdx & (ROW_MASK << i)) << flipBits;
                    } else {
                        topFlip |= (cacheIdx & (ROW_MASK << i)) >> -flipBits;
                    }
                }
                trace("topFlip");
                _traceMask(topFlip);
            }
            /**/
            inner = full & cacheData.masks.inner;
            cacheData.cache[stateIdx] = inner;
            if (cacheData.states[inner] == null) {
                calculateState(inner);
            }
        }
        
        public function calculateState(inner : uint) : void {
            //stateIdx &= cacheData.masks.inner;
            //inner = stateIdx & cacheData.masks.inner;
            var innerVector : Vector.<uint> = new Vector.<uint>(cacheData.INNER_CACHE_VECTOR_LENGTH, true);
            var i : uint = 0;
            for (var y : uint = 1; y <= cacheData.CACHE_HEIGHT; ++y) {
                var yo : uint = y * cacheData.FULL_CACHE_WIDTH;
                for (var x : uint = 1; x <= cacheData.CACHE_WIDTH; ++x) {
                    innerVector[i] = (inner & (1 << x + yo)) ? Life.ALIVE_PIXEL : Life.DEAD_PIXEL;
                    ++i;
                }
            }
            var state : Chunk = new Chunk(cacheData.CACHE_WIDTH, cacheData.CACHE_HEIGHT);
            state.setVector(innerVector);
            for each (var maskName : String in cacheData.maskNames) {
                state[maskName] = (cacheData.masks[maskName] & inner); // & full would be the same since the masks are all for the inner rect
                //precalculate moving this masked bit to the place it needs to be for neighbor use
                if (cacheData.maskNeighborOffsetNegative[maskName] == 1) {
                    state[maskName] >>= cacheData.maskNeighborOffsets[maskName];
                } else {
                    state[maskName] <<= cacheData.maskNeighborOffsets[maskName];
                }
            }
            cacheData.states[inner] = state;
        }
        
        public function calculateNext() : Boolean {
            calculateNextState(cacheIdx);
            ++cacheIdx;

            return cacheIdx < cacheData.NUM_CACHE_PERMUTATIONS;
        }

        public function traceMask(maskName : String) : void {
            trace(maskName);
            _traceMask(cacheData.masks[maskName]);
        }

        public function _traceMask(mask : uint) : void {
            var str : String = mask.toString(2);
            trace((StringUtil.repeat("0", cacheData.FULL_CACHE_WIDTH * cacheData.FULL_CACHE_HEIGHT - str.length) + str)
                  .split('')
                  .reverse()
                  .join(" ")
                  .split(new RegExp("(" + StringUtil.repeat(". ", cacheData.FULL_CACHE_WIDTH) + ")"))
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

        /**
         * Returns the next inner state for a full WxH chunk.
         */
        public static function nextFromPrev(c : uint, W : uint, H : uint) : uint {
            var n : uint = 0;
            var Wm : uint = W - 1;
            var Hm : uint = H - 1;
            for (var x : uint = 1; x < Wm; ++x) {
                for (var y : uint = 1; y < Hm; ++y) {
                    var na : uint = 0;
                    
                    var mx : uint = Math.min(W, x + 2);
                    var my : uint = Math.min(H, y + 2);
                    
                    check: for (var yi : uint = Math.max(0, y - 1); yi < my; ++yi) {
                        var yo : uint = yi * W;
                        for (var xi : uint = Math.max(0, x - 1); xi < mx; ++xi) {
                            if ((xi != x || yi != y) && (c >> (xi + yo) & 0x1)) {
                                ++na;
                                if (na == 4) {
                                    break check;
                                }
                            }
                        }
                    }
                    
                    switch (na) {
                        //stays the same
                        case 2:  {
                            n |= c & (0x1 << (x + y * W));
                            break;
                        }
                        //born
                        case 3:  {
                            n |= 0x1 << (x + y * W);
                            break;
                        }
                    }
                }
            }

            return n;
        }

        public static function nextFromPrevVector(c : Vector.<uint>, n : Vector.<uint>, W : uint, H : uint) : void {
            for (var x : uint = 0; x < W; ++x) {
                for (var y : uint = 0; y < H; ++y) {
                    var na : uint = 0;

                    var mx : uint = Math.min(W, x + 2);
                    var my : uint = Math.min(H, y + 2);

                    check: for (var yi : uint = Math.max(0, y - 1); yi < my; ++yi) {
                        var yo : uint = yi * W;
                        for (var xi : uint = Math.max(0, x - 1); xi < mx; ++xi) {
                            if ((xi != x || yi != y) && c[xi + yo] == Life.ALIVE_PIXEL) {
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
                vec[idx] = ((i >> idx) & 0x1) == 0x1 ? Life.ALIVE_PIXEL : Life.DEAD_PIXEL;
            }
        }
        
        public static function uintToVecRet(i : uint, vectorLength : uint) : Vector.<uint> {
            var v : Vector.<uint> = new Vector.<uint>(vectorLength, true);
            uintToVec(i, v);
            return v;
        }

        public static function vecToUint(vec : Vector.<uint>) : uint {
            var i : uint = 0;
            for (var idx : uint = 0; idx < vec.length; ++idx) {
                if (vec[idx] == Life.ALIVE_PIXEL) {
                    i += 0x1 << idx;
                }
            }
            return i;
        }
    }
}
