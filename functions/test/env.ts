/**
 * Deployed functions read their default Storage bucket from FIREBASE_CONFIG.
 * Under the emulators it may lack one, so tests give it the demo project's.
 */
const project = process.env.GCLOUD_PROJECT ?? 'demo-crewpoint';
const config = process.env.FIREBASE_CONFIG ? JSON.parse(process.env.FIREBASE_CONFIG) : {};
if (!config.storageBucket) {
  process.env.FIREBASE_CONFIG = JSON.stringify({
    projectId: project,
    ...config,
    storageBucket: `${project}.appspot.com`,
  });
}
