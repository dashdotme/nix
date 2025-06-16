# My Nix(os) Config

This is my living Nix setup, currently managing three hosts - a desktop, a
laptop and a macbook.

Inside, you'll find a complete hyprland setup for my Linux hosts, and a simple
set of work dependencies for my macbook.

## Result

The result looks something like this:

![screenshot](https://github.com/user-attachments/assets/d8e2c46e-40be-4087-a141-6339cde1e957)

Though in practice I fullscreen the windows with a bind.

## My Config Guidelines

1. Keep things simple, until there's a reason not to
2. Familiarity beats simplicity; a quick working solution beats a beautiful WIP; you can always tidy something that works

      - this is part of why Nix is great; you can break complex things (setting up a
      custom OS) into small steps

3. Nix doesn't need to do everything

My dotfiles, managed with [Chezmoi](https://www.chezmoi.io/), are
[here](https://github.com/dashdotme/dotfiles).
