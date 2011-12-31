package {
    import flash.display.BitmapData;
    import flash.geom.Point;
    import flash.geom.Rectangle;
    import flash.net.FileReference;
    import flash.utils.ByteArray;
    import flash.utils.describeType;
    
    import mx.utils.StringUtil;

    public class CacheData {
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

        public var generator : CacheDataGenerator;
        
        public var numGenerated : uint = 0;
        public var numHits : uint = 0;

        public function CacheData(inWidth : uint, inHeight : uint) {
            CACHE_WIDTH = inWidth;
            CACHE_HEIGHT = inHeight;
            FULL_CACHE_WIDTH = CACHE_WIDTH + 2;
            FULL_CACHE_HEIGHT = CACHE_HEIGHT + 2;
            CACHE_VECTOR_LENGTH = FULL_CACHE_WIDTH * FULL_CACHE_HEIGHT;
            INNER_CACHE_VECTOR_LENGTH = CACHE_WIDTH * CACHE_HEIGHT;
            NUM_CACHE_PERMUTATIONS = Math.pow(2, CACHE_VECTOR_LENGTH);

            cache = new Vector.<uint>(NUM_CACHE_PERMUTATIONS, true);
            for (var i : uint = 0; i < cache.length; ++i) {
                cache[i] = uint.MAX_VALUE;
            }
            states = new Vector.<Chunk>(Math.pow(2, CACHE_VECTOR_LENGTH - FULL_CACHE_WIDTH - 1), true);
            
            masks = new Chunk(CACHE_WIDTH, CACHE_HEIGHT);
            maskOffsets = new Chunk(CACHE_WIDTH, CACHE_HEIGHT);
            maskNeighborOffsets = new Chunk(CACHE_WIDTH, CACHE_HEIGHT);
            maskNeighborOffsetNegative = new Chunk(CACHE_WIDTH, CACHE_HEIGHT);

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
            
            generator = new CacheDataGenerator(this);
        }
        
        public function getNextState(state : uint) : uint {
            if (cache[state] == uint.MAX_VALUE) {
                ++numGenerated;
                generator.calculateNextState(state);
            } else {
                ++numHits;
            }
            return cache[state];
        }
        
        public function drawState(state : uint, bitmapData : BitmapData, chunkRect : Rectangle, point : Point) : void {
            if (states[state] == null) {
                ++numGenerated;
                generator.calculateState(state);
            } else {
                ++numHits;
            }
            bitmapData.copyPixels(states[state].bitmapData, chunkRect, point);
        }
    }
}
