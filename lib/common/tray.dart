import 'dart:io';

import 'package:fl_clash/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:tray_manager/tray_manager.dart';

import 'app_localizations.dart';
import 'compute.dart';
import 'constant.dart';
import 'string.dart';
import 'system.dart';
import 'window.dart';

class Tray {
  static Tray? _instance;

  Tray._internal();

  factory Tray() {
    _instance ??= Tray._internal();
    return _instance!;
  }

  String get trayIconSuffix {
    return system.isWindows ? 'ico' : 'png';
  }

  Future<void> destroy() async {
    await trayManager.destroy();
  }

  String getTryIcon({required bool isStart, required bool tunEnable}) {
    if (system.isMacOS || !isStart) {
      return 'assets/images/icon/status_1.$trayIconSuffix';
    }
    if (!tunEnable) {
      return 'assets/images/icon/status_2.$trayIconSuffix';
    }
    return 'assets/images/icon/status_3.$trayIconSuffix';
  }

  Future _updateSystemTray({
    required bool isStart,
    required bool tunEnable,
  }) async {
    if (Platform.isLinux) {
      await trayManager.destroy();
    }
    await trayManager.setIcon(
      getTryIcon(isStart: isStart, tunEnable: tunEnable),
      isTemplate: true,
    );
    if (!Platform.isLinux) {
      await trayManager.setToolTip(appName);
    }
  }

  Future<void> update({
    required TrayState trayState,
    required Traffic traffic,
  }) async {
    if (system.isAndroid) {
      return;
    }
    if (!system.isLinux) {
      await _updateSystemTray(
        isStart: trayState.isStart,
        tunEnable: trayState.tunEnable,
      );
    }
    List<MenuItem> menuItems = [];
    final showMenuItem = MenuItem(
      label: appLocalizations.show,
      onClick: (_) {
        window?.show();
      },
    );
    menuItems.add(showMenuItem);
    final startMenuItem = MenuItem.checkbox(
      label: trayState.isStart ? appLocalizations.stop : appLocalizations.start,
      onClick: (_) async {
        appController.updateStart();
      },
      checked: false,
    );
    menuItems.add(startMenuItem);
    if (system.isMacOS) {
      final speedStatistics = MenuItem.checkbox(
        label: appLocalizations.speedStatistics,
        onClick: (_) async {
          appController.updateSpeedStatistics();
        },
        checked: trayState.showTrayTitle,
      );
      menuItems.add(speedStatistics);
    }
    menuItems.add(MenuItem.separator());
    for (final mode in Mode.values) {
      menuItems.add(
        MenuItem.checkbox(
          label: Intl.message(mode.name),
          onClick: (_) {
            appController.changeMode(mode);
          },
          checked: mode == trayState.mode,
        ),
      );
    }
    menuItems.add(MenuItem.separator());
    if (system.isMacOS) {
      if (trayState.groups.isNotEmpty) {
        menuItems.add(
          MenuItem(
            type: 'keepOpen',
            label: appLocalizations.delayTest,
            onClick: (_) {
              _delayTestAllGroups(trayState.groups);
            },
          ),
        );
        menuItems.add(MenuItem.separator());
      }
      for (final group in trayState.groups) {
        List<MenuItem> subMenuItems = [];
        subMenuItems.add(
          MenuItem(
            type: 'keepOpen',
            label: appLocalizations.delayTest,
            onClick: (_) {
              _delayTestGroup(group);
            },
          ),
        );
        subMenuItems.add(MenuItem.separator());
        for (final proxy in group.all) {
          final delay = appController.getDelayValue(
            proxyName: proxy.name,
            testUrl: group.testUrl,
          );
          final delayLabel = _formatDelay(delay);
          final proxyLabel = delayLabel != null
              ? '${proxy.name}\t$delayLabel'
              : proxy.name;
          subMenuItems.add(
            MenuItem.checkbox(
              label: proxyLabel,
              checked:
                  appController.getSelectedProxyName(group.name) == proxy.name,
              onClick: (_) {
                appController.updateCurrentSelectedMap(group.name, proxy.name);
                appController.changeProxy(
                  groupName: group.name,
                  proxyName: proxy.name,
                );
              },
            ),
          );
        }
        final selectedProxy = appController.getSelectedProxyName(group.name);
        final groupLabel =
            (selectedProxy != null && selectedProxy.isNotEmpty)
                ? '${group.name}\t$selectedProxy'
                : group.name;
        menuItems.add(
          MenuItem.submenu(
            label: groupLabel,
            submenu: Menu(items: subMenuItems),
          ),
        );
      }
      if (trayState.groups.isNotEmpty) {
        menuItems.add(MenuItem.separator());
      }
    }
    if (trayState.isStart) {
      menuItems.add(
        MenuItem.checkbox(
          label: appLocalizations.tun,
          onClick: (_) {
            appController.updateTun();
          },
          checked: trayState.tunEnable,
        ),
      );
      menuItems.add(
        MenuItem.checkbox(
          label: appLocalizations.systemProxy,
          onClick: (_) {
            appController.updateSystemProxy();
          },
          checked: trayState.systemProxy,
        ),
      );
      menuItems.add(MenuItem.separator());
    }
    final autoStartMenuItem = MenuItem.checkbox(
      label: appLocalizations.autoLaunch,
      onClick: (_) async {
        appController.updateAutoLaunch();
      },
      checked: trayState.autoLaunch,
    );
    final copyEnvVarMenuItem = MenuItem(
      label: appLocalizations.copyEnvVar,
      onClick: (_) async {
        await _copyEnv(trayState.port);
      },
    );
    menuItems.add(autoStartMenuItem);
    menuItems.add(copyEnvVarMenuItem);
    menuItems.add(MenuItem.separator());
    final exitMenuItem = MenuItem(
      label: appLocalizations.exit,
      onClick: (_) async {
        await appController.handleExit();
      },
    );
    menuItems.add(exitMenuItem);
    final menu = Menu(items: menuItems);
    await trayManager.setContextMenu(menu);
    if (system.isLinux) {
      await _updateSystemTray(
        isStart: trayState.isStart,
        tunEnable: trayState.tunEnable,
      );
    }
    updateTrayTitle(showTrayTitle: trayState.showTrayTitle, traffic: traffic);
  }

  Future<void> updateTrayTitle({
    required bool showTrayTitle,
    required Traffic traffic,
  }) async {
    if (!system.isMacOS) {
      return;
    }
    if (!showTrayTitle) {
      await trayManager.setTitle('');
    } else {
      await trayManager.setTitle(traffic.trayTitle);
    }
  }

  String? _formatDelay(int? delay) {
    if (delay == null) return null;
    if (delay == 0) return '...';
    if (delay < 0) return 'fail';
    return '${delay}ms';
  }

  void _markGroupTesting(Group group) {
    final selectedMap = appController.currentProfile?.selectedMap ?? {};
    final allGroups = appController.groups;
    final defaultTestUrl = appController.getRealTestUrl(group.testUrl);
    for (final proxy in group.all) {
      final state = computeRealSelectedProxyState(
        proxy.name,
        groups: allGroups,
        selectedMap: selectedMap,
      );
      final name = state.proxyName;
      if (name.isEmpty) continue;
      final url = state.testUrl.takeFirstValid([defaultTestUrl]);
      appController.setDelay(Delay(url: url, name: name, value: 0));
    }
  }

  Future<void> _delayTestGroup(Group group) async {
    _markGroupTesting(group);
    await appController.updateTray();
    await appController.delayTestProxies(group.all, group.testUrl);
  }

  Future<void> _delayTestAllGroups(List<Group> groups) async {
    for (final group in groups) {
      _markGroupTesting(group);
    }
    await appController.updateTray();
    for (final group in groups) {
      await appController.delayTestProxies(group.all, group.testUrl);
    }
  }

  Future<void> _copyEnv(int port) async {
    final url = 'http://127.0.0.1:$port';

    final cmdline = system.isWindows
        ? 'set \$env:all_proxy=$url'
        : 'export all_proxy=$url';

    await Clipboard.setData(ClipboardData(text: cmdline));
  }
}

final tray = system.isDesktop ? Tray() : null;
