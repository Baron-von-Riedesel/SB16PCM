# SB16PCM
Simple DOS PCM player for SoundBlaster 16.

There are 2 variants:
- sb16pcmp, running in protected-mode as 32-bit DPMI client
- sb16pcmr, running in real/v86-mode

Both variants require a 80386+ cpu.

The default values used for SoundBlaster access are
port 220h, irq 7, dma 1 and hdma 5. Values in the BLASTER
environment variable may overwrite those defaults.

Public Domain
