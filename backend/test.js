// test.js
const BACKEND_URL = 'http://localhost:4000/api/v1/media/tracks/3IoDK8qI';

async function testTrackRoute() {
  console.log(`🚀 Sending test request to: ${BACKEND_URL}...\n`);

  try {
    const response = await fetch(BACKEND_URL);
    
    if (!response.ok) {
      throw new Error(`HTTP Error! Status: ${response.status}`);
    }

    const trackData = await response.json();

    console.log('✅ --- RECEIVING RESPONSE FROM FRONTEND PROXY ---');
    console.log(`📌 ID:             ${trackData.id}`);
    console.log(`📌 Title:          ${trackData.title}`);
    console.log(`📌 Artist:         ${trackData.artistName}`);
    console.log(`📌 Album:          ${trackData.albumTitle}`);
    console.log(`📌 Cover Art:      ${trackData.coverArtUrl}`);
    console.log(`📌 Format Badge:   ${trackData.formatBadge}`);
    console.log('--------------------------------------------------');
    console.log('🎵 TARGET AUDIO STREAM URL HOSTED ON CDN:');
    console.log(`👉 ${trackData.audioStreamUrl || '❌ EMPTY / NOT FOUND'}`);
    console.log('--------------------------------------------------\n');

    if (trackData.audioStreamUrl) {
      console.log('💡 Tip: Ctrl+Click or copy-paste the CDN link above into your browser.');
      console.log('If the audio streams perfectly there, your backend logic is fully verified!');
    }

  } catch (error) {
    console.error('❌ Test request execution failed:', error.message);
  }
}

// Execute the test run
testTrackRoute();