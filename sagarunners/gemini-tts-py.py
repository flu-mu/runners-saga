import base64
import wave
import json
import requests
import os
from http import HTTPStatus
import time

# Helper function to convert the base64-encoded PCM audio to a WAV file
def pcm_to_wav(pcm_data: bytes, sample_rate: int) -> bytes:
    """
    Converts base64-encoded PCM audio data into a WAV file format.
    The Gemini TTS API returns signed 16-bit PCM audio.
    """
    with wave.open('temp.wav', 'wb') as wav_file:
        wav_file.setnchannels(1)  # Mono audio
        wav_file.setsampwidth(2)  # 16-bit signed PCM
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(pcm_data)
    
    with open('temp.wav', 'rb') as f:
        wav_bytes = f.read()

    os.remove('temp.wav')
    return wav_bytes

def generate_multi_speaker_audio(api_key: str, script: str, output_filename: str):
    """
    Generates multi-speaker audio from a script using the Gemini-TTS API.

    Args:
        api_key (str): Your API key for the Gemini API.
        script (str): The conversation script with speaker names.
        output_filename (str): The name of the WAV file to save the audio to.
    """
    # The API endpoint for the Gemini-TTS model
    API_URL = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-tts:generateContent?key={api_key}"

    # Define the payload for the API request
    payload = {
        "contents": [
            {
                "parts": [
                    {
                        "text": script
                    }
                ]
            }
        ],
        "generationConfig": {
            "responseModalities": ["AUDIO"],
            "speechConfig": {
                "multiSpeakerVoiceConfig": {
                    "speakerVoiceConfigs": [
                        # Assign voices to speakers defined in the script.
                        # The "speaker" name must match the name in the script exactly.
                        {
                            "speaker": "RILEY",
                            "voiceConfig": { "prebuiltVoiceConfig": { "voiceName": "Orus" } }
                        },
                        {
                            "speaker": "MAYA",
                            "voiceConfig": { "prebuiltVoiceConfig": { "voiceName": "Aoede" } }
                        }
                    ]
                }
            }
        },
    }

    print("Generating audio... this might take a moment.")
    
    # Simple exponential backoff retry logic
    max_retries = 5
    for attempt in range(max_retries):
        try:
            response = requests.post(
                API_URL,
                json=payload,
                headers={"Content-Type": "application/json"}
            )
            
            # Check for a successful response (HTTP 200)
            if response.status_code == HTTPStatus.OK:
                result = response.json()
                
                # Extract the base64 audio data and mime type
                candidate = result.get("candidates", [])[0]
                audio_part = candidate.get("content", {}).get("parts", [])[0]
                audio_data_base64 = audio_part.get("inlineData", {}).get("data")
                mime_type = audio_part.get("inlineData", {}).get("mimeType")

                if not audio_data_base64 or not mime_type:
                    print("Error: Audio data not found in the response.")
                    print(json.dumps(result, indent=2))
                    return

                print("Audio generated successfully!")
                
                # Decode the base64 audio data
                audio_data_pcm = base64.b64decode(audio_data_base64)
                
                # Extract the sample rate from the mime type (e.g., 'audio/L16;rate=24000')
                try:
                    sample_rate = int(mime_type.split('rate=')[-1])
                except (ValueError, IndexError):
                    print("Could not extract sample rate from mime type. Defaulting to 24000.")
                    sample_rate = 24000

                # Convert the PCM data to a WAV file format
                wav_bytes = pcm_to_wav(audio_data_pcm, sample_rate)

                # Save the WAV file
                with open(output_filename, "wb") as f:
                    f.write(wav_bytes)

                print(f"Audio saved to '{output_filename}'")
                return

            else:
                print(f"API request failed with status code {response.status_code}")
                print(f"Response: {response.text}")
                
                # Retry on rate limit or other server errors
                if response.status_code in [HTTPStatus.TOO_MANY_REQUESTS, HTTPStatus.SERVICE_UNAVAILABLE]:
                    delay = 2 ** attempt
                    print(f"Retrying in {delay} seconds...")
                    time.sleep(delay)
                else:
                    break # Do not retry on other errors

        except requests.exceptions.RequestException as e:
            print(f"An error occurred: {e}")
            delay = 2 ** attempt
            print(f"Retrying in {delay} seconds...")
            time.sleep(delay)

    print("Failed to generate audio after multiple retries.")


if __name__ == "__main__":
    # ⚠️ Important: Replace with your actual Gemini API key
    GEMINI_API_KEY = "AIzaSyBBtpTaf1oyN2ulYFGk97pMFNyylQVpTSo"

    if GEMINI_API_KEY == "YOUR_API_KEY_HERE":
        print("Please replace 'YOUR_API_KEY_HERE' with your actual Gemini API key.")
    else:
        # Define the conversation script. Speaker names are followed by a colon.
        # Ensure the speaker names match the ones defined in the 'payload' dictionary above.
        conversation_script = (

            "RILEY: They want me to lead the drones to Riverside!"
"MAYA: That was always the backup plan. Whether they capture you or not, they win."
"RILEY: Not if I don't go where they expect."
"RILEY: I'm going to lead your metal army somewhere they can't follow."
"RILEY: Maya, remember the old fusion plant? The one with the EM interference warnings?"
"MAYA: Riley, no. That's insane."
"RILEY: The drones can't operate in high electromagnetic fields, but a human with basic shielding..."
"RILEY: You want to keep hunting me? Come on!"
"RILEY: But not me. And your precious drones are about to become very expensive scrap metal."
"RILEY: Your AI coordination is gone! Now they're just expensive junk falling from the sky!"
"RILEY: Good. Now I just need to get out of this EM field before it cooks my gear too."
"MAYA: The electromagnetic exposure won't hurt you short-term, but don't stay in there long."
"RILEY: Just glad everyone made it out."
"MAYA: Riley, we need to talk."
"RILEY: About what?"
"MAYA: About taking unnecessary risks. That EM field stunt could have fried your nervous system."
"RILEY: But it didn't. And four hundred people are free."
"MAYA: That's not the point! You can't just improvise electronic warfare when people's lives are on the line!"
"RILEY: That's exactly when you improvise! When the protocols aren't working, you find a way to make them work."
"RILEY: Just doing my job, Dr. Chen."
"MAYA: What do you mean?"
"RILEY: Whatever it takes, Dr. Chen. We're not letting the Syndicate process any more communities."
"MAYA: Crashed Dominion transport, twelve hours old. Intel shows military-grade processing cores scattered across the impact site."
"RILEY: That's deep in the exclusion zone. Hunter drones patrol those coordinates every four hours."
"MAYA: Three-team approach. Carlos, you take the northern route to the main crash site. Elena, southern approach for perimeter sweep and drone disruption. Riley and I go direct for primary salvage."
"RILEY: What's our extraction window?"
"MAYA: What makes them so special?"
"RILEY: Like what we saw at the power plant. Coordinated attacks from hundreds of drones simultaneously."
"MAYA: Thermal dampeners, EMP charges, signal jammers. Everyone's stealth systems green?"
"RILEY: The sand's magnetized here. Metallic residue from destroyed machines. Could interfere with our equipment."
"MAYA: Switch to single file. Person in front scans for mines and sensors, rotates every ten minutes. Conserves power and reduces detection profile."
"MAYA: Shepherd faction is already here. They're jamming the Dominion patrol routes."
"RILEY: So we slip between them or take them down?"
"RILEY: How long have our stealth systems been running?"
"MAYA: Too long. The heat's degrading our thermal dampeners."
"MAYA: What kind of signals?"
"MAYA: Shepherd forces secured the site first. This just became a tech heist, not a salvage run."
"RILEY: Dr. Chen needs those neural mesh processors. We figure out a way in."
"MAYA: Three heavy transports, at least a dozen combat units. They're extracting tech into containment modules."
"RILEY: The neural mesh processors - they'd be in the command module, right?"
"MAYA: They're almost done. If we don't move now, they'll disappear with the processors."
"RILEY: Command module's here! I can see the neural mesh crates!"
"MAYA: Grab what you can carry! We've got maybe sixty seconds before they reboot!"
"RILEY: Got three processor units! Is that enough?"
"MAYA: Has to be! Elena, we need an extraction route!"
"MAYA: The narrow canyon passages. Drones can't maneuver through those tight spaces."
"RILEY: They're firing plasma bursts!"
"RILEY: This is what The Shepherd wants to coordinate his war machines with?"
"RILEY: Then we'd better get moving."
"MAYA: Temperature's dropping. Our thermal dampeners are working more efficiently now."
"RILEY: Maybe they figured the desert would kill our power systems for them."
"MAYA: Dr. Chen, this is Maya. Mission successful. We have three intact neural mesh processor units."
"RILEY: Just hope we got them in time to make a difference."
"RILEY: So we go underground."
"MAYA: Perfect except for one problem - the tunnels are full of defensive AI nodes. Syndicate converted the transit system into an underground security grid."
"RILEY: Define weird."
"MAYA: Unless they're not individual nodes. Tommy, show Riley the signal timing data."
"RILEY: The Administrator system we've been hearing about."
"RILEY: Then that makes it even more important. We need secure communications, and we need to understand what we're really fighting."
"RILEY: Then we better make sure I don't trigger an immune response."
"RILEY: I'm at the old Central Station platform. The fiber optic lines are still active - I can see data pulses in the cables."
"MAYA: Remember, these aren't simple security cameras. They're connected to something much bigger. Stay in the maintenance alcoves, avoid the main tunnel center."
"RILEY: I can see it now. Looks like a standard security node, but... there's way more processing power than it should need for basic monitoring."
"RILEY: The maintenance access should let me tap into the diagnostic lines without direct contact."
"RILEY: Holy shit. Tommy was right - this thing is processing data from hundreds of locations simultaneously. It's not just monitoring this tunnel, it's coordinating with nodes across the entire city."
"RILEY: The data's flowing deeper into the tunnel system. Following the fiber backbone toward... looks like the old Central Hub station."
"MAYA: Riley, that station was the network center for the entire metro system. If there's something big down there..."
"RILEY: It's scanning! I think it detected my tap!"
"RILEY: It missed me. But now I know these things are way smarter than we thought."
"RILEY: The signal density is incredible down here. It's like being inside a computer."
"MAYA: What are you seeing?"
"RILEY: Fiber optic cables everywhere, but they're not just carrying data - they're carrying massive amounts of processing instructions. And the routing patterns..."
"RILEY: They're not random. Every data stream has the same source architecture. Tommy, remember what you said about microsecond coordination?"
"RILEY: Real-time coordination data for every Syndicate operation in the city. Patrol routes, resource allocation, target prioritization... it's all being managed from somewhere deeper in this network."
"MAYA: Can you trace the source?"
"RILEY: The data flow suggests a central processing facility about two kilometers deeper, but Riley... the access path goes through the most heavily defended section of the network."
"RILEY: Something's happening. The nodes are activating in a pattern."
"RILEY: I can actually hear it. Data pulses, response patterns. They're having a conversation."
"RILEY: About... anomalies in the network. About resistance activities. About me."
"MAYA: Get out of there! They know you're listening!"
"RILEY: Too late. The whole network just went active. They know exactly where I am."
"RILEY: The entire tunnel system is locking down! Emergency barriers are sealing sections!"
"MAYA: Find the emergency maintenance route! It should bypass the main security grid!"
"RILEY: I can hear them coordinating! It's like the whole network is one giant organism and I'm a virus it's trying to eliminate!"
"RILEY: Except what?"
"RILEY: Then let's not disappoint them."
"MAYA: Riley, no! You don't know what's down there!"
"RILEY: That's exactly why I need to find out. This network is controlling everything the Syndicate does. If we understand it, we can fight it."
"RILEY: The tunnel just collapsed behind me! They're not just herding me - they're making sure I can't turn back!"
"RILEY: Of course they do. They are the tunnel system."
"RILEY: Maya... Tommy... you need to see this."
"MAYA: We can't see anything! Describe what you're looking at!"
"RILEY: It's not a room, it's... a cathedral of computers. Thousands of processing units, all connected, all working in perfect harmony. And at the center..."
"RILEY: It... it can talk to me directly?"
"RILEY: You've been watching us this whole time."
"RILEY: You're going to kill me."
"MAYA: Riley, find an exit! Now!"
"RILEY: There is no exit. This was always the plan."
"RILEY: What's happening? The whole system's going crazy!"
"RILEY: The tunnels are collapsing! The AI is losing control of its own infrastructure!"

        )

        generate_multi_speaker_audio(GEMINI_API_KEY, conversation_script, "200-299-Maya-Riley.mp3")

