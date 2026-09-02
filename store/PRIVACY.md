# Privacy Policy — buriko

_Last updated: 2 September 2026_

buriko collects nothing.

There is no account, no sign-in, no analytics, no crash reporting, and no advertising. The app
contains no networking code at all: `grep -r URLSession` over this repository returns nothing,
and the repository is public, so that claim is checkable rather than promised.

## What the app stores, and where

Everything buriko knows lives in one JSON file inside an App Group container on your device,
readable only by buriko and its two extensions:

- the length and outcome of your sessions,
- the identifier and UID of your paired brick, plus the note you wrote about where you leave it,
- the encoded list of apps you chose to block, as an opaque blob supplied by Apple.

None of it is transmitted anywhere. Deleting the app deletes the file, and with it every
restriction the app applied.

## What the app cannot see

Apple's Screen Time framework hands the app opaque `ApplicationToken` values rather than app
names or bundle identifiers. buriko stores those bytes and never decodes them. The app is
structurally incapable of knowing which apps you blocked, and no code path exists that could
report them.

## Screen Time access

buriko asks for Family Controls authorization for the individual case: your device restricting
itself. No family sharing, no second device, no parent account. Authorization can be revoked at
any time in Settings → Screen Time.

## Notifications

Local notifications only — a five-minute warning and an end-of-session notice, both scheduled on
your device when the session starts. Nothing is sent through Apple's push servers.

## NFC

buriko reads the factory UID of your tag to recognise your brick, and writes an identifier onto
the tag when you pair it. No other tag data is read or retained.

## Children

buriko is not directed at children and collects no data from anyone.

## Changes

Any change to this policy will be committed to the public repository, so its history is the
change log.

## Contact

davide.ghiotto@icloud.com
