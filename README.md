# Harbor Gallery

A native macOS gallery manager for Harbor, inspired by Photomanic. Each gallery is a Harbor notebook, and every photo is stored as its own Harbor note.

## What it does

- Stores gallery notebook IDs in an invisible local catalog for fast startup
- Lets you designate an existing notebook in any stack as a gallery
- Shows image-bearing notes inside designated gallery notebooks
- Creates one Harbor notebook per gallery and one Harbor note per photo
- Lets each gallery notebook live unstacked or inside any existing Harbor stack
- Uploads selected local images into those photo notes
- Edits a gallery's notebook name and stack
- Adds photos to an existing gallery and safely moves removed photo notes to Harbor Trash
- Renames individual photo notes and moves deleted photo notes to Harbor Trash
- Renames gallery notebooks and deletes galleries while preserving their photo notes in Harbor Trash
- Uses a shared 4, 8, 16, 24, 32, 48, 64-point spacing scale throughout the interface
- Shows Harbor-generated thumbnails and loads the original only in the detail view
- Displays the filename and linked Harbor note title(s)
- Searches locally by filename or note title
- Stores the Harbor personal access token in macOS Keychain
- Keeps unrelated images from articles, receipts, and ordinary Harbor notes out of the gallery
- Includes a manual recovery scan that can rebuild the local catalog from photo-note markers

Encrypted images appear as locked placeholders. Harbor encrypts those bytes client-side, so a separate decryption implementation would be required to display them.

## Connect Harbor

1. Sign in to Harbor’s web app.
2. Open **Settings → Developer → Personal access tokens**.
3. Create a token with the **Files**, **Notes**, and **Notebooks** scopes. An expiration is recommended.
4. Copy the token (it begins with `hbp_`) and paste it into Harbor Gallery.

Never put the token in this project or commit it to Git.

## Build a double-clickable app

In Terminal, change to this folder and run:

```sh
./build-app.sh
```

The finished app will be at `Build/Harbor Gallery.app`. The build script uses an available Apple Development signing identity when possible and otherwise falls back to an ad-hoc signature. You can drag the app to the Applications folder if you like.

## Run in Xcode

1. Accept Apple’s Xcode license if this Mac has not done so yet: open Terminal and run `sudo xcodebuild -license`.
2. Open `Package.swift` in Xcode.
3. Select the **HarborGallery** scheme and **My Mac** destination.
4. Press Run.

The app targets macOS 13 or later and uses only Apple frameworks; there are no third-party packages.

## Harbor API calls used

- `GET /api/v1/notebooks` and `GET /api/v1/stacks` to list Harbor organization
- `GET /api/v1/notes?notebook_id=...&fields=meta` to load photos in designated galleries
- `POST /api/v1/notebooks` to create a gallery notebook
- `PATCH /api/v1/notebooks/:id` to rename a gallery or move it between stacks
- `POST /api/v1/files/upload` and `POST /api/v1/notes` to add one photo per note
- `DELETE /api/v1/notes/:id` to move a removed photo note to Harbor Trash
- `GET /api/v1/files/:hash?variant=medium` for a short-lived thumbnail URL
- `GET /api/v1/files/:hash` for a short-lived original-image URL

## Sensible next steps

1. Add date grouping and a map for photos whose notes contain location metadata.
2. Download/share originals from the detail view.
3. Add public sharing after deciding exactly how that should map to Harbor notes.
4. Replace a personal token with Harbor OAuth + PKCE if the app will be distributed to other people.
