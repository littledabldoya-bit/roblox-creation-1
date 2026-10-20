# Neon Circuit

Original instrumental composed for FartNight: 152 BPM, approximately 3:24, stereo.
The 128-bar arrangement changes between intro, lead sections, an airy bridge,
tension break, final drop and outro, with variations and fills. The source is
`tools/compose_music.py`; it synthesizes every sound without third-party samples
or recordings. The MP3 is mastered for background use near -16 LUFS with headroom.

## Activate it in Roblox

1. In Creator Hub, upload `NeonCircuit.mp3` as an audio asset under the account or
   group that owns the experience. Wait for moderation/processing to complete.
2. Grant the target experience permission to use the audio in its asset settings.
3. Copy the numeric audio asset ID to `Config.Music.SoundId` in
   `src/ReplicatedStorage/FN_Config.luau`.
4. Rebuild `fartnightv5.rbxlx` and republish the place. Confirm playback in Studio and
   in a private published server. Armory → Settings → Arena Music controls muting;
   opening the Armory reduces volume. Music does not restart on character respawn.

The user uploaded this track and supplied audio ID `86882641437260`, now configured
in FN_Config. Experience permission, moderation status and actual Roblox playback
have not been verified from this workspace. Republish the updated place to activate it.

To regenerate locally, install NumPy 2.3.5 and FFmpeg, then run
`python3 tools/compose_music.py` from the repository. Normal game builds reuse the
committed MP3 and do not require composition tools.
