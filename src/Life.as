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
		
		private var states : Vector.<Object> = new Vector.<Object>(mn, true);
		private var cache : Vector.<uint> = new Vector.<uint>(mn, true);
		
		private var cacheIdx : uint = 0;
		private var c : Vector.<uint> = new Vector.<uint>(len, true);
		private var n : Vector.<uint> = new Vector.<uint>(len, true);
		private var cacheRect : Rectangle = new Rectangle(1, 1, fw, fh);
		private var cacheRect2 : Rectangle = new Rectangle(fw + 2, 1, fw, fh);
		private var cacheMat : Matrix = new Matrix(10, 0, 0, 10);

		private var map : Vector.<Object>;
		
		//mask for the inner rect
		private var innerMask : uint = 0;
		
		//masks for the inner rect corners
		private var itlMask : uint = 1 << (1 + fw);
		private var itrMask : uint = 1 << (2 * fw - 2);
		private var ibrMask : uint = 1 << (len - fw - 2);
		private var iblMask : uint = 1 << (len - 2 * fw + 1);

		//masks for each side of the inner rect
		private var itMask : uint = 0;
		private var irMask : uint = 0;
		private var ibMask : uint = 0;
		private var ilMask : uint = 0;
		
		private var masks : Vector.<String> = Vector.<String>(
			[
				"innerMask",
				"itlMask",
				"itrMask",
				"ibrMask",
				"iblMask",
				"itMask",
				"irMask",
				"ibMask",
				"ilMask",
			]
		);
		
		private function onAddedToStage(e : Event) : void {
			stage.align = StageAlign.TOP_LEFT;
			stage.scaleMode = StageScaleMode.NO_SCALE;
			
			bd = new BitmapData(W + 2, H + 2);
			bd2 = new BitmapData(W + 2, H + 2);
			fpsbd = new BitmapData(100, 30);
			
			for (var y : uint = 1; y < fh - 1; ++y) {
				var yo : uint = y * fw;
				for (var x : uint = 1; x < fw - 1; ++x) {
					innerMask |= (1 << (x + yo));
				}
			}
			for (x = 1; x < fw - 1; ++x) {
				itMask |= (1 << (x + fw));
			}
			ibMask = itMask << (fw * (CACHE_HEIGHT - 1));

			for (y = 1; y < fh - 1; ++y) {
				ilMask |= (1 << (y * fh + 1));
			}
			irMask = ilMask << (CACHE_WIDTH - 1);

			for each (var maskName : String in masks) {
				traceMask(maskName);
			}
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
			var mask : uint = this[maskName];
			var line : String = maskName;
			for (var i : uint = 0; i < len; ++i) {
				if (i % fw == 0) {
					trace(line);
					line = "";
				}
				line += " " + ((mask >> i) & 1);
			}
			trace(line);
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
		private var state : Object;
		private var maskName : String;
		private var innerVector : Vector.<uint>;
		private function fillCache() : void {
			//for (var i : uint = 0; i < mn; ++i) {
				uintToVec(cacheIdx, c);
				nextFromPrev(c, n, fw, fh);
				full = vecToUint(n);
				inner = full & innerMask;
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
					state = {
						vec: innerVector
					};
					for each (maskName in masks) {
						state[maskName] = this[maskName] & full; // & inner would be the same since the masks are all for the inner rect
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
			} else if (map == null) {
				initMap();
				bbv[0] = new Vector.<uint>((W + 2) * (H + 2));
				bbv[1] = new Vector.<uint>((W + 2) * (H + 2));
				for (var y : uint = H / 4 + 1; y < H * 3 / 4 + 1; ++y) {
					var yo : uint = (W + 2) * y;
					for (var x : uint = W / 4 + 1; x < W * 3 / 4 + 1; ++x) {
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
		
		private function initMap() : void {
			map = new Vector.<Object>(W * H, true);
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
