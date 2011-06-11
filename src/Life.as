package {
	import com.quasimondo.geom.ColorMatrix;
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.filters.BitmapFilter;
	import flash.filters.ColorMatrixFilter;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.sampler.NewObjectSample;
	import flash.utils.Dictionary;
	import flash.utils.describeType;
	
	import mx.utils.StringUtil;

	[SWF(frameRate="100",height="500",width="500")]
	public class Life extends Sprite {
		private static const W : uint = 200;
		private static const H : uint = 200;
		
		private static const CACHE_WIDTH : uint = 1;
		private static const CACHE_HEIGHT : uint = 1;
		
		private static const ALIVE : uint = 0xFF000000;
		private static const DEAD : uint = 0xFFFFFFFF;
		
		public function Life() {
			addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
			addEventListener(Event.ENTER_FRAME, onEnterFrame);
		}
		
		private var bv : Vector.<Vector.<uint>> = new Vector.<Vector.<uint>>(2, true);
		private var bbv : Vector.<Vector.<uint>> = new Vector.<Vector.<uint>>(2, true);
		private var bd : BitmapData;
		private var fpsbd : BitmapData;
		private var bd2 : BitmapData;
		private var ci : uint = 0;
		
		private var fw : uint = CACHE_WIDTH + 2;
		private var fh : uint = CACHE_HEIGHT + 2;
		private var len : uint = fw * fh;
		private var innerLen : uint = CACHE_WIDTH * CACHE_HEIGHT;
		private var mn : uint = Math.pow(2, len);
		
		private var states : Vector.<Object> = new Vector.<Object>(Math.pow(2, len - fw - 1), true);
		private var cache : Vector.<uint> = new Vector.<uint>(mn, true);
		
		private var cacheIdx : uint = 0;
		private var c : Vector.<uint> = new Vector.<uint>(len, true);
		private var n : Vector.<uint> = new Vector.<uint>(len, true);
		private var cacheRect : Rectangle = new Rectangle(1, 1, fw, fh);
		private var cacheRect2 : Rectangle = new Rectangle(fw + 2, 1, fw, fh);
		private var cacheMat : Matrix = new Matrix(10, 0, 0, 10);
		
		private var masks : Chunk = new Chunk();
		private var maskOffsets : Chunk = new Chunk();
		private var maskNeighborOffsets : Chunk = new Chunk();
		private var maskNames : Vector.<String> = new Vector.<String>();
		
		private function onAddedToStage(e : Event) : void {
			stage.align = StageAlign.TOP_LEFT;
			stage.scaleMode = StageScaleMode.NO_SCALE;
			
			bd = new BitmapData(W + 2, H + 2);
			bd2 = new BitmapData(W + 2, H + 2);
			fpsbd = new BitmapData(100, 30);
			
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

			for each (maskName in maskNames) {
				traceMask(maskName);
			}
			
			maskNeighborOffsets.bottomRight = -(
				maskNeighborOffsets.topLeft = maskOffsets.bottomRight - maskOffsets.topLeft
			);
			maskNeighborOffsets.bottomLeft= -(
				maskNeighborOffsets.topRight = maskOffsets.bottomLeft - maskOffsets.topRight
			);
			maskNeighborOffsets.bottom = -(
				maskNeighborOffsets.top = maskOffsets.bottom - maskOffsets.top
			);
			maskNeighborOffsets.right = -(
				maskNeighborOffsets.left = maskOffsets.right - maskOffsets.left
			);
			
			/*
			filters = [
				compressFilter,
				//invertFilter
			];
			
			var cm : ColorMatrix = new ColorMatrix();
			cm.adjustSaturation(-100);
			invertFilter = new ColorMatrixFilter(cm.matrix);
			*/
		}
		
		private function traceMask(maskName : String) : void {
			var mask : uint = masks[maskName];
			var str : String = mask.toString(2);
			trace(maskName + "\n" +
				(StringUtil.repeat("0", fw * fh - str.length) + str)
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
						state[maskName] = (masks[maskName] & full) // & inner would be the same since the masks are all for the inner rect
							<< maskNeighborOffsets[maskName]; //precalculate moving this masked bit to the place it needs to be for neighbor use
					}
					states[inner] = state;
				}
				cache[cacheIdx] = inner;
				++cacheIdx;
			//}
		}
		
		private function onEnterFrame(e : Event) : void {
			if (cacheIdx < mn) {
				fillCache();
				//bd.fillRect(bd.rect, 0xFF000000 | DEAD);
				bd.setVector(cacheRect, c);
				//draw(c, cacheRect, cacheMat, 10, 10);
				draw(n, cacheRect2, cacheMat);
			} else if (bbv[0] == null) {
				bbv[0] = new Vector.<uint>((W + 2) * (H + 2));
				bbv[1] = new Vector.<uint>((W + 2) * (H + 2));
				for (var y : uint = H / 4 + 1; y < H * 3 / 4 + 1; ++y) {
					var yo : uint = (W + 2) * y;
					for (var x : uint = W / 4 + 1; x < W * 3 / 4 + 1; ++x) {
						//NOTE: this is specific to the 1x1 case
						bbv[0][x + yo] = 16;
					}
				}
				/*
				bd.fillRect(new Rectangle(W / 4, H / 4, W / 2, H / 2), ALIVE);
				bv[0] = bd.getVector(bd.rect);
				bv[1] = new Vector.<uint>(W * H, true);
				draw(bv[ci], bd.rect);
				*/
			} else {
				nextFrame();
				draw(bv[ci], bd.rect);
			}
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
			graphics.drawRect(0, 0, W, H);
			graphics.endFill();
			/**/
			if (cacheIdx < mn) {
				bd2.fillRect(bd2.rect, 0x0);
				DText.draw(bd2, String(cacheIdx - 1), 10 + 10 * fw / 2, 15 + 10 * fh, DText.CENTER);
				DText.draw(bd2, String((cacheIdx - 1) & masks.inner), 10 + 10 * fw / 2, 35 + 10 * fh, DText.CENTER);

				DText.draw(bd2, String(full), 20 + 10 * fw * 3 / 2, 15 + 10 * fh, DText.CENTER);
				DText.draw(bd2, String(inner), 20 + 10 * fw * 3 / 2, 35 + 10 * fh, DText.CENTER);
				graphics.beginBitmapFill(bd2);
				graphics.drawRect(0, 0, W, H);
				graphics.endFill();
			}
			fpsbd.fillRect(fpsbd.rect, 0x0);
			DText.draw(fpsbd, FPSCounter.update(), fpsbd.width - 1, 0, DText.RIGHT);
			graphics.beginBitmapFill(fpsbd);
			graphics.drawRect(W - fpsbd.width, 0, fpsbd.width, fpsbd.height);
			graphics.endFill();
			/**/
		}
	}
}

class Chunk {
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
}
