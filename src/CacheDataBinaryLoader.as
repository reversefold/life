package {
    import flash.utils.ByteArray;

    public class CacheDataBinaryLoader {
        private var binaryData : ByteArray;
        private var _cacheLoadIdx : uint = 0;
        private var _stateLoadIdx : uint = 0;
        private var cacheData : CacheData;
        
        
        public function get cacheLoadIdx() : uint {
            return _cacheLoadIdx;
        }
        public function get cacheLoadMax() : uint {
            return cacheData.cache.length;
        }
        public function get stateLoadIdx() : uint {
            return _stateLoadIdx;
        }
        public function get stateLoadMax() : uint {
            return cacheData.states.length;
        }

        public function CacheDataBinaryLoader(binaryData : ByteArray) {
            this.binaryData = binaryData;

            binaryData.uncompress();
            var cacheWidth : uint = binaryData.readUnsignedInt();//CACHE_WIDTH
            var cacheHeight : uint = binaryData.readUnsignedInt();//CACHE_HEIGHT
            cacheData = new CacheData(cacheWidth, cacheHeight);
            cacheData.cache = new Vector.<uint>(binaryData.readUnsignedInt(), true);
        }
        
        public function loadNext() : CacheData {
            var i : uint;
            if (_cacheLoadIdx < cacheData.cache.length) {
                for (i = 0; i < 120000 && _cacheLoadIdx < cacheData.cache.length; ++i) {
                    cacheData.cache[_cacheLoadIdx] = binaryData.readUnsignedInt();
                    ++_cacheLoadIdx;
                }
            } else {
                if (_stateLoadIdx == 0) {
                    cacheData.states = new Vector.<Chunk>(binaryData.readUnsignedInt(), true);
                }
                if (_stateLoadIdx < cacheData.states.length) {
                    for (i = 0; i < 120000 && _stateLoadIdx < cacheData.states.length; ++i) {
                        if (binaryData.readBoolean()) {
                            cacheData.states[binaryData.readUnsignedInt()] = Chunk.read(binaryData, cacheData.CACHE_WIDTH, cacheData.CACHE_HEIGHT, cacheData);
                        }
                        ++_stateLoadIdx;
                    }
                } else {
                    return cacheData;
                }
            }
            return null;
        }
        
        public static function getBinaryData(cacheData : CacheData) : ByteArray {
            var ba : ByteArray = new ByteArray();
            ba.writeUnsignedInt(cacheData.CACHE_WIDTH);
            ba.writeUnsignedInt(cacheData.CACHE_HEIGHT);
            ba.writeUnsignedInt(cacheData.cache.length);
            for (var i : uint = 0; i < cacheData.cache.length; ++i) {
                ba.writeUnsignedInt(cacheData.cache[i]);
            }
            ba.writeUnsignedInt(cacheData.states.length);
            for (i = 0; i < cacheData.states.length; ++i) {
                if (cacheData.states[i] == null) {
                    ba.writeBoolean(false);
                } else {
                    ba.writeBoolean(true);
                    ba.writeUnsignedInt(i);
                    cacheData.states[i].write(ba);
                }
            }
            ba.compress();
            return ba;
        }
    }
}
