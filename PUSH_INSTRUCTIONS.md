# Publishing vmware-stig-tools to github.com/noahfarshad

Step-by-step for creating and pushing this repository. The repo is ready — sanitized, licensed, documented. You just need to create it on GitHub and push.

---

## Prerequisites (one-time)

**1. GitHub CLI (optional but easier)** — if you don't have it already:
```powershell
winget install GitHub.cli
gh auth login
```

**2. Git configured with your identity:**
```powershell
git config --global user.name "Noah Farshad"
git config --global user.email "noah@essential.coach"
```

**3. Append the full GPL-3.0 license text** (one-time):
The `LICENSE` file currently contains the standard short header. Before pushing, replace
it with the full GPL-3.0 text from <https://www.gnu.org/licenses/gpl-3.0.txt>:

```powershell
cd "$env:USERPROFILE\Desktop\essential_coach_public\vmware-stig-tools"
Invoke-WebRequest -Uri "https://www.gnu.org/licenses/gpl-3.0.txt" -OutFile "LICENSE"
```

---

## Repo — vmware-stig-tools (new)

```powershell
cd "$env:USERPROFILE\Desktop\essential_coach_public\vmware-stig-tools"

# Initialize and make first commit
git init
git branch -M main
git add .
git commit -m "Initial release — train-vmware-fix v1.0.0, inspec-runner v2.0, ckl-converter v1.0"

# Create the repo on GitHub (using gh CLI — or create manually in browser first)
gh repo create noahfarshad/vmware-stig-tools `
    --public `
    --description "VMware vSphere 8.0 STIG compliance tooling: train-vmware password fix, enhanced InSpec runner, CKL→CKLB converter, scanning guides" `
    --homepage "https://essential.coach" `
    --source . `
    --push

# Tag the initial release
git tag -a v1.0.0 -m "vmware-stig-tools v1.0.0 — initial public release"
git push origin v1.0.0

# Add topics for discoverability
gh repo edit noahfarshad/vmware-stig-tools `
    --add-topic vmware `
    --add-topic vsphere `
    --add-topic stig `
    --add-topic compliance `
    --add-topic inspec `
    --add-topic cinc-auditor `
    --add-topic ckl `
    --add-topic security `
    --add-topic federal `
    --add-topic disa
```

**If not using `gh` CLI**, create the repo manually:

1. Go to <https://github.com/new>
2. Repository name: `vmware-stig-tools`
3. Description: the one from above
4. Public, no README/gitignore/license (we have them)
5. Create, then run:
   ```powershell
   git remote add origin https://github.com/noahfarshad/vmware-stig-tools.git
   git push -u origin main
   git tag -a v1.0.0 -m "vmware-stig-tools v1.0.0 — initial public release"
   git push origin v1.0.0
   ```

---

## Optional — create a GitHub Release

After pushing the tag:

1. Go to <https://github.com/noahfarshad/vmware-stig-tools/releases/new>
2. Choose tag `v1.0.0`, title `v1.0.0 — Initial public release`
3. Paste the v1.0.0 entry from `CHANGELOG.md` into the description
4. Set as latest release, publish

---

## Post-Push: Update the Customer Story

Once the repo is live, the customer success story on essential.coach should reference it:

- Story slug (suggested): `vmware-stig-compliance-tooling`
- Repo URL: <https://github.com/noahfarshad/vmware-stig-tools>

Add it via the publisher script in `publish-scripts/` — the same flow used for the prior six repos.

---

## Verification After Push

```powershell
# Confirm repo is public and accessible
gh repo view noahfarshad/vmware-stig-tools --web

# Confirm tag is present
git ls-remote --tags origin

# Confirm topics are set
gh repo view noahfarshad/vmware-stig-tools --json repositoryTopics
```
