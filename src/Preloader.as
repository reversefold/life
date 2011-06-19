package {
    import flash.display.DisplayObject;
    import flash.display.MovieClip;
    import flash.display.StageAlign;
    import flash.display.StageScaleMode;
    import flash.events.Event;
    import flash.utils.getDefinitionByName;

    public class Preloader extends MovieClip {
        public function Preloader() {
            trace("Preloader");
            stop();
            addEventListener(Event.ENTER_FRAME, onEnterFrame);
        }

        public function onEnterFrame(event : Event) : void {
			stage.align = StageAlign.TOP_LEFT;
			stage.scaleMode = StageScaleMode.NO_SCALE;
			graphics.lineStyle(1, 0);
			graphics.drawRect(int(stage.stageWidth / 4), int(stage.stageHeight / 2) - 10, int(stage.stageWidth / 2), 20);
			graphics.lineStyle();
			
			graphics.beginFill(0);
			graphics.drawRect(int(stage.stageWidth / 4) + 2, int(stage.stageHeight / 2) - 8, (int(stage.stageWidth / 2) - 3) * stage.loaderInfo.bytesLoaded / stage.loaderInfo.bytesTotal, 17);
			graphics.endFill();
            if (framesLoaded == totalFrames) {
                removeEventListener(Event.ENTER_FRAME, onEnterFrame);
                nextFrame();
                init();
            }
        }

        private function init() : void {
            //if class is inside package you'll have use full path ex.org.actionscript.Main
            var mainClass : Class = Class(getDefinitionByName("Life"));
            if (mainClass) {
                var main : Object = new mainClass();
                addChild(main as DisplayObject);
				graphics.clear();
            }
        }
    }
}
