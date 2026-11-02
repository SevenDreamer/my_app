// Shizuku UserService shell contract (ported from DSHA IShellService.aidl).
// Behavior contract preserved: exec / execVirtualScreen / destroy.
package com.example.my_app;

interface IShellService {
  String exec(String cmd);
  String execVirtualScreen(String command);
  void destroy();
}
