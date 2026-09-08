# Reply to App Review — 1.0 (2), Guideline 2.1 demo video request

Received: 5 September 2026. Submission ID `bd38e031-a11b-445c-9d03-bf18edbd4cb0`.
Sent: (not yet sent)

## Before sending

1. Upload 1.0 (3) (`build/export/Brick.ipa`) and select it for the version.
2. Record the video from `store/DEMO-VIDEO.md` against that build.
3. ~~Put the video URL in App Review Information → Notes.~~ Done — it is the first line of the
   notes, pushed with `python3 store/connect.py metadata --video-url …`. Sign-in required: No.
4. **Check the numbered list below against what the video actually shows, and delete what it
   doesn't.** The video is 91 seconds; claiming a step Apple can't see is worse than claiming
   fewer.
5. Then send the reply.

---

Hello,

Thank you — the demo video is now linked in the App Review Information section for build 1.0 (3),
and the URL is also here:

https://youtu.be/Igl_C9sU3jk

The video was filmed with a second camera so that the physical iPhone and the NFC tag are both in
frame during every tap, and there are no cuts inside a tap. It shows, in order:

1. The build under review, 1.0 (3), being opened on a physical iPhone from TestFlight.
2. Onboarding and Screen Time (Family Controls) authorization.
3. **The initial pairing.** With no tag paired, "Pair your brick" starts an `NFCTagReaderSession`.
   The tag is held to the back of the phone; the app writes its identity to the tag as an NDEF
   record, locks the tag read-only, and stores the tag's factory UID. The user then names the tag
   and notes where they keep it.
4. Choosing the apps to block, with Apple's own `FamilyActivityPicker`.
5. Starting a session by tapping the tag: the shield goes up and the end is scheduled.
6. A blocked app showing the shield, with the time remaining and the note about where the tag was
   left.
7. An unpaired tag being refused: the app matches the tag's UID against the paired one, so a
   foreign tag does nothing.
8. A tap before the agreed minimum being refused, with the time remaining.
9. The tag being left in another room, the phone taken away, and the walk back.
10. Ending the session by tapping the tag again, and the previously blocked app opening normally.
11. The remaining tag-driven flows: a reverse setup, where a tap buys a fixed open window instead
    of starting a block, and an exit route, where several tags must be tapped in a set order
    before a session will end.
12. The emergency unlock — a ten-second press, three per rolling seven days — which is the
    fastest way to end a session during review.
13. Finally, the demo-tag mode described in our review notes: entering the code **BRICK-REVIEW**
    under Settings → App Review swaps the Core NFC reader for a simulated one, so that pairing,
    starting and ending can all be exercised on a review device with no tag. It is shown last, and
    turned off again on camera, so it is clear the rest of the video used real NFC hardware.

**On the hardware itself.** There is no proprietary accessory to obtain. The "designated hardware"
is an ordinary NFC tag — an NTAG215 sticker or card costing about a euro — optionally inside a
3D-printed shell whose model is public domain in our repository. Any NFC tag works. The app reads
the tag's factory UID with Core NFC (`NFCTagReaderSession`, entitlement format `TAG`) and matches
it against the paired UID; the object matters because of where the user leaves it, not because of
what it contains.

**And for testing without one.** Demo-tag mode, above, exists precisely so review is never blocked
on hardware. The access code is `BRICK-REVIEW`, entered under Settings → App Review, and it also
substitutes the Face ID prompt so a device with no enrolled face is not blocked either. There is
no account and no sign-in anywhere in the app.

The app's source is public, including the Core NFC adapters:
https://github.com/davide97g/brick

Please let us know if any part of the workflow needs to be shown differently and we will re-film
it.

Thank you.
