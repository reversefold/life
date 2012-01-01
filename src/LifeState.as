package {
    import com.foxaweb.utils.Raster;
    
    import flash.display.BitmapData;
    import flash.geom.Point;
    import flash.geom.Rectangle;

    public class LifeState {
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
            
            for (var i : uint = FULL_CHUNKED_WIDTH + 1; i < FULL_CHUNKED_LIVE_LENGTH; ++i) {
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
                if (neighbors.top < FULL_CHUNKED_WIDTH) {
                    off = FULL_CHUNKED_LENGTH - FULL_CHUNKED_WIDTH * 2;
                    neighbors.top += off;
                    neighbors.topLeft += off;
                    neighbors.topRight += off;
                }
                neighbors.bottom = downIdx;
                if (neighbors.bottom > FULL_CHUNKED_LENGTH - FULL_CHUNKED_WIDTH) {
                    off = FULL_CHUNKED_WIDTH * 2 - FULL_CHUNKED_LENGTH;
                    neighbors.bottom += off;
                    neighbors.bottomLeft += off;
                    neighbors.bottomRight += off;
                }
                neighbors.left = i - 1;
                if (neighbors.left % FULL_CHUNKED_WIDTH == 0) {
                    off = FULL_CHUNKED_WIDTH - 2;
                    neighbors.left += off;
                    neighbors.topLeft += off;
                    neighbors.topRight += off;
                }
                neighbors.right = i + 1;
                if ((neighbors.right + 1) % FULL_CHUNKED_WIDTH == 0) {
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
                case 2:
                    for (y = 1; y < CHUNKED_HEIGHT - 1; ++y) {
                        yo = FULL_CHUNKED_WIDTH * y;
                        for (x = 1; x < CHUNKED_WIDTH - 1; ++x) {
                            currentStates[x + yo] = cacheData.masks.inner & uint(Math.random() * uint.MAX_VALUE);
                        }
                    }
                    break;
                case 1:
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
                case 0:
                default:
                    for (y = CHUNKED_HEIGHT / 4 + 1; y < CHUNKED_HEIGHT * 3 / 4 + 1; ++y) {
                        yo = FULL_CHUNKED_WIDTH * y;
                        for (x = CHUNKED_WIDTH / 4 + 1; x < CHUNKED_WIDTH * 3 / 4 + 1; ++x) {
                            currentStates[x + yo] = cacheData.masks.inner;
                        }
                    }
                    break;
            }
            currentChunksToCheck = new Vector.<Boolean>(FULL_CHUNKED_LENGTH, true);
            for (var i : uint = FULL_CHUNKED_WIDTH + 1; i < FULL_CHUNKED_LIVE_LENGTH; ++i) {
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
                /*
                //chunkRect.x
                point.x
                    = i % FULL_CHUNKED_WIDTH * cacheData.CACHE_WIDTH;
                //chunkRect.y
                point.y
                    = int(int(i) / int(FULL_CHUNKED_WIDTH)) * cacheData.CACHE_HEIGHT;
                */
                //bitmapData.setVector(chunkRect, states[nextStates[i]].vector);
                if (cacheData.states[currentStates[i]] == null) {
                    cacheData.generator.calculateState(currentStates[i]);
                }
                bitmapData.copyPixels(cacheData.states[currentStates[i]].bitmapData, chunkRect, points[i]);

                //cacheData.drawState(currentStates[i], bitmapData, chunkRect, points[i]);
                //bitmapData.copyPixels(cacheData.states[currentStates[i]].bitmapData, chunkRect, point);
            }
            bitmapData.unlock();
        }
        
        public function drawChunkedAndNext() : void {
            /*
            r.x = 0;
            r.y = 0;
            */
            bitmapData.lock();
            nextChunksToCheck = new Vector.<Boolean>(FULL_CHUNKED_LENGTH, true);
            for (var i : uint = FULL_CHUNKED_WIDTH + 1; i < FULL_CHUNKED_LIVE_LENGTH; ++i) {
                if (
                    //checks for the last index in a row, which is always dead
                    (i % FULL_CHUNKED_WIDTH) == FULL_CHUNKED_WIDTH - 1
                ) {
                    //skips the first index in a row as well, which is also always deadf
                    ++i;
                    continue;
                }
                if (!currentChunksToCheck[i]) {
                    continue;
                }
                
                /*
                upIdx = i - FULL_CHUNKED_WIDTH;
                downIdx = i + FULL_CHUNKED_WIDTH;
                nextStates[i] = cacheData.getNextState(
                    currentStates[i]
                    | cacheData.states[currentStates[upIdx]].bottom
                    | cacheData.states[currentStates[downIdx]].top
                    | cacheData.states[currentStates[i - 1]].right
                    | cacheData.states[currentStates[i + 1]].left
                    
                    | cacheData.states[currentStates[upIdx - 1]].bottomRight
                    | cacheData.states[currentStates[upIdx + 1]].bottomLeft
                    | cacheData.states[currentStates[downIdx - 1]].topRight
                    | cacheData.states[currentStates[downIdx + 1]].topLeft
                );
                */
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
                    /*
                    //chunkRect.x
                    point.x
                        = i % FULL_CHUNKED_WIDTH * cacheData.CACHE_WIDTH;
                    //chunkRect.y
                    point.y
                        = int(int(i) / int(FULL_CHUNKED_WIDTH)) * cacheData.CACHE_HEIGHT;
                    */
                    //bitmapData.setVector(chunkRect, states[nextStates[i]].vector);
                    
                    bitmapData.copyPixels(cacheData.states[nextStates[i]].bitmapData, chunkRect, points[i]);
                    //cacheData.drawState(nextStates[i], bitmapData, chunkRect, points[i]);
                    
                    //bitmapData.copyPixels(cacheData.states[nextStates[i]].bitmapData, chunkRect, point);
                    
                    currentState = cacheData.states[currentStates[i]];
                    nextState = cacheData.states[nextStates[i]];
                    nextChunksToCheck[i] = true;
                    /*
                    if (currentState.bottom ^ nextState.bottom) {
                        nextChunksToCheck[downIdx] = true;
                    }
                    if (currentState.top ^ nextState.top) {
                        nextChunksToCheck[upIdx] = true;
                    }
                    if (currentState.left ^ nextState.left) {
                        nextChunksToCheck[i - 1] = true;
                    }
                    if (currentState.right ^ nextState.right) {
                        nextChunksToCheck[i + 1] = true;
                    }
                    if (currentState.bottomLeft ^ nextState.bottomLeft) {
                        nextChunksToCheck[downIdx - 1] = true;
                    }
                    if (currentState.bottomRight ^ nextState.bottomRight) {
                        nextChunksToCheck[downIdx + 1] = true;
                    }
                    if (currentState.topLeft ^ nextState.topLeft) {
                        nextChunksToCheck[upIdx - 1] = true;
                    }
                    if (currentState.topRight ^ nextState.topRight) {
                        nextChunksToCheck[upIdx + 1] = true;
                    }
                    */
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
                /*
                r.x += CACHE_WIDTH;
                r.x %= W;
                if (r.x == 0) {
                    r.y += CACHE_HEIGHT;
                }
                */
            }
            bitmapData.unlock();
            /** /
            graphics.clear();
            graphics.beginBitmapFill(bd);
            graphics.drawRect(0, 0, W, H);
            graphics.endFill();
            /**/
            var tmpStates : Vector.<uint> = currentStates;
            currentStates = nextStates;
            nextStates = tmpStates;
            
            var tempChunksToCheck : Vector.<Boolean> = currentChunksToCheck;
            currentChunksToCheck = nextChunksToCheck;
            nextChunksToCheck = tempChunksToCheck;
        }
    }
}
