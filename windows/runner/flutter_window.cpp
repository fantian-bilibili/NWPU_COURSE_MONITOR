#include "flutter_window.h"

#include <algorithm>
#include <cstring>
#include <dwmapi.h>
#include <optional>
#include <string>

#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

namespace {
constexpr int kMiniWindowCornerDiameter = 68;
constexpr char kDesktopChannelName[] = "nwpu_course_monitor/windows_desktop";
constexpr char kSetDesktopPinnedMethod[] = "setDesktopPinned";
constexpr char kGetDesktopPinnedMethod[] = "getDesktopPinned";
constexpr char kSetMiniWindowModeMethod[] = "setMiniWindowMode";
constexpr char kGetMiniWindowModeMethod[] = "getMiniWindowMode";
constexpr char kSetMiniWindowDarkMethod[] = "setMiniWindowDark";
constexpr char kSetAutoStartMethod[] = "setAutoStart";
constexpr char kGetAutoStartMethod[] = "getAutoStart";
constexpr char kStartWindowDragMethod[] = "startWindowDrag";
constexpr char kLaunchMiniWindowMethod[] = "launchMiniWindowProcess";
constexpr char kLaunchMainWindowMethod[] = "launchMainWindowProcess";

constexpr wchar_t kAutoStartRegKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr wchar_t kAutoStartValueName[] = L"NWPUCourseMonitor";

#ifndef DWMWA_SYSTEMBACKDROP_TYPE
#define DWMWA_SYSTEMBACKDROP_TYPE 38
#endif

#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif

constexpr DWORD kDwmCornerPreferenceRound = 2;

enum ACCENT_STATE {
  ACCENT_DISABLED = 0,
  ACCENT_ENABLE_GRADIENT = 1,
  ACCENT_ENABLE_TRANSPARENTGRADIENT = 2,
  ACCENT_ENABLE_BLURBEHIND = 3,
  ACCENT_ENABLE_ACRYLICBLURBEHIND = 4,
  ACCENT_ENABLE_HOSTBACKDROP = 5,
};

struct ACCENT_POLICY {
  int accent_state;
  int accent_flags;
  DWORD gradient_color;
  int animation_id;
};

enum WINDOWCOMPOSITIONATTRIB { WCA_ACCENT_POLICY = 19 };

struct WINDOWCOMPOSITIONATTRIBDATA {
  WINDOWCOMPOSITIONATTRIB attribute;
  PVOID data;
  SIZE_T size_of_data;
};

using SetWindowCompositionAttributeFn =
    BOOL(WINAPI*)(HWND, WINDOWCOMPOSITIONATTRIBDATA*);

bool ParseBoolArgument(const flutter::MethodCall<flutter::EncodableValue>& call,
                       const char* key, bool fallback = false) {
  bool value_result = fallback;
  const flutter::EncodableValue* arguments = call.arguments();
  if (arguments == nullptr) {
    return fallback;
  }

  if (const auto* map = std::get_if<flutter::EncodableMap>(arguments)) {
    const auto iterator = map->find(flutter::EncodableValue(key));
    if (iterator != map->end()) {
      if (const bool* parsed = std::get_if<bool>(&iterator->second)) {
        value_result = *parsed;
      }
    }
  } else if (std::strcmp(key, "enabled") == 0) {
    if (const bool* parsed = std::get_if<bool>(arguments)) {
      value_result = *parsed;
    }
  }

  return value_result;
}

bool ParseEnabledArgument(
    const flutter::MethodCall<flutter::EncodableValue>& call) {
  return ParseBoolArgument(call, "enabled", false);
}

bool ApplyAccentPolicy(HWND window, ACCENT_STATE accent_state,
                       DWORD gradient_color) {
  HMODULE user32_module = LoadLibraryW(L"user32.dll");
  if (user32_module == nullptr) {
    return false;
  }

  const auto set_window_composition_attribute =
      reinterpret_cast<SetWindowCompositionAttributeFn>(
          GetProcAddress(user32_module, "SetWindowCompositionAttribute"));
  if (set_window_composition_attribute == nullptr) {
    FreeLibrary(user32_module);
    return false;
  }

  ACCENT_POLICY accent = {accent_state, 0, gradient_color, 0};
  WINDOWCOMPOSITIONATTRIBDATA data = {WCA_ACCENT_POLICY, &accent,
                                      sizeof(accent)};
  const BOOL applied = set_window_composition_attribute(window, &data);
  FreeLibrary(user32_module);
  return applied == TRUE;
}

void ApplyMiniWindowMaterial(HWND window, bool dark) {
  const MARGINS glass_margins = {-1, -1, -1, -1};
  DwmExtendFrameIntoClientArea(window, &glass_margins);

  DWORD backdrop = 0;
  DwmSetWindowAttribute(window, DWMWA_SYSTEMBACKDROP_TYPE, &backdrop,
                        sizeof(backdrop));
  DwmSetWindowAttribute(window, DWMWA_WINDOW_CORNER_PREFERENCE,
                        &kDwmCornerPreferenceRound,
                        sizeof(kDwmCornerPreferenceRound));

  // GradientColor uses AABBGGRR; keep the alpha high enough so the desktop
  // blur shows through instead of falling back to an opaque black surface.
  const DWORD gradient_color = dark ? 0xB02A2118 : 0x88FCFAF7;
  if (!ApplyAccentPolicy(window, ACCENT_ENABLE_ACRYLICBLURBEHIND,
                         gradient_color)) {
    ApplyAccentPolicy(window, ACCENT_ENABLE_BLURBEHIND, 0);
  }
}

void ClearMiniWindowMaterial(HWND window) {
  ApplyAccentPolicy(window, ACCENT_DISABLED, 0);
  const MARGINS normal_margins = {0, 0, 0, 0};
  DwmExtendFrameIntoClientArea(window, &normal_margins);

  const DWORD backdrop = 1;
  DwmSetWindowAttribute(window, DWMWA_SYSTEMBACKDROP_TYPE, &backdrop,
                        sizeof(backdrop));
}
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project,
                             bool start_in_mini_mode)
    : project_(project), start_in_mini_mode_(start_in_mini_mode) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  RegisterDesktopChannel();
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  if (start_in_mini_mode_) {
    SetMiniWindowMode(true);
  }

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  desktop_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::RegisterDesktopChannel() {
  if (!flutter_controller_ || !flutter_controller_->engine()) {
    return;
  }

  desktop_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), kDesktopChannelName,
          &flutter::StandardMethodCodec::GetInstance());

  desktop_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == kSetDesktopPinnedMethod) {
          const bool enabled = ParseEnabledArgument(call);
          const bool applied = SetDesktopPinned(enabled);
          result->Success(flutter::EncodableValue(applied));
          return;
        }

        if (call.method_name() == kGetDesktopPinnedMethod) {
          result->Success(flutter::EncodableValue(desktop_pinned_));
          return;
        }

        if (call.method_name() == kSetMiniWindowModeMethod) {
          const bool enabled = ParseEnabledArgument(call);
          const bool applied = SetMiniWindowMode(enabled);
          result->Success(flutter::EncodableValue(applied));
          return;
        }

        if (call.method_name() == kGetMiniWindowModeMethod) {
          result->Success(flutter::EncodableValue(mini_window_mode_));
          return;
        }

        if (call.method_name() == kSetMiniWindowDarkMethod) {
          const bool enabled = ParseEnabledArgument(call);
          const bool applied = SetMiniWindowDark(enabled);
          result->Success(flutter::EncodableValue(applied));
          return;
        }

        if (call.method_name() == kSetAutoStartMethod) {
          const bool enabled = ParseEnabledArgument(call);
          const bool start_in_mini_mode =
              ParseBoolArgument(call, "startMini", false);
          const bool applied = SetAutoStart(enabled, start_in_mini_mode);
          result->Success(flutter::EncodableValue(applied));
          return;
        }

        if (call.method_name() == kGetAutoStartMethod) {
          result->Success(flutter::EncodableValue(GetAutoStart()));
          return;
        }

        if (call.method_name() == kStartWindowDragMethod) {
          const bool started = StartWindowDrag();
          result->Success(flutter::EncodableValue(started));
          return;
        }

        if (call.method_name() == kLaunchMiniWindowMethod) {
          const bool launched = LaunchWindowProcess(true);
          result->Success(flutter::EncodableValue(launched));
          return;
        }

        if (call.method_name() == kLaunchMainWindowMethod) {
          const bool launched = LaunchWindowProcess(false);
          result->Success(flutter::EncodableValue(launched));
          return;
        }

        result->NotImplemented();
      });
}

bool FlutterWindow::SetDesktopPinned(bool enabled) {
  HWND window = GetHandle();
  if (window == nullptr) {
    return false;
  }

  desktop_pinned_ = enabled;

  LONG ex_style = GetWindowLong(window, GWL_EXSTYLE);
  if (enabled) {
    ex_style |= WS_EX_TOOLWINDOW;
  } else {
    ex_style &= ~WS_EX_TOOLWINDOW;
  }
  SetWindowLong(window, GWL_EXSTYLE, ex_style);

  const UINT flags = SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE |
                     SWP_NOOWNERZORDER | SWP_FRAMECHANGED;
  SetWindowPos(window, enabled ? HWND_BOTTOM : HWND_NOTOPMOST, 0, 0, 0, 0,
               flags);
  return true;
}

bool FlutterWindow::SetMiniWindowMode(bool enabled) {
  HWND window = GetHandle();
  if (window == nullptr) {
    return false;
  }

  if (!has_original_style_) {
    original_window_style_ = GetWindowLong(window, GWL_STYLE);
    original_ex_style_ = GetWindowLong(window, GWL_EXSTYLE);
    has_original_style_ = true;
  }

  if (enabled && !mini_window_mode_) {
    GetWindowRect(window, &restored_bounds_);
    has_restored_bounds_ = true;
  }

  mini_window_mode_ = enabled;
  SetDesktopPinned(enabled);

  if (enabled) {
    const LONG mini_style = WS_POPUP;
    SetWindowLong(window, GWL_STYLE, mini_style);

    LONG mini_ex_style = original_ex_style_;
    mini_ex_style |= WS_EX_TOOLWINDOW;
    mini_ex_style &= ~WS_EX_APPWINDOW;
    SetWindowLong(window, GWL_EXSTYLE, mini_ex_style);

    ApplyMiniWindowMaterial(window, mini_window_dark_);

    RECT work_area{0, 0, 0, 0};
    SystemParametersInfo(SPI_GETWORKAREA, 0, &work_area, 0);

    const int target_width = 430;
    const int target_height = 760;
    const int x = std::max(work_area.left, work_area.right - target_width - 20);
    const int y =
        std::max(work_area.top, work_area.bottom - target_height - 20);
    SetWindowPos(window, HWND_BOTTOM, x, y, target_width, target_height,
                 SWP_NOACTIVATE | SWP_NOOWNERZORDER | SWP_FRAMECHANGED);

    RECT actual_bounds{0, 0, 0, 0};
    GetWindowRect(window, &actual_bounds);
    const LONG raw_width = actual_bounds.right - actual_bounds.left;
    const LONG raw_height = actual_bounds.bottom - actual_bounds.top;
    const int actual_width = raw_width > 1 ? static_cast<int>(raw_width) : 1;
    const int actual_height =
        raw_height > 1 ? static_cast<int>(raw_height) : 1;
    HRGN rounded_region =
        CreateRoundRectRgn(0, 0, actual_width + 1, actual_height + 1,
                           kMiniWindowCornerDiameter,
                           kMiniWindowCornerDiameter);
    SetWindowRgn(window, rounded_region, TRUE);
    ForceWindowRefresh();
    return true;
  }

  if (has_restored_bounds_) {
    SetWindowLong(window, GWL_STYLE, original_window_style_);
    SetWindowLong(window, GWL_EXSTYLE, original_ex_style_);
    ClearMiniWindowMaterial(window);
    const int width = restored_bounds_.right - restored_bounds_.left;
    const int height = restored_bounds_.bottom - restored_bounds_.top;
    SetWindowPos(window, HWND_NOTOPMOST, restored_bounds_.left,
                 restored_bounds_.top, width, height,
                 SWP_NOACTIVATE | SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
    SetWindowRgn(window, nullptr, TRUE);
    ForceWindowRefresh();
    return true;
  }

  SetWindowLong(window, GWL_STYLE, original_window_style_);
  SetWindowLong(window, GWL_EXSTYLE, original_ex_style_);
  ClearMiniWindowMaterial(window);
  SetWindowPos(window, HWND_NOTOPMOST, 40, 40, 1280, 720,
               SWP_NOACTIVATE | SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
  SetWindowRgn(window, nullptr, TRUE);
  ForceWindowRefresh();
  return true;
}

bool FlutterWindow::LaunchWindowProcess(bool launch_in_mini_mode) {
  wchar_t module_path[MAX_PATH] = {0};
  if (GetModuleFileNameW(nullptr, module_path, MAX_PATH) == 0) {
    return false;
  }

  std::wstring command = L"\"";
  command += module_path;
  command += L"\"";
  if (launch_in_mini_mode) {
    command += L" --windows-mini-window";
  }

  STARTUPINFOW startup_info{};
  startup_info.cb = sizeof(startup_info);
  PROCESS_INFORMATION process_info{};
  std::wstring mutable_command = command;
  const BOOL created = CreateProcessW(
      nullptr, mutable_command.data(), nullptr, nullptr, FALSE, 0, nullptr,
      nullptr, &startup_info, &process_info);
  if (!created) {
    return false;
  }

  CloseHandle(process_info.hThread);
  CloseHandle(process_info.hProcess);

  HWND window = GetHandle();
  if (window != nullptr) {
    PostMessage(window, WM_CLOSE, 0, 0);
  }
  return true;
}

bool FlutterWindow::SetMiniWindowDark(bool enabled) {
  mini_window_dark_ = enabled;
  HWND window = GetHandle();
  if (window == nullptr) {
    return false;
  }
  if (mini_window_mode_) {
    ApplyMiniWindowMaterial(window, mini_window_dark_);
    ForceWindowRefresh();
  }
  return true;
}

bool FlutterWindow::SetAutoStart(bool enabled, bool start_in_mini_mode) {
  HKEY key = nullptr;
  const LONG open_status =
      RegCreateKeyExW(HKEY_CURRENT_USER, kAutoStartRegKey, 0, nullptr, 0,
                      KEY_SET_VALUE | KEY_QUERY_VALUE, nullptr, &key, nullptr);
  if (open_status != ERROR_SUCCESS || key == nullptr) {
    return false;
  }

  LONG status = ERROR_SUCCESS;
  if (enabled) {
    wchar_t module_path[MAX_PATH] = {0};
    if (GetModuleFileNameW(nullptr, module_path, MAX_PATH) == 0) {
      RegCloseKey(key);
      return false;
    }
    std::wstring command = L"\"";
    command += module_path;
    command += L"\"";
    if (start_in_mini_mode) {
      command += L" --windows-mini-window";
    }

    status = RegSetValueExW(
        key, kAutoStartValueName, 0, REG_SZ,
        reinterpret_cast<const BYTE*>(command.c_str()),
        static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
  } else {
    status = RegDeleteValueW(key, kAutoStartValueName);
    if (status == ERROR_FILE_NOT_FOUND) {
      status = ERROR_SUCCESS;
    }
  }

  RegCloseKey(key);
  return status == ERROR_SUCCESS;
}

bool FlutterWindow::GetAutoStart() const {
  HKEY key = nullptr;
  const LONG open_status = RegOpenKeyExW(HKEY_CURRENT_USER, kAutoStartRegKey, 0,
                                         KEY_QUERY_VALUE, &key);
  if (open_status != ERROR_SUCCESS || key == nullptr) {
    return false;
  }

  wchar_t buffer[2048] = {0};
  DWORD buffer_size = sizeof(buffer);
  const LONG status =
      RegGetValueW(key, nullptr, kAutoStartValueName, RRF_RT_REG_SZ, nullptr,
                   buffer, &buffer_size);
  RegCloseKey(key);
  return status == ERROR_SUCCESS && buffer_size > sizeof(wchar_t);
}

bool FlutterWindow::StartWindowDrag() {
  if (!mini_window_mode_) {
    return false;
  }
  HWND window = GetHandle();
  if (window == nullptr) {
    return false;
  }
  ReleaseCapture();
  SendMessage(window, WM_NCLBUTTONDOWN, HTCAPTION, 0);
  return true;
}

void FlutterWindow::RefreshBottomZOrder() {
  if (!desktop_pinned_) {
    return;
  }

  HWND window = GetHandle();
  if (window == nullptr) {
    return;
  }

  SetWindowPos(window, HWND_BOTTOM, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE |
                   SWP_NOOWNERZORDER);
}

void FlutterWindow::ForceWindowRefresh() {
  if (flutter_controller_) {
    flutter_controller_->ForceRedraw();
  }

  HWND window = GetHandle();
  if (window == nullptr) {
    return;
  }

  InvalidateRect(window, nullptr, TRUE);
  UpdateWindow(window);
  RedrawWindow(window, nullptr, nullptr,
               RDW_ERASE | RDW_FRAME | RDW_INVALIDATE | RDW_ALLCHILDREN |
                   RDW_UPDATENOW);
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  if (desktop_pinned_) {
    switch (message) {
      case WM_WINDOWPOSCHANGING: {
        auto* window_position = reinterpret_cast<WINDOWPOS*>(lparam);
        if (window_position != nullptr &&
            (window_position->flags & SWP_NOZORDER) == 0) {
          window_position->hwndInsertAfter = HWND_BOTTOM;
        }
        break;
      }
      case WM_ACTIVATE:
      case WM_SETFOCUS:
      case WM_EXITSIZEMOVE:
      case WM_SHOWWINDOW:
        RefreshBottomZOrder();
        break;
      case WM_SYSCOMMAND:
        if (mini_window_mode_ && (wparam & 0xFFF0) == SC_MINIMIZE) {
          return 0;
        }
        break;
    }
  }

  switch (message) {
    case WM_ERASEBKGND:
      if (mini_window_mode_) {
        return 1;
      }
      break;

    case WM_DWMCOMPOSITIONCHANGED:
      if (mini_window_mode_) {
        ApplyMiniWindowMaterial(hwnd, mini_window_dark_);
        return 0;
      }
      break;

    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
