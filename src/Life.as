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
	
	[SWF(frameRate="100", width="504", height="500")]
	public class Life extends Sprite {
		private static const W : uint = 504;
		private static const H : uint = 500;
		
		private static const CACHE_WIDTH : uint = 3;
		private static const CACHE_HEIGHT : uint = 2;

		private static const CHUNKED_W : uint = W / CACHE_WIDTH;
		private static const CHUNKED_H : uint = H / CACHE_HEIGHT;
		
		private static const F_CHUNKED_W : uint = CHUNKED_W + 2;
		private static const F_CHUNKED_H : uint = CHUNKED_H + 2;
		
		private static const F_CHUNKED_LEN : uint = F_CHUNKED_W * F_CHUNKED_H;

		private static const F_CHUNKED_W_R : uint = F_CHUNKED_W - 1;
		private static const F_CHUNKED_LIVE_LEN : uint = F_CHUNKED_LEN - F_CHUNKED_W;

		private static const LOAD : Boolean = true;

		private static const COMPUTES_PER_FRAME : uint = 400;
		
		private static const ALIVE : uint = 0xFF000000;
		private static const DEAD : uint = 0xFFFFFFFF;
		
		public function Life() {
			addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
			addEventListener(Event.ENTER_FRAME, onEnterFrame);
		}
		
		private var bv : Vector.<Vector.<uint>> = new Vector.<Vector.<uint>>(2, true);
		private var bbv : Vector.<Vector.<uint>> = new Vector.<Vector.<uint>>(2, true);
		private var bd : BitmapData = new BitmapData(W + 2, H + 2, true);
		private var fpsbd : BitmapData = new BitmapData(100, 50, true);
		private var fpsb : Bitmap = new Bitmap(fpsbd);
		private var bd2 : BitmapData = new BitmapData(W + 2, H + 2, true);
		private var ci : uint = 0;
		private var nci : uint = 1;
		
		private var fw : uint = CACHE_WIDTH + 2;
		private var fh : uint = CACHE_HEIGHT + 2;
		private var len : uint = fw * fh;
		private var innerLen : uint = CACHE_WIDTH * CACHE_HEIGHT;
		private var mn : uint = Math.pow(2, len);

		private var cache : Vector.<uint> = new Vector.<uint>(mn, true);
		private var states : Vector.<Chunk> = new Vector.<Chunk>(Math.pow(2, len - fw - 1), true);
		
		private var cacheIdx : uint = 0;
		private var c : Vector.<uint> = new Vector.<uint>(len, true);
		private var n : Vector.<uint> = new Vector.<uint>(len, true);
		private var cc : Vector.<Boolean> = new Vector.<Boolean>(F_CHUNKED_LEN, true);
		private var nc : Vector.<Boolean> = new Vector.<Boolean>(F_CHUNKED_LEN, true);
		private var tc : Vector.<Boolean>;
		private var cacheRect : Rectangle = new Rectangle(1, 1, fw, fh);
		private var cacheRect2 : Rectangle = new Rectangle(fw + 4, 1, fw, fh);
		private var cacheMat : Matrix = new Matrix(10, 0, 0, 10);
		
		private var masks : Chunk = new Chunk();
		private var maskOffsets : Chunk = new Chunk();
		private var maskNeighborOffsets : Chunk = new Chunk();
		private var maskNeighborOffsetNegative : Chunk = new Chunk();
		private var maskNames : Vector.<String> = new Vector.<String>();
		
		private var data : String = null;
		private var f : FileReference;
		
		private var reset : Boolean = true;
		
		private function onAddedToStage(e : Event) : void {
			stage.align = StageAlign.TOP_LEFT;
			stage.scaleMode = StageScaleMode.NO_SCALE;

			stage.addEventListener(KeyboardEvent.KEY_UP, function(e : KeyboardEvent) : void {
				trace("Pressed " + e.charCode);
				if (e.charCode == 'r'.charCodeAt()) {
					reset = true;
				}
				if (data == null || (e.charCode != 's'.charCodeAt() && e.charCode != 'S'.charCodeAt())) {
					return;
				}
				var fn : String = CACHE_WIDTH + "x" + CACHE_HEIGHT + ".json";
				f = new FileReference();
				f.save(data, fn);
			});
			
			for each (maskName in describeType(masks).variable.@name) {
				if (maskName == "vector") {
					continue;
				}
				maskNames.push(maskName);
			}

			maskOffsets.topLeft = maskOffsets.top = maskOffsets.left = (1 + fw);
			maskOffsets.topRight = maskOffsets.right = (2 * fw - 2);
			maskOffsets.bottomLeft = maskOffsets.bottom = (len - 2 * fw + 1);
			maskOffsets.bottomRight = (len - fw - 2);

			masks.topLeft = masks.topRight = masks.bottomLeft = masks.bottomRight = 1;
			for (var x : uint = 0; x < CACHE_WIDTH; ++x) {
				masks.top |= 1 << x;
			}
			masks.bottom = masks.top;
			
			var i : uint = 0;
			for (var y : uint = 0; y < CACHE_HEIGHT; ++y, i += fw) {
				masks.left |= 1 << i;
			}
			masks.right = masks.left;
			
			for each (maskName in maskNames) {
				masks[maskName] <<= maskOffsets[maskName];
			}
			
			i = 0;
			for (y = 0; y < CACHE_HEIGHT; ++y, i += fw) {
				masks.inner |= masks.top << i;
			}
			
			maskNeighborOffsets.bottomRight 
				 = maskNeighborOffsets.topLeft = maskOffsets.bottomRight - maskOffsets.topLeft + fw + 1;
			maskNeighborOffsets.bottomLeft
				 = maskNeighborOffsets.topRight = maskOffsets.bottomLeft - maskOffsets.topRight + fw - 1;
			maskNeighborOffsets.bottom
				 = maskNeighborOffsets.top = maskOffsets.bottom - maskOffsets.top + fw;
			maskNeighborOffsets.right
				 = maskNeighborOffsets.left = maskOffsets.right - maskOffsets.left + 1;
			maskNeighborOffsetNegative.bottomRight = maskNeighborOffsetNegative.bottomLeft
				= maskNeighborOffsetNegative.bottom = maskNeighborOffsetNegative.right = 1;
			/*
			for each (maskName in maskNames) {
				traceMask(maskName);
			}
			*/
			/*
			filters = [
				compressFilter,
				//invertFilter
			];
			
			var cm : ColorMatrix = new ColorMatrix();
			cm.adjustSaturation(-100);
			invertFilter = new ColorMatrixFilter(cm.matrix);
			*/
			/*
			var j : JSONDecoderAsync = new JSONDecoderAsync(JSON.encode([{key: "val", key2: 2, o: {}, a: [], o2: {k: "y"}, arr: [1, 2, "3", 4]}, 5, [5, 4, 3], 6]), true);
			i = 0;
			while (!j.done) {
				trace("loop " + i);
				j.loop();
				++i;
			}
			var v : * = j.getValue();
			trace(JSON.encode(v));
			*/
			fpsb.x = W - fpsb.width;
			addChild(fpsb);
		}
		
		private function traceMask(maskName : String) : void {
			trace(maskName);
			_traceMask(masks[maskName]);
		}
		
		private function _traceMask(mask : uint) : void {
			var str : String = mask.toString(2);
			trace((StringUtil.repeat("0", fw * fh - str.length) + str)
					.split('')
					.reverse()
					.join(" ")
					.split(new RegExp("(" + StringUtil.repeat(". ", fw) + ")"))
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
				vec[idx] = ((i >> idx) & 0x1) == 0x1 ? ALIVE : DEAD;
			}
		}
		
		private static function vecToUint(vec : Vector.<uint>) : uint {
			var i : uint = 0;
			for (var idx : uint = 0; idx < vec.length; ++idx) {
				if (vec[idx] == ALIVE) {
					i += 0x1 << idx;
				}
			}
			return i;
		}
		
		private var full : uint;
		private var inner : uint;
		private var state : Chunk;
		private var maskName : String;
		private var innerVector : Vector.<uint>;
		private function fillCache() : void {
			//for (var i : uint = 0; i < mn; ++i) {
				uintToVec(cacheIdx, c);
				nextFromPrev(c, n, fw, fh);
				full = vecToUint(n);
				inner = full & masks.inner;
				if (states[inner] == null) {
					innerVector = new Vector.<uint>(innerLen, true);
					var i : uint = 0;
					for (var y : uint = 1; y <= CACHE_HEIGHT; ++y) {
						var yo : uint = y * fw;
						for (var x : uint = 1; x <= CACHE_WIDTH; ++x) {
							innerVector[i] = (full & (1 << x + yo)) ? ALIVE : DEAD;
							++i;
						}
					}
					state = new Chunk();
					state.vector = innerVector;
					for each (maskName in maskNames) {
						state[maskName] = (masks[maskName] & full); // & inner would be the same since the masks are all for the inner rect
							//<< maskNeighborOffsets[maskName];
						if (maskNeighborOffsetNegative[maskName] == 1) {
							state[maskName] >>= maskNeighborOffsets[maskName]
						} else {
							state[maskName] <<= maskNeighborOffsets[maskName]; //precalculate moving this masked bit to the place it needs to be for neighbor use
						}
					}
					states[inner] = state;
				}
				cache[cacheIdx] = inner;
				++cacheIdx;
			//}
		}
		
		private var d : JSONDecoderAsync = null;
		private var dataObj : Object = null;
		//private var dataObj : Object = LifeData.data3x3;
		
		//private var dataObj : Object = null;
		private function onLoadComplete(e : Event) : void {
			trace("file loaded");
			d = new JSONDecoderAsync(e.target.data, true);
			jsonStart = getTimer();
			/*
			var o : Object = JSON.decode(e.target.data);
			for (var i : uint = 0; i < cache.length; ++i) {
				cache[i] = o.cache[i];
			}
			for (i = 0; i < states.length; ++i) {
				var c : Chunk;
				if (o.states[i] == null) {
					c = null;
				} else {
					c = new Chunk(o.states[i]);
				}
				states[i] = c;
			}
			*/
			drawProgressBar(fileProgress, fileSize, PROGRESS_Y);
		}
		
		private var l : URLLoader = null;
		private var cacheLoadIdx : uint = 0;
		private var stateLoadIdx : uint = 0;
		private var loaded : Boolean = false;
		private static var PROGRESS_Y : uint = 300;
		private var fileProgress : uint = 0;
		private var fileSize : uint = 1;
		
		private var b : Bitmap = null;
		
		private function onIoError(e : Event) : void {
			trace(e);
		}
		
		private function onProgress(e : ProgressEvent) : void {
			fileProgress = e.bytesLoaded;
			fileSize = e.bytesTotal;
		}
		
		private var jsonStart : * = null;
		private function onEnterFrame(e : Event) : void {
			if (LOAD && !loaded) {
				bd2.fillRect(bd2.rect, 0x0);
				if (l == null) {
					trace("loading file");
					var u : URLRequest = new URLRequest("../assets/data/" + CACHE_WIDTH + "x" + CACHE_HEIGHT + ".json");
					l = new URLLoader(u);
					l.addEventListener(Event.COMPLETE, onLoadComplete);
					l.addEventListener(IOErrorEvent.IO_ERROR, onIoError);
					l.addEventListener(ProgressEvent.PROGRESS, onProgress);
				} else if (d != null) {
					if (dataObj == null && !d.done) {
						//trace("decoding JSON " + Number(d.tokenizer.loc * 100 / d.tokenizer.jsonString.length).toFixed(2) + "% " + d.tokenizer.loc + "/" + d.tokenizer.jsonString.length);
						for (i = 0; i < 150000; ++i) {
							if (d.loop()) {
								trace(((getTimer() - jsonStart) / 1000).toFixed(4) + "s parsing JSON");
								dataObj = d.getValue();
								break;
							}
						}
					} else if (cacheLoadIdx < cache.length) {
						//trace("loading cache " + Number(cacheLoadIdx * 100 / cache.length).toFixed(2) + "% " + cacheLoadIdx + "/" + cache.length);
						for (i = 0; i < 60000 && cacheLoadIdx < cache.length; ++i) {
							cache[cacheLoadIdx] = dataObj.cache[cacheLoadIdx];
							++cacheLoadIdx;
						}
					} else if (stateLoadIdx < states.length) {
						//trace("loading state " + Number(stateLoadIdx * 100 / states.length).toFixed(2) + "% " + stateLoadIdx + "/" + states.length);
						for (i = 0; i < 60000 && stateLoadIdx < states.length; ++i) {
							var ch : Chunk;
							if (dataObj.states[stateLoadIdx] == null) {
								ch = null;
							} else {
								ch = new Chunk(dataObj.states[stateLoadIdx]);
							}
							states[stateLoadIdx] = ch;
							++stateLoadIdx;
						}
						loaded = stateLoadIdx == states.length;
					}
				}

				drawProgressBar(fileProgress, fileSize, PROGRESS_Y);
				drawProgressBar(d != null ? d.tokenizer.loc : 0, d != null ? d.tokenizer.jsonString.length : 1, PROGRESS_Y + 22);
				drawProgressBar(cacheLoadIdx, cache.length, PROGRESS_Y + 44);
				drawProgressBar(stateLoadIdx, states.length, PROGRESS_Y + 66);
				/*
				graphics.beginBitmapFill(fpsbd);
				graphics.drawRect(W - fpsbd.width, 0, fpsbd.width, fpsbd.height);
				graphics.endFill();
				*/
			} else if (!LOAD && cacheIdx < mn) {
				bd2.fillRect(bd2.rect, 0x0);
				var i : uint = 0;
				while (i < COMPUTES_PER_FRAME && cacheIdx < mn) {
					fillCache();
					++i;
				}
				//bd.fillRect(bd.rect, 0xFF000000 | DEAD);
				bd.setVector(cacheRect, c);
				//draw(c, cacheRect, cacheMat, 10, 10);
				draw(n, cacheRect2, cacheMat);
				/*
				for each (maskName in maskNames) {
				trace("16 " + maskName);
				_traceMask(states[16][maskName]);
				}
				/**/
				/**/
				if (cacheIdx == mn) {
					data = 
						"{\n" +
						'    "width": ' + CACHE_WIDTH + ",\n" +
						'    "height": ' + CACHE_HEIGHT + ",\n" +
						'    "cache": [' + cache + "],\n" +
						'    "states": [' + states + "]\n" +
						'}';
					trace(data);
				}
				/*
				graphics.beginBitmapFill(fpsbd);
				graphics.drawRect(W - fpsbd.width, 0, fpsbd.width, fpsbd.height);
				graphics.endFill();
				*/
				/**/
			} else if (reset) {
				reset = false;
				graphics.clear();
				d = null;
				trace("initing chunks");
				bbv[0] = new Vector.<uint>(F_CHUNKED_LEN);
				bbv[1] = new Vector.<uint>(F_CHUNKED_LEN);
				if (false) {
					for (var y : uint = 1; y < CHUNKED_H - 1; ++y) {
						var yo : uint = F_CHUNKED_W * y;
						for (var x : uint = 1; x < CHUNKED_W - 1; ++x) {
							bbv[0][x + yo] = masks.inner & uint(Math.random() * uint.MAX_VALUE);
						}
					}
				} else {
					for (var y : uint = CHUNKED_H / 4 + 1; y < CHUNKED_H * 3 / 4 + 1; ++y) {
						var yo : uint = F_CHUNKED_W * y;
						for (var x : uint = CHUNKED_W / 4 + 1; x < CHUNKED_W * 3 / 4 + 1; ++x) {
							bbv[0][x + yo] = masks.inner;
						}
					}
				}
				cc = new Vector.<Boolean>(F_CHUNKED_LEN, true);
				for (i = F_CHUNKED_W + 1; i < F_CHUNKED_LIVE_LEN; ++i) {
					if ((i % F_CHUNKED_W) == F_CHUNKED_W_R) {
						++i;
						continue;
					}
					cc[i] = true;
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
				if (b == null) {
					b = new Bitmap(bd);
					b.x = -1;
					b.y = -1;
					addChild(b);
					if (fpsb.parent != null) {
						fpsb.parent.removeChild(fpsb);
					}
					addChild(fpsb);
				}
				drawChunked();
				/** /
				bd.fillRect(new Rectangle(W / 4, H / 4, W / 2, H / 2), ALIVE);
				bv[0] = bd.getVector(bd.rect);
				bv[1] = new Vector.<uint>(W * H, true);
				draw(bv[ci], bd.rect);
				/**/
				FPSCounter.reset();
			} else {
				//nextChunkedFrame();
				drawChunked();
			/*
			} else {
				nextFrame();
				draw(bv[ci], bd.rect);
			*/
			}
			drawFPS();
		}
		
		private var r : Rectangle = new Rectangle(0, 0, CACHE_WIDTH, CACHE_HEIGHT);
		private var i : uint;
		private var m : uint;
		private var upIdx : uint;
		private var downIdx : uint;
		private var cst : Chunk;
		private var nst : Chunk;
		private function drawChunked() : void {
			/*
			r.x = 0;
			r.y = 0;
			*/
			c = bbv[ci];
			n = bbv[nci];
			bd.lock();
			nc = new Vector.<Boolean>(F_CHUNKED_LEN, true);
			for (i = F_CHUNKED_W + 1; i < F_CHUNKED_LIVE_LEN; ++i) {
				if (
					//checks for the last index in a row, which is always dead
					(i % F_CHUNKED_W) == F_CHUNKED_W_R
				) {
					//skips the first index in a row as well, which is also always deadf
					++i;
					continue;
				}
				if (!cc[i]) {
					continue;
				}

				r.x = i % F_CHUNKED_W * CACHE_WIDTH;
				r.y = int(int(i) / int(F_CHUNKED_W)) * CACHE_HEIGHT;
				bd.setVector(r, states[c[i]].vector);
				upIdx = i - F_CHUNKED_W;
				downIdx = i + F_CHUNKED_W;
				n[i] = cache[
					c[i]
					+ states[c[upIdx]].bottom
					+ states[c[downIdx]].top
					+ states[c[i - 1]].right
					+ states[c[i + 1]].left
					
					+ states[c[upIdx - 1]].bottomRight
					+ states[c[upIdx + 1]].bottomLeft
					+ states[c[downIdx - 1]].topRight
					+ states[c[downIdx + 1]].topLeft
				];
				if (c[i] ^ n[i]) {
					cst = states[c[i]];
					nst = states[n[i]];
					nc[i] = true;
					if (cst.bottom ^ nst.bottom) {
						nc[downIdx] = true;
					}
					if (cst.top ^ nst.top) {
						nc[upIdx] = true;
					}
					if (cst.left ^ nst.left) {
						nc[i - 1] = true;
					}
					if (cst.right ^ nst.right) {
						nc[i + 1] = true;
					}
					if (cst.bottomLeft ^ nst.bottomLeft) {
						nc[downIdx - 1] = true;
					}
					if (cst.bottomRight ^ nst.bottomRight) {
						nc[downIdx + 1] = true;
					}
					if (cst.topLeft ^ nst.topLeft) {
						nc[upIdx - 1] = true;
					}
					if (cst.topRight ^ nst.topRight) {
						nc[upIdx + 1] = true;
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
			bd.unlock();
			/** /
			graphics.clear();
			graphics.beginBitmapFill(bd);
			graphics.drawRect(0, 0, W, H);
			graphics.endFill();
			/**/
			i = ci;
			ci = nci;
			nci = i;
			
			tc = cc;
			cc = nc;
			nc = tc;
		}
		
		private function nextFrame() : void {
			var c : Vector.<uint> = bv[ci];
			ci++;
			ci %= bv.length;
			var n : Vector.<uint> = bv[ci];
			nextFromPrev(c, n, W, H);
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
							if ((xi != x || yi != y) && c[xi + yo] == ALIVE) {
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
							n[x + y * W] = DEAD;
							break;
						case 2:
							var i : uint = x + y * W;
							n[i] = c[i];
							break;
						case 3:
							n[x + y * W] = ALIVE;
							break;
					}
				}
			}
		}
		/*
		private var p : Point = new Point(0, 0);
		private var invertFilter : BitmapFilter = new ColorMatrixFilter(
			[
				-1,    0,    0,   0,    0,
			     0,   -1,    0,   0,    0,
			     0,    0,   -1,   0,    0,
				 0,    0,    0,   1,    0
			]);
		private var compressFilter : BitmapFilter = new ColorMatrixFilter(
			[
				 245,    0,    0,    0,   10,
				   0,  245,    0,    0,   10,
				   0,    0,  245,    0,   10,
				   0,    0,    0,    0,  255
			]);
		*/
		private function draw(vec : Vector.<uint>, rect : Rectangle, mat : Matrix = null) : void {
			//bd2.fillRect(bd2.rect, 0xFF000000);
			//bd2.setVector(rect, vec);
			//bd.fillRect(bd.rect, 0xFFFFFFFF);
			//bd.applyFilter(bd2, bd.rect, p, filter);
			bd.setVector(rect, vec);
			graphics.clear();
			graphics.beginBitmapFill(bd, mat);
			graphics.drawRect(-1, -1, W, H);
			graphics.endFill();
			/**/
			if (cacheIdx < mn) {
				drawProgressBar(cacheIdx, mn, int(H * 3 / 4));
				
				DText.draw(bd2, String(cacheIdx - 1), 10 + 10 * fw / 2, 15 + 10 * fh, DText.CENTER);
				DText.draw(bd2, String((cacheIdx - 1) & masks.inner), 10 + 10 * fw / 2, 35 + 10 * fh, DText.CENTER);

				DText.draw(bd2, String(full), 40 + 10 * fw * 3 / 2, 15 + 10 * fh, DText.CENTER);
				DText.draw(bd2, String(inner), 40 + 10 * fw * 3 / 2, 35 + 10 * fh, DText.CENTER);
				graphics.beginBitmapFill(bd2);
				graphics.drawRect(-1, -1, W, H);
				graphics.endFill();
			}
			//drawFPS();
			/**/
		}
		
		private function drawProgressBar(cur : uint, tot : uint, y : uint) : void {
			graphics.lineStyle(1, 0);
			graphics.drawRect(int(W / 4), y, int(W / 2), 20);
			graphics.lineStyle();
			graphics.beginFill(0x0);
			graphics.drawRect(int(W / 4 + 2), y + 2, int(W / 2 - 3) * cur / tot, 17);
			graphics.endFill();
			
			DText.draw(bd2, Number(cur * 100 / tot).toFixed(1) + "%", int(W / 2), y + 2, DText.CENTER);
			
			graphics.beginBitmapFill(bd2);
			graphics.drawRect(0, 0, W, H);
			graphics.endFill();
		}
		
		private var fpsp : Point = new Point(W - fpsbd.width, 0);
		private function drawFPS() : void {
			fpsbd.lock();
			fpsbd.fillRect(fpsbd.rect, 0x00000000);
			DText.draw(fpsbd, FPSCounter.update(), fpsbd.width - 1, 0, DText.RIGHT);
			fpsbd.unlock();
			//bd.copyPixels(fpsbd, fpsbd.rect, fpsp, null, null, true);
			/** /
			graphics.beginBitmapFill(fpsbd);
			graphics.drawRect(W - fpsbd.width, 0, fpsbd.width, fpsbd.height);
			graphics.endFill();
			/**/
		}
	}
}

import flash.utils.describeType;

class Chunk extends Object {
	public function Chunk(o : Object = null) {
		if (o == null) {
			return;
		}
		for each (var n : String in describeType(this).variable.@name) {
			if (n == "vector") {
				this[n] = Vector.<uint>(o[n]);
			} else {
				this[n] = o[n];
			}
		}
	}
	
	public var inner : uint;
	public var top : uint;
	public var bottom : uint;
	public var left : uint;
	public var right : uint;
	public var topRight : uint;
	public var topLeft : uint;
	public var bottomRight : uint;
	public var bottomLeft : uint;
	public var vector : Vector.<uint>;
	
	public function toString() : String {
		var v : Vector.<String> = new Vector.<String>();
		for each (var n : String in describeType(this).variable.@name) {
			v.push('"' + n + '": ' + (this[n] is Vector.<uint> ? "[" + this[n] + "]" : this[n]));
		}
		return "{" + v.join(",") + "}";
	}
}
