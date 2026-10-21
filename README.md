# ViraChat

A real-time chat application built with Phoenix LiveView.

## Features

- Private and group conversations, with group admin roles
- Real-time messages, typing indicators, presence and last seen
- Read receipts (sent / delivered / seen), unread counts and title badge
- Replies, edits, soft deletes, forwarding, stars, reactions and link previews
- Image uploads, voice notes, emoji picker and `@mention` autocomplete
- Conversation pin / mute / archive / clear, blocking and message reports
- Magic-link and password authentication, password reset, account settings
- Admin area: dashboard, users, conversations, reports queue and audit log
- Audio/video calls between two users over WebRTC

## Requirements

- Elixir 1.15+ and Erlang/OTP 26+
- PostgreSQL
- Node.js (only for the asset dependencies)

## Setup

```sh
mix setup
mix phx.server
```

Then visit [`localhost:4000`](http://localhost:4000).

To promote an account to superuser (needed for the first `/admin` login):

```sh
mix virachat.make_superuser you@example.com
```

## Web push notifications

Development VAPID keys live in `config/dev.exs`. To use your own pair (or in
production), generate one with:

```sh
mix generate.vapid.keys
```

and provide `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY` (and optionally
`VAPID_SUBJECT`) as environment variables. Without a key pair, push
notifications are skipped silently.

## Development

```sh
mix precommit   # compile with warnings as errors, format, and run the test suite
```

## Learn more

- Official website: https://www.phoenixframework.org/
- Guides: https://hexdocs.pm/phoenix/overview.html
- Docs: https://hexdocs.pm/phoenix
- Forum: https://elixirforum.com/c/phoenix-forum
