#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <climits>
#include <cstdlib>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

unsigned int WindowDimensionFromEnvironment(const wchar_t* name,
                                            unsigned int fallback) {
  wchar_t text[32] = {};
  const DWORD length = ::GetEnvironmentVariableW(name, text, _countof(text));
  if (length == 0 || length >= _countof(text)) {
    return fallback;
  }

  wchar_t* end = nullptr;
  const unsigned long value = std::wcstoul(text, &end, 10);
  if (end == text || *end != L'\0' || value == 0 || value > UINT_MAX) {
    return fallback;
  }
  return static_cast<unsigned int>(value);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(
      WindowDimensionFromEnvironment(L"FLUTTER_WINDOW_WIDTH", 800),
      WindowDimensionFromEnvironment(L"FLUTTER_WINDOW_HEIGHT", 500));
  if (!window.CreateAndShow(L"flutter_home_dashboard_8cun", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
