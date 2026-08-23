# Decommissioning the old `@home` subvolume

The root (`@`) and home are wiped on every boot; persistent state lives in
`@persist`. The old `@home` subvolume is kept only as a rollback net until we
are confident nothing was missed. This runbook removes it safely.

> **Why so careful?** `@persist` and `@home` are siblings on the *same* btrfs
> filesystem. A typo'd path or a stale mount during deletion is how people
> lose their persistent data (see impermanence#258 / PR #268).

## Step 0 — Preconditions

- [ ] At least one week on the ephemeral-home setup without issues
- [ ] GDM login, ssh keys, browser profiles, Documents all confirmed intact
      across multiple reboots
- [ ] `journalctl -b -u home-manager-nithin.service` ends in `Finished`

## Step 1 — Verify nothing references `@home`

```bash
mount | grep '@home' && echo "STILL MOUNTED - STOP" || echo clear
```

If mounted: something (fstab leftover, old generation booted) still uses it.
Do not proceed.

## Step 2 — Look before deleting

```bash
sudo mkdir -p /mnt/b5
sudo mount -o subvolid=5 /dev/mapper/crypted /mnt/b5
ls /mnt/b5                 # expect: @ @home @nix @old_roots @persist @swap
sudo btrfs subvolume list -o /mnt/b5/@home   # everything that dies with it
```

Read the list. Nested subvolumes inside `@home` are deleted with it.

## Step 3 — Quarantine (reversible) instead of deleting

```bash
sudo mv /mnt/b5/@home /mnt/b5/@home-TODELETE-$(date +%F)
sudo umount /mnt/b5
sudo reboot
```

A mistaken `mv` costs nothing; a mistaken `delete` costs everything. Boot a
few times over the following week(s) — if anything unexpectedly missing shows
up, it can still be copied out:

```bash
sudo mount -o subvolid=5 /dev/mapper/crypted /mnt/b5
ls /mnt/b5/@home-TODELETE-*/
```

## Step 4 — Final delete (irreversible)

```bash
sudo mount -o subvolid=5 /dev/mapper/crypted /mnt/b5
sudo btrfs subvolume delete /mnt/b5/@home-TODELETE-*
sudo umount /mnt/b5
```

## Rollback escape hatch (if the week goes badly)

The quarantined volume can be reactivated at any time:

1. Copy any missing data out of it into `/persist/home/nithin/`
2. Or fully revert: re-add to `hosts/ntsv/hardware-configuration.nix`:

   ```nix
   "/home" = {
     device = "/dev/disk/by-uuid/1703ff9d-bde4-44b2-9f99-5cd211642af1";
     fsType = "btrfs";
     options = [ "subvol=@home" ];
   };
   ```

   then rename `/mnt/b5/@home-TODELETE-*` back to `@home`, remove the tmpfiles
   ownership shim commit if desired, and `nh os switch`.

## Related cleanup

Dormant junk migrated into `/persist/home/nithin` before whitelisting was
finalized can be pruned manually anytime — it is invisible in `$HOME` but
occupies disk. Check first that nothing whitelisted lives under the path
being removed.
