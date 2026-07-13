# Example — guiding the AI to the right command

GLIA doesn't fire off a command and give up when it fails. It shows you every
command *before* it runs, and when something doesn't work you can hand it a
hint — in plain words — and it refines its answer. Hints **add up**, so the
assistant closes in on the right command *with* you, not instead of you.

Here is a real session (host names and addresses changed). The goal: reach a
home media server that the user only knows by a short name.

```console
$ glia ping the media server

Thinking...
Proposed command:  ping mediahub
Enter = run | n = cancel | r = retry:
ping: mediahub: Name or service not known
The command failed (exit 2).
Enter = fix | type a hint for the AI | n = quit: it's a host I reach over ssh

Thinking...
Proposed command:  ping mediahub
Enter = run | n = cancel | r = retry:
ping: mediahub: Name or service not known
The command failed (exit 2).
Enter = fix | type a hint for the AI | n = quit: check my ssh setup, it resolves via mDNS

Thinking...
Proposed command:  ping mediahub.local
Enter = run | n = cancel | r = retry:
PING mediahub.local (fe80::a11:22ff:fe33:4455%eth0) 56 data bytes
64 bytes from mediahub.local: icmp_seq=1 ttl=64 time=103 ms
64 bytes from mediahub.local: icmp_seq=2 ttl=64 time=8.29 ms
64 bytes from mediahub.local: icmp_seq=3 ttl=64 time=5.66 ms
```

## What just happened

- You asked in plain language; GLIA turned it into a real command and **showed
  it first** — you approve, then it runs.
- The command failed, and instead of a dead end GLIA offered to try again *with
  your help*.
- You added two hints ("it's an ssh host", "it resolves via mDNS"). They
  **accumulate**: the second attempt still remembers the first.
- With that context the model corrected `mediahub` → `mediahub.local`, and the
  ping went through.

Nothing here is magic: you stayed in control the whole time, and along the way
you learned that this host answers on its `.local` mDNS name.

## Make it stick

So you don't have to re-explain it next time, teach it to GLIA once:

```console
$ glia --remember "mediahub is reachable as mediahub.local (mDNS)"
```

Now that fact travels with every request, and GLIA will reach for
`mediahub.local` on the first try. And if it's a command you run often, save the
working one as a shortcut right after it succeeds:

```console
$ glia -a save
```

Next time it's just:

```console
$ glia -a mediahub
```

no AI needed.
