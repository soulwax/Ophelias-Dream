"""Validation and contextual prompt assembly for conversational TTS auditions."""
import math
from studio import model

QWEN_SPEAKERS = {"Vivian", "Serena", "Uncle_Fu", "Dylan", "Eric", "Ryan", "Aiden", "Ono_Anna", "Sohee"}
CAST = {"ophelia": "Ophelia", "mathilda": "Mathilda"}


def normalize(payload):
    """Accept only a compact, bounded chain of known cast voices and TTS speakers."""
    if not isinstance(payload, dict):
        raise ValueError("conversation request must be an object")
    context = str(payload.get("context", "")).strip()[:900]
    raw_turns = payload.get("turns")
    if not isinstance(raw_turns, list) or not 2 <= len(raw_turns) <= 8:
        raise ValueError("a conversation chain needs between 2 and 8 turns")
    turns = []
    for index, raw in enumerate(raw_turns, start=1):
        if not isinstance(raw, dict):
            raise ValueError(f"turn {index} is invalid")
        speaker = str(raw.get("speaker", "")).lower()
        mood = str(raw.get("mood", "steady"))
        text = str(raw.get("text", "")).strip()[:600]
        if speaker not in CAST or mood not in model.MOODS or not text:
            raise ValueError(f"turn {index} needs a cast speaker, known mood, and text")
        voice = str(raw.get("voice", "Serena"))
        if voice not in QWEN_SPEAKERS:
            raise ValueError(f"turn {index} has an unsupported Qwen speaker")
        turns.append({
            "uid": str(raw.get("uid", ""))[:100], "speaker": speaker, "mood": mood, "text": text,
            "voice": voice, "direction": str(raw.get("direction", "")).strip()[:320],
        })
    raw_profiles = payload.get("profiles", {})
    profiles = {}
    for speaker in CAST:
        profiles[speaker] = str(raw_profiles.get(speaker, "")).strip()[:400] if isinstance(raw_profiles, dict) else ""
    try:
        variants = min(max(int(payload.get("variants", 2)), 1), 3)
        seed = min(max(int(payload.get("seed", 1)), 1), 2_147_483_000)
        temperature = min(max(float(payload.get("temperature", 0.85)), 0.55), 1.2)
        if not math.isfinite(temperature):
            raise ValueError("temperature must be finite")
    except (TypeError, ValueError) as error:
        raise ValueError("variants and seed must be whole numbers; temperature must be numeric") from error
    return {"context": context, "turns": turns, "profiles": profiles, "variants": variants,
            "seed": seed, "temperature": temperature}


def instruction(context, profiles, history, turn, turn_number, turn_count):
    """Give each isolated TTS call enough conversation to shape its response."""
    name = CAST[turn["speaker"]]
    profile = profiles.get(turn["speaker"]) or f"A natural, intimate female voice for {name}; restrained and emotionally truthful."
    parts = [f"Speaker identity: {profile}"]
    if context:
        parts.append(f"Scene context: {context}")
    if history:
        exchanges = [f'{CAST[speaker]} ({mood}) said: “{text[:240]}”' for speaker, mood, text in history[-4:]]
        parts.append("Conversation immediately before this line: " + " Then: ".join(exchanges))
    parts.append(f"This is {name}'s response, turn {turn_number} of {turn_count}. Listen emotionally to the preceding exchange; continue its subtext and relationship, and respond to what was actually said. Do not repeat or narrate the earlier lines.")
    parts.append(f"Current emotional direction: {turn['direction'] or turn['mood']}. Keep the delivery specific, varied, and conversational rather than stage-like.")
    return " ".join(parts)[:2600]
