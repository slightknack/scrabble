# zig raylib scrabble demo

> N.B. I wrote a blog post walking through the code. There's also a web demo. Read it here:
>
> [One day with Zig, Raylib, and jj](https://slightknack.dev/blog/zig-raylib/)

I was messing around trying to make a scrabble board. Some notable things:

- Written in Zig. I finally got on the Zig train
- Uses raylib. What a nice library.
- Using jj to manage version control. Just out of curiosity.

Eventually, I'd like to try:

- [ ] Fleshing out more of the game
- [x] Compiling to wasm and putting it up on the web.
- [ ] Making this network multiplayer?

# Installation

clone the repository. You can run with:

```
zig build run
```

You can build for the web by following the directions in [Not-Nik/raylib-zig](https://github.com/Not-Nik/raylib-zig).

Happy hacking!
