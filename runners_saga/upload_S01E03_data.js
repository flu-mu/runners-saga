// Upload script for S01E03 with correct Firebase Storage URL
const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./runners-saga-app-firebase-adminsdk-fbsvc-d64ba6b8cb.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'runners-saga-app'
});

const db = admin.firestore();

// Episode data with properly encoded URL (notice %2F instead of /)
const episodeData = {
  audioFile: 'https://firebasestorage.googleapis.com/v0/b/runners-saga-app.firebasestorage.app/o/audio%2Fepisodes%2FS01E03%2FS01E03.mp3?alt=media&token=ac56d2b9-c95d-4020-8202-d964f912706c',
  sceneTimestamps: [
    {
      sceneType: "missionBriefing",
      startTime: "0:00",
      endTime: "0:09",
      startSeconds: 0,
      endSeconds: 9
    },
    {
      sceneType: "theJourney", 
      startTime: "0:10",
      endTime: "0:19",
      startSeconds: 10,
      endSeconds: 19
    },
    {
      sceneType: "firstContact",
      startTime: "0:20", 
      endTime: "0:29",
      startSeconds: 20,
      endSeconds: 29
    },
    {
      sceneType: "theCrisis",
      startTime: "0:30",
      endTime: "0:39", 
      startSeconds: 30,
      endSeconds: 39
    },
    {
      sceneType: "extractionDebrief",
      startTime: "0:40",
      endTime: "0:49",
      startSeconds: 40,
      endSeconds: 49
    }
  ]
};

// Upload the data
async function uploadEpisodeData() {
  try {
    console.log('🚀 Uploading S01E03 episode data...');
    
    // Update the S01E03 document
    await db.collection('episodes').doc('S01E03').update(episodeData);
    
    console.log('✅ S01E03 episode data uploaded successfully!');
    console.log('🎵 Single audio file mode should now work with proper URL encoding');
    console.log('📁 Audio file: S01E03.mp3 (488KB)');
    
  } catch (error) {
    console.error('❌ Error uploading data:', error);
  }
  
  process.exit(0);
}

uploadEpisodeData();























