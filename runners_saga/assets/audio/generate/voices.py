import io
import os
from pydub import AudioSegment
from google.cloud import texttospeech
from google.oauth2 import service_account
import xml.etree.ElementTree as ET

# -------------------------------
# Configuration
# -------------------------------
THIS_DIR = os.path.dirname(os.path.abspath(__file__))
SSML_FILE = os.path.join(THIS_DIR, "episode2.ssml")
OUTPUT_FILE = os.path.join(THIS_DIR, "episode2_final.wav")

# Map characters to Google voices
VOICE_MAP = {
    # Names match SSML <voice name="..."> values used in episode2.ssml
    "Riley": "en-US-Wavenet-F",
    "Maya": "en-US-Wavenet-D",
    "CommanderMorrison": "en-US-Wavenet-B",
    "Tommy": "en-US-Wavenet-C",
    "DrChen": "en-US-Wavenet-A",
    "HostileLeader": "en-US-Wavenet-B",
    "HostileMember": "en-US-Wavenet-F",
    "Narrator": "en-US-Wavenet-D",
    "MysteriousVoice": "en-US-Wavenet-B",
    "SecondVoice": "en-US-Wavenet-F",
    "SettlementVoice": "en-US-Wavenet-D",
}

# Optional: Map <audio src="..."/> to local files for background/foley
AUDIO_MAP = {
    "footsteps_drip.wav": "sounds/footsteps_drip.wav",
    "footstep_caution.wav": "sounds/footstep_caution.wav",
    "splash_echo.wav": "sounds/splash_echo.wav",
    "fast_footsteps.wav": "sounds/fast_footsteps.wav",
    "gear_shift.wav": "sounds/gear_shift.wav"
}

# -------------------------------
# Initialize Google TTS client (with local service account fallback)
# -------------------------------
def _build_tts_client() -> texttospeech.TextToSpeechClient:
    # If ADC is already configured, use it
    if os.environ.get("GOOGLE_APPLICATION_CREDENTIALS"):
        return texttospeech.TextToSpeechClient()

    # Fallback to local service account file in this directory
    this_dir = os.path.dirname(os.path.abspath(__file__))
    sa_path = os.path.join(this_dir, "runners-saga-app.json")
    if os.path.exists(sa_path):
        creds = service_account.Credentials.from_service_account_file(sa_path)
        return texttospeech.TextToSpeechClient(credentials=creds)

    # As a final fallback, try default (will raise a clear error if not configured)
    return texttospeech.TextToSpeechClient()

client = _build_tts_client()

# -------------------------------
# Parse SSML
# -------------------------------
tree = ET.parse(SSML_FILE)
root = tree.getroot()

# Final audio segment
final_audio = AudioSegment.silent(duration=0)

def synthesize_ssml_line(ssml_text, voice_name):
    """Synthesize a single SSML line to AudioSegment"""
    synthesis_input = texttospeech.SynthesisInput(ssml=ssml_text)
    voice = texttospeech.VoiceSelectionParams(
        language_code="en-US",
        name=voice_name
    )
    audio_config = texttospeech.AudioConfig(
        audio_encoding=texttospeech.AudioEncoding.LINEAR16,
        sample_rate_hertz=24000,
    )
    
    response = client.synthesize_speech(
        input=synthesis_input,
        voice=voice,
        audio_config=audio_config
    )
    
    audio_segment = AudioSegment.from_raw(
        io.BytesIO(response.audio_content),
        sample_width=2,
        frame_rate=24000,
        channels=1
    )
    return audio_segment

# -------------------------------
# Process: synthesize all <voice> elements found anywhere in the SSML
# -------------------------------
for voice_el in root.iter("voice"):
    character = voice_el.attrib.get("name", "Narrator")
    ssml_text = ET.tostring(voice_el, encoding="unicode", method="xml")
    voice_name = VOICE_MAP.get(character, VOICE_MAP["Narrator"])  # default if unmapped
    tts_audio = synthesize_ssml_line(ssml_text, voice_name)
    final_audio += tts_audio

# Optional: mix in any top-level <audio> elements if present
for audio_el in root.iter("audio"):
    src_file = audio_el.attrib.get("src")
    if src_file in AUDIO_MAP:
        try:
            audio_clip = AudioSegment.from_file(AUDIO_MAP[src_file])
            final_audio += audio_clip
        except Exception as e:
            print(f"Warning: failed to load audio {src_file}: {e}")

# -------------------------------
# Export final WAV
# -------------------------------
final_audio.export(OUTPUT_FILE, format="wav")
print(f"Episode 2 synthesized successfully as {OUTPUT_FILE}")
