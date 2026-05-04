# train-vmware Password Special Character Fix

A patched `connection.rb` for the train-vmware InSpec plugin that fixes authentication failures when vCenter passwords contain special characters.

## The Problem

When deploying VMware STIG compliance scans against real customer environments, you'll eventually hit a password that contains characters like `$`, `%`, `&`, `|`, backticks, or quotes. The train-vmware plugin's authentication will fail with confusing errors that look like the credentials are wrong — even though they're not.

The root cause is in `train-vmware-0.2.0/lib/train-vmware/connection.rb`:

```ruby
login_command = "Connect-VIServer #{options[:viserver]} -User #{options[:username]} -Password '#{options[:password]}' | Out-Null"
```

The password is passed directly to PowerShell as part of a command string. When the password contains, say, `MyP@ss$Word123`, PowerShell parses `$Word123` as a variable reference (which doesn't exist), strips it, and tries to authenticate with the wrong password.

## The Fix

Rather than try to escape every possible special character (which is fragile and incomplete), this patch Base64-encodes the password in Ruby, passes it to PowerShell as an opaque string, and decodes it inside PowerShell before the authentication call.

```ruby
password_b64 = Base64.strict_encode64(options[:password].to_s)

login_command = "$pwd = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('#{password_b64}')); $conn = Connect-VIServer #{options[:viserver]} -User #{options[:username]} -Password $pwd; if ($conn) { Write-Output 'SUCCESS' } else { Write-Error 'FAILED' }"
```

The decoded password lives entirely inside the PowerShell variable `$pwd` and is never subject to PowerShell's command-line variable interpolation. The same pattern is applied to the `Connect-SsoAdminServer` call.

The patch also adds an explicit `SUCCESS` / `FAILED` marker for output parsing rather than relying on exit codes, which were unreliable across PowerShell error states.

## Installation

```bash
chmod +x install.sh
sudo ./install.sh
```

The installer:
1. Verifies the train-vmware plugin is installed at the expected path (`/root/.inspec/gems/3.1.0/gems/train-vmware-0.2.0/`)
2. Creates a backup of the original `connection.rb` (or a timestamped one if a backup already exists)
3. Copies the patched file in place
4. Verifies the patch landed by grepping for the Base64 encoding signature

## Manual Installation

If you prefer not to run the installer:

```bash
# Backup original
cp /root/.inspec/gems/3.1.0/gems/train-vmware-0.2.0/lib/train-vmware/connection.rb \
   /root/.inspec/gems/3.1.0/gems/train-vmware-0.2.0/lib/train-vmware/connection.rb.backup

# Install patch
cp connection.rb /root/.inspec/gems/3.1.0/gems/train-vmware-0.2.0/lib/train-vmware/connection.rb
```

## Testing

After installation, test with a password that actually contains special characters:

```bash
export VISERVER="vcenter.example.com"
export VISERVER_USERNAME="administrator@vsphere.local"
export VISERVER_PASSWORD='MyP@ss$Word123!&%'

inspec exec /usr/share/stigs/vsphere/8.0/v2r3-stig/vsphere/inspec/vmware-vsphere-8.0-stig-baseline/esxi/ \
    -t vmware:// \
    --input vmhostName=esxi-host.example.com \
    --reporter cli
```

If you got "incorrect user name or password" before and now you don't, the patch is working.

## Tested Special Characters

The patch was validated against passwords containing:

- Dollar signs (`$`)
- Percent signs (`%`)
- Ampersands (`&`)
- Pipes (`|`)
- Backticks (`` ` ``)
- Single and double quotes (`'`, `"`)
- Backslashes (`\`)

All authenticated successfully against vCenter 8.0 U3.

## Rollback

```bash
cp /root/.inspec/gems/3.1.0/gems/train-vmware-0.2.0/lib/train-vmware/connection.rb.backup \
   /root/.inspec/gems/3.1.0/gems/train-vmware-0.2.0/lib/train-vmware/connection.rb
```

## Compatibility

- VMware STIG Tools Appliance running Photon OS 5.0
- train-vmware plugin version 0.2.0
- InSpec / CINC Auditor 6.6.0+
- vSphere 8.0 (U2 and U3 verified)

Your gem path may differ slightly depending on your InSpec installation. The installer handles the standard appliance layout; for non-standard installs, edit the `PLUGIN_DIR` variable at the top of `install.sh`.

## Files

- `connection.rb` — the patched Ruby file
- `install.sh` — installer with backup + verification

## Upstream

This is a local patch against `train-vmware` v0.2.0. The fix has not been merged upstream. If/when an upstream release addresses special-character handling, this patch becomes unnecessary.

---

License: GPL-3.0 (matching the parent repository). The patch is a derivative of the original Apache-2.0 `connection.rb` from `train-vmware`; the modifications are released under GPL-3.0 alongside the rest of this toolset.
