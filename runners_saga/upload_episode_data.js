// Quick Firebase Upload Script for S01E02
// Run this to upload your episode data instantly

const admin = require('firebase-admin');

// Initialize Firebase Admin (you'll need to get your service account key)
const serviceAccount = require('./runners-saga-app-firebase-adminsdk-fbsvc-d64ba6b8cb.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'runners-saga-app'
});

const db = admin.firestore();

// Your episode data
const episodeData = {
  audioFile: 'https://firebasestorage.googleapis.com/v0/b/runners-saga-app.firebasestorage.app/o/audio%2Fepisodes%2FS01E02%2FS01E02.mp3?alt=media&token=923b2927-1ca7-4388-b466-0e8c9d7b683c',
  sceneTimestamps: [
    {
      sceneType: "missionBriefing",
      startTime: "0:00",
      endTime: "0:07",
      startSeconds: 0,
      endSeconds: 7
    },
    {
      sceneType: "theJourney",
      startTime: "0:08",
      endTime: "2:06",
      startSeconds: 8,
      endSeconds: 126
    },
    {
      sceneType: "firstContact",
      startTime: "2:07",
      endTime: "3:52",
      startSeconds: 127,
      endSeconds: 232
    },
    {
      sceneType: "theCrisis",
      startTime: "3:53",
      endTime: "5:28",
      startSeconds: 233,
      endSeconds: 328
    },
    {
      sceneType: "extractionDebrief",
      startTime: "5:29",
      endTime: "6:40",
      startSeconds: 329,
      endSeconds: 400
    }
  ]
};

// Upload the data
async function uploadEpisodeData() {
  try {
    console.log('🚀 Uploading episode data...');
    
    // Update the S01E02 document
    await db.collection('episodes').doc('S01E02').update(episodeData);
    
    console.log('✅ Episode data uploaded successfully!');
    console.log('🎵 Single audio file mode should now work automatically');
    
  } catch (error) {
    console.error('❌ Error uploading data:', error);
  }
  
  process.exit(0);
}

uploadEpisodeData();
