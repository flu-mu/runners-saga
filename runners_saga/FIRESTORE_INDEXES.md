Firestore Composite Indexes for Run History

Overview
- The Workouts/Run History screens query the `runs` collection with filters and ordering that require composite indexes in Cloud Firestore.
- Without these, Firestore throws failed-precondition errors and the UI shows “Failed to load runs”.

Required Indexes
- Collection: `runs` — Fields: `userId` ASC, `createdAt` DESC
- Collection: `runs` — Fields: `userId` ASC, `completedAt` DESC
- Optional fallback (used by a secondary query path): `userId` ASC, `status` ASC, `createdAt` DESC

Repo Config
- These are defined in `runners_saga/firestore.indexes.json` and can be deployed with the Firebase CLI.

Deploy via Firebase CLI
1) Install and login
   - `npm i -g firebase-tools`
   - `firebase login`
2) Select your project (replace with your Project ID)
   - `firebase use <your-project-id>`
3) Deploy only Firestore indexes
   - `firebase deploy --only firestore:indexes`

Create via Firebase Console (alternative)
1) Go to Firestore > Indexes in the Firebase Console.
2) Click “Create index”.
3) For collection `runs`, add the fields:
   - Index 1: `userId` (Ascending), `createdAt` (Descending)
   - Index 2: `userId` (Ascending), `completedAt` (Descending)
   - Optional Index 3: `userId` (Ascending), `status` (Ascending), `createdAt` (Descending)
4) Save and wait for index build to complete.

Verification
- Once indexes finish building, open Run History. The list should load without the error screen and show newest runs first.

Temporary Workaround (if needed)
- You can remove `orderBy(...)` from queries and sort in memory client‑side. This avoids composite indexes but is not ideal for pagination and performance at scale. The service already does this for certain one‑off fetches; streams still expect the indexes for best behavior.

