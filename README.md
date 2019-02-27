# Unofficial File Exporter for Orgamax
With this small CLI script you can copy files organized within Orgamax to any backup path you want them to be copied to. This is especially useful if you want to send receipts to your tax accountant.

## Dependencies

Depends on Orgamax and Ruby 2.0+ with Bundler

## Usage

Clone this repo to any directory on your PC.

    $ git clone https://github.com/loyaruarutoitsu/orgamax-file-export.git
    
Install dependencies with bundler:

    $ cd orgamax-file-exporter
    $ bundle
    
Initialize configuration for export:

    $ bin/cli init
    
Start export:

    $ bin/cli export
    
