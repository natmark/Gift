# Gift
[![Build Status](https://app.bitrise.io/app/e776376dc65f1094/status.svg?token=jzvrcR1lWeilag1JjNcwlQ&branch=master)](https://app.bitrise.io/app/e776376dc65f1094)

Gift is a git like version control system written in Swift

## Instalation
- Clone this repository
  - `$ git clone git@github.com:natmark/Gift.git`

- Build from source and locate binary to `/usr/local/bin/`
  - `$ make install`

## Usage (Currently supports the following commands)
```
$ gift help
Available commands:

   add           Add file contents to the index
   cat-file      Provide content of repository objects
   checkout      Checkout a commit inside of a directory.
   commit        Record changes to the repository
   hash-object   Compute object ID and optionally creates a blob from a file
   help          Display general or command-specific help
   init          Create an empty Git repository or reinitialize an existing one
   log           Display history of a given commit.
   ls-tree       Pretty-print a tree object.
   rev-parse     Parse revision (or other objects )identifiers
   show-ref      List references.
   tag           List and create tags.
   version       Display the current version of Gift
```

## References
- [Write yourself a Git](https://wyag.thb.lt/)
- [thblt/write-yourself-a-git](https://github.com/thblt/write-yourself-a-git)
