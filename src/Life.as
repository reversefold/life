package {
	import com.foxaweb.utils.Raster;
	import com.reversefold.json.JSON;
	import com.reversefold.json.JSONDecoderAsync;
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.events.ProgressEvent;
	import flash.filters.BitmapFilter;
	import flash.filters.ColorMatrixFilter;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.net.FileFilter;
	import flash.net.FileReference;
	import flash.net.SharedObject;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.sampler.NewObjectSample;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;
	import flash.utils.describeType;
	import flash.utils.getTimer;
	
	import mx.utils.StringUtil;
	
	[SWF(frameRate="1000")]//, width="1000", height="700"
	[Frame(factoryClass="Preloader")]
	public class Life extends Sprite {
        public var cacheData : CacheData;
        public var cacheDataGenerator : CacheDataGenerator;
        public var cacheDataBinaryLoader : CacheDataBinaryLoader;
        public var lifeState : LifeState;
        
        /**/
		public static const CACHE_WIDTH : uint = 3;
		public static const CACHE_HEIGHT : uint = 3;
		/**/
        
		//[Embed(source="assets/data/3x3.bin", mimeType="application/octet-stream")]
		private var d : Class;
		
        public static const ON_DEMAND : Boolean = true;
		public static const LOAD : Boolean = false;
		public static const LOAD_JSON : Boolean = false;
		
		public static const CACHE_COMPUTATIONS_PER_FRAME : uint = 1000;
		
		public static const ALIVE_PIXEL : uint = 0xFF000000;
		public static const DEAD_PIXEL : uint = 0xFFFFFFFF;
		
		public static const PROGRESS_Y : uint = 300;
		
		public static var fpsBitmapData : BitmapData = new BitmapData(100, 80, true);
		public static var fpsBitmap : Bitmap = new Bitmap(fpsBitmapData);

		public static var sizeBitmapData : BitmapData = new BitmapData(100, 20, true);
		public static var sizeBitmap : Bitmap = new Bitmap(sizeBitmapData);
		
		public static var preBitmapData : BitmapData;
		public static var preBitmap : Bitmap;
		public static var postBitmapData : BitmapData;
		public static var postBitmap : Bitmap;
		
		public static var dataString : String = null;
		public static var fileRef : FileReference;
		
		public static var jsonDecoder : JSONDecoderAsync = null;
		public static var loadedDataObject : Object = null;
		
		public static var loader : URLLoader = null;
		public static var loaded : Boolean = false;
		public static var fileProgress : uint = 0;
		public static var fileSize : uint = 1;
		
		public static var jsonStartTime : * = null;
		public static var loadStartTime : * = null;
		public static var generateStartTime : * = null;
		
		public static var i : uint;
		
		public static var loadFile : FileReference;
		
		public static var enterFrameListener : Function;
		
		public static var type : uint = 1;
		
		public static var paused : Boolean = false;

		public static var bitmap : Bitmap;
		//public static var bitmapData2 : BitmapData;

		private static var binaryData : ByteArray;
		private static var lso : SharedObject;


		public function Life() {
			addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
		}

		private function onKeyUp(e : KeyboardEvent) : void {
			//trace("Pressed " + e.charCode);
            var char : String = String.fromCharCode(e.charCode);
			switch (char) {
			    case 'p':
    				invertPause();
    				break;
			    case 'f':
    				FPSCounter.reset();
    				break;
    			case 'l':
    				loadFile = new FileReference();
    				loadFile.addEventListener(Event.SELECT, onLoadFileSelect);
    				loadFile.browse([new FileFilter("RLE File", "rle")]);
    				removeEventListener(Event.ENTER_FRAME, enterFrameListener);
    				enterFrameListener = null;
    				break;
    			case 'n':
    				drawChunkedAndNext();
    				break;
    			/*
    			case 'n':
    				removeEventListener(Event.ENTER_FRAME, enterFrameListener);
    				addEventListener(Event.ENTER_FRAME, renderNaive);
    				enterFrameListener = renderNaive;
                    break;
    			case 'c':
    				removeEventListener(Event.ENTER_FRAME, enterFrameListener);
    				addEventListener(Event.ENTER_FRAME, drawChunkedAndNext);
    				enterFrameListener = drawChunkedAndNext;
                    break;
    			*/
                case 's':
                    var fn : String = cacheData.CACHE_WIDTH + "x" + cacheData.CACHE_HEIGHT
                        //+ ".json";
                        + ".bin";
                    var ba : ByteArray = CacheDataBinaryLoader.getBinaryData(cacheData);
                    var fileRef : FileReference = new FileReference();
                    fileRef.save(ba, fn);
                    break;
                default:
                    var types : Vector.<String> = Vector.<String>([
                        'r',
                        '1',
                        '2',
                        '3',
                        '4'
                    ]);
                    if (types.indexOf(char) == -1) {
                        break;
                    }
                    type = types.indexOf(char);//(type + 1) % 3;
                    removeEventListener(Event.ENTER_FRAME, enterFrameListener);
                    enterFrameListener = resetListener;
                    addEventListener(Event.ENTER_FRAME, resetListener);
                    break;
            }
		}

		private function onLoadFileSelect(e : Event) : void {
			loadFile.addEventListener(ProgressEvent.PROGRESS, onProgress);
			loadFile.addEventListener(Event.COMPLETE, onLoadRLEComplete);
			loadFile.load();
		}

        private function onLoadRLEComplete(e : Event) : void {
            lifeState.parseRLE(loadFile.data.toString());
            
            addEventListener(Event.ENTER_FRAME, drawChunkedAndNext);
            enterFrameListener = drawChunkedAndNext;
            lifeState.drawChunked();
            
            pause(true);
        }
        
		private function pause(resetFPS : Boolean = false) : void {
			if (resetFPS) {
				FPSCounter.reset();
			}
			removeEventListener(Event.ENTER_FRAME, enterFrameListener);
			removeEventListener(Event.ENTER_FRAME, drawFPS);
			paused = true;
		}
		
		private function unpause() : void {
			addEventListener(Event.ENTER_FRAME, enterFrameListener);
			addEventListener(Event.ENTER_FRAME, drawFPS);
			paused = false;
		}
		
		private function invertPause(resetFPS : Boolean = false) : void {
			if (paused) {
				unpause();
			} else {
				pause(resetFPS);
			}
		}

		
		private function reset(e : Event = null) : void {
            doReset();
            
            if (enterFrameListener == drawChunkedAndNext) {
                removeEventListener(Event.ENTER_FRAME, enterFrameListener);
                addEventListener(Event.ENTER_FRAME, resetListener);
                enterFrameListener = resetListener;
            } else {
                lifeState.reset(stage.stageWidth, stage.stageHeight, type);
                
                if (bitmap != null && bitmap.parent != null) {
                    bitmap.parent.removeChild(bitmap);
                }
                bitmap = new Bitmap(lifeState.bitmapData);
                
                bitmap.x = -CACHE_WIDTH;
                bitmap.y = -CACHE_HEIGHT;
                addChild(bitmap);
            }
        }
        
        private function doReset() : void {
            lifeState.reset(stage.stageWidth, stage.stageHeight, type);
            
            if (bitmap != null && bitmap.parent != null) {
                bitmap.parent.removeChild(bitmap);
            }
            bitmap = new Bitmap(lifeState.bitmapData);
            
            bitmap.x = -CACHE_WIDTH;
            bitmap.y = -CACHE_HEIGHT;
            addChild(bitmap);

			//bitmapData2 = new BitmapData(FULL_DISPLAY_WIDTH, FULL_DISPLAY_HEIGHT, true);

			if (fpsBitmap != null && fpsBitmap.parent != null) {
				fpsBitmap.parent.removeChild(fpsBitmap);
			}
			fpsBitmap.x = lifeState.DISPLAY_WIDTH - fpsBitmap.width;
			addChild(fpsBitmap);

			if (sizeBitmap != null && sizeBitmap.parent != null) {
				sizeBitmap.parent.removeChild(sizeBitmap);
			}
			sizeBitmap.x = lifeState.DISPLAY_WIDTH - sizeBitmap.width;
			sizeBitmap.y = fpsBitmap.height;
			addChild(sizeBitmap);

            drawSize();
        }
		
		private function onAddedToStage(e : Event) : void {
			stage.align = StageAlign.TOP_LEFT;
			stage.scaleMode = StageScaleMode.NO_SCALE;

			graphics.clear();
			
			stage.addEventListener(KeyboardEvent.KEY_UP, onKeyUp);
			stage.addEventListener(Event.RESIZE, reset);

            cacheData = new CacheData(CACHE_WIDTH, CACHE_HEIGHT);
            lifeState = new LifeState(cacheData);

            reset();

            preBitmapData = new BitmapData(cacheData.FULL_CACHE_WIDTH, cacheData.FULL_CACHE_HEIGHT);
            preBitmap = new Bitmap(preBitmapData);
            postBitmapData = new BitmapData(cacheData.FULL_CACHE_WIDTH, cacheData.FULL_CACHE_HEIGHT);
            postBitmap = new Bitmap(postBitmapData);

			if (LOAD) {
                /*
				if (LOAD_JSON) {
					addEventListener(Event.ENTER_FRAME, loadListener);
					enterFrameListener = loadListener;
				} else {
                */
					addEventListener(Event.ENTER_FRAME, loadBinaryListener);
					enterFrameListener = loadBinaryListener;
				//}
            } else if (ON_DEMAND) {
                addEventListener(Event.ENTER_FRAME, resetListener);
                enterFrameListener = resetListener;
			} else {
                cacheDataGenerator = cacheData.generator;
				addEventListener(Event.ENTER_FRAME, generateListener);
				enterFrameListener = generateListener;
			}
			addEventListener(Event.ENTER_FRAME, drawFPS);
		}

		private function onLoadComplete(e : Event) : void {
			trace("file loaded");
			jsonDecoder = new JSONDecoderAsync(e.target.data, true);
			jsonStartTime = getTimer();
			drawProgressBar(fileProgress, fileSize, PROGRESS_Y);
		}
				
		private function onIoError(e : Event) : void {
			trace(e);
		}
		
		private function onProgress(e : ProgressEvent) : void {
			fileProgress = e.bytesLoaded;
			fileSize = e.bytesTotal;
		}
		
		private function onBinaryLoadComplete(e : Event) : void {
			trace("file loaded");
			binaryData = e.target.data;
			lso = SharedObject.getLocal(lifeState.CHUNKED_WIDTH + "x" + lifeState.CHUNKED_HEIGHT, "/");
			lso.data.bin = binaryData;
			lso.flush();
			uncompress = true;
			
			//jsonDecoder = new JSONDecoderAsync(e.target.data, true);
			//jsonStartTime = getTimer();
			drawProgressBar(fileProgress, fileSize, PROGRESS_Y);
		}

		private var uncompress : Boolean = false;
		private function loadBinaryListener(e : Event) : void {
			//bitmapData2.fillRect(bitmapData2.rect, 0x0);
            lifeState.bitmapData.fillRect(lifeState.bitmapData.rect, 0);
			var u : URLRequest;
			if (loader == null && lso == null) {
				loadStartTime = getTimer();

				lso = SharedObject.getLocal(lifeState.CHUNKED_WIDTH + "x" + lifeState.CHUNKED_HEIGHT, "/");
				if (d != null) {
					trace("using embedded data");
					binaryData = new d();
					uncompress = true;
					fileProgress = fileSize = binaryData.bytesAvailable;
				} else if (lso.data.bin != null) {
					trace("using locally stored data");
					binaryData = lso.data.bin;
					fileProgress = fileSize = binaryData.bytesAvailable;
					uncompress = true;
				} else {
					trace("loading file");
					u = new URLRequest("assets/data/" + CACHE_WIDTH + "x" + CACHE_HEIGHT + ".bin");
					loader = new URLLoader(u);
					loader.dataFormat = URLLoaderDataFormat.BINARY;
					loader.addEventListener(Event.COMPLETE, onBinaryLoadComplete);
					loader.addEventListener(IOErrorEvent.IO_ERROR, onIoError);
					loader.addEventListener(ProgressEvent.PROGRESS, onProgress);
				}
			} else if (binaryData != null && uncompress) {
				try {
                    cacheDataBinaryLoader = new CacheDataBinaryLoader(binaryData);
					uncompress = false;
				} catch (e : Error) {
					trace("loading file");
					u = new URLRequest("assets/data/" + CACHE_WIDTH + "x" + CACHE_HEIGHT + ".bin");
					loader = new URLLoader(u);
					loader.dataFormat = URLLoaderDataFormat.BINARY;
					loader.addEventListener(Event.COMPLETE, onBinaryLoadComplete);
					loader.addEventListener(IOErrorEvent.IO_ERROR, onIoError);
					loader.addEventListener(ProgressEvent.PROGRESS, onProgress);
				}
			} else if (binaryData != null) {
				try {
                    cacheData = cacheDataBinaryLoader.loadNext();
                    loaded = (cacheData != null)
				} catch (e : Error) {
					if (lso != null) {
						lso.data.bin = null;
						lso.flush();
						lso = null;
						loader = null;
						binaryData = null;
					}
				}
			}
			
			drawProgressBar(fileProgress, fileSize, PROGRESS_Y);
            if (cacheDataBinaryLoader != null) {
			    drawProgressBar(cacheDataBinaryLoader.cacheLoadIdx, cacheDataBinaryLoader.cacheLoadMax, PROGRESS_Y + 22);
			    drawProgressBar(cacheDataBinaryLoader.stateLoadIdx, cacheDataBinaryLoader.stateLoadMax, PROGRESS_Y + 44);
            }
			if (loaded) {
				trace("Loading time: " + ((getTimer() - loadStartTime) / 1000).toFixed(2) + "s");

                lifeState = new LifeState(cacheData);
                doReset();

				cacheDataBinaryLoader = null;
                
				removeEventListener(Event.ENTER_FRAME, enterFrameListener);
				addEventListener(Event.ENTER_FRAME, resetListener);
				enterFrameListener = resetListener;
			}
		}
		/*
		private function loadListener(e : Event) : void {
			//bitmapData2.fillRect(bitmapData2.rect, 0x0);
			bitmapData.fillRect(bitmapData.rect, 0);
			if (loader == null) {
				loadStartTime = getTimer();
				trace("loading file");
				var u : URLRequest = new URLRequest("../assets/data/" + CACHE_WIDTH + "x" + CACHE_HEIGHT + ".json");
				loader = new URLLoader(u);
				loader.addEventListener(Event.COMPLETE, onLoadComplete);
				loader.addEventListener(IOErrorEvent.IO_ERROR, onIoError);
				loader.addEventListener(ProgressEvent.PROGRESS, onProgress);
			} else if (jsonDecoder != null) {
				if (loadedDataObject == null && !jsonDecoder.done) {
					//trace("decoding JSON " + Number(d.tokenizer.loc * 100 / d.tokenizer.jsonString.length).toFixed(2) + "% " + d.tokenizer.loc + "/" + d.tokenizer.jsonString.length);
					for (i = 0; i < 150000; ++i) {
						if (jsonDecoder.loop()) {
							trace(((getTimer() - jsonStartTime) / 1000).toFixed(4) + "s parsing JSON");
							loadedDataObject = jsonDecoder.getValue();
							break;
						}
					}
				} else if (cacheLoadIdx < cache.length) {
					//trace("loading cache " + Number(cacheLoadIdx * 100 / cache.length).toFixed(2) + "% " + cacheLoadIdx + "/" + cache.length);
					cacheLoadIdx = cache.length;
					cache = Vector.<uint>(loadedDataObject.cache);
					/*
					for (i = 0; i < 60000 && cacheLoadIdx < cache.length; ++i) {
					cache[cacheLoadIdx] = loadedDataObject.cache[cacheLoadIdx];
					++cacheLoadIdx;
					}
					* /
				} else if (stateLoadIdx < states.length) {
					//trace("loading state " + Number(stateLoadIdx * 100 / states.length).toFixed(2) + "% " + stateLoadIdx + "/" + states.length);
					for (i = 0; i < 60000 && stateLoadIdx < states.length; ++i) {
						var ch : Chunk;
						if (loadedDataObject.states[stateLoadIdx] == null) {
							ch = null;
						} else {
							ch = new Chunk(CACHE_WIDTH, CACHE_HEIGHT, loadedDataObject.states[stateLoadIdx]);
						}
						states[stateLoadIdx] = ch;
						++stateLoadIdx;
					}
					loaded = stateLoadIdx == states.length;
				}
			}
			
			drawProgressBar(fileProgress, fileSize, PROGRESS_Y);
			drawProgressBar(jsonDecoder != null ? jsonDecoder.tokenizer.loc : 0, jsonDecoder != null ? jsonDecoder.tokenizer.jsonString.length : 1, PROGRESS_Y + 22);
			drawProgressBar(cacheLoadIdx, cache.length, PROGRESS_Y + 44);
			drawProgressBar(stateLoadIdx, states.length, PROGRESS_Y + 66);
			/*
			graphics.beginBitmapFill(fpsbd);
			graphics.drawRect(W - fpsbd.width, 0, fpsbd.width, fpsbd.height);
			graphics.endFill();
			* /
			if (loaded) {
				trace("Loading time: " + ((getTimer() - loadStartTime) / 1000).toFixed(2) + "s");
				
				removeEventListener(Event.ENTER_FRAME, enterFrameListener);
				addEventListener(Event.ENTER_FRAME, resetListener);
				enterFrameListener = resetListener;
			}
		}
		*/
		private function resetListener(e : Event) : void {
			if (preBitmap.parent != null) {
				preBitmap.parent.removeChild(preBitmap);
				postBitmap.parent.removeChild(postBitmap);
			}
			trace("initing chunks");
            doReset();

            lifeState.bitmapData.fillRect(lifeState.bitmapData.rect, 0);
            graphics.clear();
            jsonDecoder = null;

			lifeState.drawChunked();
			
			removeEventListener(Event.ENTER_FRAME, enterFrameListener);
			if (!paused) {
				addEventListener(Event.ENTER_FRAME, drawChunkedAndNext);
			}
			enterFrameListener = drawChunkedAndNext;
		}

        /*
		private function renderNaive(e : Event) : void {
			nextFrame();
			draw(lifeState.currentStates, lifeState.bitmapData.rect);
		}
		*/
        
		private function generateListener(e : Event) : void {
			if (preBitmap.parent == null) {
				generateStartTime = getTimer();
				preBitmap.x = 10;
				postBitmap.x = 40 + cacheData.FULL_CACHE_WIDTH * 10;
				preBitmap.y = postBitmap.y = 10;
				preBitmap.scaleX = postBitmap.scaleX
					= preBitmap.scaleY = postBitmap.scaleY = 10;
				addChild(preBitmap);
				addChild(postBitmap);
			}
			preBitmapData.fillRect(preBitmapData.rect, 0x0);
			postBitmapData.fillRect(postBitmapData.rect, 0x0);
			var i : uint = 0;
            var more : Boolean = true;
			while (i < CACHE_COMPUTATIONS_PER_FRAME && more) {
				more = cacheDataGenerator.calculateNext();
				++i;
			}
			preBitmapData.setVector(preBitmapData.rect, CacheDataGenerator.uintToVecRet(cacheDataGenerator.cacheIdx, cacheData.CACHE_VECTOR_LENGTH));
			postBitmapData.setVector(postBitmapData.rect, CacheDataGenerator.uintToVecRet(cacheData.getNextState(cacheDataGenerator.cacheIdx), cacheData.CACHE_VECTOR_LENGTH));
			
			lifeState.bitmapData.fillRect(lifeState.bitmapData.rect, 0x0);
			
			drawProgressBar(cacheDataGenerator.cacheIdx, cacheData.NUM_CACHE_PERMUTATIONS, PROGRESS_Y);
			
			DText.draw(lifeState.bitmapData, String(cacheDataGenerator.cacheIdx - 1), 10 + 10 * cacheData.FULL_CACHE_WIDTH / 2, 15 + 10 * cacheData.FULL_CACHE_HEIGHT, DText.CENTER);
			DText.draw(lifeState.bitmapData, String((cacheDataGenerator.cacheIdx - 1) & cacheData.masks.inner), 10 + 10 * cacheData.FULL_CACHE_WIDTH / 2, 35 + 10 * cacheData.FULL_CACHE_HEIGHT, DText.CENTER);
			
			DText.draw(lifeState.bitmapData, String(cacheDataGenerator.full), 40 + 10 * cacheData.FULL_CACHE_WIDTH * 3 / 2, 15 + 10 * cacheData.FULL_CACHE_HEIGHT, DText.CENTER);
			DText.draw(lifeState.bitmapData, String(cacheDataGenerator.inner), 40 + 10 * cacheData.FULL_CACHE_WIDTH * 3 / 2, 35 + 10 * cacheData.FULL_CACHE_HEIGHT, DText.CENTER);

			if (!more) {
				trace("Generation time: " + Number((getTimer() - generateStartTime) / 1000).toFixed(2) + "s");
				dataString = 
					"{\n" +
					'    "width": ' + CACHE_WIDTH + ",\n" +
					'    "height": ' + CACHE_HEIGHT + ",\n" +
					'    "cache": [' + cacheData.cache + "],\n" +
					'    "states": [' + cacheData.states + "]\n" +
					'}';
				//trace(dataString);
				
				removeEventListener(Event.ENTER_FRAME, enterFrameListener);
				addEventListener(Event.ENTER_FRAME, resetListener);
				enterFrameListener = resetListener;
			}
		}
        
		private function draw(vec : Vector.<uint>, rect : Rectangle, mat : Matrix = null) : void {
            lifeState.bitmapData.setVector(rect, vec);
			graphics.clear();
			graphics.beginBitmapFill(lifeState.bitmapData, mat);
			graphics.drawRect(-CACHE_WIDTH, -CACHE_HEIGHT, lifeState.FULL_DISPLAY_WIDTH, lifeState.FULL_DISPLAY_HEIGHT);
			graphics.endFill();
		}
        
        private function drawChunkedAndNext(e : Event = null) : void {
            lifeState.drawChunkedAndNext();
        }
		
		private function drawProgressBar(cur : uint, tot : uint, y : uint) : void {
            lifeState.bitmapData.drawRect(new Rectangle(int(lifeState.DISPLAY_WIDTH / 4), y, int(lifeState.DISPLAY_WIDTH / 2), 20), ALIVE_PIXEL);
            lifeState.bitmapData.fillRect(new Rectangle(int(lifeState.DISPLAY_WIDTH / 4 + 2), y + 2, int(lifeState.DISPLAY_WIDTH / 2 - 3) * cur / tot, 17), ALIVE_PIXEL);
			DText.draw(lifeState.bitmapData, Number(cur * 100 / tot).toFixed(1) + "%", int(lifeState.DISPLAY_WIDTH / 2), y + 3, DText.CENTER);
		}
		
        private var prevNumGenerated : uint = 0;
		private function drawFPS(e : Event = null) : void {
			fpsBitmapData.lock();
			fpsBitmapData.fillRect(fpsBitmapData.rect, 0x00000000);
			DText.draw(fpsBitmapData,
                FPSCounter.update() + "\n"
                + cacheData.numGenerated + "\n"
                + (cacheData.numGenerated - prevNumGenerated) + "\n"
                + cacheData.numHits,
                fpsBitmapData.width - 1, 0, DText.RIGHT);
            prevNumGenerated = cacheData.numGenerated;
            cacheData.numHits = 0;
			fpsBitmapData.unlock();
		}
        
		private function drawSize(e : Event = null) : void {
			sizeBitmapData.lock();
			sizeBitmapData.fillRect(fpsBitmapData.rect, 0x00000000);
			DText.draw(sizeBitmapData, lifeState.DISPLAY_WIDTH + "x" + lifeState.DISPLAY_HEIGHT, sizeBitmapData.width - 1, 0, DText.RIGHT);
			sizeBitmapData.unlock();
		}
	}
}
