# Life, Cached....in Chunks #

This is a version of Conway's Game of Life written during [a friendly competition](http://www.reversefold.com/blog/2011/06/22/life-cached/ "My blog entry"). The original idea was to precalculate all of the possible outcomes for every possible chunk of a certain size, then use those precalculations to speed up the rendering of Life. The current version instead caches on-demand, calculating only as needed and then reusing those values.

The speed of the implementation is mostly due to the representation of the pixels as simple bits (as they are only "on" or "off), breaking up the screen into 3x3 blocks, using simple bit-wise operations to stitch together the block with its surroundings to create a 5x5 block, then using that as a lookup into the cache. Once a state has been calculated, it is thwn broken up and the needed bitmasks and bitshifting operations are pre-calculated so as to speed up later use.