#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project,
                         bool start_in_mini_mode = false);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  void RegisterDesktopChannel();
  bool SetDesktopPinned(bool enabled);
  bool SetMiniWindowMode(bool enabled);
  bool SetMiniWindowDark(bool enabled);
  bool LaunchWindowProcess(bool launch_in_mini_mode);
  bool SetAutoStart(bool enabled, bool start_in_mini_mode);
  bool GetAutoStart() const;
  bool StartWindowDrag();
  void RefreshBottomZOrder();
  void ForceWindowRefresh();

  // The project to run.
  flutter::DartProject project_;
  bool start_in_mini_mode_ = false;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Desktop small-window mode state.
  bool desktop_pinned_ = false;
  bool mini_window_mode_ = false;
  bool mini_window_dark_ = false;

  // Bounds used for restoring from mini-window mode.
  RECT restored_bounds_ = RECT{0, 0, 0, 0};
  bool has_restored_bounds_ = false;

  // Original styles for restoring from mini-window mode.
  LONG original_window_style_ = 0;
  LONG original_ex_style_ = 0;
  bool has_original_style_ = false;

  // Channel for Flutter <-> Win32 desktop mode control.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      desktop_channel_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
