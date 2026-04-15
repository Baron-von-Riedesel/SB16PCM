# SB16PCM
Simple DOS PCM player for SoundBlaster 16.

Six variants may be created:
- sb16pcmf: 32-bit protected-mode, model flat
- sb16pcmr, 16-bit real/v86-mode, model small
- sb16pcmt: 32-bit protected-mode, model tiny
- sb16pcmv, 16-bit v86-mode, model small, uses VDS DMA buffer
- sb16pcmx: 16-bit protected-mode, model small
- sb16cdr,  16-bit real/v86-mode, model small; digital CD player

All variants require a 80386+ cpu.

The default values used for SoundBlaster access are
port 220h, irq 7, dma 1 and hdma 5. Values in the BLASTER
environment variable may overwrite those defaults.

Public Domain
