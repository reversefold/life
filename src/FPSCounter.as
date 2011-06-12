package {
    import flash.utils.getTimer;

    public class FPSCounter {
        private static var last : uint;
        private static var ticks : uint;
        private static var text : String;
		private static var min : Number;
		private static var max : Number;
		
		//static
		{
			reset();
		}

		public static function reset() : void {
			last = getTimer();
			ticks = 0;
			text = "--.- FPS\n--.- min\n--.- max";
			min = Number.MAX_VALUE;
			max = Number.MIN_VALUE;
		}
		
        public static function update() : String {
            ++ticks;
            var now : uint = getTimer();
            var delta : uint = now - last;
            if (delta >= 1000) {
                var fps : Number = ticks / delta * 1000;
				min = Math.min(min, fps);
				max = Math.max(max, fps);
                text = fps.toFixed(1) + " FPS\n"
					+ min.toFixed(1) + " min\n"
					+ max.toFixed(1) + " max";
                ticks = 0;
                last = now;
            }
            return text;
        }
    }
}
