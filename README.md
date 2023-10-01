# laniservu

Laniservu Nix Flake

## Image

To build an image which you can flash to USB disk:
`nix build .#nuc-router-image -o result-nuc-router`

Then you can write the resulting `result-nuc-router/nixos.img` to eg. USB disk
with something like:
`dd if=result-nuc-router/nixos.img of=/dev/<DISK> bs=32M status=progress`.
(Beware that you use right disk for `of=` parameter so you don't overwrite your
hard disk!)
