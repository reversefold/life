package {
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.geom.Rectangle;
	import flash.utils.Dictionary;

	[SWF(frameRate="10",height="500",width="500")]
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
			//addEventListener(MouseEvent.CLICK, onClick);
		}
		
		private var bv : Vector.<Vector.<uint>> = new Vector.<Vector.<uint>>();
		private var bd : BitmapData;
		private var ci : uint = 0;
		private var cache : Dictionary;
		private var allRect : Rectangle;
		//private var go : Boolean = true;
		
		/*
		private function onClick(e : MouseEvent) : void {
			go = !go;
		}
		*/
		
		private function onAddedToStage(e : Event) : void {
			stage.align = StageAlign.TOP_LEFT;
			stage.scaleMode = StageScaleMode.NO_SCALE;
			
			bd = new BitmapData(W, H, false);
			bd.fillRect(new Rectangle(W / 4, H / 4, W / 2, H / 2), ALIVE);
			allRect = new Rectangle(0, 0, W, H);
			bv[0] = bd.getVector(allRect);
			bv[1] = new Vector.<uint>(W * H, true);
			
			cache = new Dictionary();
			fillCache(CACHE_WIDTH, CACHE_HEIGHT);
			
			draw(bv[ci]);
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
		
		private function fillCache(w : uint, h : uint) : void {
			var fw : uint = w + 2;
			var fh : uint = h + 2;
			var len : uint = fw * fh;
			var mn : uint = Math.pow(2, len);
			var c : Vector.<uint> = new Vector.<uint>(len);
			var n : Vector.<uint> = new Vector.<uint>(len);
			for (var i : uint = 0; i < mn; ++i) {
				uintToVec(i, c);
				nextFromPrev(c, n, fw, fh);
				cache[i] = vecToUint(n);
			}
		}
		
		private function onEnterFrame(e : Event) : void {
			//if (go) {
				nextFrame();
				draw(bv[ci]);
			//}
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
					
					for (var yi : uint = Math.max(0, y - 1); yi < my; ++yi) {
						var yo : uint = yi * W;
						for (var xi : uint = Math.max(0, x - 1); xi < mx; ++xi) {
							if ((xi != x || yi != y) && c[xi + yo] == ALIVE) {
								++na;
								if (na == 4) {
									break;
								}
							}
						}
						if (na == 4) {
							break;
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
		
		private function draw(vec : Vector.<uint>, x : uint = 0, y : uint = 0) : void {
			bd.setVector(allRect, vec);
			DText.draw(bd, FPSCounter.update(), W - 1, 0, DText.RIGHT);
			graphics.beginBitmapFill(bd);
			graphics.drawRect(x, y, W, H);
			graphics.endFill();
		}
	}
}
