import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Menu bar nativa macOS (HIG-compliant).
///
/// Flutter 3.35 espone solo un sottoinsieme di [PlatformProvidedMenuItemType]
/// (about, quit, hide, hideOthers, toggleFullScreen, minimizeWindow,
/// zoomWindow, arrangeWindowsInFront). Per cut/copy/paste/undo usiamo
/// [PlatformMenuItem] senza onSelected: appaiono nel menu e le shortcut
/// di sistema (Cmd+C ecc.) continuano a funzionare via responder chain.
class MacosMenuBar extends StatelessWidget {
  final Widget child;
  final VoidCallback onNuovoImport;
  final VoidCallback onNavigaImpostazioni;

  const MacosMenuBar({
    super.key,
    required this.child,
    required this.onNuovoImport,
    required this.onNavigaImpostazioni,
  });

  @override
  Widget build(BuildContext context) {
    return PlatformMenuBar(
      menus: [
        // ── App menu ──────────────────────────────────────────────────────
        PlatformMenu(
          label: 'EsamiTracker',
          menus: [
            const PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.about,
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'Impostazioni…',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.comma,
                    meta: true,
                  ),
                  onSelected: onNavigaImpostazioni,
                ),
              ],
            ),
            const PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.hide,
                ),
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.hideOtherApplications,
                ),
              ],
            ),
            const PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.quit,
                ),
              ],
            ),
          ],
        ),

        // ── File ──────────────────────────────────────────────────────────
        PlatformMenu(
          label: 'File',
          menus: [
            PlatformMenuItem(
              label: 'Nuovo Import',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyN,
                meta: true,
              ),
              onSelected: onNuovoImport,
            ),
          ],
        ),

        // ── Modifica ──────────────────────────────────────────────────────
        // onSelected null → voci visive nel menu; le shortcut di sistema
        // (Cmd+Z/X/C/V/A) funzionano comunque via responder chain macOS.
        PlatformMenu(
          label: 'Modifica',
          menus: [
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'Annulla',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyZ,
                    meta: true,
                  ),
                ),
                PlatformMenuItem(
                  label: 'Ripeti',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyZ,
                    meta: true,
                    shift: true,
                  ),
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'Taglia',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyX,
                    meta: true,
                  ),
                ),
                PlatformMenuItem(
                  label: 'Copia',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyC,
                    meta: true,
                  ),
                ),
                PlatformMenuItem(
                  label: 'Incolla',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyV,
                    meta: true,
                  ),
                ),
                PlatformMenuItem(
                  label: 'Seleziona tutto',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyA,
                    meta: true,
                  ),
                ),
              ],
            ),
          ],
        ),

        // ── Visualizza ────────────────────────────────────────────────────
        const PlatformMenu(
          label: 'Visualizza',
          menus: [
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.toggleFullScreen,
            ),
          ],
        ),

        // ── Finestra ──────────────────────────────────────────────────────
        const PlatformMenu(
          label: 'Finestra',
          menus: [
            PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.minimizeWindow,
                ),
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.zoomWindow,
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.arrangeWindowsInFront,
                ),
              ],
            ),
          ],
        ),
      ],
      child: child,
    );
  }
}
