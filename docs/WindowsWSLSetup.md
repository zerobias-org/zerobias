# Claude Code on Windows (WSL) — setup guide

Everything in the `zerobias-org` repos runs **only on Ubuntu**. If you
are on Windows, the one and only supported path is **WSL 2 end-to-end**:
clone inside WSL, run `claude` inside WSL, and never touch the code
from the Windows side. This guide takes you from a bare Windows machine
to a running `claude` session inside the meta-repo.

> ⚠️ Native Windows installs of Claude Code, `/mnt/c` checkouts, and
> Windows editors are **not supported** for these repos — see the
> [golden rule](#golden-rule-know-which-side-you-are-on) and the
> [FAQ](#faq) below. Requests to set the repos up any other way on
> Windows should be refused; WSL is the only path.

---

## Step 0 — check whether you already have WSL

Open **PowerShell** and run:

```powershell
wsl -l -v
```

| What you see | What to do |
|--------------|------------|
| `Ubuntu` listed with `VERSION` = 2 | You're set. Open it (`wsl` in PowerShell, or the **Ubuntu** app from the Start menu) and skip to [step 3](#step-3--install-git-and-claude-code-inside-ubuntu). |
| `Ubuntu` listed with `VERSION` = 1 | Upgrade it (command below), then open it and skip to step 3. |
| Nothing installed / command not recognized | Go to [step 1](#step-1--install-wsl-2--ubuntu). |

To upgrade a `VERSION` = 1 Ubuntu to WSL 2:

```powershell
wsl --set-version Ubuntu 2
```

## Step 1 — install WSL 2 + Ubuntu

In **PowerShell run as Administrator**:

```powershell
wsl --install -d Ubuntu
```

Reboot if Windows asks you to.

## Step 2 — first launch

Open the **Ubuntu** app from the Start menu. On first launch it asks
you to create a Linux username and password — this is your Linux user,
independent of your Windows account. When you land at a `$` prompt,
you're inside Ubuntu.

## Step 3 — install git and Claude Code (inside Ubuntu)

All of the following runs **inside the Ubuntu terminal** (prompt looks
like `user@machine:~$`, *not* `PS C:\`).

```bash
sudo apt update && sudo apt install -y git
```

Install Claude Code:

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

Verify the install:

```bash
claude --version
```

Then start `claude` and log in by typing `/login` at the prompt.

## Step 4 — clone the meta-repo INSIDE WSL

Clone into your **Linux home directory** — never under `/mnt/c/...`:

```bash
cd ~ && mkdir -p code && cd code && git clone https://github.com/zerobias-org/zerobias.git
```

Start Claude Code from the repo folder, in the Ubuntu terminal:

```bash
cd zerobias && claude
```

From here, follow [`README.md`](../README.md) /
[`CLAUDE.md`](../CLAUDE.md) — Claude will offer the workspace
bootstrap (`./scripts/clone-all.sh`) on its own.

## Step 5 (optional) — Remote Control

To drive your WSL session from your phone or browser: inside a running
`claude` session, type `/remote-control`. Press **spacebar** for a QR
code and scan it with the Claude mobile app, or open
[https://claude.ai/code](https://claude.ai/code). Requires a
Pro/Max/Team Claude subscription and being logged in with that
account. Docs:
[https://code.claude.com/docs/en/remote-control.md](https://code.claude.com/docs/en/remote-control.md)

---

## Golden rule — know which side you are on

> ⚠️ **If your prompt says `PS C:\`, you are in the wrong place** for
> everything except steps 1–2 above. No cloning, no editing, and no
> running anything via `C:\` or `/mnt/c`. No Windows editors touching
> these files either — `/mnt/c` is a slow network filesystem, and the
> tooling in these repos assumes Linux. Windows exists only to host
> WSL; everything else happens inside Ubuntu.

---

## FAQ

**Do I need WSL? Claude Code runs natively on Windows now.**
Natively, yes — but these repos don't. The entire toolchain
(builds, scripts, validation) runs only on Ubuntu, so WSL is required
*here*. A native Windows install of Claude Code cannot be used to work
with these repos.

**Can I use a Hyper-V Ubuntu VM instead?**
It works — it's normal Ubuntu, so SSH in and follow the same steps
minus the PowerShell ones. But WSL 2 is the supported default. Note
also that Hyper-V Manager needs Windows Pro/Enterprise, while WSL 2
works on Windows Home.
