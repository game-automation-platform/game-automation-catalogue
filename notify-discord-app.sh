#!/usr/bin/env bash
#
# Announces a GAP app release on Discord. Posts one embed with the release
# notes' changelog -- everything above the first "---" line, minus the
# "### Changes" heading -- so the install instructions below it stay on the
# release page, which the embed links to.
#
# package-release.sh drafts the release; this runs when a human publishes it,
# so the changelog is the trimmed one, not the raw commit list.
#
# Usage: notify-discord-app.sh TITLE URL NOTES_FILE
#
# The webhook URL is read from $DISCORD_WEBHOOK_URL, never from the repo:
# anyone holding it can post to the channel.
#
# Requires: jq (https://jqlang.org), curl

set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "Usage: $0 TITLE URL NOTES_FILE" >&2
  exit 1
fi

title="$1"
url="$2"
notes_file="$3"

if [ -z "${DISCORD_WEBHOOK_URL:-}" ]; then
  echo "DISCORD_WEBHOOK_URL is not set; skipping the Discord announcement."
  exit 0
fi

# GitHub stores release bodies with CRLF when edited in the browser.
changes="$(tr -d '\r' < "$notes_file" \
  | awk '/^---[[:space:]]*$/ { exit } /^#+[[:space:]]*Changes[[:space:]]*$/ { next } { print }')"

# Same caps as notify-discord.sh: 256 for a title, 4096 for a description.
jq -n -c --arg title "$title" --arg url "$url" --arg changes "$changes" '
  {
    embeds: [{
      title: ($title | .[:256]),
      url: $url,
      description: ($changes | gsub("^\\s+|\\s+$"; "")
        | if . == "" then "See the release page for details." else . end
        | if length > 4096 then .[:4093] + "..." else . end),
      color: 5793266,
      footer: {text: "Update from the starter: Download and install the latest APK"}
    }]
  }' \
  | curl -fsS -o /dev/null -H 'Content-Type: application/json' --data-binary @- "$DISCORD_WEBHOOK_URL"
echo "Announced: $title"
