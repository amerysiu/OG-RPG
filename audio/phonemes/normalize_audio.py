import os
import shutil

# Folder configuration paths
SOURCE_DIR = "./audio/phonemes/"
TARGET_DIR = "./audio/phonemes/"

# Phoneme library mapping matrix: Translates Freesound codes to clean OG values
PHONEME_MAP = {
    "pp": "p", "tt": "t", "kk": "k", "ss": "s", "ff": "f", "ll": "l",
    "mm": "m", "nn": "n", "rr": "r", "hh": "h", "jj": "j", "vvv": "v",
    "zzz": "z", "shh": "sh", "wuh": "w", "yyuh": "y", "kss": "x",
    "ahh": "a",  # Short a as in cat
    "eh": "e",   # Short e as in bed
    "ih": "i",   # Short i as in bin
    "ohh": "o",  # Short o as in hop
    "uh": "u",   # Short u as in sun
    "ck": "ck", "ch": "ch", "th": "th", "wh": "wh"
}

def clean_and_rename_assets():
    if not os.path.exists(SOURCE_DIR):
        print(f"Error: Directory target path {SOURCE_DIR} missing.")
        return

    print("====================================================")
    # Target file scan array iteration loop
    for filename in os.listdir(SOURCE_DIR):
        if not filename.endswith(".wav") and not filename.endswith(".wav.wav"):
            continue
            
        # Parse the raw Freesound component token name
        if "__margo_heston__" in filename:
            raw_token = filename.split("__margo_heston__")[1]
            # Strip extra extensions safely
            clean_token = raw_token.replace(".wav.wav", "").replace(".wav", "").strip().lower()
            
            # Match tokens to unified shorthand keys
            if clean_token in PHONEME_MAP:
                new_name = f"{PHONEME_MAP[clean_token]}.wav"
                src_path = os.path.join(SOURCE_DIR, filename)
                dest_path = os.path.join(TARGET_DIR, new_name)
                
                shutil.copy2(src_path, dest_path)
                print(f"  [MAPPED] '{filename}' -> '{new_name}'")

    print("[SUCCESS] Freesound assets compiled into clean OG targets!")
    print("====================================================")

if __name__ == "__main__":
    clean_and_rename_assets()
