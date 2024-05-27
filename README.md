### What Is This?

Atari Breakout But The Tiles Are Falling Down.

### Rules Of The Game:

    - Missing the bullet(or ball?), decreases how many lifes you have left
    - If any tile goes beyond the y-axis, your life would decrease
    - A Red tile gives 4 points
    - An Orange tile gives 3 points
    - A Green tile gives 2 points
    - A Yellow tile gives 1 point
    - If you die in atari fallout, you die in real life :)

### How to run

- Grab the binary for your operating system from [here](...)

### Building From Source

1. [Install](https://nim-lang.org/install.html) Nim.
1. Clone this repo: `git clone https://github.com/Uzo2005/atariFallout.git`
1. Go into the directory `cd atariFallout`
1. Run `nimble install`, to install the `naylib` dependency(raylib bindings for nim by the awesome @planetis-m)
1. Run `nim c -d:release -o atariFallout main.nim`
1. Run the generated binary `./atariFallout`
