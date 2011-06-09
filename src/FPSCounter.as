package {
    import flash.utils.getTimer;

    public class FPSCounter {
        private static var last : uint = getTimer();
        private static var ticks : uint = 0;
        private static var text : String = "--.- FPS";

        public static function update() : String {
            ticks++;
            var now : uint = getTimer();
            var delta : uint = now - last;
            if (delta >= 1000) {
                var fps : Number = ticks / delta * 1000;
                text = fps.toFixed(1) + " FPS";
                ticks = 0;
                last = now;
            }
            return text;
        }
    }
}
