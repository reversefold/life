package {
    import com.foxaweb.utils.Raster;
    
    import flash.display.BitmapData;
    import flash.geom.Point;
    import flash.geom.Rectangle;
    import flash.utils.ByteArray;

    public class LifeState {
        public static const WRAP : Boolean = true;
        
        [Embed(source="assets/data/corder-lineship.rle", mimeType="application/octet-stream")]
        private static var _CORDER_LINESHIP: Class;
        [Embed(source="assets/data/corder-adjustable-lineship-short.rle", mimeType="application/octet-stream")]
        private static var _CORDER_ADJUSTABLE_LINESHIP: Class;

        public static var CORDER_LINESHIP : String = ByteArray(new _CORDER_LINESHIP()).toString();
        public static var CORDER_ADJUSTABLE_LINESHIP : String = ByteArray(new _CORDER_ADJUSTABLE_LINESHIP()).toString();
        
        public var REQUESTED_WIDTH : uint;
        public var REQUESTED_HEIGHT : uint;
        
        public var DISPLAY_WIDTH : uint;
        public var DISPLAY_HEIGHT : uint;
        
        public var CHUNKED_WIDTH : uint;
        public var CHUNKED_HEIGHT : uint;
        
        public var FULL_CHUNKED_WIDTH : uint;
        public var FULL_CHUNKED_HEIGHT : uint;
        
        public var FULL_CHUNKED_LENGTH : uint;
        public var FULL_CHUNKED_LIVE_LENGTH : uint;
        
        public var FULL_DISPLAY_WIDTH : uint;
        public var FULL_DISPLAY_HEIGHT : uint;

        private var cacheData : CacheData;
        
        public var upIdx : uint;
        public var downIdx : uint;
        public var currentState : Chunk;
        public var nextState : Chunk;
        public var point : Point = new Point();

        public var currentStates : Vector.<uint>;
        public var nextStates : Vector.<uint>;
        public var points : Vector.<Point>;
        public var stateNeighbors : Vector.<Chunk>;
        
        public var currentChunksToCheck : Vector.<Boolean>;
        public var nextChunksToCheck : Vector.<Boolean>;

        public var bitmapData : Raster;

        public var chunkRect : Rectangle;

        public function LifeState(inCacheData : CacheData) {
            cacheData = inCacheData;
        }
        
        public function reset(requestedWidth : uint, requestedHeight : uint, type : uint) : void {
            REQUESTED_WIDTH = requestedWidth;
            REQUESTED_HEIGHT = requestedHeight;
            
            DISPLAY_WIDTH = int(REQUESTED_WIDTH / cacheData.CACHE_WIDTH) * cacheData.CACHE_WIDTH;
            DISPLAY_HEIGHT = int(REQUESTED_HEIGHT / cacheData.CACHE_HEIGHT) * cacheData.CACHE_HEIGHT;
            
            CHUNKED_WIDTH = DISPLAY_WIDTH / cacheData.CACHE_WIDTH;
            CHUNKED_HEIGHT = DISPLAY_HEIGHT / cacheData.CACHE_HEIGHT;
            
            FULL_CHUNKED_WIDTH = CHUNKED_WIDTH + 2;
            FULL_CHUNKED_HEIGHT = CHUNKED_HEIGHT + 2;
            
            FULL_CHUNKED_LENGTH = FULL_CHUNKED_WIDTH * FULL_CHUNKED_HEIGHT;
            FULL_CHUNKED_LIVE_LENGTH = FULL_CHUNKED_LENGTH - FULL_CHUNKED_WIDTH;
            
            FULL_DISPLAY_WIDTH = DISPLAY_WIDTH + cacheData.CACHE_WIDTH * 2;
            FULL_DISPLAY_HEIGHT = DISPLAY_HEIGHT + cacheData.CACHE_HEIGHT * 2;
            
            chunkRect = new Rectangle(0, 0, cacheData.CACHE_WIDTH, cacheData.CACHE_HEIGHT);

            currentStates = new Vector.<uint>(FULL_CHUNKED_LENGTH, true);
            nextStates = new Vector.<uint>(FULL_CHUNKED_LENGTH, true);
            points = new Vector.<Point>(FULL_CHUNKED_LENGTH, true);
            stateNeighbors = new Vector.<Chunk>(FULL_CHUNKED_LENGTH, true);
            var i : uint;
            
            for (i = FULL_CHUNKED_WIDTH + 1; i < FULL_CHUNKED_LIVE_LENGTH; ++i) {
                points[i] = new Point(
                    i % FULL_CHUNKED_WIDTH * cacheData.CACHE_WIDTH,
                    int(int(i) / int(FULL_CHUNKED_WIDTH)) * cacheData.CACHE_HEIGHT
                );
                
                var neighbors : Chunk = new Chunk(0, 0);
                
                upIdx = i - FULL_CHUNKED_WIDTH;
                downIdx = i + FULL_CHUNKED_WIDTH;
                
                neighbors.topLeft = upIdx - 1;
                neighbors.topRight = upIdx + 1;
                neighbors.bottomLeft = downIdx - 1;
                neighbors.bottomRight = downIdx + 1;
                
                var off : int;
                
                neighbors.top = upIdx;
                if (WRAP && neighbors.top < FULL_CHUNKED_WIDTH) {
                    off = FULL_CHUNKED_LENGTH - FULL_CHUNKED_WIDTH * 2;
                    neighbors.top += off;
                    neighbors.topLeft += off;
                    neighbors.topRight += off;
                }
                neighbors.bottom = downIdx;
                if (WRAP && neighbors.bottom > FULL_CHUNKED_LENGTH - FULL_CHUNKED_WIDTH) {
                    off = FULL_CHUNKED_WIDTH * 2 - FULL_CHUNKED_LENGTH;
                    neighbors.bottom += off;
                    neighbors.bottomLeft += off;
                    neighbors.bottomRight += off;
                }
                neighbors.left = i - 1;
                if (WRAP && (neighbors.left % FULL_CHUNKED_WIDTH) == 0) {
                    off = FULL_CHUNKED_WIDTH - 2;
                    neighbors.left += off;
                    neighbors.topLeft += off;
                    neighbors.bottomLeft += off;
                }
                neighbors.right = i + 1;
                if (WRAP && ((neighbors.right + 1) % FULL_CHUNKED_WIDTH) == 0) {
                    off = FULL_CHUNKED_WIDTH - 2;
                    neighbors.right -= off;
                    neighbors.topRight -= off;
                    neighbors.bottomRight -= off;
                }
                
                stateNeighbors[i] = neighbors;
            }
            
            currentChunksToCheck = new Vector.<Boolean>(FULL_CHUNKED_LENGTH, true);
            nextChunksToCheck = new Vector.<Boolean>(FULL_CHUNKED_LENGTH, true);

            bitmapData = new Raster(FULL_DISPLAY_WIDTH, FULL_DISPLAY_HEIGHT, true);
            
            var y : uint;
            var yo : uint;
            var x : uint;
            switch (type) {
                case 4:
                    parseRLE(CORDER_ADJUSTABLE_LINESHIP);
                    break;
                case 3:
                    parseRLE(CORDER_LINESHIP);
                    break;
                case 2:
                    var m : uint = 7 << (cacheData.FULL_CACHE_WIDTH + 1);
                    for (y = 2; y < cacheData.FULL_CACHE_HEIGHT - 1; ++y) {
                        m |= 1 << (cacheData.FULL_CACHE_WIDTH * y + 1);
                    }
                    for (y = 1; y < CHUNKED_HEIGHT - 1; y+=2) {
                        yo = FULL_CHUNKED_WIDTH * y;
                        for (x = 1; x < CHUNKED_WIDTH - 1; ++x) {
                            currentStates[x + yo] = m;
                        }
                    }
                    break;
                case 1:
                    for (y = CHUNKED_HEIGHT / 4 + 1; y < CHUNKED_HEIGHT * 3 / 4 + 1; ++y) {
                        yo = FULL_CHUNKED_WIDTH * y;
                        for (x = CHUNKED_WIDTH / 4 + 1; x < CHUNKED_WIDTH * 3 / 4 + 1; ++x) {
                            currentStates[x + yo] = cacheData.masks.inner;
                        }
                    }
                    break;
                case 0:
                default:
                    for (y = 1; y < CHUNKED_HEIGHT - 1; ++y) {
                        yo = FULL_CHUNKED_WIDTH * y;
                        for (x = 1; x < CHUNKED_WIDTH - 1; ++x) {
                            currentStates[x + yo] = cacheData.masks.inner & uint(Math.random() * uint.MAX_VALUE);
                        }
                    }
                    break;
            }
            currentChunksToCheck = new Vector.<Boolean>(FULL_CHUNKED_LENGTH, true);
            for (i = FULL_CHUNKED_WIDTH + 1; i < FULL_CHUNKED_LIVE_LENGTH; ++i) {
                if ((i % FULL_CHUNKED_WIDTH) == FULL_CHUNKED_WIDTH - 1) {
                    ++i;
                    continue;
                }
                currentChunksToCheck[i] = true;
            }
        }
        
        public function drawChunked() : void {
            bitmapData.lock();
            for (var i : uint = FULL_CHUNKED_WIDTH + 1; i < FULL_CHUNKED_LIVE_LENGTH; ++i) {
                if (
                    //checks for the last index in a row, which is always dead
                    (i % FULL_CHUNKED_WIDTH) == FULL_CHUNKED_WIDTH - 1
                ) {
                    //skips the first index in a row as well, which is also always dead
                    ++i;
                    continue;
                }
                if (cacheData.states[currentStates[i]] == null) {
                    cacheData.generator.calculateState(currentStates[i]);
                }
                bitmapData.copyPixels(cacheData.states[currentStates[i]].bitmapData, chunkRect, points[i]);
            }
            bitmapData.unlock();
        }
        
        public function drawChunkedAndNext() : void {
            bitmapData.lock();
            nextChunksToCheck = new Vector.<Boolean>(FULL_CHUNKED_LENGTH, true);
            for (var i : uint = FULL_CHUNKED_WIDTH + 1; i < FULL_CHUNKED_LIVE_LENGTH; ++i) {
                /*
                if (
                    //checks for the last index in a row, which is always dead
                    (i % FULL_CHUNKED_WIDTH) == FULL_CHUNKED_WIDTH - 1
                ) {
                    //skips the first index in a row as well, which is also always dead
                    ++i;
                    continue;
                }
                */
                if (!currentChunksToCheck[i]) {
                    continue;
                }
                var neighbors : Chunk = stateNeighbors[i];
                nextStates[i] = cacheData.getNextState(
                    currentStates[i]
                    | cacheData.states[currentStates[neighbors.top]].bottom
                    | cacheData.states[currentStates[neighbors.bottom]].top
                    | cacheData.states[currentStates[neighbors.left]].right
                    | cacheData.states[currentStates[neighbors.right]].left
                    
                    | cacheData.states[currentStates[neighbors.topLeft]].bottomRight
                    | cacheData.states[currentStates[neighbors.topRight]].bottomLeft
                    | cacheData.states[currentStates[neighbors.bottomLeft]].topRight
                    | cacheData.states[currentStates[neighbors.bottomRight]].topLeft
                );
                if (currentStates[i] ^ nextStates[i]) {
                    bitmapData.copyPixels(cacheData.states[nextStates[i]].bitmapData, chunkRect, points[i]);
                    
                    currentState = cacheData.states[currentStates[i]];
                    nextState = cacheData.states[nextStates[i]];
                    nextChunksToCheck[i] = true;

                    if (currentState.bottom ^ nextState.bottom) {
                        nextChunksToCheck[neighbors.bottom] = true;
                    }
                    if (currentState.top ^ nextState.top) {
                        nextChunksToCheck[neighbors.top] = true;
                    }
                    if (currentState.left ^ nextState.left) {
                        nextChunksToCheck[neighbors.left] = true;
                    }
                    if (currentState.right ^ nextState.right) {
                        nextChunksToCheck[neighbors.right] = true;
                    }
                    if (currentState.bottomLeft ^ nextState.bottomLeft) {
                        nextChunksToCheck[neighbors.bottomLeft] = true;
                    }
                    if (currentState.bottomRight ^ nextState.bottomRight) {
                        nextChunksToCheck[neighbors.bottomRight] = true;
                    }
                    if (currentState.topLeft ^ nextState.topLeft) {
                        nextChunksToCheck[neighbors.topLeft] = true;
                    }
                    if (currentState.topRight ^ nextState.topRight) {
                        nextChunksToCheck[neighbors.topRight] = true;
                    }
                }
            }
            bitmapData.unlock();

            var tmpStates : Vector.<uint> = currentStates;
            currentStates = nextStates;
            nextStates = tmpStates;
            
            var tempChunksToCheck : Vector.<Boolean> = currentChunksToCheck;
            currentChunksToCheck = nextChunksToCheck;
            nextChunksToCheck = tempChunksToCheck;
        }
        
        public function setPixel(x : uint, y : uint) : void {
            var idx : uint = int(x / cacheData.CACHE_WIDTH) + 1
                + int(y / cacheData.CACHE_HEIGHT + 1) * FULL_CHUNKED_WIDTH;
            var xxx : uint = x % cacheData.CACHE_WIDTH;
            var yyy : uint = y % cacheData.CACHE_HEIGHT;
            currentStates[idx] |= 0x1 << (xxx + 1 + (yyy + 1) * cacheData.FULL_CACHE_WIDTH);
        }
        
        public function parseRLE(str : String) : void {
            str = str.replace(/(\r\n|\n|\r)/g, "\n");
            var i : uint = 0;
            var line : String;
            var lines : Vector.<String> = Vector.<String>(str.split("\n"));
            var lines2 : Vector.<String> = new Vector.<String>();
            for each (line in lines) {
                line = line.replace(/\s+/g, "");
                if (line.length > 0 && line.charAt(0) != "#") {
                    lines2.push(line);
                }
            }
            lines = lines2;
            line = lines.shift().replace(/\s*/g, "");
            var parts : Vector.<String> = Vector.<String>(line.split(","));
            var width : uint;
            var height : uint;
            for each (var part : String in parts) {
                var bits : Vector.<String> = Vector.<String>(part.split("="));
                if (bits[0] == "x") {
                    width = uint(bits[1]);
                } else {
                    height = uint(bits[1]);
                }
            }
            str = lines.join("").replace(/\s*/g, "");
            var numStr : String = "";
            var num : uint = 1;
            for (i = FULL_CHUNKED_WIDTH + 1; i < FULL_CHUNKED_LIVE_LENGTH; ++i) {
                if ((i % FULL_CHUNKED_WIDTH) == FULL_CHUNKED_WIDTH - 1) {
                    ++i;
                    continue;
                }
                currentStates[i] = nextStates[i] = 0x0;
                nextChunksToCheck[i] = currentChunksToCheck[i] = true;
            }
            var x : uint = 0;
            var y : uint = 0;
            for (i = 0; i < str.length; ++i) {
                var char : String = str.charAt(i);
                if (char.charCodeAt() >= '0'.charCodeAt() && char.charCodeAt() <= '9'.charCodeAt()) {
                    numStr += char;
                } else {
                    if (numStr.length > 0) {
                        num = uint(numStr);
                        numStr = "";
                    } else {
                        num = 1;
                    }
                    switch (char) {
                        case "b":
                            x += num;
                            break;
                        case "$":
                            y += num;
                            x = 0;
                            break;
                        case "o":
                            for (var j : uint = 0; j < num; ++j) {
                                var xx : int = x + int(CHUNKED_WIDTH / 2) * cacheData.CACHE_WIDTH - int(width / 2);
                                var yy : int = y + int(CHUNKED_HEIGHT / 2) * cacheData.CACHE_HEIGHT - int(height / 2);
                                if (xx >= (CHUNKED_WIDTH * cacheData.CACHE_WIDTH)) {
                                    xx %= (CHUNKED_WIDTH * cacheData.CACHE_WIDTH);
                                }
                                while (xx < 0) {
                                    xx += CHUNKED_WIDTH * cacheData.CACHE_WIDTH;
                                }
                                if (yy >= (CHUNKED_HEIGHT * cacheData.CACHE_HEIGHT)) {
                                    yy %= (CHUNKED_HEIGHT * cacheData.CACHE_HEIGHT);
                                }
                                while (yy < 0) {
                                    yy += CHUNKED_HEIGHT * cacheData.CACHE_HEIGHT;
                                }
                                setPixel(xx, yy);
                                ++x;
                            }
                            break;
                        case "!":
                            return;
                        default:
                            throw new Error("What is a '" + char + "'?");
                            break;
                    }
                }
            }
        }
    }
}
