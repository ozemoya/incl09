# Activity 09: Local Storage Part II

Myles Miller · 002753776 · Undergraduate pathway

This Flutter app extends my Activity 08 SQLite guest roster with folders and cards. It keeps the original `MyDatabase.db` filename and `my_table` guest rows, upgrades the database from version 1 to version 2, and adds a catalogue. The UI uses typed `FolderRecord` and `CardRecord` models and calls `DatabaseHelper` methods for storage rather than running SQL inside widgets.

## Build and run

Run `flutter pub get`, `flutter run`, `flutter analyze`, and `flutter build apk --release` from this directory with an Android emulator or device. The Android package is `edu.gsu.myles.local_storage_lab`. The release APK is generated at `build/app/outputs/flutter-apk/app-release.apk`. Dependencies include `sqflite`, `path_provider`, and `path`.

## Storage design

Version 2 adds `folders(id, name UNIQUE, created_at)` and `cards(id, title, suit, notes, image_ref, folder_id)`, with index `idx_cards_folder_id`. `cards.folder_id` references `folders.id` with `ON DELETE CASCADE`; `onConfigure` enables foreign keys for each opened connection. The version-gated `onUpgrade` creates only the new catalogue tables, leaving the original guest table alone. A fresh installation creates all three tables. Cards are selected, updated, and deleted by integer ID, so duplicate titles are safe. A folder delete has an explicit confirmation dialog because it also removes its cards.

The nullable `image_ref` stores a reference, not image bytes. The app shows a text/suit placeholder when the reference is absent or unusable and leaves the card data intact. This keeps the database small, but external image availability is not guaranteed offline.

## Recorded manual tests (October 8, 2026)

Tests used an Android Pixel 7 Pro emulator (Android 17). The version-1 install and the version-2 upgrade used the same package and database file. Read-only database snapshots were used to confirm rows and IDs; sample names are fictional.

| Test | Action and expected result | Observed result |
| --- | --- | --- |
| T1a | Upgrade existing version-1 app without losing guests | Before: `PRAGMA user_version=1`; guests `(2,River,35)`, `(3,Acorn,0)`, `(4,Oak,130)`. After installing version 2 over the same app: `user_version=2`; those three rows and values remained unchanged; `folders`, `cards`, and `idx_cards_folder_id` existed. See `evidence/T1_before.png`. Pass. |
| T1b | Fresh version-2 install also creates original and catalogue schema | Separate disposable package `edu.gsu.myles.local_storage_fresh`: `user_version=2`; original guest table, folders, cards, and index existed; initial guest/folder counts were zero. Added folder `Empty test` (ID 1) and opened its zero-card screen without error. Pass. |
| T2 | Create two folders, including duplicate card titles in one folder | Created Moon (ID 1) and Lantern (ID 2). Inserted Beacon (card ID 1) into Lantern; Echo (IDs 2 and 3) into Moon. Counts: Moon 2, Lantern 1. See `evidence/T2_cards.png`. Pass. |
| T3 | Edit one duplicate by ID, then cancel another edit | Updated card ID 2 to `Echo revised` with notes `Revised`; card ID 3 remained `Echo`. Entered a proposed edit for ID 3 and canceled; database remained unchanged. Pass. |
| T4 | Force-stop and relaunch the same installation | Database rows before and after restart matched: Moon 2, Lantern 1, card ID 2 `Echo revised`, card ID 3 `Echo`, and original guests unchanged. See `evidence/T4_after.png`. Pass. |
| T5 | Cancel and confirm card/folder deletion | Canceling card ID 3 deletion changed nothing. Confirming removed that card and made Moon count 1. Canceling Moon deletion changed nothing. Confirming folder ID 1 deletion removed remaining card ID 2 by cascade; Lantern and Beacon remained, as did all guests. Pass. |
| T6 | Null image and invalid inputs | Beacon with null `image_ref` displayed a Hearts placeholder and its title. Whitespace-only card title, blank folder name, and duplicate `Lantern` folder name produced feedback; persisted counts remained Lantern 1 and Beacon 1. Pass. |

The app was analyzed with no issues (`analysis_output.txt`). I installed the release APK over the same app, opened it, and saw all three original guest rows plus Lantern with one card after the T5 deletion sequence. The screenshots show the original roster, duplicate-title cards, and cards after restart. T1b uses a separate test package copied from the version-2 source; it is not part of this submission repository. No automated UI test is claimed.

## Decisions and limits

The cascade rule is suitable for this disposable card catalogue but would be risky for records requiring independent retention. The image fallback preserves title and suit even when artwork is missing. I did not implement cloud synchronization or an image picker because the assignment does not require them.

## Attribution

I used Gemini AI for conceptual help and an AI coding assistant for implementation and writing. The reported database rows, screenshots, and device actions above were independently checked on the emulator; the AI did not supply those results. Assignment reference: [Activity 09 Local Storage Part II](https://codd.cs.gsu.edu/~lhenry23/mad/ica/act09/v2/index.html).
