# Guided notification setup

Walk the user through connecting their phone, assuming they have never heard of ntfy or Pushover. Keep it warm and one step at a time; never paste both providers' full instructions at once. This same guide is used from the first-run `/playbook:setup` and the first time offline mode needs a channel.

Notifications are configured once for the whole machine: write the files under `~/.claude/playbook/` so every project can use them (a single project can override later with its own `.claude/playbook/` files). Always finish by sending a real test ping and confirming it landed.

## Step 1: which phone?

Ask **iPhone or Android?** before anything else. The answer changes both the recommendation and the ntfy steps.

## Step 2: explain the two options, then recommend

Put it in plain words, no jargon:

- **ntfy is free.** A free app. Playbook makes you a private, unguessable channel that only your phone is subscribed to. On Android it can wake you even through Do Not Disturb; on iPhone it can ping you, but Apple will not let it force through Do Not Disturb or a Focus.
- **Pushover is a one-off ~$5** (free for 30 days, then a one-time purchase on the app store, not a subscription). It is tied to your account, and on iPhone it can break through Do Not Disturb with Critical Alerts.

Then recommend by phone:

- **Android:** suggest ntfy. It is free and wakes them fully.
- **iPhone:** if they only want a heads-up, ntfy is free and fine; if they need to be certain it wakes them, for overnight or long unattended runs, Pushover's one-off cost is worth it.

Ask which they want, or whether to skip for now.

## Step 3a: ntfy

1. **Install the app.** iPhone: the App Store. Android: Google Play or F-Droid. Tell them to search "ntfy".
2. **Generate the private channel**, a 32-character random string with no dictionary words so it cannot be guessed. This self-checks the length and falls back to `openssl` if the first method comes up short:
   ```bash
   topic="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)"
   [ "${#topic}" -eq 32 ] || topic="$(openssl rand -base64 48 | LC_ALL=C tr -dc 'A-Za-z0-9' | head -c 32)"
   echo "$topic"
   ```
   Confirm it printed a full 32 characters before saving. If both methods somehow come up short, say so and stop rather than saving a weak channel.
3. **Save it** globally and set the provider:
   ```bash
   mkdir -p ~/.claude/playbook
   printf '%s\n' "$topic" > ~/.claude/playbook/ntfy-topic
   printf 'ntfy\n'        > ~/.claude/playbook/notify-provider
   ```
4. **Tell them it is the only lock.** ntfy channels are not password protected, so this random name is the sole thing keeping the notifications private. Treat it like a password: do not paste it into a repo, an issue, or a public chat.
5. **Subscribe the phone.** Copy-paste is the reliable path on both phones and is never skipped; the QR is only an optional Android shortcut and must never be the sole method. Show the channel name in a code block so it is easy to copy.
   - **Copy-paste (both phones, always works):** open ntfy, tap the plus button or "Subscribe to topic", paste this exactly into the Topic field, leave the server as the default `ntfy.sh`, and tap Subscribe.
   - **Android shortcut (optional):** on Android they can instead scan a QR with the phone camera. Render it locally in the terminal, never through an online QR service, since it encodes the secret channel, and let it fail soft:
     ```bash
     qrencode -m 2 -t ANSIUTF8 "ntfy://ntfy.sh/${topic}" 2>/dev/null || echo "(QR unavailable, use the copy-paste channel above)"
     ```
     If `qrencode` is missing you may offer to install it with consent (`brew install qrencode`, `apt-get install qrencode`, `dnf install qrencode`, or `pacman -S qrencode`), but never block on it. The `ntfy://` deep link is Android only, so do not show a QR on iPhone, and if it is absent, does not render, or will not scan, just fall back to copy-paste.
6. **Wait** until they confirm the app lists the subscription, then send the test in Step 4. The test is what actually proves it worked, so run it whichever way they subscribed.

## Step 3b: Pushover

1. **Install the app** and mention it costs a one-off ~$5 after a 30-day free trial. iPhone: App Store. Android: Google Play. Tell them to search "Pushover".
2. **Create an account** in the app. Its main screen shows a **User Key**, a 30-character code. Ask them to paste it here, then save it:
   ```bash
   mkdir -p ~/.claude/playbook
   printf '%s\n' "<user-key>" > ~/.claude/playbook/pushover-user
   ```
3. **Register an application** so Playbook can send: visit `https://pushover.net/apps/build`, name it something like "Claude Code", create it, and copy the **API Token/Key**. Ask them to paste it, then save it and set the provider:
   ```bash
   printf '%s\n' "<api-token>" > ~/.claude/playbook/pushover-token
   printf 'pushover\n'        > ~/.claude/playbook/notify-provider
   ```
4. **Enable Critical Alerts** so it can wake them through Do Not Disturb: in the Pushover app settings turn on Critical Alerts and accept the iOS prompt. Without this, even the loudest alerts will not bypass Do Not Disturb.
5. Send the test in Step 4.

## Step 4: send a live test, and treat it as the safety net

This live test is what actually confirms the whole chain works, whichever way they subscribed, so it is also the recovery path when a subscribe shortcut like the Android QR silently does nothing. Always run it, and never report setup as complete until the user confirms the notification arrived.

Send one real notification with the plugin's notify script (the same one offline mode uses at `scripts/notify`):

```bash
scripts/notify --level info "Playbook is connected" "You'll get pings like this when offline mode needs you."
```

For Pushover you may send this test at `--level critical` instead, so they can confirm the Do Not Disturb bypass; warn them it will be loud.

Read the outcome and self-correct rather than moving on:

- **Exit 0 but nothing arrived:** the send succeeded, so the subscription did not take. For ntfy, re-check the channel was pasted exactly and the app lists it under the `ntfy.sh` server, then re-send; this is the usual outcome when an Android QR did not subscribe, so fall back to copy-paste and re-test. For Pushover, confirm the app is signed in.
- **Exit 4 (no config):** a topic or credential did not save. Re-write the file under `~/.claude/playbook/`, confirm it reads back the expected value, then re-send.
- **Exit 3 (publish failed):** a network or provider error. Retry once, and check the token or topic for stray spaces or newlines.
- **Exit 5 (curl missing):** install `curl`, then re-send.

Loop until the user confirms it landed. Only then is notification setup done. If they genuinely cannot get it working, leave the saved config in place, tell them plainly it is not yet delivering, and point them at re-running `/playbook:setup` later.
