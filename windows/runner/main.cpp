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

  // Get screen work area size (excluding taskbar)
  RECT workArea;
  SystemParametersInfo(SPI_GETWORKAREA, 0, &workArea, 0);
  LONG screenWidth = workArea.right - workArea.left;
  LONG screenHeight = workArea.bottom - workArea.top;

  // Calculate window size: height=full screen, width=3/4 of height
  LONG windowHeight = screenHeight;
  LONG windowWidth = static_cast<LONG>(windowHeight * 0.75);

  // Ensure window width does not exceed screen width
  if (windowWidth > screenWidth) {
    windowWidth = screenWidth;
  }

  // Calculate center position
  LONG windowLeft = workArea.left + (screenWidth - windowWidth) / 2;
  LONG windowTop = workArea.top + (screenHeight - windowHeight) / 2;

  FlutterWindow window(project);
  Win32Window::Point origin(windowLeft, windowTop);
  Win32Window::Size size(windowWidth, windowHeight);
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
