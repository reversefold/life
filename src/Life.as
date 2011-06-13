package {
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
	import flash.net.FileReference;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.sampler.NewObjectSample;
	import flash.utils.Dictionary;
	import flash.utils.describeType;
	import flash.utils.getTimer;
	
	import mx.utils.StringUtil;
	
	[SWF(frameRate="100", width="1000", height="1000")]
	public class Life extends Sprite {
		private static const CACHE_WIDTH : uint = 2;
		private static const CACHE_HEIGHT : uint = 2;
		
		private static const REQUESTED_WIDTH : uint = 1000;
		private static const REQUESTED_HEIGHT : uint = 1000;
		
		private static const LOAD : Boolean = false;
		
		private static const CACHE_COMPUTATIONS_PER_FRAME : uint = 400;
		
		private static const ALIVE_PIXEL : uint = 0xFF000000;
		private static const DEAD_PIXEL : uint = 0xFFFFFFFF;
		
		private static const FULL_CACHE_WIDTH : uint = CACHE_WIDTH + 2;
		private static const FULL_CACHE_HEIGHT : uint = CACHE_HEIGHT + 2;
		
		private static const CACHE_VECTOR_LENGTH : uint = FULL_CACHE_WIDTH * FULL_CACHE_HEIGHT;
		private static const INNER_CACHE_VECTOR_LENGTH : uint = CACHE_WIDTH * CACHE_HEIGHT;
		private static const NUM_CACHE_PERMUTATIONS : uint = Math.pow(2, CACHE_VECTOR_LENGTH);
		
		private static const DISPLAY_WIDTH : uint = int(REQUESTED_WIDTH / CACHE_WIDTH) * CACHE_WIDTH;
		private static const DISPLAY_HEIGHT : uint = int(REQUESTED_HEIGHT / CACHE_HEIGHT) * CACHE_HEIGHT;

		private static const CHUNKED_WIDTH : uint = DISPLAY_WIDTH / CACHE_WIDTH;
		private static const CHUNKED_HEIGHT : uint = DISPLAY_HEIGHT / CACHE_HEIGHT;
		
		private static const FULL_CHUNKED_WIDTH : uint = CHUNKED_WIDTH + 2;
		private static const FULL_CHUNKED_HEIGHT : uint = CHUNKED_HEIGHT + 2;
		
		private static const FULL_CHUNKED_LENGTH : uint = FULL_CHUNKED_WIDTH * FULL_CHUNKED_HEIGHT;
		private static const FULL_CHUNKED_LIVE_LENGTH : uint = FULL_CHUNKED_LENGTH - FULL_CHUNKED_WIDTH;
		
		private static const FULL_DISPLAY_WIDTH : uint = DISPLAY_WIDTH + CACHE_WIDTH * 2;
		private static const FULL_DISPLAY_HEIGHT : uint = DISPLAY_HEIGHT + CACHE_HEIGHT * 2;

		private static const PROGRESS_Y : uint = 300;
		
		private static var bitmapData : BitmapData = new BitmapData(FULL_DISPLAY_WIDTH, FULL_DISPLAY_HEIGHT, true);
		private static var bitmap : Bitmap = null;
		private static var bitmapData2 : BitmapData = new BitmapData(FULL_DISPLAY_WIDTH, FULL_DISPLAY_HEIGHT, true);
		private static var fpsBitmapData : BitmapData = new BitmapData(100, 50, true);
		private static var fpsBitmap : Bitmap = new Bitmap(fpsBitmapData);
		
		private static var cache : Vector.<uint> = new Vector.<uint>(NUM_CACHE_PERMUTATIONS, true);
		private static var states : Vector.<Chunk> = new Vector.<Chunk>(Math.pow(2, CACHE_VECTOR_LENGTH - FULL_CACHE_WIDTH - 1), true);
		
		private static var cacheIdx : uint = 0;
		private static var currentStates : Vector.<uint> = new Vector.<uint>(CACHE_VECTOR_LENGTH, true);
		private static var nextStates : Vector.<uint> = new Vector.<uint>(CACHE_VECTOR_LENGTH, true);
		private static var tmpStates : Vector.<uint>;
		
		private static var currentChunksToCheck : Vector.<Boolean> = new Vector.<Boolean>(FULL_CHUNKED_LENGTH, true);
		private static var nextChunksToCheck : Vector.<Boolean> = new Vector.<Boolean>(FULL_CHUNKED_LENGTH, true);
		private static var tempChunksToCheck : Vector.<Boolean>;
		
		private static const preBitmapData : BitmapData = new BitmapData(FULL_CACHE_WIDTH, FULL_CACHE_HEIGHT);
		private static const preBitmap : Bitmap = new Bitmap(preBitmapData);
		private static const postBitmapData : BitmapData = new BitmapData(FULL_CACHE_WIDTH, FULL_CACHE_HEIGHT);
		private static const postBitmap : Bitmap = new Bitmap(postBitmapData);
		
		private static var cacheRect : Rectangle = new Rectangle(1, 1, FULL_CACHE_WIDTH, FULL_CACHE_HEIGHT);
		private static var cacheRect2 : Rectangle = new Rectangle(FULL_CACHE_WIDTH + 4, 1, FULL_CACHE_WIDTH, FULL_CACHE_HEIGHT);
		private static var cacheMat : Matrix = new Matrix(10, 0, 0, 10);
		
		private static var masks : Chunk = new Chunk();
		private static var maskOffsets : Chunk = new Chunk();
		private static var maskNeighborOffsets : Chunk = new Chunk();
		private static var maskNeighborOffsetNegative : Chunk = new Chunk();
		private static var maskNames : Vector.<String> = new Vector.<String>();
		
		private static var dataString : String = null;
		private static var fileRef : FileReference;
		
		private static var full : uint;
		private static var inner : uint;
		private static var state : Chunk;
		private static var maskName : String;
		private static var innerVector : Vector.<uint>;
		private static var jsonDecoder : JSONDecoderAsync = null;
		private static var loadedDataObject : Object = null;
		//private static var loadedDataObject : Object = LifeData.data2x2;
		
		private static var loader : URLLoader = null;
		private static var cacheLoadIdx : uint = 0;
		private static var stateLoadIdx : uint = 0;
		private static var loaded : Boolean = false;
		private static var fileProgress : uint = 0;
		private static var fileSize : uint = 1;
		
		private static var jsonStartTime : * = null;
		private static var chunkRect : Rectangle = new Rectangle(0, 0, CACHE_WIDTH, CACHE_HEIGHT);
		private static var i : uint;
		private static var upIdx : uint;
		private static var downIdx : uint;
		private static var currentState : Chunk;
		private static var nextState : Chunk;
		
		private static var enterFrameListener : Function;
		
		private static var random : Boolean = false;
		
		private static var paused : Boolean = false;
		
		public function Life() {
			addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
			if (LOAD) {
				addEventListener(Event.ENTER_FRAME, loadListener);
				enterFrameListener = loadListener;
			} else {
				addEventListener(Event.ENTER_FRAME, generateListener);
				enterFrameListener = generateListener;
			}
			addEventListener(Event.ENTER_FRAME, drawFPS);
		}

		private function onKeyUp(e : KeyboardEvent) : void {
			trace("Pressed " + e.charCode);
			if (e.charCode == 'r'.charCodeAt()) {
				random = !random;
				removeEventListener(Event.ENTER_FRAME, enterFrameListener);
				enterFrameListener = resetListener;
				addEventListener(Event.ENTER_FRAME, resetListener);
				return;
			}
			if (e.charCode == 'p'.charCodeAt()) {
				if (paused) {
					addEventListener(Event.ENTER_FRAME, enterFrameListener);
					addEventListener(Event.ENTER_FRAME, drawFPS);
				} else {
					removeEventListener(Event.ENTER_FRAME, enterFrameListener);
					removeEventListener(Event.ENTER_FRAME, drawFPS);
				}
				paused = !paused;
				return;
			}
			/*
			if (e.charCode == 'n'.charCodeAt()) {
				removeEventListener(Event.ENTER_FRAME, enterFrameListener);
				addEventListener(Event.ENTER_FRAME, renderNaive);
				enterFrameListener = renderNaive;
			}
			if (e.charCode == 'c'.charCodeAt()) {
				removeEventListener(Event.ENTER_FRAME, enterFrameListener);
				addEventListener(Event.ENTER_FRAME, drawChunked);
				enterFrameListener = drawChunked;
			}
			*/
			if (dataString == null || (e.charCode != 's'.charCodeAt())) {
				return;
			}
			var fn : String = CACHE_WIDTH + "x" + CACHE_HEIGHT + ".json";
			fileRef = new FileReference();
			fileRef.save(dataString, fn);
		}
		
		private function onAddedToStage(e : Event) : void {
			stage.align = StageAlign.TOP_LEFT;
			stage.scaleMode = StageScaleMode.NO_SCALE;

			stage.addEventListener(KeyboardEvent.KEY_UP, onKeyUp);
			
			for each (maskName in describeType(masks).variable.@name) {
				if (maskName == "vector") {
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

			bitmap = new Bitmap(bitmapData);
			bitmap.x = -CACHE_WIDTH;
			bitmap.y = -CACHE_HEIGHT;
			addChild(bitmap);

			fpsBitmap.x = DISPLAY_WIDTH - fpsBitmap.width;
			addChild(fpsBitmap);
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
		
		private static function uintToVec(i : uint, vec : Vector.<uint>) : void {
			for (var idx : uint = 0; idx < vec.length; ++idx) {
				vec[idx] = ((i >> idx) & 0x1) == 0x1 ? ALIVE_PIXEL : DEAD_PIXEL;
			}
		}
		
		private static function vecToUint(vec : Vector.<uint>) : uint {
			var i : uint = 0;
			for (var idx : uint = 0; idx < vec.length; ++idx) {
				if (vec[idx] == ALIVE_PIXEL) {
					i += 0x1 << idx;
				}
			}
			return i;
		}
		
		private function fillCache() : void {
			uintToVec(cacheIdx, currentStates);
			nextFromPrev(currentStates, nextStates, FULL_CACHE_WIDTH, FULL_CACHE_HEIGHT);
			full = vecToUint(nextStates);
			inner = full & masks.inner;
			if (states[inner] == null) {
				innerVector = new Vector.<uint>(INNER_CACHE_VECTOR_LENGTH, true);
				var i : uint = 0;
				for (var y : uint = 1; y <= CACHE_HEIGHT; ++y) {
					var yo : uint = y * FULL_CACHE_WIDTH;
					for (var x : uint = 1; x <= CACHE_WIDTH; ++x) {
						innerVector[i] = (full & (1 << x + yo)) ? ALIVE_PIXEL : DEAD_PIXEL;
						++i;
					}
				}
				state = new Chunk();
				state.vector = innerVector;
				for each (maskName in maskNames) {
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
		
		private function loadListener(e : Event) : void {
			//bitmapData2.fillRect(bitmapData2.rect, 0x0);
			if (loader == null) {
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
					*/
				} else if (stateLoadIdx < states.length) {
					//trace("loading state " + Number(stateLoadIdx * 100 / states.length).toFixed(2) + "% " + stateLoadIdx + "/" + states.length);
					for (i = 0; i < 60000 && stateLoadIdx < states.length; ++i) {
						var ch : Chunk;
						if (loadedDataObject.states[stateLoadIdx] == null) {
							ch = null;
						} else {
							ch = new Chunk(loadedDataObject.states[stateLoadIdx]);
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
			*/
			if (loaded) {
				removeEventListener(Event.ENTER_FRAME, enterFrameListener);
				addEventListener(Event.ENTER_FRAME, resetListener);
				enterFrameListener = resetListener;
			}
		}
		
		private function resetListener(e : Event) : void {
			if (preBitmap.parent != null) {
				preBitmap.parent.removeChild(preBitmap);
				postBitmap.parent.removeChild(postBitmap);
			}
			bitmapData.fillRect(bitmapData.rect, 0);
			graphics.clear();
			jsonDecoder = null;
			trace("initing chunks");
			currentStates = new Vector.<uint>(FULL_CHUNKED_LENGTH);
			nextStates = new Vector.<uint>(FULL_CHUNKED_LENGTH);
			var y : uint;
			var yo : uint;
			var x : uint;
			if (random) {
				for (y = 1; y < CHUNKED_HEIGHT - 1; ++y) {
					yo = FULL_CHUNKED_WIDTH * y;
					for (x = 1; x < CHUNKED_WIDTH - 1; ++x) {
						currentStates[x + yo] = masks.inner & uint(Math.random() * uint.MAX_VALUE);
					}
				}
			} else {
				for (y = CHUNKED_HEIGHT / 4 + 1; y < CHUNKED_HEIGHT * 3 / 4 + 1; ++y) {
					yo = FULL_CHUNKED_WIDTH * y;
					for (x = CHUNKED_WIDTH / 4 + 1; x < CHUNKED_WIDTH * 3 / 4 + 1; ++x) {
						currentStates[x + yo] = masks.inner;
					}
				}
			}
			currentChunksToCheck = new Vector.<Boolean>(FULL_CHUNKED_LENGTH, true);
			for (i = FULL_CHUNKED_WIDTH + 1; i < FULL_CHUNKED_LIVE_LENGTH; ++i) {
				if ((i % FULL_CHUNKED_WIDTH) == FULL_CHUNKED_WIDTH - 1) {
					++i;
					continue;
				}
				currentChunksToCheck[i] = true;
			}
			/*
			for (y = 0; y < F_CHUNKED_H; ++y) {
			var s : String = "";
			yo = F_CHUNKED_W * y;
			for (x = 0; x < F_CHUNKED_W; ++x) {
			s += bbv[0][x + yo] > 0 ? "1" : "0";
			}
			trace(s);
			}
			*/
			/*
			if (bitmap == null) {
				bitmap = new Bitmap(bitmapData);
				bitmap.x = -CACHE_WIDTH;
				bitmap.y = -CACHE_HEIGHT;
				addChild(bitmap);
				if (fpsBitmap.parent != null) {
					fpsBitmap.parent.removeChild(fpsBitmap);
				}
				addChild(fpsBitmap);
			}
			*/
			drawChunked();
			/** /
			 bd.fillRect(new Rectangle(W / 4, H / 4, W / 2, H / 2), ALIVE);
			 bv[0] = bd.getVector(bd.rect);
			 bv[1] = new Vector.<uint>(W * H, true);
			 draw(bv[ci], bd.rect);
			/**/
			FPSCounter.reset();
			
			removeEventListener(Event.ENTER_FRAME, enterFrameListener);
			addEventListener(Event.ENTER_FRAME, drawChunked);
			enterFrameListener = drawChunked;
		}
		
		private function renderNaive(e : Event) : void {
			nextFrame();
			draw(currentStates, bitmapData.rect);
		}
		
		private function generateListener(e : Event) : void {
			if (preBitmap.parent == null) {
				preBitmap.x = 10;
				postBitmap.x = 40 + FULL_CACHE_WIDTH * 10;
				preBitmap.y = postBitmap.y = 10;
				preBitmap.scaleX = postBitmap.scaleX
					= preBitmap.scaleY = postBitmap.scaleY = 10;
				addChild(preBitmap);
				addChild(postBitmap);
			}
			preBitmapData.fillRect(preBitmapData.rect, 0x0);
			postBitmapData.fillRect(postBitmapData.rect, 0x0);
			var i : uint = 0;
			while (i < CACHE_COMPUTATIONS_PER_FRAME && cacheIdx < NUM_CACHE_PERMUTATIONS) {
				fillCache();
				++i;
			}
			preBitmapData.setVector(preBitmapData.rect, currentStates);
			//bd.fillRect(bd.rect, 0xFF000000 | DEAD);
			//bitmapData.setVector(cacheRect, currentStates);
			//draw(c, cacheRect, cacheMat, 10, 10);
			postBitmapData.setVector(postBitmapData.rect, nextStates);
			//draw(nextStates, cacheRect2, cacheMat);
			
			bitmapData.fillRect(bitmapData.rect, 0x0);
			
			drawProgressBar(cacheIdx, NUM_CACHE_PERMUTATIONS, PROGRESS_Y);
			
			DText.draw(bitmapData, String(cacheIdx - 1), 10 + 10 * FULL_CACHE_WIDTH / 2, 15 + 10 * FULL_CACHE_HEIGHT, DText.CENTER);
			DText.draw(bitmapData, String((cacheIdx - 1) & masks.inner), 10 + 10 * FULL_CACHE_WIDTH / 2, 35 + 10 * FULL_CACHE_HEIGHT, DText.CENTER);
			
			DText.draw(bitmapData, String(full), 40 + 10 * FULL_CACHE_WIDTH * 3 / 2, 15 + 10 * FULL_CACHE_HEIGHT, DText.CENTER);
			DText.draw(bitmapData, String(inner), 40 + 10 * FULL_CACHE_WIDTH * 3 / 2, 35 + 10 * FULL_CACHE_HEIGHT, DText.CENTER);
			/*
			graphics.beginBitmapFill(bitmapData);
			graphics.drawRect(-CACHE_WIDTH, -CACHE_HEIGHT, FULL_DISPLAY_WIDTH, FULL_DISPLAY_HEIGHT);
			graphics.endFill();
			*/

			if (cacheIdx == NUM_CACHE_PERMUTATIONS) {
				dataString = 
					"{\n" +
					'    "width": ' + CACHE_WIDTH + ",\n" +
					'    "height": ' + CACHE_HEIGHT + ",\n" +
					'    "cache": [' + cache + "],\n" +
					'    "states": [' + states + "]\n" +
					'}';
				/*
				dataString = 
					"{\n" +
					'    width: ' + CACHE_WIDTH + ",\n" +
					'    height: ' + CACHE_HEIGHT + ",\n" +
					'    cache: [' + cache + "],\n" +
					'    states: [' + states + "]\n" +
					'}';
				*/
				//trace(dataString);
				
				removeEventListener(Event.ENTER_FRAME, enterFrameListener);
				addEventListener(Event.ENTER_FRAME, resetListener);
				enterFrameListener = resetListener;
			}
			/*
			graphics.beginBitmapFill(fpsbd);
			graphics.drawRect(W - fpsbd.width, 0, fpsbd.width, fpsbd.height);
			graphics.endFill();
			*/
		}
		
		private function drawChunked(e : Event = null) : void {
			/*
			r.x = 0;
			r.y = 0;
			*/
			bitmapData.lock();
			nextChunksToCheck = new Vector.<Boolean>(FULL_CHUNKED_LENGTH, true);
			for (i = FULL_CHUNKED_WIDTH + 1; i < FULL_CHUNKED_LIVE_LENGTH; ++i) {
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

				chunkRect.x = i % FULL_CHUNKED_WIDTH * CACHE_WIDTH;
				chunkRect.y = int(int(i) / int(FULL_CHUNKED_WIDTH)) * CACHE_HEIGHT;
				bitmapData.setVector(chunkRect, states[currentStates[i]].vector);
				upIdx = i - FULL_CHUNKED_WIDTH;
				downIdx = i + FULL_CHUNKED_WIDTH;
				nextStates[i] = cache[
					currentStates[i]
					+ states[currentStates[upIdx]].bottom
					+ states[currentStates[downIdx]].top
					+ states[currentStates[i - 1]].right
					+ states[currentStates[i + 1]].left
					
					+ states[currentStates[upIdx - 1]].bottomRight
					+ states[currentStates[upIdx + 1]].bottomLeft
					+ states[currentStates[downIdx - 1]].topRight
					+ states[currentStates[downIdx + 1]].topLeft
				];
				if (currentStates[i] ^ nextStates[i]) {
					currentState = states[currentStates[i]];
					nextState = states[nextStates[i]];
					nextChunksToCheck[i] = true;
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
			tmpStates = currentStates;
			currentStates = nextStates;
			nextStates = tmpStates;

			tempChunksToCheck = currentChunksToCheck;
			currentChunksToCheck = nextChunksToCheck;
			nextChunksToCheck = tempChunksToCheck;
		}
		
		private function nextFrame() : void {
			tmpStates = currentStates;
			currentStates = nextStates;
			nextStates = tmpStates;
			nextFromPrev(currentStates, nextStates, DISPLAY_WIDTH, DISPLAY_HEIGHT);
		}
		
		private function nextFromPrev(c : Vector.<uint>, n : Vector.<uint>, W : uint, H : uint) : void {
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
						case 4:
							n[x + y * W] = DEAD_PIXEL;
							break;
						case 2:
							var i : uint = x + y * W;
							n[i] = c[i];
							break;
						case 3:
							n[x + y * W] = ALIVE_PIXEL;
							break;
					}
				}
			}
		}

		private function draw(vec : Vector.<uint>, rect : Rectangle, mat : Matrix = null) : void {
			//bd2.fillRect(bd2.rect, 0xFF000000);
			//bd2.setVector(rect, vec);
			//bd.fillRect(bd.rect, 0xFFFFFFFF);
			//bd.applyFilter(bd2, bd.rect, p, filter);
			bitmapData.setVector(rect, vec);
			graphics.clear();
			graphics.beginBitmapFill(bitmapData, mat);
			graphics.drawRect(-CACHE_WIDTH, -CACHE_HEIGHT, FULL_DISPLAY_WIDTH, FULL_DISPLAY_HEIGHT);
			graphics.endFill();
			/*
			if (cacheIdx < NUM_CACHE_PERMUTATIONS) {
				drawProgressBar(cacheIdx, NUM_CACHE_PERMUTATIONS, int(DISPLAY_HEIGHT * 3 / 4));
				
				DText.draw(bitmapData2, String(cacheIdx - 1), 10 + 10 * FULL_CACHE_WIDTH / 2, 15 + 10 * FULL_CACHE_HEIGHT, DText.CENTER);
				DText.draw(bitmapData2, String((cacheIdx - 1) & masks.inner), 10 + 10 * FULL_CACHE_WIDTH / 2, 35 + 10 * FULL_CACHE_HEIGHT, DText.CENTER);

				DText.draw(bitmapData2, String(full), 40 + 10 * FULL_CACHE_WIDTH * 3 / 2, 15 + 10 * FULL_CACHE_HEIGHT, DText.CENTER);
				DText.draw(bitmapData2, String(inner), 40 + 10 * FULL_CACHE_WIDTH * 3 / 2, 35 + 10 * FULL_CACHE_HEIGHT, DText.CENTER);
				graphics.beginBitmapFill(bitmapData2);
				graphics.drawRect(-CACHE_WIDTH, -CACHE_HEIGHT, FULL_DISPLAY_WIDTH, FULL_DISPLAY_HEIGHT);
				graphics.endFill();
			}
			*/
			//drawFPS();
		}
		
		private function drawProgressBar(cur : uint, tot : uint, y : uint) : void {
			graphics.lineStyle(1, ALIVE_PIXEL);
			graphics.drawRect(int(DISPLAY_WIDTH / 4), y, int(DISPLAY_WIDTH / 2), 20);
			graphics.lineStyle();
			graphics.beginFill(ALIVE_PIXEL);
			graphics.drawRect(int(DISPLAY_WIDTH / 4 + 2), y + 2, int(DISPLAY_WIDTH / 2 - 3) * cur / tot, 17);
			graphics.endFill();
			
			DText.draw(bitmapData, Number(cur * 100 / tot).toFixed(1) + "%", int(DISPLAY_WIDTH / 2), y + 3, DText.CENTER);
			/*
			graphics.beginBitmapFill(bitmapData2);
			graphics.drawRect(-CACHE_WIDTH, -CACHE_HEIGHT, FULL_DISPLAY_WIDTH, FULL_DISPLAY_HEIGHT);
			graphics.endFill();
			*/
		}
		
		private function drawFPS(e : Event = null) : void {
			fpsBitmapData.lock();
			fpsBitmapData.fillRect(fpsBitmapData.rect, 0x00000000);
			DText.draw(fpsBitmapData, FPSCounter.update(), fpsBitmapData.width - 1, 0, DText.RIGHT);
			fpsBitmapData.unlock();
			/** /
			graphics.beginBitmapFill(fpsbd);
			graphics.drawRect(W - fpsbd.width, 0, fpsbd.width, fpsbd.height);
			graphics.endFill();
			/**/
		}
	}
}
