# sops.nvim

sops.nvim is a Neovim plugin for working with SOPS encrypted files. It provides
transparent decryption and encryption of SOPS files when they are opened and
saved.

## Supported Files

- YAML
- JSON
- dotenv
- INI

The store format comes from the file name with any `.sops` parts removed, so
`secrets.sops.yaml`, `.env.sops` and `.sops.env` all work. Other names fall back
to the buffer's filetype, then to SOPS's own detection.

## Requirements

You are required to have [sops](https://github.com/getsops/sops)
available on your path

## Installation

### Lazy

```lua
{
    "trixnz/sops.nvim",
    lazy = false
}
```

### Packer

```lua
use {
  "trixnz/sops.nvim"
}
```

## Acknowledgements

[vscode-sops](https://github.com/signageos/vscode-sops)
