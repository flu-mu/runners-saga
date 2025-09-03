const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.cert('./runners-saga-app-firebase-adminsdk-fbsvc-d64ba6b8cb.json'),
  projectId: 'runners-saga-app'
});

const db = admin.firestore();

// S01E02 data with 5 separate audio files (you'll need to upload these files to Firebase Storage first)
const episodeData = {
  // Remove single file mode fields
  audioFile: null,
  sceneTimestamps: null,
  
  // Add multiple files mode
  audioFiles: [
    // You need to upload these 5 files to Firebase Storage and get their URLs
    // Replace these placeholder URLs with actual Firebase Storage URLs
    "https://firebasestorage.googleapis.com/v0/b/runners-saga-app.firebasestorage.app/o/audio%2Fepisodes%2FS01E02%2Fscene_1_mission_briefing.mp3?alt=media&token=PLACEHOLDER_TOKEN_1",
    "https://firebasestorage.googleapis.com/v0/b/runners-saga-app.firebasestorage.app/o/audio%2Fepisodes%2FS01E02%2Fscene_2_the_journey.mp3?alt=media&token=PLACEHOLDER_TOKEN_2", 
    "https://firebasestorage.googleapis.com/v0/b/runners-saga-app.firebasestorage.app/o/audio%2Fepisodes%2FS01E02%2Fscene_3_first_contact.mp3?alt=media&token=PLACEHOLDER_TOKEN_3",
    "https://firebasestorage.googleapis.com/v0/b/runners-saga-app.firebasestorage.app/o/audio%2Fepisodes%2FS01E02%2Fscene_4_the_crisis.mp3?alt=media&token=PLACEHOLDER_TOKEN_4",
    "https://firebasestorage.googleapis.com/v0/b/runners-saga-app.firebasestorage.app/o/audio%2Fepisodes%2FS01E02%2Fscene_5_extraction_debrief.mp3?alt=media&token=PLACEHOLDER_TOKEN_5"
  ],
  
  // Update metadata to reflect multiple files mode
  metadata: {
    audioDuration: "19:00", // Total duration of all 5 scenes
    audioDurationSeconds: 1140, // 19 minutes
    singleFileMode: false, // Changed to false
    multipleFileMode: true, // Added this
    sceneCount: 5,
    fileCount: 5
  }
};

// Upload the data
async function updateS01E02ToMultipleFiles() {
  try {
    console.log('🚀 Updating S01E02 to use multiple audio files mode...');
    
    // Update the S01E02 document
    await db.collection('episodes').doc('S01E02').update(episodeData);
    
    console.log('✅ S01E02 updated successfully!');
    console.log('🎵 Now using 5 separate audio files instead of single file');
    console.log('📁 Audio files: 5 separate scene files');
    console.log('⚠️  IMPORTANT: You need to upload the 5 audio files to Firebase Storage first!');
    console.log('📂 Upload path: audio/episodes/S01E02/');
    console.log('📝 File names:');
    console.log('   - scene_1_mission_briefing.mp3');
    console.log('   - scene_2_the_journey.mp3');
    console.log('   - scene_3_first_contact.mp3');
    console.log('   - scene_4_the_crisis.mp3');
    console.log('   - scene_5_extraction_debrief.mp3');
    
  } catch (error) {
    console.error('❌ Error updating S01E02:', error);
  }
  
  process.exit(0);
}

updateS01E02ToMultipleFiles();
