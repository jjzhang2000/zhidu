#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

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

  // === Multi-Monitor DPI Fix ===
  // Instead of using SystemParametersInfo(SPI_GETWORKAREA) which only returns
  // the primary monitor's work area (problematic when app opens on a
  // non-primary monitor with different DPI), we use a reasonable default
  // window size.
  //
  // The Dart layer (window_manager + screen_retriever) handles the actual
  // multi-monitor positioning and sizing after the window is created.
  //
  // Win32Window::Create uses physical pixels internally but accepts logical
  // pixel coordinates. We use CW_USEDEFAULT for position to let Windows
  // choose a sensible default, and specify a reasonable default size.
  // The Dart _initWindowManager() will reposition/resize the window correctly
  // for whatever monitor it appears on.

  FlutterWindow window(project);
  Win32Window::Point origin(0, 0);
  Win32Window::Size size(960, 720);
  if (!window.Create(L"智读", origin, size)) {
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
