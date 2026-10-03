#include "crash.h"

#include <QDir>
#include <QTime>
#include <QtGlobal>

#include <atomic>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <ctime>
#include <deque>
#include <exception>
#include <mutex>
#include <string>

#ifdef _WIN32
#include <windows.h>
// After windows.h
#include <dbghelp.h>
#include <shellapi.h>
#else
#include <execinfo.h>
#include <unistd.h>
#endif

namespace wallpaper {
namespace {

constexpr size_t RECENT_LINES = 200;

struct State {
  std::mutex mutex;
  std::deque<std::string> recent; // Last Qt messages, newest last
  FILE *log = nullptr;            // latest.log
  std::string dir;                // UTF-8
#ifdef _WIN32
  std::wstring wdir;
#endif
  std::string version;
  char lastFatal[512] = {};
  QtMessageHandler previous = nullptr;
  std::atomic_flag crashing = ATOMIC_FLAG_INIT;
};

State &state() {
  static State s;
  return s;
}

void onMessage(QtMsgType type, const QMessageLogContext &context,
               const QString &message) {
  static const char *const names[] = {"debug", "warning", "critical", "fatal",
                                      "info"};
  State &s = state();
  const std::string line =
      QStringLiteral("%1 %2: %3")
          .arg(QTime::currentTime().toString(QStringLiteral("HH:mm:ss.zzz")),
               QString::fromLatin1(names[type <= QtInfoMsg ? type : 0]),
               message)
          .toStdString();
  {
    std::lock_guard lock(s.mutex);
    s.recent.push_back(line);
    if (s.recent.size() > RECENT_LINES)
      s.recent.pop_front();
    if (s.log) {
      std::fprintf(s.log, "%s\n", line.c_str());
      std::fflush(s.log);
    }
  }
  if (type ==
      QtFatalMsg) // Qt aborts right after this, the abort handler reports it
    std::snprintf(s.lastFatal, sizeof s.lastFatal, "%s",
                  message.toUtf8().constData());
  if (s.previous)
    s.previous(type, context, message);
}

#ifdef _WIN32

const char *fileName(const char *path) {
  const char *name = path;
  for (const char *p = path; *p; ++p)
    if (*p == '/' || *p == '\\')
      name = p + 1;
  return name;
}

const char *exceptionName(DWORD code) {
  switch (code) {
  case EXCEPTION_ACCESS_VIOLATION:
    return "Access violation";
  case EXCEPTION_STACK_OVERFLOW:
    return "Stack overflow";
  case EXCEPTION_ILLEGAL_INSTRUCTION:
    return "Illegal instruction";
  case EXCEPTION_INT_DIVIDE_BY_ZERO:
    return "Division by zero";
  case EXCEPTION_IN_PAGE_ERROR:
    return "In-page error";
  case 0xE06D7363:
    return "Unhandled C++ exception";
  default:
    return "Unhandled exception";
  }
}

// "Qt6Quick.dll+0x1a2b3": with the module's PDB this pins the exact line
void moduleOffset(DWORD64 address, char *out, size_t size) {
  HMODULE module = nullptr;
  char path[MAX_PATH] = "?";
  if (GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                             GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                         reinterpret_cast<LPCSTR>(address), &module)) {
    GetModuleFileNameA(module, path, MAX_PATH);
    std::snprintf(out, size, "%s+0x%llx", fileName(path),
                  address - reinterpret_cast<DWORD64>(module));
  } else {
    std::snprintf(out, size, "0x%llx", address);
  }
}

void writeStack(FILE *f, CONTEXT context) {
#if defined(_M_X64)
  HANDLE process = GetCurrentProcess();
  SymSetOptions(SYMOPT_UNDNAME | SYMOPT_DEFERRED_LOADS);
  SymInitialize(process, nullptr, TRUE);
  STACKFRAME64 frame = {};
  frame.AddrPC.Offset = context.Rip;
  frame.AddrPC.Mode = AddrModeFlat;
  frame.AddrFrame.Offset = context.Rbp;
  frame.AddrFrame.Mode = AddrModeFlat;
  frame.AddrStack.Offset = context.Rsp;
  frame.AddrStack.Mode = AddrModeFlat;
  alignas(SYMBOL_INFO) char buffer[sizeof(SYMBOL_INFO) + 256];
  auto *symbol = reinterpret_cast<SYMBOL_INFO *>(buffer);
  for (int i = 0; i < 64; ++i) {
    if (!StackWalk64(IMAGE_FILE_MACHINE_AMD64, process, GetCurrentThread(),
                     &frame, &context, nullptr, SymFunctionTableAccess64,
                     SymGetModuleBase64, nullptr) ||
        !frame.AddrPC.Offset)
      break;
    char where[MAX_PATH + 32];
    moduleOffset(frame.AddrPC.Offset, where, sizeof where);
    std::memset(buffer, 0, sizeof buffer);
    symbol->SizeOfStruct = sizeof(SYMBOL_INFO);
    symbol->MaxNameLen = 255;
    DWORD64 displacement = 0;
    // Only exported names without PDBs, so it can be a neighbour of the real
    // function
    if (SymFromAddr(process, frame.AddrPC.Offset, &displacement, symbol))
      std::fprintf(f, "  #%02d %s (near %s+0x%llx)\n", i, where, symbol->Name,
                   displacement);
    else
      std::fprintf(f, "  #%02d %s\n", i, where);
  }
  SymCleanup(process);
#else
  (void)context;
  std::fprintf(f, "  (stack walk only on x64)\n");
#endif
}

#endif

[[noreturn]] void crash(const char *reason, void *exceptionPointers) {
  State &s = state();
  if (s.crashing.test_and_set()) {
    for (;;) {
#ifdef _WIN32
      Sleep(INFINITE);
#else
      pause();
#endif
    }
  }

  char stamp[32];
  std::time_t now = std::time(nullptr);
  std::strftime(stamp, sizeof stamp, "%Y%m%d-%H%M%S", std::localtime(&now));
  char logPath[1024];
  std::snprintf(logPath, sizeof logPath, "%s/crash-%s.log", s.dir.c_str(),
                stamp);

#ifdef _WIN32
  auto *pointers = static_cast<EXCEPTION_POINTERS *>(exceptionPointers);
  std::wstring wlog = s.wdir + L"\\crash-" +
                      std::wstring(stamp, stamp + std::strlen(stamp)) + L".log";
  FILE *f = _wfopen(wlog.c_str(), L"w");
#else
  (void)exceptionPointers;
  FILE *f = std::fopen(logPath, "w");
#endif
  if (f) {
    std::fprintf(f, "Wallpaper Browser %s crashed\n", s.version.c_str());
    std::fprintf(f, "Time: %s\nQt: %s\nReason: %s\n\nStack:\n", stamp,
                 qVersion(), reason);
#ifdef _WIN32
    CONTEXT context = {};
    if (pointers && pointers->ContextRecord)
      context = *pointers->ContextRecord;
    else
      RtlCaptureContext(&context);
    writeStack(f, context);
#else
    std::fflush(f);
    void *frames[64];
    backtrace_symbols_fd(frames, backtrace(frames, 64), fileno(f));
#endif
    std::fprintf(f, "\nLast messages:\n");
    // Skipped if the crash happened while a message was being logged
    if (s.mutex.try_lock()) {
      for (const std::string &line : s.recent)
        std::fprintf(f, "  %s\n", line.c_str());
      s.mutex.unlock();
    }
    std::fclose(f);
  }

#ifdef _WIN32
  // A minidump opens in WinDbg or Visual Studio at the crash, with every
  // thread's stack
  std::wstring wdump = s.wdir + L"\\crash-" +
                       std::wstring(stamp, stamp + std::strlen(stamp)) +
                       L".dmp";
  HANDLE dump = CreateFileW(wdump.c_str(), GENERIC_WRITE, 0, nullptr,
                            CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (dump != INVALID_HANDLE_VALUE) {
    MINIDUMP_EXCEPTION_INFORMATION info = {GetCurrentThreadId(), pointers,
                                           FALSE};
    MiniDumpWriteDump(GetCurrentProcess(), GetCurrentProcessId(), dump,
                      MINIDUMP_TYPE(MiniDumpWithThreadInfo |
                                    MiniDumpWithIndirectlyReferencedMemory),
                      pointers ? &info : nullptr, nullptr, nullptr);
    CloseHandle(dump);
  }

  wchar_t text[2048];
  _snwprintf_s(
      text, _TRUNCATE,
      L"Wallpaper Browser ran into a fatal error and has to close.\n\n%hs\n\n"
      L"A crash report was saved to:\n%ls\n\nOpen the folder?",
      reason, wlog.c_str());
  // Shown from the crashing thread: it runs its own message loop, so it works
  // even when the UI thread is the one that's stuck
  if (MessageBoxW(nullptr, text, L"Wallpaper Browser crashed",
                  MB_YESNO | MB_ICONERROR | MB_TOPMOST | MB_SETFOREGROUND) ==
      IDYES) {
    std::wstring args = L"/select,\"" + wlog + L"\"";
    ShellExecuteW(nullptr, L"open", L"explorer.exe", args.c_str(), nullptr,
                  SW_SHOWNORMAL);
  }
  TerminateProcess(GetCurrentProcess(), 1);
#endif
  std::fprintf(stderr, "Wallpaper Browser crashed: %s\nReport: %s\n", reason,
               logPath);
  std::_Exit(1);
}

#ifdef _WIN32

LONG WINAPI onException(EXCEPTION_POINTERS *e) {
  char reason[512];
  char where[MAX_PATH + 32];
  const DWORD code = e->ExceptionRecord->ExceptionCode;
  moduleOffset(reinterpret_cast<DWORD64>(e->ExceptionRecord->ExceptionAddress),
               where, sizeof where);
  std::snprintf(reason, sizeof reason, "%s (0x%08lX) at %s",
                exceptionName(code), code, where);
  crash(reason, e);
}

void onPureCall() { crash("Pure virtual function call", nullptr); }

void onInvalidParameter(const wchar_t *, const wchar_t *, const wchar_t *,
                        unsigned int, uintptr_t) {
  crash("Invalid parameter passed to a C runtime function", nullptr);
}

#endif

void onSignal(int signal) {
  State &s = state();
  char reason[640];
  if (signal == SIGABRT && s.lastFatal[0])
    std::snprintf(reason, sizeof reason, "Qt fatal error: %s", s.lastFatal);
  else
    std::snprintf(reason, sizeof reason, "%s",
                  signal == SIGABRT   ? "Aborted"
                  : signal == SIGSEGV ? "Segmentation fault"
                  : signal == SIGFPE  ? "Floating point exception"
                                      : "Illegal instruction");
#ifndef _WIN32
  // Hand the signal back so the system still gets its core dump, unless a
  // dialog ended it first
  std::signal(signal, SIG_DFL);
#endif
  crash(reason, nullptr);
}

void onTerminate() {
  char reason[512] = "Unhandled C++ exception";
  if (auto current = std::current_exception()) {
    try {
      std::rethrow_exception(current);
    } catch (const std::exception &e) {
      std::snprintf(reason, sizeof reason, "Unhandled C++ exception: %s",
                    e.what());
    } catch (...) {
    }
  }
  crash(reason, nullptr);
}

} // namespace

void installCrashHandler(const QString &logDir, const QString &version) {
  State &s = state();
  QDir().mkpath(logDir);
  s.dir = QDir::toNativeSeparators(logDir).toStdString();
  s.version = version.toStdString();
#ifdef _WIN32
  s.wdir = QDir::toNativeSeparators(logDir).toStdWString();
  s.log = _wfopen((s.wdir + L"\\latest.log").c_str(), L"w");
  SetUnhandledExceptionFilter(onException);
  _set_purecall_handler(onPureCall);
  _set_invalid_parameter_handler(onInvalidParameter);
#ifdef _MSC_VER
  // abort() shows no "Debug Error" box of its own, ours is enough
  _set_abort_behavior(0, _WRITE_ABORT_MSG | _CALL_REPORTFAULT);
#endif
#else
  s.log = std::fopen(
      (logDir + QStringLiteral("/latest.log")).toLocal8Bit().constData(), "w");
  std::signal(SIGSEGV, onSignal);
  std::signal(SIGBUS, onSignal);
  std::signal(SIGILL, onSignal);
  std::signal(SIGFPE, onSignal);
#endif
  std::signal(SIGABRT, onSignal);
  std::set_terminate(onTerminate);
  s.previous = qInstallMessageHandler(onMessage);
}

void reportFatal(const QString &message) {
  const QByteArray utf8 = message.toUtf8();
  crash(utf8.constData(), nullptr);
}

} // namespace wallpaper
