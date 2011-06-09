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

	[SWF(frameRate="100",height="1000",width="1000")]
	public class Life extends Sprite {
		private static const W : uint = 400;
		private static const H : uint = 400;
		
		private static const ALIVE : uint = 0xFF000000;
		private static const DEAD : uint = 0xFFFFFFFF;
		
		public function Life() {
			addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
			addEventListener(Event.ENTER_FRAME, onEnterFrame);
			addEventListener(MouseEvent.CLICK, onClick);
		}
		
		private var bv : Vector.<Vector.<uint>> = new Vector.<Vector.<uint>>();
		private var bd : BitmapData;
		private var ci : uint = 0;
		private var cache : Dictionary;
		private var allRect : Rectangle;
		private var go : Boolean = true;
		
		private function onClick(e : MouseEvent) : void {
			go = !go;
		}
		
		private function onAddedToStage(e : Event) : void {
			stage.align = StageAlign.TOP_LEFT;
			stage.scaleMode = StageScaleMode.NO_SCALE;
			
			bd = new BitmapData(W, H, false);
			bd.fillRect(new Rectangle(W / 4, H / 4, W / 2, H / 2), ALIVE);
			allRect = new Rectangle(0, 0, W, H);
			bv[0] = bd.getVector(allRect);
			bv[1] = new Vector.<uint>(W * H, true);
			
			cache = new Dictionary();
			fillCache(4, 4);
			
			draw();
		}
		
		private function fillCache(w : uint, h : uint) : void {
			
		}
		
		private function onEnterFrame(e : Event) : void {
			if (go) {
				nextFrame();
				draw();
			}
		}
		
		private function nextFrame() : void {
			var c : Vector.<uint> = bv[ci];
			ci++;
			ci %= bv.length;
			var n : Vector.<uint> = bv[ci];
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
							n[x + y * W] = 0xFFFFFFFF;
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
		
		private function draw() : void {
			bd.setVector(allRect, bv[ci]);
			DText.draw(bd, FPSCounter.update(), W - 1, 0, DText.RIGHT);
			graphics.beginBitmapFill(bd);
			graphics.moveTo(0, 0);
			graphics.drawRect(0, 0, W, H);
			graphics.endFill();
		}
	}
}
