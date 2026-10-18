# Draft 1.1: Voice mode

**Status:** parked, name only. No design yet. **Held:** excluded from "deploy all drafts".
**Trigger to revisit:** Skintel Stripe revenue reaches $5,000 (see `README.md`), or the founder asks.

The founder asked to keep this as a separate draft from 1.0 and gave no details yet. Presumably it is talking
to Ask Skintel by voice, but that is a guess; ask before designing.

## Open questions

- Where does it live: Ask Skintel only, or also scanning and logging?
- Speech in, speech out, or both? On-device speech recognition, or a server model?
- Free or Skintel+ only? Voice adds API cost per turn.
- Microphone and speech permissions need usage strings, App Privacy answers and a privacy policy update.
  Read `docs/APP_REVIEW_NOTES.md` first.
- Voice goes to the same AI providers as typed text, so it needs the same AI consent (`AIConsent`).
