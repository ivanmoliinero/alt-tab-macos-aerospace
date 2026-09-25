# AltTab fork by [@ivanmoliinero](https://github.com/ivanmoliinero)

This fork of AltTab adds native integration with the **[AeroSpace](https://github.com/nikitabobko/AeroSpace)** tiling window manager and introduces a **Radial Pie Menu** switcher style.

### Key Additions in this Fork

- **AeroSpace Tiling Window Manager Integration:**
  - High-performance Unix domain socket IPC (`/tmp/bobko.aerospace-<user>.sock`) for sub-millisecond window querying without process-spawning overhead.
  - Automatically filters the switcher window list to only display windows in the currently focused AeroSpace workspace.
  - Preserves the spatial layout ordering of the AeroSpace container tree so window positions remain consistent.

- **Radial Pie Menu Switcher:**
  - New radial/pie menu visualization mode selectable in **Preferences → Appearance → Style** (available freely without Pro gating).
  - Spatial slice layout arranged in clockwise order starting at 12 o'clock, maintaining fixed spatial positions based on AeroSpace window layout.
  - Interactive mouse hover tracking that selects sectors based on cursor angle from the center.
  - Circular keyboard navigation (`Tab` / `Shift+Tab` / arrow keys) that steps sequentially through adjacent sectors.
  - Centered floating glass UI with application icons, window titles, and AeroSpace workspace badges.

- **Developer & Build Tooling:**
  - Local build and installation scripts (`./scripts/build_local.sh`, `./scripts/install_local.sh`) with automatic ad-hoc code-signing and TCC permission management.

---

# Original documentation
<div align="center">

<a href="https://alt-tab.app/"><img src="docs/readme/main.svg" alt="AltTab Pro — 7.4M downloads — 15K GitHub stars — Get AltTab"/></a>

<a href="https://jb.gg/OpenSource"><img src="docs/readme/sponsor.svg" alt="Sponsored by JetBrains" width="900"/></a>

</div>
