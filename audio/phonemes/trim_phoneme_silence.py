import os
import glob
from pydub import AudioSegment
from pydub.silence import detect_leading_silence

# Use an absolute base path or clear current directory marker to avoid double-nesting
TARGET_DIR = "./audio/phonemes"
SILENCE_THRESHOLD_DB = -50.0  

def trim_file_silence(file_path):
    try:
        sound = AudioSegment.from_file(file_path, format="wav")
        
        # Guard Clause: Check if the file is completely silent first
        if sound.max_dBFS == float('-inf') or sound.rms == 0:
            print(f"  [TEMPLATE] {os.path.basename(file_path)}: Clean silent placeholder. Leaving as-is for engine safety.")
            return

        # Measure leading and trailing silent boundaries
        start_trim = detect_leading_silence(sound, silence_threshold=SILENCE_THRESHOLD_DB)
        reversed_sound = sound.reverse()
        end_trim = detect_leading_silence(reversed_sound, silence_threshold=SILENCE_THRESHOLD_DB)
        
        duration = len(sound)
        trimmed_sound = sound[start_trim:(duration - end_trim)]
        
        if len(trimmed_sound) > 0:
            trimmed_sound.export(file_path, format="wav")
            print(f"  [TRIMMED] {os.path.basename(file_path)}: Front {start_trim}ms / Back {end_trim}ms cut.")
        else:
            print(f"  [SKIPPED] {os.path.basename(file_path)}: High background noise floor matches threshold boundaries.")
            
    except Exception as e:
        print(f"  [ERROR] Processing failed for template block {file_path}: {str(e)}")

def create_mock_phoneme_assets():
    required_sounds = [
        "cat", "hop", "bin", "mat", "sun", "pig", "fed", "cup", "map", "net",
        "stop", "frog", "flag", "plum", "spot", "drop", "skid", "clip", "plan",
        "fast", "tent", "hand", "lamp", "desk", "milk", "rust", "belt", "fond",
        "a", "e", "i", "o", "u", "sh", "ch", "th", "wh", "ck"
    ]
    
    mock_silence = AudioSegment.silent(duration=500)
    created_any = False
    
    for sound in required_sounds:
        file_path = os.path.join(TARGET_DIR, f"{sound}.wav")
        if not os.path.exists(file_path):
            mock_silence.export(file_path, format="wav")
            print(f"  Created placeholder: {sound}.wav")
            created_any = True
            
    if created_any:
        print("\n[INFO] Generated missing silent assets. Replace these placeholders with real voice recordings when ready!")

if __name__ == "__main__":
    print("====================================================")
    print("      OG PHONEME ENGINE - TRACK AUTO-INITIALIZER     ")
    print("====================================================")
    
    # Ensure targets directory exists properly without nesting
    os.makedirs(TARGET_DIR, exist_ok=True)
    
    # Double check if any real files are here or if we need placeholders
    wav_files = glob.glob(os.path.join(TARGET_DIR, "*.wav"))
    
    if not wav_files:
        print(f"\nNo assets found inside target directory: {os.path.abspath(TARGET_DIR)}")
        create_mock_phoneme_assets()
        wav_files = glob.glob(os.path.join(TARGET_DIR, "*.wav"))
        
    print(f"\nProcessing {len(wav_files)} target audio blocks...")
    for file in wav_files:
        trim_file_silence(file)
        
    print("====================================================")
    print("[SUCCESS] Audio environment initialization completed cleanly!")
